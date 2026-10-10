-- 0001_enums.sql — PROJECT_APP standalone backend. Target: Supabase / PostgreSQL 15+.
-- Money is JOD stored as numeric(…,3) (1 JOD = 1000 fils). No card data anywhere in this schema.

create type user_role           as enum ('customer','provider','admin');
create type account_status      as enum ('active','suspended','deleted');
create type verification_status as enum ('pending','approved','rejected','suspended');
create type city_code           as enum ('amman','irbid');   -- extend later with ALTER TYPE ... ADD VALUE
create type job_status as enum (
  'REQUESTED','ACCEPTED','EN_ROUTE','ARRIVED','INSPECTION','QUOTE_SENT',
  'AWAITING_PAYMENT','PAID','IN_PROGRESS','COMPLETED',
  'DECLINED','CANCELLED','EXPIRED','DISPUTED');
create type quote_status      as enum ('draft','sent','approved','rejected','expired','superseded');
create type quote_item_kind   as enum ('labor','parts','additional');
create type payment_status    as enum ('pending','authorized','paid','failed','refunded');
create type payment_mode      as enum ('prototype','gateway');
create type invoice_status    as enum ('issued','paid','void');
create type invoice_line_kind as enum ('visit_fee','labor','parts','additional','discount');
create type dispute_kind      as enum ('job_dispute','user_report');
create type dispute_status    as enum ('open','under_review','resolved','dismissed');
create type notification_type as enum (
  'new_request','request_accepted','request_declined','provider_en_route','provider_arrived',
  'inspection_started','quote_received','quote_approved','quote_rejected','payment_successful',
  'work_started','work_completed','review_request','new_review','job_cancelled','job_expired',
  'dispute_opened','dispute_resolved');
