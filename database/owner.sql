-- The owner email was explicitly designated by the user.
create function marketplace_private.assign_owner() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from auth.users where id=new.id and lower(email)='craigasian@gmail.com' and email_confirmed_at is not null) then new.role:='admin'; end if;
 return new;
end $$;
revoke all on function marketplace_private.assign_owner() from public,anon,authenticated;
create trigger market_verified_owner before insert on public.market_profiles for each row execute function marketplace_private.assign_owner();
