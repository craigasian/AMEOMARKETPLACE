begin;
-- Entire fixture and every mutation roll back. No persistent test listings or accounts.
insert into auth.users(id,email,email_confirmed_at) values
 ('11111111-1111-4111-8111-111111111111','client@marketplace.test',now()),
 ('22222222-2222-4222-8222-222222222222','pro@marketplace.test',now()),
 ('33333333-3333-4333-8333-333333333333','stranger@marketplace.test',now()),
 ('44444444-4444-4444-8444-444444444444','admin@marketplace.test',now());
insert into public.market_profiles(id,display_name,role) values
 ('11111111-1111-4111-8111-111111111111','Test Client','client'),
 ('22222222-2222-4222-8222-222222222222','Test Pro','pro'),
 ('33333333-3333-4333-8333-333333333333','Test Stranger','client'),
 ('44444444-4444-4444-8444-444444444444','Test Admin','admin');
create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; end$$;
create function pg_temp.denied(action text,payload jsonb) returns boolean language plpgsql as $$begin perform public.market_action(action,payload);return false;exception when others then return true;end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.market_action('apply','{"name":"Test Pro","headline":"Practical AI training","bio":"Test professional with extensive experience in AI coaching.","category":"Coaching","city":"Irvine","delivery":"Both","hourly_rate":150,"credentials":"Test only"}');
select pg_temp.assert_true(pg_temp.denied('moderate',jsonb_build_object('id',(select id from market_listings where user_id=auth.uid()),'status','approved')),'pro cannot self-approve');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.market_profiles','UPDATE'),'no role escalation by direct update');
select pg_temp.assert_true(not has_function_privilege('anon','public.market_action(text,jsonb)','EXECUTE'),'anonymous RPC forbidden');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select pg_temp.assert_true((select count(*)=0 from market_listings),'pending hidden from clients');
select pg_temp.assert_true(pg_temp.denied('request','{"pro_id":"22222222-2222-4222-8222-222222222222","title":"Test","brief":"A test request for coaching"}'),'unapproved pro cannot receive requests');
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select public.market_action('moderate',jsonb_build_object('id',(select id from market_listings limit 1),'status','approved'));
select pg_temp.assert_true((select count(*)=1 from market_audit),'moderation audited');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.market_action('request','{"pro_id":"22222222-2222-4222-8222-222222222222","title":"Training project","brief":"Help our team build practical AI skills."}');
select public.market_action('message',jsonb_build_object('project_id',(select id from market_projects limit 1),'body','Hello, can you scope this?'));
select pg_temp.assert_true(pg_temp.denied('quote',jsonb_build_object('project_id',(select id from market_projects limit 1),'scope','Malicious client quote','amount',1)),'client cannot quote as pro');
select pg_temp.assert_true(pg_temp.denied('book',jsonb_build_object('project_id',(select id from market_projects limit 1),'starts_at',now()+interval '1 day','ends_at',now()+interval '1 day 1 hour')),'cannot book before quote acceptance');
select pg_temp.assert_true(pg_temp.denied('review',jsonb_build_object('project_id',(select id from market_projects limit 1),'rating',5,'body','Premature review')),'review before completion denied');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select pg_temp.assert_true((select count(*)=0 from market_projects),'stranger cannot read projects');
select pg_temp.assert_true((select count(*)=0 from market_messages),'stranger cannot read messages');
select pg_temp.assert_true((select count(*)=1 from market_profiles),'stranger sees only own account');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.market_action('quote',jsonb_build_object('project_id',(select id from market_projects limit 1),'scope','Two hours of team AI coaching','amount',300));
select pg_temp.assert_true(pg_temp.denied('accept',jsonb_build_object('project_id',(select id from market_projects limit 1))),'pro cannot accept own quote');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.market_action('accept',jsonb_build_object('project_id',(select id from market_projects limit 1)));
select public.market_action('book',jsonb_build_object('project_id',(select id from market_projects limit 1),'starts_at',now()+interval '2 days','ends_at',now()+interval '2 days 1 hour'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select pg_temp.assert_true((select count(*)=0 from market_bookings),'stranger cannot read bookings');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.market_action('confirm_booking',jsonb_build_object('project_id',(select id from market_projects limit 1)));
select pg_temp.assert_true(pg_temp.denied('complete',jsonb_build_object('project_id',(select id from market_projects limit 1))),'pro cannot confirm own completed work');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.market_action('complete',jsonb_build_object('project_id',(select id from market_projects limit 1)));
select public.market_action('review',jsonb_build_object('project_id',(select id from market_projects limit 1),'rating',5,'body','Useful coaching, test review.'));
select pg_temp.assert_true(pg_temp.denied('review',jsonb_build_object('project_id',(select id from market_projects limit 1),'rating',5,'body','Duplicate review denied')),'duplicate review denied');
select pg_temp.assert_true((select status='completed' from market_bookings limit 1),'booking completed');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.market_action('apply','{"name":"Edited Pro","headline":"Changed AI training","bio":"A changed professional profile must return for admin approval.","category":"Coaching","city":"Irvine","delivery":"Both","hourly_rate":160}');
select pg_temp.assert_true((select status='pending' from market_listings limit 1),'pro edits return to approval queue');
set local role anon;
select pg_temp.assert_true((select count(*)=0 from market_listings),'pending invisible to anonymous users');
select pg_temp.assert_true((select count(*)=1 from market_reviews),'completed reviews publicly readable');
reset role;
select 'PASS: all marketplace workflow and access assertions' as result;
rollback;
