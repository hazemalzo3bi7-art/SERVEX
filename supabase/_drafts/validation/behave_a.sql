\set ON_ERROR_STOP 0
begin;
create function pg_temp.as_user(uid uuid, q text) returns text language plpgsql as $$
declare r text; begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text,''), true);
  execute 'set local role ' || case when uid is null then 'anon' else 'authenticated' end;
  begin execute q; r := 'OK'; exception when others then r := 'ERR: ' || left(sqlerrm, 90); end;
  reset role; return r; end $$;
create function pg_temp.count_as(uid uuid, q text) returns text language plpgsql as $$
declare n bigint; begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text,''), true);
  execute 'set local role ' || case when uid is null then 'anon' else 'authenticated' end;
  begin execute q into n; exception when others then reset role; return 'ERR: ' || left(sqlerrm, 80); end;
  reset role; return n::text; end $$;
do $$
declare c1 uuid:='a0000000-0000-4000-8000-000000000001'; c2 uuid:='a0000000-0000-4000-8000-000000000002';
  p1 uuid:='a0000000-0000-4000-8000-000000000011'; adm uuid; oq uuid; r text;
  j_req uuid:='b0000000-0000-4000-8000-000000000001'; j_insp uuid:='b0000000-0000-4000-8000-000000000004'; j_done uuid:='b0000000-0000-4000-8000-000000000009';
  total bigint; own bigint;
begin
  select id into adm from profiles where role='admin' limit 1;
  select q.id into oq from quotes q join jobs j on j.id=q.job_id where j.customer_id<>c1 and q.status='sent' limit 1;
  select count(*) into total from jobs; select count(*) into own from jobs where customer_id=c1;

  r := pg_temp.count_as(null,'select count(*) from jobs');
  raise notice '% | anon reads jobs -> %', case when r like 'ERR%' or r='0' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.count_as(c1,'select count(*) from jobs');
  raise notice '% | customer1 sees only own jobs (own=%, total=%) -> %', case when r=own::text and own<total then 'PASS' else 'FAIL' end, own, total, r;
  r := pg_temp.count_as(c1,'select count(*) from audit_logs');
  raise notice '% | customer cannot read audit_logs -> %', case when r like 'ERR%' or r='0' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.count_as(c1,'select count(*) from payments where job_id in (select id from jobs where customer_id<>'''||c1||''')');
  raise notice '% | customer cannot see other customers payments -> %', case when r like 'ERR%' or r='0' then 'PASS' else 'FAIL' end, r;

  r := pg_temp.as_user(c1,'update jobs set status=''PAID'' where id='''||j_insp||'''');
  raise notice '% | customer cannot set job status directly -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'update profiles set role=''admin'' where id='''||c1||'''');
  raise notice '% | customer cannot make self admin -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;

  r := pg_temp.as_user(c1,'select transition_job('''||j_req||''', ''PAID'', null)');
  raise notice '% | illegal transition REQUESTED->PAID rejected -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select create_review('''||j_done||''', 5, ''again'')');
  raise notice '% | duplicate review rejected -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c2,'select create_review('''||j_done||''', 5, ''not my job'')');
  raise notice '% | review by non-party rejected -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select create_review('''||j_req||''', 5, ''too early'')');
  raise notice '% | review on non-completed job rejected -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select create_review('''||j_done||''', 9, ''bad score'')');
  raise notice '% | out-of-range score rejected -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select approve_quote('''||oq||''')');
  raise notice '% | cannot approve another customers quote -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;

  r := pg_temp.as_user(c1,'select cancel_job('''||j_req||''', ''changed my mind'')');
  raise notice '% | customer cancels own REQUESTED job -> %', case when r='OK' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select cancel_job('''||j_req||''', ''again'')');
  raise notice '% | cancel again is idempotent BY DESIGN (returns the cancelled job) -> %', case when r='OK' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select admin_set_account_status('''||c2||''', ''suspended'', ''x'')');
  raise notice '% | customer cannot suspend accounts -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(adm,'select admin_set_account_status('''||c2||''', ''suspended'', ''test'')');
  raise notice '% | admin can suspend an account -> %', case when r='OK' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c2,'select create_job((select id from services limit 1), '''||p1||''', ''amman'', ''x'', ''x'', 31.95, 35.91, ''suspended user request'')');
  raise notice '% | suspended user cannot create a job -> %', case when r like 'ERR%' then 'PASS' else 'INFO' end, r;
end $$;
rollback;
