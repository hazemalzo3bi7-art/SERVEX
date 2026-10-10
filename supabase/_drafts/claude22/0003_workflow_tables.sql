-- 0003_workflow_tables.sql — jobs, state machine, inspection, quotes, payments, invoices, reviews, disputes, notifications, audit.
-- Error contract: business-rule violations raise exceptions whose MESSAGE is a stable code (ERR_*), DETAIL is human text.

-- ================= JOBS =================
create table jobs (
  id uuid primary key default gen_random_uuid(),
  job_number bigint generated always as identity unique,   -- human-friendly support reference
  customer_id uuid not null references profiles(id) on delete restrict,
  provider_id uuid not null references provider_profiles(user_id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  problem_description text not null check (length(trim(problem_description)) between 5 and 2000),
  city city_code not null,
  neighborhood text,
  address_text text not null check (length(trim(address_text)) between 3 and 300),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  status job_status not null default 'REQUESTED',
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by uuid references profiles(id),
  cancellation_reason text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (customer_id <> provider_id),
  check (status <> 'CANCELLED' or (cancelled_at is not null and cancellation_reason is not null))
);
create trigger trg_jobs_updated before update on jobs for each row execute function set_updated_at();
create index idx_jobs_customer on jobs (customer_id, created_at desc);
create index idx_jobs_provider on jobs (provider_id, status, created_at desc);
create index idx_jobs_open on jobs (status) where status not in ('COMPLETED','DECLINED','CANCELLED','EXPIRED');

create table job_status_history (
  id bigint generated always as identity primary key,
  job_id uuid not null references jobs(id) on delete cascade,
  from_status job_status,
  to_status job_status not null,
  changed_by uuid references profiles(id),     -- null = system
  actor_role text not null check (actor_role in ('customer','provider','admin','system')),
  note text,
  created_at timestamptz not null default now()
);
create index idx_jsh_job on job_status_history (job_id, created_at, id);

-- ================= STATE MACHINE (data-driven) =================
create table allowed_job_transitions (
  from_status job_status not null,
  to_status   job_status not null,
  actor text not null check (actor in ('customer','provider','system','admin')),
  primary key (from_status, to_status, actor)
);
-- 'admin' may perform ANY pair that exists here (any actor). See docs/JOB_STATE_MACHINE.md.
insert into allowed_job_transitions values
 ('REQUESTED','ACCEPTED','provider'),('REQUESTED','DECLINED','provider'),
 ('REQUESTED','CANCELLED','customer'),('REQUESTED','EXPIRED','system'),
 ('ACCEPTED','EN_ROUTE','provider'),
 ('ACCEPTED','CANCELLED','customer'),('ACCEPTED','CANCELLED','provider'),
 ('EN_ROUTE','ARRIVED','provider'),
 ('EN_ROUTE','CANCELLED','customer'),('EN_ROUTE','CANCELLED','provider'),
 ('ARRIVED','INSPECTION','provider'),
 ('ARRIVED','CANCELLED','customer'),('ARRIVED','CANCELLED','provider'),
 ('INSPECTION','QUOTE_SENT','provider'),
 ('INSPECTION','CANCELLED','customer'),('INSPECTION','CANCELLED','provider'),
 ('QUOTE_SENT','AWAITING_PAYMENT','customer'),
 ('QUOTE_SENT','CANCELLED','customer'),('QUOTE_SENT','CANCELLED','provider'),
 ('QUOTE_SENT','EXPIRED','system'),
 ('AWAITING_PAYMENT','PAID','customer'),   -- PROTOTYPE ONLY (pay_demo). Remove when payment_mode = gateway.
 ('AWAITING_PAYMENT','PAID','system'),     -- real gateway webhook (service role)
 ('AWAITING_PAYMENT','CANCELLED','customer'),
 ('PAID','IN_PROGRESS','provider'),
 ('PAID','DISPUTED','customer'),
 ('IN_PROGRESS','COMPLETED','provider'),
 ('IN_PROGRESS','DISPUTED','customer'),('IN_PROGRESS','DISPUTED','provider'),
 ('COMPLETED','DISPUTED','customer'),('COMPLETED','DISPUTED','provider'),
 ('DISPUTED','COMPLETED','admin'),('DISPUTED','CANCELLED','admin');

create function enforce_job_rules() returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_actor text;
begin
  if is_seed_bypass() then return new; end if;

  if tg_op = 'INSERT' then
    if new.status <> 'REQUESTED' then
      raise exception 'ERR_INVALID_STATE' using detail = 'New jobs must start as REQUESTED';
    end if;
    return new;
  end if;

  if new.customer_id <> old.customer_id or new.provider_id <> old.provider_id or new.service_id <> old.service_id then
    raise exception 'ERR_VALIDATION' using detail = 'Job parties and service are immutable';
  end if;
  if new.status = old.status then return new; end if;

  if v_uid is null then v_actor := 'system';
  elsif exists (select 1 from profiles where id = v_uid and role = 'admin' and status = 'active') then v_actor := 'admin';
  elsif v_uid = old.provider_id then v_actor := 'provider';
  elsif v_uid = old.customer_id then v_actor := 'customer';
  else raise exception 'ERR_FORBIDDEN' using detail = 'Not a participant of this job';
  end if;

  if not exists (select 1 from allowed_job_transitions t
                 where t.from_status = old.status and t.to_status = new.status
                   and (t.actor = v_actor or v_actor = 'admin')) then
    raise exception 'ERR_INVALID_TRANSITION'
      using detail = format('%s -> %s is not allowed for actor %s', old.status, new.status, v_actor);
  end if;

  -- data prerequisites (defence in depth; RPCs also validate)
  if new.status = 'ACCEPTED' and not exists (
       select 1 from provider_profiles pp join profiles p on p.id = pp.user_id
       where pp.user_id = new.provider_id and pp.verification_status = 'approved' and p.status = 'active') then
    raise exception 'ERR_FORBIDDEN' using detail = 'Provider is not approved/active';
  elsif new.status = 'QUOTE_SENT' and not (
       exists (select 1 from inspections where job_id = new.id)
       and exists (select 1 from quotes where job_id = new.id and status = 'sent')) then
    raise exception 'ERR_INVALID_STATE' using detail = 'QUOTE_SENT requires an inspection and a sent quote';
  elsif new.status = 'AWAITING_PAYMENT' and not exists (select 1 from quotes where job_id = new.id and status = 'approved') then
    raise exception 'ERR_INVALID_STATE' using detail = 'AWAITING_PAYMENT requires an approved quote';
  elsif new.status in ('PAID','COMPLETED') and not exists (select 1 from payments where job_id = new.id and status = 'paid') then
    raise exception 'ERR_INVALID_STATE' using detail = 'This state requires a paid payment';
  elsif new.status = 'CANCELLED' and (new.cancellation_reason is null or length(trim(new.cancellation_reason)) < 3) then
    raise exception 'ERR_VALIDATION' using detail = 'A cancellation reason is required';
  end if;

  if new.status = 'ACCEPTED'  then new.accepted_at := now(); end if;
  if new.status = 'COMPLETED' then new.completed_at := now(); end if;
  if new.status = 'CANCELLED' then new.cancelled_at := now(); new.cancelled_by := v_uid; end if;

  insert into job_status_history (job_id, from_status, to_status, changed_by, actor_role, note)
  values (new.id, old.status, new.status, v_uid, v_actor, nullif(current_setting('app.transition_note', true), ''));
  return new;
end $$;
create trigger trg_jobs_rules before insert or update on jobs for each row execute function enforce_job_rules();

create function log_job_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if is_seed_bypass() then return new; end if;
  insert into job_status_history (job_id, to_status, changed_by, actor_role)
  values (new.id, new.status, auth.uid(), 'customer');
  return new;
end $$;
create trigger trg_jobs_created after insert on jobs for each row execute function log_job_created();

-- ================= INSPECTION =================
create table inspections (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id) on delete cascade,
  findings text not null check (length(trim(findings)) >= 3),
  recommended_work text not null check (length(trim(recommended_work)) >= 3),
  provider_notes text,
  estimated_duration_minutes integer check (estimated_duration_minutes between 5 and 1440),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_insp_updated before update on inspections for each row execute function set_updated_at();

create table inspection_photos (          -- metadata only; the file lives in Storage bucket inspection-photos
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references inspections(id) on delete cascade,
  storage_path text not null unique,
  caption text check (length(caption) <= 200),
  content_type text not null check (content_type in ('image/jpeg','image/png','image/webp')),
  size_bytes integer not null check (size_bytes between 1 and 5242880),
  created_at timestamptz not null default now()
);
create index idx_ip_inspection on inspection_photos (inspection_id);
create function limit_inspection_photos() returns trigger language plpgsql as $$
begin
  if (select count(*) from inspection_photos where inspection_id = new.inspection_id) >= 10 then
    raise exception 'ERR_VALIDATION' using detail = 'Maximum 10 photos per inspection';
  end if;
  return new;
end $$;
create trigger trg_ip_limit before insert on inspection_photos for each row execute function limit_inspection_photos();

-- ================= QUOTES =================
create table quotes (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  status quote_status not null default 'draft',
  visit_fee numeric(10,3) not null default 0 check (visit_fee >= 0),
  discount  numeric(10,3) not null default 0 check (discount >= 0),
  subtotal  numeric(12,3) not null default 0,                 -- maintained by trigger from quote_items
  total     numeric(12,3) generated always as (visit_fee + subtotal - discount) stored,
  commission_rate numeric(6,4) check (commission_rate between 0 and 1),   -- snapshot taken when quote is SENT
  notes text check (length(notes) <= 1000),
  expires_at timestamptz,
  sent_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_quotes_updated before update on quotes for each row execute function set_updated_at();
create index idx_quotes_job on quotes (job_id);
-- at most ONE live quote per job: no contradictory active quotes
create unique index uq_quotes_one_live on quotes (job_id) where status in ('draft','sent','approved');

create table quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quotes(id) on delete cascade,
  kind quote_item_kind not null,
  description text not null check (length(trim(description)) between 2 and 200),
  quantity numeric(8,2) not null default 1 check (quantity > 0),
  unit_price numeric(10,3) not null check (unit_price >= 0),
  line_total numeric(12,3) generated always as (round(quantity * unit_price, 3)) stored,
  sort_order integer not null default 0
);
create index idx_qi_quote on quote_items (quote_id);

create function guard_quote_item() returns trigger language plpgsql security definer set search_path = public as $$
declare v_status quote_status;
begin
  if is_seed_bypass() then return coalesce(new, old); end if;
  select status into v_status from quotes where id = coalesce(new.quote_id, old.quote_id);
  if found and v_status <> 'draft' then
    raise exception 'ERR_INVALID_STATE' using detail = 'Quote items can only change while the quote is a draft';
  end if;
  return coalesce(new, old);
end $$;
create trigger trg_qi_guard before insert or update or delete on quote_items for each row execute function guard_quote_item();

create function recompute_quote_subtotal() returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid := coalesce(new.quote_id, old.quote_id);
begin
  update quotes set subtotal = coalesce((select sum(line_total) from quote_items where quote_id = v_id), 0) where id = v_id;
  return coalesce(new, old);
end $$;
create trigger trg_qi_recompute after insert or update or delete on quote_items for each row execute function recompute_quote_subtotal();

create function guard_quote_update() returns trigger language plpgsql as $$
begin
  if is_seed_bypass() then return new; end if;
  if new.job_id <> old.job_id then raise exception 'ERR_VALIDATION' using detail = 'job_id is immutable'; end if;
  if old.status <> 'draft' and (new.visit_fee <> old.visit_fee or new.discount <> old.discount) then
    raise exception 'ERR_INVALID_STATE' using detail = 'Amounts are frozen once a quote is sent';
  end if;
  if new.status <> old.status and not (
       (old.status = 'draft'    and new.status in ('sent','superseded')) or
       (old.status = 'sent'     and new.status in ('approved','rejected','expired','superseded')) or
       (old.status = 'approved' and new.status = 'superseded')) then
    raise exception 'ERR_INVALID_STATE' using detail = format('Quote %s -> %s is not allowed', old.status, new.status);
  end if;
  return new;
end $$;
create trigger trg_quotes_guard before update on quotes for each row execute function guard_quote_update();

-- ================= PAYMENTS (prototype now; gateway-ready; NEVER card data) =================
create table payments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete restrict,
  quote_id uuid not null references quotes(id) on delete restrict,
  mode payment_mode not null default 'prototype',
  status payment_status not null default 'pending',
  amount numeric(12,3) not null check (amount > 0),
  currency char(3) not null default 'JOD' check (currency = 'JOD'),
  commission_rate numeric(6,4) not null default 0 check (commission_rate between 0 and 1),
  platform_commission numeric(12,3) not null default 0 check (platform_commission >= 0),
  provider_earnings numeric(12,3) not null check (provider_earnings >= 0),
  idempotency_key text check (length(idempotency_key) between 8 and 64),
  gateway_name text,                -- e.g. 'demo' now; real gateway name later
  gateway_reference text,           -- opaque gateway id (payment intent / transaction). NO PAN/CVV/PIN.
  failure_reason text,
  refunded_amount numeric(12,3) not null default 0 check (refunded_amount >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (platform_commission + provider_earnings = amount),
  check (refunded_amount <= amount)
);
create trigger trg_payments_updated before update on payments for each row execute function set_updated_at();
create unique index uq_payments_one_live on payments (job_id) where status in ('pending','authorized','paid');
create unique index uq_payments_idem on payments (job_id, idempotency_key) where idempotency_key is not null;
create index idx_payments_job on payments (job_id);

create table payment_events (       -- append-only log; gateway webhook idempotency via unique gateway_event_id
  id bigint generated always as identity primary key,
  payment_id uuid not null references payments(id) on delete cascade,
  event_type text not null,
  gateway_event_id text unique,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index idx_pe_payment on payment_events (payment_id);

-- ================= INVOICES =================
create sequence invoice_number_seq;
create table invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  job_id uuid not null unique references jobs(id) on delete restrict,
  customer_id uuid not null references profiles(id) on delete restrict,
  provider_id uuid not null references provider_profiles(user_id) on delete restrict,
  payment_id uuid references payments(id) on delete restrict,
  status invoice_status not null default 'issued',
  subtotal numeric(12,3) not null check (subtotal >= 0),
  discount numeric(12,3) not null default 0 check (discount >= 0),
  total numeric(12,3) not null check (total >= 0),
  currency char(3) not null default 'JOD',
  file_path text,                       -- optional PDF in bucket invoice-files
  issued_at timestamptz not null default now(),
  paid_at timestamptz,
  check (total = subtotal - discount)
);
create index idx_invoices_customer on invoices (customer_id, issued_at desc);
create index idx_invoices_provider on invoices (provider_id, issued_at desc);

create table invoice_line_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  kind invoice_line_kind not null,
  description text not null,
  quantity numeric(8,2) not null default 1,
  amount numeric(12,3) not null,        -- signed: discount lines are negative
  sort_order integer not null default 0
);
create index idx_ili_invoice on invoice_line_items (invoice_id);

-- ================= REVIEWS (customer<->provider; replaces separate "ratings") =================
create table reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete restrict,
  reviewee_id uuid not null references profiles(id) on delete restrict,
  score smallint not null check (score between 1 and 5),
  comment text check (length(comment) <= 1000),
  is_visible boolean not null default true,        -- admin moderation
  created_at timestamptz not null default now(),
  unique (job_id, reviewer_id),
  check (reviewer_id <> reviewee_id)
);
create index idx_reviews_reviewee on reviews (reviewee_id) where is_visible;

create function enforce_review_rules() returns trigger language plpgsql security definer set search_path = public as $$
declare j jobs%rowtype;
begin
  if is_seed_bypass() then return new; end if;
  select * into j from jobs where id = new.job_id;
  if j.status <> 'COMPLETED' then
    raise exception 'ERR_INVALID_STATE' using detail = 'Only COMPLETED jobs can be reviewed';
  end if;
  if not ((new.reviewer_id = j.customer_id and new.reviewee_id = j.provider_id)
       or (new.reviewer_id = j.provider_id and new.reviewee_id = j.customer_id)) then
    raise exception 'ERR_FORBIDDEN' using detail = 'Reviewer/reviewee must be the two parties of the job';
  end if;
  if j.completed_at < now() - make_interval(days => setting_num('review_window_days', 30)::int) then
    raise exception 'ERR_EXPIRED' using detail = 'Review window has closed';
  end if;
  return new;
end $$;
create trigger trg_reviews_rules before insert on reviews for each row execute function enforce_review_rules();

create function refresh_provider_rating() returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid := coalesce(new.reviewee_id, old.reviewee_id);
begin
  update provider_profiles pp set
    rating_avg   = coalesce((select round(avg(score)::numeric, 2) from reviews where reviewee_id = v_id and is_visible), 0),
    rating_count = (select count(*) from reviews where reviewee_id = v_id and is_visible)
  where pp.user_id = v_id;
  return coalesce(new, old);
end $$;
create trigger trg_reviews_agg after insert or update of is_visible, score or delete on reviews
  for each row execute function refresh_provider_rating();

-- ================= DISPUTES / REPORTS =================
create table disputes (
  id uuid primary key default gen_random_uuid(),
  kind dispute_kind not null default 'job_dispute',
  job_id uuid references jobs(id) on delete restrict,
  reported_user_id uuid references profiles(id) on delete restrict,
  opened_by uuid not null references profiles(id) on delete restrict,
  reason text not null check (length(trim(reason)) between 3 and 200),
  details text check (length(details) <= 2000),
  status dispute_status not null default 'open',
  resolution text,
  resolved_by uuid references profiles(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  check ((kind = 'job_dispute' and job_id is not null) or (kind = 'user_report' and reported_user_id is not null))
);
create unique index uq_disputes_one_open_per_job on disputes (job_id) where kind = 'job_dispute' and status in ('open','under_review');
create index idx_disputes_status on disputes (status, created_at desc);

-- ================= NOTIFICATIONS =================
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles(id) on delete cascade,
  type notification_type not null,
  title text not null,
  message text not null,
  job_id uuid references jobs(id) on delete cascade,
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_notif_recipient on notifications (recipient_id, created_at desc);
create index idx_notif_unread on notifications (recipient_id) where read_at is null;

create function push_notification(p_recipient uuid, p_type notification_type, p_title text, p_message text, p_job uuid, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into notifications (recipient_id, type, title, message, job_id, data) values (p_recipient, p_type, p_title, p_message, p_job, p_data)
$$;

create function notify_on_status_change() returns trigger language plpgsql security definer set search_path = public as $$
declare j jobs%rowtype; svc text;
begin
  if is_seed_bypass() then return new; end if;
  select * into j from jobs where id = new.job_id;
  select name_en into svc from services where id = j.service_id;
  case new.to_status
    when 'REQUESTED' then perform push_notification(j.provider_id,'new_request','New service request', format('New %s request in %s.', svc, initcap(j.city::text)), j.id);
    when 'ACCEPTED' then perform push_notification(j.customer_id,'request_accepted','Request accepted', format('Your %s request was accepted.', svc), j.id);
    when 'DECLINED' then perform push_notification(j.customer_id,'request_declined','Request declined', format('Your %s request was declined. Try another provider.', svc), j.id);
    when 'EN_ROUTE' then perform push_notification(j.customer_id,'provider_en_route','Provider on the way', 'Your provider is on the way.', j.id);
    when 'ARRIVED' then perform push_notification(j.customer_id,'provider_arrived','Provider arrived', 'Your provider has arrived.', j.id);
    when 'INSPECTION' then perform push_notification(j.customer_id,'inspection_started','Inspection started', 'Your provider started the inspection.', j.id);
    when 'QUOTE_SENT' then perform push_notification(j.customer_id,'quote_received','New quote', 'You received a quote. Review and approve it.', j.id);
    when 'AWAITING_PAYMENT' then perform push_notification(j.provider_id,'quote_approved','Quote approved', 'The customer approved your quote. Awaiting payment.', j.id);
    when 'PAID' then perform push_notification(j.provider_id,'payment_successful','Payment received', 'Payment was completed. You can start the work.', j.id);
    when 'IN_PROGRESS' then perform push_notification(j.customer_id,'work_started','Work started', 'Your provider started the work.', j.id);
    when 'COMPLETED' then
      perform push_notification(j.customer_id,'work_completed','Work completed', 'The job is complete. Your invoice is ready.', j.id);
      perform push_notification(j.customer_id,'review_request','Rate your provider', 'How was the service? Leave a review.', j.id);
      perform push_notification(j.provider_id,'review_request','Rate your customer', 'Leave a review for this job.', j.id);
    when 'CANCELLED' then
      if new.changed_by is not distinct from j.customer_id then
        perform push_notification(j.provider_id,'job_cancelled','Job cancelled','The customer cancelled the job.', j.id);
      elsif new.changed_by is not distinct from j.provider_id then
        perform push_notification(j.customer_id,'job_cancelled','Job cancelled','The provider cancelled the job.', j.id);
      else
        perform push_notification(j.customer_id,'job_cancelled','Job cancelled','The job was cancelled.', j.id);
        perform push_notification(j.provider_id,'job_cancelled','Job cancelled','The job was cancelled.', j.id);
      end if;
    when 'EXPIRED' then
      perform push_notification(j.customer_id,'job_expired','Request expired','The request expired.', j.id);
      perform push_notification(j.provider_id,'job_expired','Request expired','The request expired.', j.id);
    when 'DISPUTED' then
      if new.changed_by is not distinct from j.customer_id then
        perform push_notification(j.provider_id,'dispute_opened','Dispute opened','The customer opened a dispute.', j.id);
      else
        perform push_notification(j.customer_id,'dispute_opened','Dispute opened','A dispute was opened on your job.', j.id);
      end if;
    else null;
  end case;
  return new;
end $$;
create trigger trg_history_notify after insert on job_status_history for each row execute function notify_on_status_change();

create function notify_on_quote_rejected() returns trigger language plpgsql security definer set search_path = public as $$
declare v_provider uuid;
begin
  if is_seed_bypass() then return new; end if;
  if new.status = 'rejected' and old.status = 'sent' then
    select provider_id into v_provider from jobs where id = new.job_id;
    perform push_notification(v_provider,'quote_rejected','Quote rejected','The customer rejected your quote.', new.job_id);
  end if;
  return new;
end $$;
create trigger trg_quotes_notify after update of status on quotes for each row execute function notify_on_quote_rejected();

create function notify_on_review() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if is_seed_bypass() then return new; end if;
  perform push_notification(new.reviewee_id,'new_review','New review', format('You received a %s-star review.', new.score), new.job_id);
  return new;
end $$;
create trigger trg_reviews_notify after insert on reviews for each row execute function notify_on_review();

-- ================= AUDIT =================
create table audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index idx_audit_entity on audit_logs (entity_type, entity_id);
create index idx_audit_actor on audit_logs (actor_id, created_at desc);
