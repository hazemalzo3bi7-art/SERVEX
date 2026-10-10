-- 0005_rls.sql — least-privilege grants + Row Level Security. Deny by default.
-- Clients (role `authenticated`) read via RLS and WRITE ONLY where explicitly granted below; everything transactional goes through RPCs.
-- `anon` gets nothing. `service_role` (server only) bypasses RLS — never ship its key in the app.

-- ---------- RLS helper functions (SECURITY DEFINER avoids policy recursion) ----------
create function safe_uuid(p text) returns uuid language sql immutable as $$
  select case when p ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then p::uuid end
$$;
create function is_job_party(p_job uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from jobs where id = p_job and auth.uid() in (customer_id, provider_id))
$$;
create function is_job_provider(p_job uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from jobs where id = p_job and provider_id = auth.uid())
$$;
create function is_job_customer(p_job uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from jobs where id = p_job and customer_id = auth.uid())
$$;
create function provider_visible(p_user uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from provider_profiles pp join profiles p on p.id = pp.user_id
                 where pp.user_id = p_user and pp.verification_status = 'approved' and p.status = 'active')
$$;
create function shares_job_with(p_user uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from jobs where (customer_id = auth.uid() and provider_id = p_user)
                                       or (provider_id = auth.uid() and customer_id = p_user))
$$;

-- ---------- enable RLS everywhere ----------
do $$ declare t text; begin
  foreach t in array array['profiles','customer_profiles','provider_profiles','provider_specialties','provider_service_areas',
    'provider_availability','provider_services','provider_portfolio','categories','services','app_settings','jobs',
    'job_status_history','allowed_job_transitions','inspections','inspection_photos','quotes','quote_items','payments',
    'payment_events','invoices','invoice_line_items','reviews','disputes','notifications','audit_logs'] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- ---------- grants ----------
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;

grant select on profiles, customer_profiles, provider_profiles, provider_specialties, provider_service_areas,
  provider_availability, provider_services, provider_portfolio, categories, services, jobs, job_status_history,
  allowed_job_transitions, inspections, inspection_photos, quotes, quote_items, payments, payment_events, invoices,
  invoice_line_items, reviews, disputes, notifications, audit_logs to authenticated;

grant insert on profiles, customer_profiles, provider_profiles, provider_specialties, provider_service_areas,
  provider_availability, provider_services, provider_portfolio, inspections, inspection_photos, disputes,
  categories, services to authenticated;
grant delete on provider_specialties, provider_service_areas, provider_availability, provider_services,
  provider_portfolio, inspection_photos to authenticated;

-- column-level UPDATE: users can never self-edit role/status/verification/ratings/counters
grant update (full_name, avatar_path, email, preferred_language) on profiles to authenticated;
grant update (default_city, default_neighborhood, default_address, default_lat, default_lng, preferences) on customer_profiles to authenticated;
grant update (bio, years_experience, city, base_lat, base_lng, service_radius_km, is_available) on provider_profiles to authenticated;
grant update (weekday, start_time, end_time) on provider_availability to authenticated;
grant update (base_visit_fee) on provider_services to authenticated;
grant update (title, description, work_date) on provider_portfolio to authenticated;
grant update (findings, recommended_work, provider_notes, estimated_duration_minutes) on inspections to authenticated;
grant update (read_at) on notifications to authenticated;
grant update on categories, services to authenticated;   -- admin-only via policy

-- RPC + helper execute rights
grant execute on function is_admin(), safe_uuid(text), is_job_party(uuid), is_job_provider(uuid), is_job_customer(uuid),
  provider_visible(uuid), shares_job_with(uuid) to authenticated;
grant execute on function
  search_providers(uuid, double precision, double precision, numeric, boolean, text, integer, integer),
  create_job(uuid, uuid, city_code, text, text, double precision, double precision, text),
  transition_job(uuid, job_status, text), cancel_job(uuid, text),
  create_quote(uuid, numeric, numeric, jsonb, text), send_quote(uuid), approve_quote(uuid), reject_quote(uuid, text),
  pay_demo(uuid, text, boolean), complete_job(uuid), create_review(uuid, integer, text),
  open_dispute(uuid, text, text), resolve_dispute(uuid, text, text),
  admin_set_provider_verification(uuid, verification_status, text), admin_set_account_status(uuid, account_status, text),
  admin_moderate_review(uuid, boolean, text), admin_update_setting(text, jsonb) to authenticated;
grant execute on function expire_stale_jobs() to service_role;   -- cron / Edge Function only

-- ---------- profiles ----------
create policy profiles_select on profiles for select to authenticated
  using (id = auth.uid() or is_admin() or shares_job_with(id) or provider_visible(id));
create policy profiles_insert on profiles for insert to authenticated
  with check (id = auth.uid() and role in ('customer','provider') and status = 'active' and phone is null);
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ---------- customer profiles (private) ----------
create policy cp_select on customer_profiles for select to authenticated using (user_id = auth.uid() or is_admin());
create policy cp_insert on customer_profiles for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'customer'));
create policy cp_update on customer_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- provider profile (public when approved) ----------
create policy pp_select on provider_profiles for select to authenticated
  using (verification_status = 'approved' or user_id = auth.uid() or is_admin());
create policy pp_insert on provider_profiles for insert to authenticated
  with check (user_id = auth.uid() and verification_status = 'pending' and rating_avg = 0 and rating_count = 0
              and completed_jobs = 0 and is_available = false
              and exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'provider'));
create policy pp_update on provider_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- provider-owned child tables: visible when provider is approved/own/admin; writable only by the owner ----------
do $$ declare t text; begin
  foreach t in array array['provider_specialties','provider_service_areas','provider_availability','provider_services','provider_portfolio'] loop
    execute format('create policy %I on %I for select to authenticated using (provider_visible(provider_id) or provider_id = auth.uid() or is_admin())', t || '_select', t);
    execute format('create policy %I on %I for insert to authenticated with check (provider_id = auth.uid())', t || '_insert', t);
    execute format('create policy %I on %I for delete to authenticated using (provider_id = auth.uid())', t || '_delete', t);
  end loop;
end $$;
create policy provider_availability_update on provider_availability for update to authenticated using (provider_id = auth.uid()) with check (provider_id = auth.uid());
create policy provider_services_update     on provider_services     for update to authenticated using (provider_id = auth.uid()) with check (provider_id = auth.uid());
create policy provider_portfolio_update    on provider_portfolio    for update to authenticated using (provider_id = auth.uid()) with check (provider_id = auth.uid());

-- ---------- catalog: readable by all signed-in users, writable by admin ----------
create policy categories_select on categories for select to authenticated using (is_active or is_admin());
create policy categories_insert on categories for insert to authenticated with check (is_admin());
create policy categories_update on categories for update to authenticated using (is_admin()) with check (is_admin());
create policy services_select on services for select to authenticated using (is_active or is_admin());
create policy services_insert on services for insert to authenticated with check (is_admin());
create policy services_update on services for update to authenticated using (is_admin()) with check (is_admin());
create policy transitions_select on allowed_job_transitions for select to authenticated using (true);
-- app_settings: no policy for authenticated => invisible. Read/written only via definer functions (setting_num, admin_update_setting).

-- ---------- jobs: participants + admin READ ONLY; all writes via RPC ----------
create policy jobs_select on jobs for select to authenticated
  using (customer_id = auth.uid() or provider_id = auth.uid() or is_admin());
create policy jsh_select on job_status_history for select to authenticated
  using (is_admin() or is_job_party(job_id));

-- ---------- inspection (provider writes while job is INSPECTION; both parties read) ----------
create policy insp_select on inspections for select to authenticated using (is_admin() or is_job_party(job_id));
create policy insp_insert on inspections for insert to authenticated
  with check (is_job_provider(job_id) and exists (select 1 from jobs j where j.id = job_id and j.status = 'INSPECTION'));
create policy insp_update on inspections for update to authenticated
  using (is_job_provider(job_id) and exists (select 1 from jobs j where j.id = job_id and j.status = 'INSPECTION'))
  with check (is_job_provider(job_id));
create policy ip_select on inspection_photos for select to authenticated
  using (is_admin() or exists (select 1 from inspections i where i.id = inspection_id and is_job_party(i.job_id)));
create policy ip_insert on inspection_photos for insert to authenticated
  with check (exists (select 1 from inspections i join jobs j on j.id = i.job_id
                      where i.id = inspection_id and j.provider_id = auth.uid() and j.status = 'INSPECTION'));
create policy ip_delete on inspection_photos for delete to authenticated
  using (exists (select 1 from inspections i join jobs j on j.id = i.job_id
                 where i.id = inspection_id and j.provider_id = auth.uid() and j.status = 'INSPECTION'));

-- ---------- quotes / items: provider sees own incl. draft; customer sees only non-draft; writes via RPC ----------
create policy quotes_select on quotes for select to authenticated
  using (is_admin() or is_job_provider(job_id) or (status <> 'draft' and is_job_customer(job_id)));
create policy qi_select on quote_items for select to authenticated
  using (exists (select 1 from quotes q where q.id = quote_id));      -- inherits quotes visibility

-- ---------- money: read-only for parties; writes via RPC / service role ----------
create policy payments_select on payments for select to authenticated using (is_admin() or is_job_party(job_id));
create policy payment_events_select on payment_events for select to authenticated using (is_admin());
create policy invoices_select on invoices for select to authenticated
  using (customer_id = auth.uid() or provider_id = auth.uid() or is_admin());
create policy ili_select on invoice_line_items for select to authenticated
  using (exists (select 1 from invoices i where i.id = invoice_id));  -- inherits invoices visibility

-- ---------- reviews: created via RPC; visible to author, subject, admin; provider reviews public when provider approved ----------
create policy reviews_select on reviews for select to authenticated
  using (reviewer_id = auth.uid() or reviewee_id = auth.uid() or is_admin() or (is_visible and provider_visible(reviewee_id)));

-- ---------- disputes / reports ----------
create policy disputes_select on disputes for select to authenticated
  using (opened_by = auth.uid() or is_admin() or (job_id is not null and is_job_party(job_id)));
create policy disputes_insert_report on disputes for insert to authenticated
  with check (kind = 'user_report' and opened_by = auth.uid() and reported_user_id is not null
              and reported_user_id <> auth.uid() and status = 'open' and job_id is null);

-- ---------- notifications / audit ----------
create policy notif_select on notifications for select to authenticated using (recipient_id = auth.uid());
create policy notif_update on notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy audit_select on audit_logs for select to authenticated using (is_admin());
