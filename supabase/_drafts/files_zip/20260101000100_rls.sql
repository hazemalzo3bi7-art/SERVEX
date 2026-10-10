-- PROJECT_APP Row Level Security (DRAFT B5). Deny-by-default: RLS on, only listed policies allow.
-- Service role (server/Edge functions) bypasses RLS: use it ONLY for webhooks, expiry jobs, seed.

do $$ declare t text; begin
  foreach t in array array['profiles','customer_profiles','provider_profiles','provider_availability',
    'categories','services','provider_services','provider_portfolio','jobs','job_status_history',
    'allowed_job_transitions','inspections','quotes','payments','invoices','invoice_line_items',
    'ratings','notifications','audit_logs'] loop
    execute format('alter table %I enable row level security', t);
  end loop; end $$;

-- Column-level hardening: users may not self-edit role/status/verification/rating/etc.
revoke update on profiles, provider_profiles, jobs, notifications from authenticated;
grant update (full_name, avatar_url, email, phone) on profiles to authenticated;
grant update (bio, years_experience, city, base_lat, base_lng, service_radius_km, is_available) on provider_profiles to authenticated;
grant update (status, cancellation_reason) on jobs to authenticated;
grant update (read_at) on notifications to authenticated;

-- profiles
create policy profiles_select on profiles for select to authenticated using (
  id = auth.uid() or is_admin()
  or exists (select 1 from jobs j where (j.customer_id = auth.uid() and j.provider_id = profiles.id)
                                      or (j.provider_id = auth.uid() and j.customer_id = profiles.id))
  or exists (select 1 from provider_profiles pp where pp.user_id = profiles.id and pp.verification_status = 'approved'));
create policy profiles_insert on profiles for insert to authenticated
  with check (id = auth.uid() and role in ('customer','provider') and status = 'active');
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());

-- customer_profiles (private)
create policy cp_all on customer_profiles for all to authenticated
  using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid() or is_admin());

-- provider_profiles: approved ones are discoverable; owner sees own; admin sees all
create policy pp_select on provider_profiles for select to authenticated
  using (verification_status = 'approved' or user_id = auth.uid() or is_admin());
create policy pp_insert on provider_profiles for insert to authenticated
  with check (user_id = auth.uid() and verification_status = 'pending'
              and rating_avg = 0 and rating_count = 0 and completed_jobs = 0
              and exists (select 1 from profiles where id = auth.uid() and role = 'provider'));
create policy pp_update on provider_profiles for update to authenticated
  using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid() or is_admin());
-- NOTE: admins change verification_status via service role / admin RPC (column grant excludes it).

-- provider-owned child tables
create policy pa_select on provider_availability for select to authenticated using (true);
create policy pa_write  on provider_availability for all to authenticated
  using (provider_id = auth.uid() or is_admin()) with check (provider_id = auth.uid() or is_admin());
create policy ps_select on provider_services for select to authenticated using (true);
create policy ps_write  on provider_services for all to authenticated
  using (provider_id = auth.uid() or is_admin()) with check (provider_id = auth.uid() or is_admin());
create policy port_select on provider_portfolio for select to authenticated using (true);
create policy port_write  on provider_portfolio for all to authenticated
  using (provider_id = auth.uid() or is_admin()) with check (provider_id = auth.uid() or is_admin());

-- catalog: readable by everyone signed in, writable by admin only
create policy cat_select on categories for select to authenticated using (is_active or is_admin());
create policy cat_admin  on categories for all to authenticated using (is_admin()) with check (is_admin());
create policy svc_select on services for select to authenticated using (is_active or is_admin());
create policy svc_admin  on services for all to authenticated using (is_admin()) with check (is_admin());
create policy trans_select on allowed_job_transitions for select to authenticated using (true);

-- jobs: participants only. Transition legality is enforced by trigger enforce_job_rules.
create policy jobs_select on jobs for select to authenticated
  using (customer_id = auth.uid() or provider_id = auth.uid() or is_admin());
create policy jobs_insert on jobs for insert to authenticated
  with check (customer_id = auth.uid() and status = 'REQUESTED'
              and exists (select 1 from provider_services ps join provider_profiles pp on pp.user_id = ps.provider_id
                          where ps.provider_id = jobs.provider_id and ps.service_id = jobs.service_id
                            and pp.verification_status = 'approved'));
create policy jobs_update on jobs for update to authenticated
  using (customer_id = auth.uid() or provider_id = auth.uid() or is_admin())
  with check (customer_id = auth.uid() or provider_id = auth.uid() or is_admin());

create policy jsh_select on job_status_history for select to authenticated
  using (is_admin() or exists (select 1 from jobs j where j.id = job_id and (j.customer_id = auth.uid() or j.provider_id = auth.uid())));

-- inspections: provider writes only while job is ARRIVED/INSPECTION; both parties read
create policy insp_select on inspections for select to authenticated
  using (is_admin() or exists (select 1 from jobs j where j.id = job_id and (j.customer_id = auth.uid() or j.provider_id = auth.uid())));
create policy insp_insert on inspections for insert to authenticated
  with check (exists (select 1 from jobs j where j.id = job_id and j.provider_id = auth.uid() and j.status in ('ARRIVED','INSPECTION')));

-- quotes: provider edits ONLY while draft; customer reads once sent; approval via RPC below
create policy quotes_select on quotes for select to authenticated
  using (is_admin()
    or exists (select 1 from jobs j where j.id = job_id and j.provider_id = auth.uid())
    or (status <> 'draft' and exists (select 1 from jobs j where j.id = job_id and j.customer_id = auth.uid())));
create policy quotes_insert on quotes for insert to authenticated
  with check (status = 'draft' and exists (select 1 from jobs j where j.id = job_id and j.provider_id = auth.uid() and j.status = 'INSPECTION'));
create policy quotes_update on quotes for update to authenticated
  using (status = 'draft' and exists (select 1 from jobs j where j.id = job_id and j.provider_id = auth.uid()))
  with check (status in ('draft','sent') and exists (select 1 from jobs j where j.id = job_id and j.provider_id = auth.uid()));

-- payments / invoices: read-only for parties; writes only via service role (gateway webhook) or RPC
create policy pay_select on payments for select to authenticated
  using (is_admin() or exists (select 1 from jobs j where j.id = job_id and (j.customer_id = auth.uid() or j.provider_id = auth.uid())));
create policy inv_select on invoices for select to authenticated
  using (is_admin() or customer_id = auth.uid() or provider_id = auth.uid());
create policy ili_select on invoice_line_items for select to authenticated
  using (exists (select 1 from invoices i where i.id = invoice_id and (i.customer_id = auth.uid() or i.provider_id = auth.uid() or is_admin())));

-- ratings: own insert (trigger enforces COMPLETED + parties); parties read
create policy rat_select on ratings for select to authenticated
  using (rater_id = auth.uid() or ratee_id = auth.uid() or is_admin()
         or exists (select 1 from provider_profiles pp where pp.user_id = ratee_id and pp.verification_status = 'approved'));
create policy rat_insert on ratings for insert to authenticated with check (rater_id = auth.uid());

-- notifications: recipient only
create policy notif_select on notifications for select to authenticated using (recipient_id = auth.uid());
create policy notif_update on notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- audit logs: admin read only; inserts by service role
create policy audit_select on audit_logs for select to authenticated using (is_admin());

-- RPC: customer approves a sent quote (atomic, validated server-side)
create function approve_quote(p_quote_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare q quotes%rowtype; j jobs%rowtype;
begin
  select * into q from quotes where id = p_quote_id for update;
  if not found then raise exception 'quote not found'; end if;
  select * into j from jobs where id = q.job_id for update;
  if j.customer_id <> auth.uid() then raise exception 'not your job'; end if;
  if q.status <> 'sent' then raise exception 'quote is not awaiting approval'; end if;
  if q.expires_at is not null and q.expires_at < now() then raise exception 'quote expired'; end if;
  if j.status <> 'QUOTE_SENT' then raise exception 'job is not in QUOTE_SENT'; end if;
  update quotes set status = 'approved' where id = q.id;
  update jobs set status = 'AWAITING_PAYMENT' where id = j.id;  -- trigger validates + logs (actor=customer)
end $$;
revoke all on function approve_quote(uuid) from public;
grant execute on function approve_quote(uuid) to authenticated;
