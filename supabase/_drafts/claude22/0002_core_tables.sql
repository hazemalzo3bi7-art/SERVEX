-- 0002_core_tables.sql — identity, provider, catalog, settings.

create function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

-- True only for trusted seed/maintenance sessions (no JWT) that explicitly set the GUC.
-- A signed-in client always has auth.uid() set, so it can never use this bypass.
create function is_seed_bypass() returns boolean language sql stable as $$
  select auth.uid() is null and coalesce(current_setting('app.bypass_job_rules', true), '') = 'on'
$$;

-- ---------- identity ----------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'customer',
  phone text unique check (phone ~ '^\+9627[789][0-9]{7}$'),
  email text,
  full_name text not null check (length(trim(full_name)) between 2 and 100),
  avatar_path text,                                   -- storage path in bucket profile-photos
  preferred_language text not null default 'ar' check (preferred_language in ('ar','en')),
  status account_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create trigger trg_profiles_updated before update on profiles for each row execute function set_updated_at();
create index idx_profiles_role on profiles (role) where status = 'active';

create function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and status = 'active')
$$;

create table customer_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  default_city city_code,
  default_neighborhood text,
  default_address text,
  default_lat double precision check (default_lat between -90 and 90),
  default_lng double precision check (default_lng between -180 and 180),
  preferences jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_cp_updated before update on customer_profiles for each row execute function set_updated_at();

-- ---------- catalog ----------
create table categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
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
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name_en text not null,
  name_ar text not null,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0
);
create index idx_services_category on services (category_id) where is_active;

-- ---------- provider ----------
create table provider_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  bio text check (length(bio) <= 1000),
  years_experience smallint check (years_experience between 0 and 60),
  verification_status verification_status not null default 'pending',
  verified_at timestamptz,
  rating_avg numeric(3,2) not null default 0 check (rating_avg between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  completed_jobs integer not null default 0 check (completed_jobs >= 0),
  city city_code,
  base_lat double precision check (base_lat between -90 and 90),
  base_lng double precision check (base_lng between -180 and 180),
  service_radius_km numeric(5,1) not null default 10 check (service_radius_km between 1 and 100),
  is_available boolean not null default false,       -- master on/off switch
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_pp_updated before update on provider_profiles for each row execute function set_updated_at();
create index idx_pp_discovery on provider_profiles (city, verification_status, is_available);
create index idx_pp_geo on provider_profiles (base_lat, base_lng);  -- PostGIS geography+GiST is the documented upgrade path

create table provider_specialties (
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  category_id uuid not null references categories(id) on delete restrict,
  years_experience smallint check (years_experience between 0 and 60),
  primary key (provider_id, category_id)
);

create table provider_service_areas (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  city city_code not null,
  neighborhood text not null,
  unique (provider_id, city, neighborhood)
);

create table provider_availability (          -- weekly schedule in Asia/Amman local time; weekday 0=Sunday
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references provider_profiles(user_id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  check (end_time > start_time)
);
create index idx_pa_provider on provider_availability (provider_id, weekday);

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
  title text not null check (length(title) <= 120),
  description text check (length(description) <= 1000),
  image_path text not null,                    -- storage path in bucket provider-portfolio
  work_date date,
  created_at timestamptz not null default now()
);
create index idx_portfolio_provider on provider_portfolio (provider_id);

-- ---------- configurable business settings (NOTHING business-critical is hardcoded) ----------
create table app_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now()
);
create trigger trg_settings_updated before update on app_settings for each row execute function set_updated_at();

create function setting_num(p_key text, p_default numeric) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::numeric from app_settings where key = p_key), p_default)
$$;
create function setting_text(p_key text, p_default text) returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select value #>> '{}' from app_settings where key = p_key), p_default)
$$;

insert into app_settings (key, value, description) values
 ('commission_rate',       '0',                         'Platform commission as a fraction of quote total (0.10 = 10%). NOT APPROVED: owner decision pending. 0 = no commission.'),
 ('commission_status',     '"pending_owner_decision"',  'Informational: approval state of the commission model.'),
 ('payment_mode',          '"prototype"',               'prototype = simulated payments (pay_demo RPC enabled). gateway = real provider; pay_demo disabled.'),
 ('quote_validity_hours',  '48',                        'Hours a sent quote stays approvable.'),
 ('request_expiry_minutes','15',                        'Minutes a REQUESTED job waits for provider response before EXPIRED.'),
 ('review_window_days',    '30',                        'Days after COMPLETED during which reviews can be created.'),
 ('dispute_window_days',   '7',                         'Days after COMPLETED during which a dispute can be opened.'),
 ('eta_speed_kmh',         '30',                        'Assumed average urban speed for the rough ETA estimate in provider search.'),
 ('max_open_requests_per_customer','5',                 'Abuse guard: max simultaneously open jobs per customer.'),
 ('max_quote_total',       '5000',                      'Sanity cap (JOD) on a single quote total.');
