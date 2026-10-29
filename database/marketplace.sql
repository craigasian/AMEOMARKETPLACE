-- Additive marketplace schema. Existing CRM tables are deliberately preserved.
create schema if not exists marketplace_private;
revoke all on schema marketplace_private from public;
create table public.market_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 120),
 role text not null default 'client' check(role in ('client','pro','admin')),
 suspended boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.market_listings (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique references public.market_profiles(id),
 name text not null check(char_length(name) between 1 and 120),
 headline text not null check(char_length(headline) between 5 and 180),
 bio text not null check(char_length(bio) between 30 and 5000),
 category text not null check(category in ('Coaching','Team training','Implementation','AI strategy','Automation')),
 city text not null check(char_length(city) between 2 and 100),
 delivery text not null check(delivery in ('Remote','In person','Both')),
 hourly_rate numeric(10,2) not null check(hourly_rate between 0 and 10000),
 credentials text not null default '' check(char_length(credentials)<=3000),
 status text not null default 'pending' check(status in ('pending','approved','rejected','suspended')),
 created_at timestamptz not null default now()
);
create table public.market_projects (
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null references public.market_profiles(id),
 pro_id uuid not null references public.market_profiles(id),
 title text not null check(char_length(title) between 3 and 180),
 brief text not null check(char_length(brief) between 10 and 10000),
 scope text check(char_length(scope)<=10000),
 amount numeric(10,2) check(amount between 0 and 1000000),
 status text not null default 'requested' check(status in ('requested','quoted','accepted','declined','cancelled','completed')),
 created_at timestamptz not null default now(),
 check(client_id<>pro_id)
);
create table public.market_messages (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.market_projects(id),
 sender_id uuid not null references public.market_profiles(id),
 body text not null check(char_length(body) between 1 and 5000),
 created_at timestamptz not null default now()
);
create table public.market_bookings (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null unique references public.market_projects(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 status text not null default 'requested' check(status in ('requested','confirmed','cancelled','completed')),
 created_at timestamptz not null default now(),
 check(ends_at>starts_at and ends_at<=starts_at+interval '8 hours')
);
create table public.market_reviews (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null unique references public.market_projects(id),
 client_id uuid not null references public.market_profiles(id),
 pro_id uuid not null references public.market_profiles(id),
 rating integer not null check(rating between 1 and 5),
 body text not null check(char_length(body) between 5 and 2000),
 created_at timestamptz not null default now()
);
create table public.market_audit (
 id bigint generated always as identity primary key,
 actor_id uuid not null references public.market_profiles(id),
 action text not null, target_id uuid not null,
 created_at timestamptz not null default now()
);
create index on public.market_projects(client_id);
create index on public.market_projects(pro_id);
create index on public.market_messages(project_id,created_at);
create index on public.market_messages(sender_id);
create index on public.market_reviews(pro_id);
create index on public.market_reviews(client_id);
create index on public.market_audit(actor_id);
create index on public.market_listings(status,category,city);
create function marketplace_private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.market_profiles where id=auth.uid() and role='admin' and not suspended)
$$;
create function marketplace_private.is_active() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.market_profiles where id=auth.uid() and not suspended)
$$;
grant usage on schema marketplace_private to authenticated;
grant execute on function marketplace_private.is_admin(),marketplace_private.is_active() to authenticated;
revoke execute on function marketplace_private.is_admin(),marketplace_private.is_active() from public;
-- All mutations go through one explicitly authorized transactional endpoint.
revoke all on public.market_profiles,public.market_listings,public.market_projects,public.market_messages,public.market_bookings,public.market_reviews,public.market_audit from anon,authenticated;
grant select on public.market_listings,public.market_reviews to anon;
grant select on public.market_profiles,public.market_listings,public.market_projects,public.market_messages,public.market_bookings,public.market_reviews,public.market_audit to authenticated;
alter table public.market_profiles enable row level security;
alter table public.market_listings enable row level security;
alter table public.market_projects enable row level security;
alter table public.market_messages enable row level security;
alter table public.market_bookings enable row level security;
alter table public.market_reviews enable row level security;
alter table public.market_audit enable row level security;
create policy profiles_self on public.market_profiles for select to authenticated using(id=(select auth.uid()) or (select marketplace_private.is_admin()));
create policy listings_public on public.market_listings for select to anon using(status='approved');
create policy listings_members on public.market_listings for select to authenticated using(status='approved' or user_id=(select auth.uid()) or (select marketplace_private.is_admin()));
create policy projects_participants on public.market_projects for select to authenticated using((select marketplace_private.is_active()) and (client_id=(select auth.uid()) or pro_id=(select auth.uid()) or (select marketplace_private.is_admin())));
create policy messages_participants on public.market_messages for select to authenticated using(exists(select 1 from public.market_projects p where p.id=project_id));
create policy bookings_participants on public.market_bookings for select to authenticated using(exists(select 1 from public.market_projects p where p.id=project_id));
create policy reviews_public on public.market_reviews for select to anon,authenticated using(true);
create policy audit_admin on public.market_audit for select to authenticated using((select marketplace_private.is_admin()));
create function public.market_action(action text, payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); me public.market_profiles; p public.market_projects; b public.market_bookings; target uuid; result jsonb; s timestamptz; e timestamptz;
begin
 if uid is null then raise exception 'Sign in required'; end if;
 if not exists(select 1 from auth.users where id=uid and email_confirmed_at is not null) then raise exception 'Verify your email first'; end if;
 if action='profile' then
   insert into public.market_profiles(id,display_name) values(uid,trim(payload->>'display_name'))
   on conflict(id) do update set display_name=excluded.display_name;
   return jsonb_build_object('ok',true);
 end if;
 select * into me from public.market_profiles where id=uid;
 if me.id is null or me.suspended then raise exception 'Complete your profile or contact support'; end if;
 if action='apply' then
   insert into public.market_listings(user_id,name,headline,bio,category,city,delivery,hourly_rate,credentials)
   values(uid,trim(payload->>'name'),trim(payload->>'headline'),trim(payload->>'bio'),payload->>'category',trim(payload->>'city'),payload->>'delivery',(payload->>'hourly_rate')::numeric,coalesce(payload->>'credentials',''))
   on conflict(user_id) do update set name=excluded.name,headline=excluded.headline,bio=excluded.bio,category=excluded.category,city=excluded.city,delivery=excluded.delivery,hourly_rate=excluded.hourly_rate,credentials=excluded.credentials,status='pending'
   returning to_jsonb(market_listings.*) into result;
   update public.market_profiles set role='pro' where id=uid and role='client';
   return result;
 elsif action='moderate' then
   if not marketplace_private.is_admin() then raise exception 'Admin only'; end if;
   if payload->>'status' not in ('approved','rejected','suspended') then raise exception 'Invalid moderation status'; end if;
   update public.market_listings set status=payload->>'status' where id=(payload->>'id')::uuid returning id into target;
   if target is null then raise exception 'Listing not found'; end if;
   insert into public.market_audit(actor_id,action,target_id) values(uid,'listing_'||(payload->>'status'),target);
   return jsonb_build_object('ok',true);
 elsif action='suspend_user' then
   if not marketplace_private.is_admin() or (payload->>'id')::uuid=uid then raise exception 'Admin only; cannot suspend yourself'; end if;
   update public.market_profiles set suspended=(payload->>'suspended')::boolean where id=(payload->>'id')::uuid returning id into target;
   update public.market_listings set status='suspended' where user_id=target and (payload->>'suspended')::boolean;
   insert into public.market_audit(actor_id,action,target_id) values(uid,'user_suspended_'||(payload->>'suspended'),target);
   return jsonb_build_object('ok',true);
 elsif action='request' then
   target:=(payload->>'pro_id')::uuid;
   if target=uid or not exists(select 1 from public.market_listings l join public.market_profiles u on u.id=l.user_id where l.user_id=target and l.status='approved' and not u.suspended) then raise exception 'Choose an approved professional'; end if;
   insert into public.market_projects(client_id,pro_id,title,brief) values(uid,target,trim(payload->>'title'),trim(payload->>'brief')) returning to_jsonb(market_projects.*) into result;
   return result;
 end if;
 target:=(payload->>'project_id')::uuid;
 select * into p from public.market_projects where id=target for update;
 if p.id is null or (uid<>p.client_id and uid<>p.pro_id) then raise exception 'Project access denied'; end if;
 if not exists(select 1 from public.market_profiles where id=p.client_id and not suspended) or not exists(select 1 from public.market_profiles where id=p.pro_id and not suspended) then raise exception 'Participant unavailable'; end if;
 case action
 when 'message' then
   insert into public.market_messages(project_id,sender_id,body) values(p.id,uid,trim(payload->>'body')) returning to_jsonb(market_messages.*) into result;
 when 'quote' then
   if uid<>p.pro_id or p.status not in ('requested','quoted') then raise exception 'Quote cannot be changed'; end if;
   if payload->>'scope' is null or char_length(trim(payload->>'scope'))<10 or payload->>'amount' is null then raise exception 'Scope and amount required'; end if;
   update public.market_projects set scope=trim(payload->>'scope'),amount=(payload->>'amount')::numeric,status='quoted' where id=p.id;
 when 'accept','decline' then
   if uid<>p.client_id or p.status<>'quoted' then raise exception 'Only client can respond to a quote'; end if;
   update public.market_projects set status=case when action='accept' then 'accepted' else 'declined' end where id=p.id;
 when 'cancel' then
   if p.status in ('completed','cancelled','declined') then raise exception 'Project already closed'; end if;
   update public.market_projects set status='cancelled' where id=p.id;
   update public.market_bookings set status='cancelled' where project_id=p.id;
 when 'book' then
   if uid<>p.client_id or p.status<>'accepted' then raise exception 'Accept the quote before booking'; end if;
   s:=(payload->>'starts_at')::timestamptz; e:=(payload->>'ends_at')::timestamptz;
   if s is null or e is null or s<now() then raise exception 'Choose a future time'; end if;
   insert into public.market_bookings(project_id,starts_at,ends_at) values(p.id,s,e)
   on conflict(project_id) do update set starts_at=excluded.starts_at,ends_at=excluded.ends_at,status='requested' where market_bookings.status in ('requested','cancelled');
   if not found then raise exception 'Confirmed bookings must be cancelled before rescheduling'; end if;
 when 'confirm_booking' then
   if uid<>p.pro_id or p.status<>'accepted' then raise exception 'Professional confirmation required'; end if;
   perform pg_advisory_xact_lock(hashtextextended(p.pro_id::text,0));
   select * into b from public.market_bookings where project_id=p.id for update;
   if b.status<>'requested' or b.id is null or b.starts_at<now() then raise exception 'No future booking request'; end if;
   if exists(select 1 from public.market_bookings x join public.market_projects y on y.id=x.project_id where y.pro_id=p.pro_id and x.status='confirmed' and x.id<>b.id and tstzrange(x.starts_at,x.ends_at,'[)') && tstzrange(b.starts_at,b.ends_at,'[)')) then raise exception 'This time overlaps another confirmed booking'; end if;
   update public.market_bookings set status='confirmed' where id=b.id;
 when 'cancel_booking' then
   update public.market_bookings set status='cancelled' where project_id=p.id and status in ('requested','confirmed');
 when 'complete' then
   if uid<>p.client_id or p.status<>'accepted' then raise exception 'Only the client can confirm completed work'; end if;
   update public.market_projects set status='completed' where id=p.id;
   update public.market_bookings set status='completed' where project_id=p.id and status='confirmed';
 when 'review' then
   if uid<>p.client_id or p.status<>'completed' then raise exception 'Reviews require completed work'; end if;
   insert into public.market_reviews(project_id,client_id,pro_id,rating,body) values(p.id,uid,p.pro_id,(payload->>'rating')::integer,trim(payload->>'body')) returning to_jsonb(market_reviews.*) into result;
 else raise exception 'Unknown action';
 end case;
 return coalesce(result,jsonb_build_object('ok',true));
end $$;
revoke execute on function public.market_action(text,jsonb) from public,anon;
grant execute on function public.market_action(text,jsonb) to authenticated;
