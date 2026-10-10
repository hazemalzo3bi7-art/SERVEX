-- PROJECT_APP core schema (DRAFT B3). Targets Supabase/PostgreSQL 15+.
-- Money is JOD: 3 decimals (1 JOD = 1000 fils). NEVER store card data here.

-- ---------- enums ----------
create type user_role           as enum ('customer','provider','admin');
create type account_status      as enum ('active','suspended','deleted');
create type verification_status as enum ('pending','approved','rejected','suspended');
create type job_status as enum (
  'REQUESTED','ACCEPTED','EN_ROUTE','ARRIVED','INSPECTION','QUOTE_SENT',
  'AWAITING_PAYMENT','PAID','IN_PROGRESS','COMPLETED',
  'DECLINED','CANCELLED','EXPIRED','DISPUTED');
create type quote_status    as enum ('draft','sent','approved','rejected','expired','superseded');
create type payment_status  as enum ('pending','authorized','paid','failed','refunded','partially_refunded');
create type payment_mode    as enum ('prototype','gateway');
create type invoice_status  as enum ('issued','paid','void');
create type notification_type as enum (
  'job_requested','job_accepted','provider_en_route','provider_arrived','inspection_completed',
  'quote_received','quote_approved','payment_completed','work_started','job_completed',
  'new_rating','job_cancelled','job_declined','job_expired','job_disputed');

-- ---------- helpers ----------
create function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

-- ---------- identity ----------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'customer',
  phone text unique check (phone ~ '^\+9627[789][0-9]{7}$'),
  email text,
  full_name text not null check (length(trim(full_name)) between 2 and 100),
  avatar_url text,
  status account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create trigger trg_profiles_updated before update on profiles for each row execute function set_updated_at();

create function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and status = 'active')
$$;

create table customer_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  default_address text,
  default_lat double precision check (default_lat between -90 and 90),
  default_lng double precision check (default_lng between -180 and 180),
  preferences jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_cp_updated before update on customer_profiles for each row execute function set_updated_at();

create table provider_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  bio text check (length(bio) <= 1000),
  years_experience smallint check (years_experience between 0 and 60),
  verification_status verification_status not null default 'pending',
  rating_avg numeric(3,2) not null default 0 check (rating_avg between 0 and 5),
  rating_count integer not null default 0,
  completed_jobs integer not null default 0,
  city text check (city in ('amman','irbid')),
  base_lat double precision check (base_lat between -90 and 90),
  base_lng double precision check (base_lng between -180 and 180),
  service_radius_km numeric(5,1) not null default 10 check (service_radius_km between 1 and 100),
  is_available boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_pp_updated before update on provider_profiles for each row execute function set_updated_at();
create index idx_pp_discovery on provider_profiles (city, verification_status, is_available);
create index idx_pp_geo on provider_profiles (base_lat, base_lng); -- upgrade path: PostGIS geography + GiST (see B9)

create table provider_availability (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  check (end_time > start_time)
);
create index idx_pa_provider on provider_availability (provider_id, weekday);

-- ---------- catalog ----------
create table categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_en text not null,
  name_ar text not null,
  icon text,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0
);
create table services (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete restrict,
  slug text not null unique,
  name_en text not null,
  name_ar text not null,
  description text,
  is_active boolean not null default true
);
create index idx_services_category on services (category_id) where is_active;

create table provider_services (
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  service_id uuid not null references services(id) on delete restrict,
  base_visit_fee numeric(10,3) not null default 0 check (base_visit_fee >= 0),
  primary key (provider_id, service_id)
);
create index idx_ps_service on provider_services (service_id);

create table provider_portfolio (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  title text not null,
  description text,
  image_path text not null,  -- Supabase Storage object path, never a public secret URL
  work_date date,
  created_at timestamptz not null default now()
);
create index idx_portfolio_provider on provider_portfolio (provider_id);

-- ---------- jobs ----------
create table jobs (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references profiles(id) on delete restrict,
  provider_id uuid not null references provider_profiles(user_id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  problem_description text not null check (length(problem_description) between 5 and 2000),
  city text not null check (city in ('amman','irbid')),
  address_text text not null,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  status job_status not null default 'REQUESTED',
  cancelled_by uuid references profiles(id),
  cancellation_reason text,
  completed_at timestamptz,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (customer_id <> provider_id)
);
create trigger trg_jobs_updated before update on jobs for each row execute function set_updated_at();
create index idx_jobs_customer on jobs (customer_id, created_at desc);
create index idx_jobs_provider on jobs (provider_id, status, created_at desc);

create table job_status_history (
  id bigint generated always as identity primary key,
  job_id uuid not null references jobs(id) on delete cascade,
  from_status job_status,
  to_status job_status not null,
  changed_by uuid references profiles(id),  -- null = system
  note text,
  created_at timestamptz not null default now()
);
create index idx_jsh_job on job_status_history (job_id, created_at);

create table allowed_job_transitions (
  from_status job_status not null,
  to_status   job_status not null,
  actor text not null check (actor in ('customer','provider','system','admin')),
  primary key (from_status, to_status, actor)
);
-- PROPOSED transition matrix (the 14 states are unchanged; see docs/DATABASE_PLAN.md)
insert into allowed_job_transitions values
 ('REQUESTED','ACCEPTED','provider'),('REQUESTED','DECLINED','provider'),
 ('REQUESTED','CANCELLED','customer'),('REQUESTED','EXPIRED','system'),
 ('ACCEPTED','EN_ROUTE','provider'),('ACCEPTED','CANCELLED','customer'),('ACCEPTED','CANCELLED','provider'),
 ('EN_ROUTE','ARRIVED','provider'),('EN_ROUTE','CANCELLED','customer'),('EN_ROUTE','CANCELLED','provider'),
 ('ARRIVED','INSPECTION','provider'),('ARRIVED','CANCELLED','customer'),('ARRIVED','CANCELLED','provider'),
 ('INSPECTION','QUOTE_SENT','provider'),('INSPECTION','CANCELLED','customer'),('INSPECTION','CANCELLED','provider'),
 ('QUOTE_SENT','AWAITING_PAYMENT','customer'),('QUOTE_SENT','CANCELLED','customer'),
 ('QUOTE_SENT','CANCELLED','provider'),('QUOTE_SENT','EXPIRED','system'),
 ('AWAITING_PAYMENT','PAID','system'),('AWAITING_PAYMENT','CANCELLED','customer'),
 ('PAID','IN_PROGRESS','provider'),('PAID','DISPUTED','customer'),
 ('IN_PROGRESS','COMPLETED','provider'),('IN_PROGRESS','DISPUTED','customer'),('IN_PROGRESS','DISPUTED','provider'),
 ('COMPLETED','DISPUTED','customer'),
 ('DISPUTED','COMPLETED','admin'),('DISPUTED','CANCELLED','admin');

create function enforce_job_rules() returns trigger language plpgsql security definer set search_path = public as $$
declare v_actor text; v_uid uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    if new.status <> 'REQUESTED' then raise exception 'new jobs must start as REQUESTED'; end if;
    return new;
  end if;

  if v_uid is not null and not is_admin() then
    if new.customer_id <> old.customer_id or new.provider_id <> old.provider_id
       or new.service_id <> old.service_id then
      raise exception 'job parties and service are immutable';
    end if;
  end if;

  if new.status <> old.status then
    if v_uid is null then v_actor := 'system';
    elsif is_admin() then v_actor := 'admin';
    elsif v_uid = old.provider_id then v_actor := 'provider';
    elsif v_uid = old.customer_id then v_actor := 'customer';
    else raise exception 'not a participant of this job'; end if;

    if not exists (select 1 from allowed_job_transitions t
                   where t.from_status = old.status and t.to_status = new.status
                     and (t.actor = v_actor or v_actor = 'admin')) then
      raise exception 'illegal job transition % -> % for actor %', old.status, new.status, v_actor;
    end if;

    if new.status = 'CANCELLED' then new.cancelled_by := v_uid; end if;
    if new.status = 'COMPLETED' then new.completed_at := now(); end if;
    insert into job_status_history(job_id, from_status, to_status, changed_by)
      values (new.id, old.status, new.status, v_uid);
  end if;
  return new;
end $$;
create trigger trg_jobs_rules before insert or update on jobs for each row execute function enforce_job_rules();

-- initial history row is written AFTER insert (FK needs the job row to exist)
create function log_job_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into job_status_history(job_id, to_status, changed_by) values (new.id, new.status, auth.uid());
  return new;
end $$;
create trigger trg_jobs_created after insert on jobs for each row execute function log_job_created();

-- ---------- inspection / quote ----------
create table inspections (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id) on delete cascade,
  findings text not null,
  recommended_work text not null,
  provider_notes text,
  photo_paths text[] not null default '{}' check (cardinality(photo_paths) <= 10),
  created_at timestamptz not null default now()
);

create table quotes (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  status quote_status not null default 'draft',
  labor numeric(10,3) not null default 0 check (labor >= 0),
  parts numeric(10,3) not null default 0 check (parts >= 0),
  visit_fee numeric(10,3) not null default 0 check (visit_fee >= 0),
  additional_fees numeric(10,3) not null default 0 check (additional_fees >= 0),
  discount numeric(10,3) not null default 0 check (discount >= 0),
  total numeric(10,3) generated always as (labor + parts + visit_fee + additional_fees - discount) stored,
  commission_rate numeric(5,4) not null default 0.1000 check (commission_rate between 0 and 1), -- snapshot; PLACEHOLDER rate, owner to decide
  platform_commission numeric(10,3) generated always as (round((labor + parts + visit_fee + additional_fees - discount) * commission_rate, 3)) stored,
  provider_earnings numeric(10,3) generated always as ((labor + parts + visit_fee + additional_fees - discount) - round((labor + parts + visit_fee + additional_fees - discount) * commission_rate, 3)) stored,
  notes text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (discount <= labor + parts + visit_fee + additional_fees)
);
create trigger trg_quotes_updated before update on quotes for each row execute function set_updated_at();
-- one live quote per job (no contradictory quotes)
create unique index uq_quotes_one_active on quotes (job_id) where status in ('draft','sent','approved');

-- ---------- payments / invoices (no card data, ever) ----------
create table payments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete restrict,
  quote_id uuid not null references quotes(id) on delete restrict,
  mode payment_mode not null default 'prototype',
  status payment_status not null default 'pending',
  amount numeric(10,3) not null check (amount > 0),
  currency char(3) not null default 'JOD',
  gateway_name text,
  gateway_reference text,           -- opaque id from the future gateway; no PAN/CVV/PIN
  refunded_amount numeric(10,3) not null default 0 check (refunded_amount >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (refunded_amount <= amount)
);
create trigger trg_payments_updated before update on payments for each row execute function set_updated_at();
create unique index uq_payments_one_paid on payments (job_id) where status in ('authorized','paid');

create table invoices (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs(id) on delete restrict,
  customer_id uuid not null references profiles(id) on delete restrict,
  provider_id uuid not null references provider_profiles(user_id) on delete restrict,
  status invoice_status not null default 'issued',
  subtotal numeric(10,3) not null check (subtotal >= 0),
  discount numeric(10,3) not null default 0,
  total numeric(10,3) not null check (total >= 0),
  currency char(3) not null default 'JOD',
  issued_at timestamptz not null default now()
);
create table invoice_line_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  kind text not null check (kind in ('visit_fee','labor','parts','additional','discount')),
  description text not null,
  amount numeric(10,3) not null
);
create index idx_ili_invoice on invoice_line_items (invoice_id);

-- ---------- ratings ----------
create table ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  rater_id uuid not null references profiles(id) on delete restrict,
  ratee_id uuid not null references profiles(id) on delete restrict,
  score smallint not null check (score between 1 and 5),
  comment text check (length(comment) <= 1000),
  created_at timestamptz not null default now(),
  unique (job_id, rater_id),
  check (rater_id <> ratee_id)
);
create index idx_ratings_ratee on ratings (ratee_id);

create function enforce_rating_rules() returns trigger language plpgsql security definer set search_path = public as $$
declare j jobs%rowtype;
begin
  select * into j from jobs where id = new.job_id;
  if j.status <> 'COMPLETED' then raise exception 'only COMPLETED jobs can be rated'; end if;
  if not ((new.rater_id = j.customer_id and new.ratee_id = j.provider_id)
       or (new.rater_id = j.provider_id and new.ratee_id = j.customer_id)) then
    raise exception 'rater/ratee must be the two parties of the job';
  end if;
  return new;
end $$;
create trigger trg_ratings_rules before insert on ratings for each row execute function enforce_rating_rules();

create function refresh_provider_rating() returns trigger language plpgsql security definer set search_path = public as $$
begin
  update provider_profiles pp set
    rating_avg = coalesce((select round(avg(score)::numeric,2) from ratings where ratee_id = new.ratee_id),0),
    rating_count = (select count(*) from ratings where ratee_id = new.ratee_id)
  where pp.user_id = new.ratee_id;
  return new;
end $$;
create trigger trg_ratings_agg after insert on ratings for each row execute function refresh_provider_rating();

-- ---------- notifications / audit ----------
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles(id) on delete cascade,
  type notification_type not null,
  title text not null,
  message text not null,
  job_id uuid references jobs(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_notif_recipient on notifications (recipient_id, created_at desc);

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
