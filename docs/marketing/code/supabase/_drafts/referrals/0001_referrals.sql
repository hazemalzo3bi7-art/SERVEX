-- Servex — referral system DRAFT
-- Location: staged under supabase/_drafts/ deliberately.
-- DO NOT move into supabase/migrations/ without the owner's explicit approval (project decision D-024).
--
-- Conventions matched to the claude22 schema:
--   * uuid PKs, timestamptz default now()
--   * RLS enabled, deny by default; writes only where granted
--   * transactional writes via SECURITY DEFINER functions with fixed search_path
--   * `profiles(id) references auth.users(id)`, `is_admin()` helper already exists
--   * no financial reward columns — reward model is NOT yet defined by the owner

-- ---------- enums ----------

create type referral_status as enum ('pending', 'attributed', 'converted', 'rewarded', 'expired');
create type referral_party  as enum ('customer', 'provider');

-- ---------- tables ----------

create table referral_codes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique references profiles(id) on delete cascade,
  code        text not null unique check (code ~ '^[A-Z0-9]{4,16}$'),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table referrals (
  id                  uuid primary key default gen_random_uuid(),
  referrer_user_id    uuid not null references profiles(id) on delete cascade,
  referred_user_id    uuid not null unique references profiles(id) on delete cascade,
  code                text not null,
  referrer_role       referral_party not null,
  referred_role       referral_party not null,
  status              referral_status not null default 'pending',
  attributed_at       timestamptz,
  converted_at        timestamptz,
  expires_at          timestamptz,
  created_at          timestamptz not null default now(),
  constraint referrals_no_self check (referrer_user_id <> referred_user_id)
);

create index idx_referrals_referrer on referrals (referrer_user_id, created_at desc);
create index idx_referrals_status   on referrals (status);

-- ---------- RLS ----------

alter table referral_codes enable row level security;
alter table referrals      enable row level security;

-- A user may read their own code; admins may read all.
create policy referral_codes_select on referral_codes for select to authenticated
  using (user_id = auth.uid() or is_admin());

-- A user may read referrals they are part of; admins may read all.
create policy referrals_select on referrals for select to authenticated
  using (referrer_user_id = auth.uid() or referred_user_id = auth.uid() or is_admin());

-- No direct INSERT/UPDATE/DELETE grants: all writes go through the RPCs below.

grant select on referral_codes, referrals to authenticated;

-- ---------- RPCs (SECURITY DEFINER, fixed search_path) ----------

-- Generate (or return) the caller's own referral code.
create function ensure_my_referral_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_code text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select code into v_code from referral_codes where user_id = v_uid;
  if found then
    return v_code;
  end if;

  -- Short, unambiguous alphabet (no 0/O/1/I/L).
  v_code := 'SRVX-' || upper(
    translate(substr(encode(gen_random_bytes(6), 'base64'), 1, 6), '01OILl+/=', 'ABCDEF')
  );

  insert into referral_codes (user_id, code) values (v_uid, v_code)
  on conflict (user_id) do update set user_id = excluded.user_id
  returning code into v_code;

  return v_code;
end $$;

-- Attribute a referral at signup. Called by the newly registered user.
create function attribute_referral(p_code text) returns referrals
language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_referrer uuid;
  v_row      referrals;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select user_id into v_referrer
  from referral_codes
  where code = upper(trim(p_code)) and is_active = true;

  if v_referrer is null then
    raise exception 'invalid referral code';
  end if;

  if v_referrer = v_uid then
    raise exception 'self-referral is not allowed';
  end if;

  insert into referrals (
    referrer_user_id, referred_user_id, code,
    referrer_role, referred_role, status, attributed_at, expires_at
  )
  select
    v_referrer,
    v_uid,
    upper(trim(p_code)),
    rp.role::text::referral_party,
    np.role::text::referral_party,
    'attributed',
    now(),
    now() + interval '30 days'
  from profiles rp, profiles np
  where rp.id = v_referrer and np.id = v_uid
  on conflict (referred_user_id) do nothing
  returning * into v_row;

  return v_row;
end $$;

-- Mark a referral converted when the referred user completes their first booking.
-- Intended to be called from the job-completion path (or a trigger), not by the client.
create function mark_referral_converted(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not is_admin() and auth.uid() <> p_user then
    raise exception 'not allowed';
  end if;

  update referrals
     set status = 'converted', converted_at = now()
   where referred_user_id = p_user
     and status = 'attributed';
end $$;

revoke all on function ensure_my_referral_code()      from public, anon;
revoke all on function attribute_referral(text)       from public, anon;
revoke all on function mark_referral_converted(uuid)  from public, anon;
grant execute on function ensure_my_referral_code()      to authenticated;
grant execute on function attribute_referral(text)       to authenticated;
grant execute on function mark_referral_converted(uuid)  to authenticated;

-- NOTE: reward columns are intentionally omitted. Add them only after the owner
-- defines the reward model (see docs/marketing/REFERRAL_STRATEGY.md).
