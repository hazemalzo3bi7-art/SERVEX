-- 0004_functions.sql — helpers, search, and transactional RPCs.
-- All RPCs: SECURITY DEFINER + fixed search_path + explicit auth.uid() checks. Clients can NOT write jobs/quotes/payments/invoices/reviews directly.
-- Error contract: exception MESSAGE = ERR_UNAUTHENTICATED | ERR_FORBIDDEN | ERR_NOT_FOUND | ERR_VALIDATION | ERR_INVALID_STATE | ERR_INVALID_TRANSITION | ERR_CONFLICT | ERR_EXPIRED

create function _require_user() returns uuid language plpgsql stable as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'ERR_UNAUTHENTICATED' using detail = 'Sign in required'; end if;
  return v;
end $$;

create function _audit(p_action text, p_entity_type text, p_entity_id text, p_details jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into audit_logs (actor_id, action, entity_type, entity_id, details) values (auth.uid(), p_action, p_entity_type, p_entity_id, p_details)
$$;

-- ================= geo / availability / search =================
create function haversine_km(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

-- No schedule rows + is_available=true => treated as always available. Schedule is Asia/Amman local time.
create function provider_available_now(p_provider uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select pp.is_available and (
    not exists (select 1 from provider_availability a where a.provider_id = pp.user_id)
    or exists (select 1 from provider_availability a
               where a.provider_id = pp.user_id
                 and a.weekday = extract(dow from timezone('Asia/Amman', now()))::int
                 and timezone('Asia/Amman', now())::time between a.start_time and a.end_time))
  from provider_profiles pp where pp.user_id = p_provider
$$;

create function search_providers(
  p_service_id uuid, p_lat double precision, p_lng double precision,
  p_max_km numeric default 15, p_only_available boolean default true,
  p_sort text default 'distance', p_limit integer default 20, p_offset integer default 0)
returns table (provider_id uuid, full_name text, avatar_path text, bio text, years_experience smallint,
               rating_avg numeric, rating_count integer, completed_jobs integer, city city_code,
               distance_km numeric, eta_minutes integer, available_now boolean, base_visit_fee numeric)
language sql stable security definer set search_path = public as $$
  with base as (
    select pp.user_id, pr.full_name, pr.avatar_path, pp.bio, pp.years_experience, pp.rating_avg, pp.rating_count,
           pp.completed_jobs, pp.city, ps.base_visit_fee, pp.service_radius_km,
           haversine_km(p_lat, p_lng, pp.base_lat, pp.base_lng) as d
    from provider_services ps
    join provider_profiles pp on pp.user_id = ps.provider_id
    join profiles pr on pr.id = pp.user_id
    where ps.service_id = p_service_id and pp.verification_status = 'approved'
      and pr.status = 'active' and pp.base_lat is not null)
  select b.user_id, b.full_name, b.avatar_path, b.bio, b.years_experience, b.rating_avg, b.rating_count,
         b.completed_jobs, b.city, round(b.d::numeric, 2),
         ceil(b.d / setting_num('eta_speed_kmh', 30) * 60)::int,
         provider_available_now(b.user_id), b.base_visit_fee
  from base b
  where b.d <= least(p_max_km, b.service_radius_km)
    and (not p_only_available or provider_available_now(b.user_id))
  order by case when p_sort = 'rating' then -b.rating_avg end,
           case when p_sort = 'price' then b.base_visit_fee end,
           b.d
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0)
$$;

-- ================= jobs =================
create function create_job(
  p_service_id uuid, p_provider_id uuid, p_city city_code, p_neighborhood text,
  p_address_text text, p_lat double precision, p_lng double precision, p_problem_description text)
returns jobs language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_pp provider_profiles%rowtype; v_job jobs; v_open int;
begin
  if not exists (select 1 from profiles where id = v_uid and role = 'customer' and status = 'active') then
    raise exception 'ERR_FORBIDDEN' using detail = 'Only active customers can request services';
  end if;
  select * into v_pp from provider_profiles where user_id = p_provider_id;
  if not found or v_pp.verification_status <> 'approved'
     or not exists (select 1 from profiles where id = p_provider_id and status = 'active') then
    raise exception 'ERR_NOT_FOUND' using detail = 'Provider not available';
  end if;
  if not exists (select 1 from provider_services ps join services s on s.id = ps.service_id
                 where ps.provider_id = p_provider_id and ps.service_id = p_service_id and s.is_active) then
    raise exception 'ERR_VALIDATION' using detail = 'Provider does not offer this service';
  end if;
  if v_pp.city is distinct from p_city then
    raise exception 'ERR_VALIDATION' using detail = 'Provider does not serve this city';
  end if;
  if v_pp.base_lat is not null and haversine_km(p_lat, p_lng, v_pp.base_lat, v_pp.base_lng) > v_pp.service_radius_km then
    raise exception 'ERR_VALIDATION' using detail = 'Location is outside the provider service area';
  end if;
  if not provider_available_now(p_provider_id) then
    raise exception 'ERR_CONFLICT' using detail = 'Provider is currently unavailable';
  end if;
  if exists (select 1 from jobs where customer_id = v_uid and provider_id = p_provider_id and service_id = p_service_id
             and status not in ('COMPLETED','DECLINED','CANCELLED','EXPIRED')) then
    raise exception 'ERR_CONFLICT' using detail = 'You already have an open request with this provider for this service';
  end if;
  select count(*) into v_open from jobs where customer_id = v_uid and status not in ('COMPLETED','DECLINED','CANCELLED','EXPIRED');
  if v_open >= setting_num('max_open_requests_per_customer', 5) then
    raise exception 'ERR_CONFLICT' using detail = 'Too many open requests';
  end if;
  insert into jobs (customer_id, provider_id, service_id, problem_description, city, neighborhood, address_text, lat, lng)
  values (v_uid, p_provider_id, p_service_id, p_problem_description, p_city, p_neighborhood, p_address_text, p_lat, p_lng)
  returning * into v_job;
  return v_job;
end $$;

-- Handles the simple provider-driven steps. Dedicated RPCs own: QUOTE_SENT, AWAITING_PAYMENT, PAID, COMPLETED, CANCELLED, DISPUTED, EXPIRED.
create function transition_job(p_job_id uuid, p_to job_status, p_note text default null)
returns jobs language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs;
begin
  if p_to not in ('ACCEPTED','DECLINED','EN_ROUTE','ARRIVED','INSPECTION','IN_PROGRESS') then
    raise exception 'ERR_VALIDATION' using detail = 'Use the dedicated RPC for this target state';
  end if;
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_uid not in (v_job.customer_id, v_job.provider_id) and not is_admin() then
    raise exception 'ERR_FORBIDDEN' using detail = 'Not a participant of this job';
  end if;
  perform set_config('app.transition_note', coalesce(p_note, ''), true);
  update jobs set status = p_to where id = p_job_id returning * into v_job;   -- trigger validates actor + transition
  return v_job;
end $$;

create function cancel_job(p_job_id uuid, p_reason text) returns jobs
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs;
begin
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_uid not in (v_job.customer_id, v_job.provider_id) and not is_admin() then
    raise exception 'ERR_FORBIDDEN' using detail = 'Not a participant of this job';
  end if;
  if v_job.status = 'CANCELLED' then return v_job; end if;   -- idempotent
  if v_job.status = 'DISPUTED' then
    raise exception 'ERR_INVALID_STATE' using detail = 'Disputed jobs are closed via resolve_dispute';
  end if;
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'ERR_VALIDATION' using detail = 'A cancellation reason is required';
  end if;
  perform set_config('app.transition_note', trim(p_reason), true);
  update jobs set status = 'CANCELLED', cancellation_reason = trim(p_reason) where id = p_job_id returning * into v_job;
  update quotes set status = 'superseded' where job_id = p_job_id and status in ('draft','sent','approved');
  update payments set status = 'failed', failure_reason = 'JOB_CANCELLED' where job_id = p_job_id and status = 'pending';
  return v_job;
end $$;

-- ================= quotes =================
create function _validate_quote_totals(p_quote quotes) returns void language plpgsql stable security definer set search_path = public as $$
begin
  if p_quote.discount > p_quote.visit_fee + p_quote.subtotal then
    raise exception 'ERR_VALIDATION' using detail = 'Discount cannot exceed the quote subtotal';
  end if;
  if p_quote.total <= 0 then raise exception 'ERR_VALIDATION' using detail = 'Quote total must be greater than zero'; end if;
  if p_quote.total > setting_num('max_quote_total', 5000) then
    raise exception 'ERR_VALIDATION' using detail = 'Quote total exceeds the allowed maximum';
  end if;
end $$;

-- p_items: [{"kind":"labor|parts|additional","description":"...","quantity":1,"unit_price":12.5}, ...]. Replaces any existing DRAFT quote.
create function create_quote(p_job_id uuid, p_visit_fee numeric, p_discount numeric, p_items jsonb, p_notes text default null)
returns quotes language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs; v_quote quotes;
begin
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_job.provider_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the assigned provider can quote'; end if;
  if v_job.status not in ('INSPECTION','QUOTE_SENT') then
    raise exception 'ERR_INVALID_STATE' using detail = 'Quotes can only be created during INSPECTION (or to revise after a rejection)';
  end if;
  if not exists (select 1 from inspections where job_id = p_job_id) then
    raise exception 'ERR_INVALID_STATE' using detail = 'Submit the inspection before quoting';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 30 then
    raise exception 'ERR_VALIDATION' using detail = 'items must be an array of 1-30 entries';
  end if;
  if exists (select 1 from quotes where job_id = p_job_id and status in ('sent','approved')) then
    raise exception 'ERR_CONFLICT' using detail = 'A sent or approved quote already exists for this job';
  end if;
  delete from quotes where job_id = p_job_id and status = 'draft';
  insert into quotes (job_id, visit_fee, discount, notes) values (p_job_id, coalesce(p_visit_fee, 0), coalesce(p_discount, 0), p_notes)
  returning * into v_quote;
  begin
    insert into quote_items (quote_id, kind, description, quantity, unit_price, sort_order)
    select v_quote.id, x.kind, x.description, coalesce(x.quantity, 1), x.unit_price, (row_number() over ())::int
    from jsonb_to_recordset(p_items) as x(kind quote_item_kind, description text, quantity numeric, unit_price numeric);
  exception when invalid_text_representation or not_null_violation or check_violation then
    raise exception 'ERR_VALIDATION' using detail = 'Invalid quote item (kind, description, quantity, unit_price)';
  end;
  select * into v_quote from quotes where id = v_quote.id;
  perform _validate_quote_totals(v_quote);
  return v_quote;
end $$;

create function send_quote(p_quote_id uuid) returns quotes
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_q quotes; v_job jobs;
begin
  select * into v_q from quotes where id = p_quote_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Quote not found'; end if;
  select * into v_job from jobs where id = v_q.job_id for update;
  if v_job.provider_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the assigned provider can send this quote'; end if;
  if v_q.status = 'sent' then return v_q; end if;   -- idempotent
  if v_q.status <> 'draft' then raise exception 'ERR_INVALID_STATE' using detail = 'Only draft quotes can be sent'; end if;
  if v_job.status not in ('INSPECTION','QUOTE_SENT') then raise exception 'ERR_INVALID_STATE' using detail = 'Job is not awaiting a quote'; end if;
  perform _validate_quote_totals(v_q);
  update quotes set status = 'sent', sent_at = now(),
         expires_at = now() + make_interval(hours => setting_num('quote_validity_hours', 48)::int),
         commission_rate = setting_num('commission_rate', 0)
   where id = p_quote_id returning * into v_q;
  if v_job.status = 'INSPECTION' then
    update jobs set status = 'QUOTE_SENT' where id = v_job.id;
  else
    perform push_notification(v_job.customer_id, 'quote_received', 'Revised quote', 'You received a revised quote.', v_job.id);
  end if;
  return v_q;
end $$;

create function approve_quote(p_quote_id uuid) returns payments
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_q quotes; v_job jobs; v_pay payments; v_commission numeric;
begin
  select * into v_q from quotes where id = p_quote_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Quote not found'; end if;
  select * into v_job from jobs where id = v_q.job_id for update;
  if v_job.customer_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the customer can approve this quote'; end if;
  if v_q.status = 'approved' then   -- idempotent replay
    select * into v_pay from payments where job_id = v_job.id and status in ('pending','authorized','paid') limit 1;
    if found then return v_pay; end if;
    raise exception 'ERR_INVALID_STATE' using detail = 'Quote already approved but has no payment';
  end if;
  if v_q.status <> 'sent' then raise exception 'ERR_INVALID_STATE' using detail = 'Quote is not awaiting approval'; end if;
  if v_q.expires_at is not null and v_q.expires_at < now() then raise exception 'ERR_EXPIRED' using detail = 'Quote has expired'; end if;
  if v_job.status <> 'QUOTE_SENT' then raise exception 'ERR_INVALID_STATE' using detail = 'Job is not in QUOTE_SENT'; end if;
  perform _validate_quote_totals(v_q);
  update quotes set status = 'approved', approved_at = now() where id = v_q.id;
  update jobs set status = 'AWAITING_PAYMENT' where id = v_job.id;
  v_commission := round(v_q.total * coalesce(v_q.commission_rate, 0), 3);
  insert into payments (job_id, quote_id, mode, status, amount, commission_rate, platform_commission, provider_earnings)
  values (v_job.id, v_q.id, setting_text('payment_mode', 'prototype')::payment_mode, 'pending', v_q.total,
          coalesce(v_q.commission_rate, 0), v_commission, v_q.total - v_commission)
  returning * into v_pay;
  return v_pay;
end $$;

create function reject_quote(p_quote_id uuid, p_reason text default null) returns quotes
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_q quotes; v_job jobs;
begin
  select * into v_q from quotes where id = p_quote_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Quote not found'; end if;
  select * into v_job from jobs where id = v_q.job_id for update;
  if v_job.customer_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the customer can reject this quote'; end if;
  if v_q.status = 'rejected' then return v_q; end if;
  if v_q.status <> 'sent' then raise exception 'ERR_INVALID_STATE' using detail = 'Only sent quotes can be rejected'; end if;
  update quotes set status = 'rejected', rejected_at = now(), rejection_reason = nullif(trim(p_reason), '')
   where id = p_quote_id returning * into v_q;
  return v_q;
end $$;

-- ================= payment (PROTOTYPE) =================
-- p_simulate_failure lets the UI demo a declined payment; a fresh pending payment is created so the customer can retry with a NEW key.
create function pay_demo(p_job_id uuid, p_idempotency_key text, p_simulate_failure boolean default false)
returns payments language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs; v_pay payments;
begin
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_job.customer_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the customer can pay'; end if;
  if setting_text('payment_mode', 'prototype') <> 'prototype' then
    raise exception 'ERR_FORBIDDEN' using detail = 'Demo payments are disabled (payment_mode is not prototype)';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 64 then
    raise exception 'ERR_VALIDATION' using detail = 'idempotency_key must be 8-64 characters';
  end if;
  select * into v_pay from payments where job_id = p_job_id and idempotency_key = p_idempotency_key;
  if found then return v_pay; end if;   -- idempotent replay
  if exists (select 1 from payments where job_id = p_job_id and status = 'paid') then
    raise exception 'ERR_CONFLICT' using detail = 'This job is already paid';
  end if;
  if v_job.status <> 'AWAITING_PAYMENT' then raise exception 'ERR_INVALID_STATE' using detail = 'Job is not awaiting payment'; end if;
  select * into v_pay from payments where job_id = p_job_id and status = 'pending' for update;
  if not found then raise exception 'ERR_INVALID_STATE' using detail = 'No pending payment for this job'; end if;

  if p_simulate_failure then
    update payments set status = 'failed', failure_reason = 'DEMO_DECLINED', idempotency_key = p_idempotency_key,
           gateway_name = 'demo', mode = 'prototype' where id = v_pay.id returning * into v_pay;
    insert into payment_events (payment_id, event_type, payload) values (v_pay.id, 'payment.failed', '{"reason":"DEMO_DECLINED"}');
    insert into payments (job_id, quote_id, mode, status, amount, commission_rate, platform_commission, provider_earnings)
    values (v_pay.job_id, v_pay.quote_id, 'prototype', 'pending', v_pay.amount, v_pay.commission_rate, v_pay.platform_commission, v_pay.provider_earnings);
    return v_pay;
  end if;

  update payments set status = 'paid', paid_at = now(), idempotency_key = p_idempotency_key, gateway_name = 'demo',
         gateway_reference = 'DEMO-' || substr(v_pay.id::text, 1, 8), mode = 'prototype'
   where id = v_pay.id returning * into v_pay;
  insert into payment_events (payment_id, event_type, payload) values (v_pay.id, 'payment.succeeded', '{"simulated":true}');
  update jobs set status = 'PAID' where id = p_job_id;
  return v_pay;
end $$;

-- ================= completion / invoice =================
create function _issue_invoice(p_job_id uuid) returns invoices
language plpgsql security definer set search_path = public as $$
declare v_job jobs; v_q quotes; v_pay payments; v_inv invoices;
begin
  select * into v_inv from invoices where job_id = p_job_id;
  if found then return v_inv; end if;
  select * into v_job from jobs where id = p_job_id;
  select * into v_q from quotes where job_id = p_job_id and status = 'approved';
  if not found then raise exception 'ERR_INVALID_STATE' using detail = 'No approved quote to invoice'; end if;
  select * into v_pay from payments where job_id = p_job_id and status = 'paid';
  if not found then raise exception 'ERR_INVALID_STATE' using detail = 'No paid payment to invoice'; end if;
  insert into invoices (invoice_number, job_id, customer_id, provider_id, payment_id, status, subtotal, discount, total, paid_at)
  values ('INV-' || to_char(timezone('Asia/Amman', now()), 'YYYY') || '-' || lpad(nextval('invoice_number_seq')::text, 6, '0'),
          p_job_id, v_job.customer_id, v_job.provider_id, v_pay.id, 'paid',
          v_q.visit_fee + v_q.subtotal, v_q.discount, v_q.total, v_pay.paid_at)
  returning * into v_inv;
  if v_q.visit_fee > 0 then
    insert into invoice_line_items (invoice_id, kind, description, quantity, amount, sort_order)
    values (v_inv.id, 'visit_fee', 'Visit / inspection fee', 1, v_q.visit_fee, 0);
  end if;
  insert into invoice_line_items (invoice_id, kind, description, quantity, amount, sort_order)
  select v_inv.id, qi.kind::text::invoice_line_kind, qi.description, qi.quantity, qi.line_total, 10 + qi.sort_order
  from quote_items qi where qi.quote_id = v_q.id;
  if v_q.discount > 0 then
    insert into invoice_line_items (invoice_id, kind, description, quantity, amount, sort_order)
    values (v_inv.id, 'discount', 'Discount', 1, -v_q.discount, 1000);
  end if;
  return v_inv;
end $$;

create function complete_job(p_job_id uuid) returns invoices
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs;
begin
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_job.provider_id <> v_uid then raise exception 'ERR_FORBIDDEN' using detail = 'Only the assigned provider can complete the job'; end if;
  if v_job.status = 'COMPLETED' then return _issue_invoice(p_job_id); end if;   -- idempotent
  if v_job.status <> 'IN_PROGRESS' then raise exception 'ERR_INVALID_STATE' using detail = 'Job must be IN_PROGRESS'; end if;
  update jobs set status = 'COMPLETED' where id = p_job_id;
  update provider_profiles set completed_jobs = completed_jobs + 1 where user_id = v_job.provider_id;
  return _issue_invoice(p_job_id);
end $$;

-- ================= reviews =================
create function create_review(p_job_id uuid, p_score integer, p_comment text default null) returns reviews
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs; v_reviewee uuid; v_rev reviews;
begin
  select * into v_job from jobs where id = p_job_id;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_uid = v_job.customer_id then v_reviewee := v_job.provider_id;
  elsif v_uid = v_job.provider_id then v_reviewee := v_job.customer_id;
  else raise exception 'ERR_FORBIDDEN' using detail = 'Only participants can review'; end if;
  if p_score is null or p_score not between 1 and 5 then raise exception 'ERR_VALIDATION' using detail = 'score must be 1-5'; end if;
  if exists (select 1 from reviews where job_id = p_job_id and reviewer_id = v_uid) then
    raise exception 'ERR_CONFLICT' using detail = 'You already reviewed this job';
  end if;
  insert into reviews (job_id, reviewer_id, reviewee_id, score, comment)   -- trigger enforces COMPLETED + window
  values (p_job_id, v_uid, v_reviewee, p_score, nullif(trim(p_comment), ''))
  returning * into v_rev;
  return v_rev;
end $$;

-- ================= disputes =================
create function open_dispute(p_job_id uuid, p_reason text, p_details text default null) returns disputes
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_job jobs; v_d disputes;
begin
  select * into v_job from jobs where id = p_job_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Job not found'; end if;
  if v_uid not in (v_job.customer_id, v_job.provider_id) then raise exception 'ERR_FORBIDDEN' using detail = 'Only participants can open a dispute'; end if;
  if v_job.status not in ('PAID','IN_PROGRESS','COMPLETED') then
    raise exception 'ERR_INVALID_STATE' using detail = 'Disputes are only possible after payment';
  end if;
  if v_job.status = 'COMPLETED' and v_job.completed_at < now() - make_interval(days => setting_num('dispute_window_days', 7)::int) then
    raise exception 'ERR_EXPIRED' using detail = 'Dispute window has closed';
  end if;
  perform set_config('app.transition_note', 'Dispute: ' || coalesce(p_reason, ''), true);
  update jobs set status = 'DISPUTED' where id = p_job_id;     -- trigger enforces who may do this
  insert into disputes (kind, job_id, opened_by, reason, details) values ('job_dispute', p_job_id, v_uid, p_reason, p_details)
  returning * into v_d;
  return v_d;
end $$;

-- p_outcome for job disputes: 'completed' | 'cancelled' (refunds a paid payment). For user reports: 'resolved' | 'dismissed'.
create function resolve_dispute(p_dispute_id uuid, p_outcome text, p_resolution text) returns disputes
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := _require_user(); v_d disputes; v_job jobs;
begin
  if not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'Admin only'; end if;
  if p_resolution is null or length(trim(p_resolution)) < 3 then raise exception 'ERR_VALIDATION' using detail = 'resolution text required'; end if;
  select * into v_d from disputes where id = p_dispute_id for update;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Dispute not found'; end if;
  if v_d.status in ('resolved','dismissed') then raise exception 'ERR_INVALID_STATE' using detail = 'Dispute already closed'; end if;

  if v_d.kind = 'user_report' then
    if p_outcome not in ('resolved','dismissed') then raise exception 'ERR_VALIDATION' using detail = 'outcome must be resolved or dismissed'; end if;
    update disputes set status = p_outcome::dispute_status, resolution = p_resolution, resolved_by = v_uid, resolved_at = now()
     where id = v_d.id returning * into v_d;
  else
    if p_outcome not in ('completed','cancelled') then raise exception 'ERR_VALIDATION' using detail = 'outcome must be completed or cancelled'; end if;
    select * into v_job from jobs where id = v_d.job_id for update;
    perform set_config('app.transition_note', 'Dispute resolved: ' || p_outcome, true);
    if p_outcome = 'completed' then
      update jobs set status = 'COMPLETED' where id = v_job.id;
      if not exists (select 1 from invoices where job_id = v_job.id) then
        update provider_profiles set completed_jobs = completed_jobs + 1 where user_id = v_job.provider_id;
      end if;
      perform _issue_invoice(v_job.id);
    else
      update payments set status = 'refunded', refunded_amount = amount where job_id = v_job.id and status = 'paid';
      update jobs set status = 'CANCELLED', cancellation_reason = 'Dispute resolved: ' || trim(p_resolution) where id = v_job.id;
    end if;
    update disputes set status = 'resolved', resolution = p_resolution, resolved_by = v_uid, resolved_at = now()
     where id = v_d.id returning * into v_d;
    perform push_notification(v_job.customer_id, 'dispute_resolved', 'Dispute resolved', 'The dispute on your job was resolved.', v_job.id);
    perform push_notification(v_job.provider_id, 'dispute_resolved', 'Dispute resolved', 'The dispute on your job was resolved.', v_job.id);
  end if;
  perform _audit('dispute.resolve', 'dispute', v_d.id::text, jsonb_build_object('outcome', p_outcome));
  return v_d;
end $$;

-- ================= system / admin =================
create function expire_stale_jobs() returns integer
language plpgsql security definer set search_path = public as $$
declare v_count integer := 0; r record;
begin
  if auth.uid() is not null and not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'System or admin only'; end if;
  perform set_config('app.transition_note', 'auto-expired', true);
  for r in select id from jobs where status = 'REQUESTED'
           and created_at < now() - make_interval(mins => setting_num('request_expiry_minutes', 15)::int) for update skip locked loop
    update jobs set status = 'EXPIRED' where id = r.id;
    v_count := v_count + 1;
  end loop;
  for r in select j.id as job_id, q.id as quote_id from jobs j join quotes q on q.job_id = j.id
           where j.status = 'QUOTE_SENT' and q.status = 'sent' and q.expires_at < now() for update of j skip locked loop
    update quotes set status = 'expired' where id = r.quote_id;
    update jobs set status = 'EXPIRED' where id = r.job_id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

create function admin_set_provider_verification(p_provider_id uuid, p_status verification_status, p_note text default null) returns provider_profiles
language plpgsql security definer set search_path = public as $$
declare v_pp provider_profiles;
begin
  if not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'Admin only'; end if;
  update provider_profiles set verification_status = p_status, verified_at = case when p_status = 'approved' then now() end
   where user_id = p_provider_id returning * into v_pp;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Provider not found'; end if;
  perform _audit('provider.verification', 'provider', p_provider_id::text, jsonb_build_object('status', p_status, 'note', p_note));
  return v_pp;
end $$;

create function admin_set_account_status(p_user_id uuid, p_status account_status, p_reason text) returns profiles
language plpgsql security definer set search_path = public as $$
declare v_p profiles;
begin
  if not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'Admin only'; end if;
  if p_user_id = auth.uid() then raise exception 'ERR_VALIDATION' using detail = 'Admins cannot change their own status'; end if;
  if p_reason is null or length(trim(p_reason)) < 3 then raise exception 'ERR_VALIDATION' using detail = 'reason required'; end if;
  update profiles set status = p_status, deleted_at = case when p_status = 'deleted' then now() end where id = p_user_id returning * into v_p;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'User not found'; end if;
  perform _audit('account.status', 'profile', p_user_id::text, jsonb_build_object('status', p_status, 'reason', p_reason));
  return v_p;
end $$;

create function admin_moderate_review(p_review_id uuid, p_visible boolean, p_reason text) returns reviews
language plpgsql security definer set search_path = public as $$
declare v_r reviews;
begin
  if not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'Admin only'; end if;
  update reviews set is_visible = p_visible where id = p_review_id returning * into v_r;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Review not found'; end if;
  perform _audit('review.moderate', 'review', p_review_id::text, jsonb_build_object('visible', p_visible, 'reason', p_reason));
  return v_r;
end $$;

create function admin_update_setting(p_key text, p_value jsonb) returns app_settings
language plpgsql security definer set search_path = public as $$
declare v_s app_settings;
begin
  if not is_admin() then raise exception 'ERR_FORBIDDEN' using detail = 'Admin only'; end if;
  if p_key = 'commission_rate' and (jsonb_typeof(p_value) <> 'number' or (p_value #>> '{}')::numeric not between 0 and 1) then
    raise exception 'ERR_VALIDATION' using detail = 'commission_rate must be a number between 0 and 1';
  end if;
  if p_key = 'payment_mode' and (p_value #>> '{}') not in ('prototype','gateway') then
    raise exception 'ERR_VALIDATION' using detail = 'payment_mode must be prototype or gateway';
  end if;
  update app_settings set value = p_value, updated_by = auth.uid() where key = p_key returning * into v_s;
  if not found then raise exception 'ERR_NOT_FOUND' using detail = 'Unknown setting'; end if;
  perform _audit('setting.update', 'setting', p_key, jsonb_build_object('value', p_value));
  return v_s;
end $$;
