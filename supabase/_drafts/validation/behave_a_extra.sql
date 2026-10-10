\set ON_ERROR_STOP 0
begin;
create function pg_temp.as_user(uid uuid, q text) returns text language plpgsql as $$
declare r text; begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text,''), true);
  execute 'set local role authenticated';
  begin execute q; r := 'OK'; exception when others then r := 'ERR: ' || left(sqlerrm, 80); end;
  reset role; return r; end $$;
do $$
declare c1 uuid:='a0000000-0000-4000-8000-000000000001'; p1 uuid:='a0000000-0000-4000-8000-000000000011';
  j_done uuid:='b0000000-0000-4000-8000-000000000009'; r text; h1 bigint; h2 bigint;
begin
  r := pg_temp.as_user(p1,'update provider_profiles set verification_status=''approved'' where user_id='''||p1||'''');
  raise notice '% | provider cannot self-approve verification -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(p1,'update provider_profiles set rating_avg=5, completed_jobs=999 where user_id='''||p1||'''');
  raise notice '% | provider cannot edit own rating/job counters -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(p1,'update provider_profiles set bio=''new bio'' where user_id='''||p1||'''');
  raise notice '% | provider CAN edit own bio (sanity) -> %', case when r='OK' then 'PASS' else 'FAIL' end, r;
  r := pg_temp.as_user(c1,'select cancel_job('''||j_done||''', ''after completion'')');
  raise notice '% | customer cannot cancel a COMPLETED job -> %', case when r like 'ERR%' then 'PASS' else 'FAIL' end, r;
  select count(*) into h1 from job_status_history where job_id='b0000000-0000-4000-8000-000000000001';
  perform pg_temp.as_user(c1,'select cancel_job(''b0000000-0000-4000-8000-000000000001'', ''first cancel'')');
  perform pg_temp.as_user(c1,'select cancel_job(''b0000000-0000-4000-8000-000000000001'', ''second cancel'')');
  select count(*) into h2 from job_status_history where job_id='b0000000-0000-4000-8000-000000000001';
  raise notice '% | idempotent cancel writes exactly 1 history row (before=%, after=%)', case when h2=h1+1 then 'PASS' else 'FAIL' end, h1, h2;
end $$;
rollback;
