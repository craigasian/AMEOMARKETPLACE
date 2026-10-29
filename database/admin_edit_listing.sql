-- Additive migration: admin_edit_listing
-- Run this once in the Supabase SQL editor for project pxlheszgngeowjvzspvt.
-- Safe to re-run: uses CREATE OR REPLACE for the function only.

create or replace function public.market_action(action text, payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  me public.market_profiles;
  p public.market_projects;
  b public.market_bookings;
  target uuid;
  result jsonb;
  s timestamptz;
  e timestamptz;
  new_status text;
begin
  if uid is null then
    raise exception 'Sign in required';
  end if;
  if not exists (
    select 1 from auth.users where id = uid and email_confirmed_at is not null
  ) then
    raise exception 'Verify your email first';
  end if;

  -- Profile setup (no marketplace profile required yet)
  if action = 'profile' then
    insert into public.market_profiles (id, display_name)
    values (uid, trim(payload->>'display_name'))
    on conflict (id) do update set display_name = excluded.display_name;
    return jsonb_build_object('ok', true);
  end if;

  select * into me from public.market_profiles where id = uid;
  if me.id is null or me.suspended then
    raise exception 'Complete your profile or contact support';
  end if;

  -- Professional application (create or update → pending)
  if action = 'apply' then
    insert into public.market_listings (
      user_id, name, headline, bio, category, city, delivery, hourly_rate, credentials
    ) values (
      uid,
      trim(payload->>'name'),
      trim(payload->>'headline'),
      trim(payload->>'bio'),
      payload->>'category',
      trim(payload->>'city'),
      payload->>'delivery',
      (payload->>'hourly_rate')::numeric,
      coalesce(payload->>'credentials', '')
    )
    on conflict (user_id) do update set
      name = excluded.name,
      headline = excluded.headline,
      bio = excluded.bio,
      category = excluded.category,
      city = excluded.city,
      delivery = excluded.delivery,
      hourly_rate = excluded.hourly_rate,
      credentials = excluded.credentials,
      status = 'pending'
    returning to_jsonb(market_listings.*) into result;
    update public.market_profiles set role = 'pro' where id = uid and role = 'client';
    return result;

  -- Simple status moderation
  elsif action = 'moderate' then
    if not marketplace_private.is_admin() then
      raise exception 'Admin only';
    end if;
    if payload->>'status' not in ('approved', 'rejected', 'suspended') then
      raise exception 'Invalid moderation status';
    end if;
    update public.market_listings
      set status = payload->>'status'
      where id = (payload->>'id')::uuid
      returning id into target;
    if target is null then
      raise exception 'Listing not found';
    end if;
    insert into public.market_audit (actor_id, action, target_id)
    values (uid, 'listing_' || (payload->>'status'), target);
    return jsonb_build_object('ok', true);

  -- Full admin field edit (new)
  elsif action = 'admin_edit_listing' then
    if not marketplace_private.is_admin() then
      raise exception 'Admin only';
    end if;

    -- Optional status; default keeps current status unless explicitly supplied
    new_status := nullif(trim(payload->>'status'), '');
    if new_status is not null and new_status not in ('pending', 'approved', 'rejected', 'suspended') then
      raise exception 'Invalid status';
    end if;

    -- Validate required fields the same way the table constraints do
    if char_length(trim(payload->>'name')) not between 1 and 120 then
      raise exception 'Name must be 1–120 characters';
    end if;
    if char_length(trim(payload->>'headline')) not between 5 and 180 then
      raise exception 'Headline must be 5–180 characters';
    end if;
    if char_length(trim(payload->>'bio')) not between 30 and 5000 then
      raise exception 'Bio must be 30–5000 characters';
    end if;
    if payload->>'category' not in ('Coaching', 'Team training', 'Implementation', 'AI strategy', 'Automation') then
      raise exception 'Invalid category';
    end if;
    if char_length(trim(payload->>'city')) not between 2 and 100 then
      raise exception 'City must be 2–100 characters';
    end if;
    if payload->>'delivery' not in ('Remote', 'In person', 'Both') then
      raise exception 'Invalid delivery format';
    end if;
    if (payload->>'hourly_rate')::numeric not between 0 and 10000 then
      raise exception 'Hourly rate must be between 0 and 10000';
    end if;
    if char_length(coalesce(payload->>'credentials', '')) > 3000 then
      raise exception 'Credentials too long';
    end if;

    update public.market_listings set
      name         = trim(payload->>'name'),
      headline     = trim(payload->>'headline'),
      bio          = trim(payload->>'bio'),
      category     = payload->>'category',
      city         = trim(payload->>'city'),
      delivery     = payload->>'delivery',
      hourly_rate  = (payload->>'hourly_rate')::numeric,
      credentials  = coalesce(payload->>'credentials', ''),
      status       = coalesce(new_status, status)
    where id = (payload->>'id')::uuid
    returning to_jsonb(market_listings.*) into result;

    if result is null then
      raise exception 'Listing not found';
    end if;

    insert into public.market_audit (actor_id, action, target_id)
    values (
      uid,
      'listing_admin_edit' || case when new_status is not null then '_' || new_status else '' end,
      (payload->>'id')::uuid
    );

    return result;

  elsif action = 'suspend_user' then
    if not marketplace_private.is_admin() or (payload->>'id')::uuid = uid then
      raise exception 'Admin only; cannot suspend yourself';
    end if;
    update public.market_profiles
      set suspended = (payload->>'suspended')::boolean
      where id = (payload->>'id')::uuid
      returning id into target;
    update public.market_listings
      set status = 'suspended'
      where user_id = target and (payload->>'suspended')::boolean;
    insert into public.market_audit (actor_id, action, target_id)
    values (uid, 'user_suspended_' || (payload->>'suspended'), target);
    return jsonb_build_object('ok', true);

  elsif action = 'request' then
    target := (payload->>'pro_id')::uuid;
    if target = uid or not exists (
      select 1
      from public.market_listings l
      join public.market_profiles u on u.id = l.user_id
      where l.user_id = target and l.status = 'approved' and not u.suspended
    ) then
      raise exception 'Choose an approved professional';
    end if;
    insert into public.market_projects (client_id, pro_id, title, brief)
    values (uid, target, trim(payload->>'title'), trim(payload->>'brief'))
    returning to_jsonb(market_projects.*) into result;
    return result;
  end if;

  -- Project-scoped actions
  target := (payload->>'project_id')::uuid;
  select * into p from public.market_projects where id = target for update;
  if p.id is null or (uid <> p.client_id and uid <> p.pro_id) then
    raise exception 'Project access denied';
  end if;
  if not exists (select 1 from public.market_profiles where id = p.client_id and not suspended)
     or not exists (select 1 from public.market_profiles where id = p.pro_id and not suspended) then
    raise exception 'Participant unavailable';
  end if;

  case action
    when 'message' then
      insert into public.market_messages (project_id, sender_id, body)
      values (p.id, uid, trim(payload->>'body'))
      returning to_jsonb(market_messages.*) into result;
    when 'quote' then
      if uid <> p.pro_id or p.status not in ('requested', 'quoted') then
        raise exception 'Quote cannot be changed';
      end if;
      if payload->>'scope' is null
         or char_length(trim(payload->>'scope')) < 10
         or payload->>'amount' is null then
        raise exception 'Scope and amount required';
      end if;
      update public.market_projects
        set scope = trim(payload->>'scope'),
            amount = (payload->>'amount')::numeric,
            status = 'quoted'
        where id = p.id;
    when 'accept', 'decline' then
      if uid <> p.client_id or p.status <> 'quoted' then
        raise exception 'Only client can respond to a quote';
      end if;
      update public.market_projects
        set status = case when action = 'accept' then 'accepted' else 'declined' end
        where id = p.id;
    when 'cancel' then
      if p.status in ('completed', 'cancelled', 'declined') then
        raise exception 'Project already closed';
      end if;
      update public.market_projects set status = 'cancelled' where id = p.id;
      update public.market_bookings set status = 'cancelled' where project_id = p.id;
    when 'book' then
      if uid <> p.client_id or p.status <> 'accepted' then
        raise exception 'Accept the quote before booking';
      end if;
      s := (payload->>'starts_at')::timestamptz;
      e := (payload->>'ends_at')::timestamptz;
      if s is null or e is null or s < now() then
        raise exception 'Choose a future time';
      end if;
      insert into public.market_bookings (project_id, starts_at, ends_at)
      values (p.id, s, e)
      on conflict (project_id) do update
        set starts_at = excluded.starts_at,
            ends_at   = excluded.ends_at,
            status    = 'requested'
        where market_bookings.status in ('requested', 'cancelled');
      if not found then
        raise exception 'Confirmed bookings must be cancelled before rescheduling';
      end if;
    when 'confirm_booking' then
      if uid <> p.pro_id or p.status <> 'accepted' then
        raise exception 'Professional confirmation required';
      end if;
      perform pg_advisory_xact_lock(hashtextextended(p.pro_id::text, 0));
      select * into b from public.market_bookings where project_id = p.id for update;
      if b.status <> 'requested' or b.id is null or b.starts_at < now() then
        raise exception 'No future booking request';
      end if;
      if exists (
        select 1
        from public.market_bookings x
        join public.market_projects y on y.id = x.project_id
        where y.pro_id = p.pro_id
          and x.status = 'confirmed'
          and x.id <> b.id
          and tstzrange(x.starts_at, x.ends_at, '[)') && tstzrange(b.starts_at, b.ends_at, '[)')
      ) then
        raise exception 'This time overlaps another confirmed booking';
      end if;
      update public.market_bookings set status = 'confirmed' where id = b.id;
    when 'cancel_booking' then
      update public.market_bookings
        set status = 'cancelled'
        where project_id = p.id and status in ('requested', 'confirmed');
    when 'complete' then
      if uid <> p.client_id or p.status <> 'accepted' then
        raise exception 'Only the client can confirm completed work';
      end if;
      update public.market_projects set status = 'completed' where id = p.id;
      update public.market_bookings
        set status = 'completed'
        where project_id = p.id and status = 'confirmed';
    when 'review' then
      if uid <> p.client_id or p.status <> 'completed' then
        raise exception 'Reviews require completed work';
      end if;
      insert into public.market_reviews (project_id, client_id, pro_id, rating, body)
      values (
        p.id, uid, p.pro_id,
        (payload->>'rating')::integer,
        trim(payload->>'body')
      )
      returning to_jsonb(market_reviews.*) into result;
    else
      raise exception 'Unknown action';
  end case;

  return coalesce(result, jsonb_build_object('ok', true));
end;
$$;

-- Permissions stay the same
revoke execute on function public.market_action(text, jsonb) from public, anon;
grant execute on function public.market_action(text, jsonb) to authenticated;

comment on function public.market_action(text, jsonb) is
  'Single authorized mutation endpoint. Includes admin_edit_listing for full field updates by admins.';
