# PROJECT_APP — Database Plan (DRAFT, backend agent, B1–B3, B5, B8)

Status: DRAFT. Written WITHOUT access to the existing frontend types/mock data. Must be reconciled (task N1 in BACKEND_HANDOFF.md) before anyone relies on it. SQL has NOT been executed against a database.

## Decisions
- Supabase/PostgreSQL, UUID keys, `timestamptz`, FK constraints, deny-by-default RLS.
- Money: `numeric(10,3)` JOD (1000 fils). Totals/commission/earnings are generated columns on `quotes`, so they cannot drift.
- Commission rate `0.1000` is a PLACEHOLDER snapshot per quote. Owner must decide the real rate.
- Cities limited to `amman`, `irbid` via check constraint (easy to relax later).
- Phone check: Jordanian mobile `+9627[789]XXXXXXX`. Verify against frontend validation.
- Location: plain lat/lng + (city, status, availability) index now. Upgrade path: PostGIS `geography` + GiST for distance/ETA search (B9). Not added yet to avoid needless complexity.
- Payments: `payments.mode` = `prototype` | `gateway`. No card fields exist. `gateway_reference` is an opaque id only.
- Soft delete: `profiles.deleted_at` + `account_status`. Financial rows use `on delete restrict` to preserve history.
- One inspection per job (unique). One live quote per job (partial unique index on draft/sent/approved).

## Relationships
- profiles 1—0..1 customer_profiles; profiles 1—0..1 provider_profiles (1:1)
- provider_profiles 1—N provider_availability, provider_portfolio
- provider_profiles N—M services via provider_services; categories 1—N services
- jobs: N—1 customer, N—1 provider, N—1 service; 1—N job_status_history, quotes (1 live), payments; 1—1 inspection, invoice
- invoices 1—N invoice_line_items; ratings: ≤2 per job (one per party); notifications N—1 recipient, optional job

## Job state machine (14 states UNCHANGED from brief)
REQUESTED, ACCEPTED, EN_ROUTE, ARRIVED, INSPECTION, QUOTE_SENT, AWAITING_PAYMENT, PAID, IN_PROGRESS, COMPLETED, DECLINED, CANCELLED, EXPIRED, DISPUTED.

The brief lists states but not transitions or actors. The matrix in `allowed_job_transitions` is a PROPOSAL (needs owner/frontend confirmation):
happy path forward only; cancel allowed before payment (customer, and provider before QUOTE_SENT/AWAITING rules as seeded); `AWAITING_PAYMENT→PAID` by system only (gateway webhook; prototype may use a service-role call); `PAID/IN_PROGRESS/COMPLETED→DISPUTED`; `DISPUTED→COMPLETED|CANCELLED` admin only; COMPLETED never goes back to IN_PROGRESS; DECLINED/CANCELLED/EXPIRED are terminal.
Enforcement: trigger `enforce_job_rules` (validates actor + transition, freezes customer/provider/service, writes `job_status_history`).

## Business rules enforced in DB
Rating only on COMPLETED jobs, only between the two parties, once per rater (trigger + unique). Quote approval only by the job's customer, only if sent, unexpired, job in QUOTE_SENT (`approve_quote` RPC). Provider can edit a quote only while draft. Users cannot change role/status/verification/rating (column grants + insert checks).

## Known gaps (not done)
No seed data, no pgTAP/SQL tests, no Zod schemas, no Edge functions, no invoice-creation RPC, no quote-expiry cron, no PostGIS, no storage bucket policies, no notification-writing triggers, no admin RPCs (verification, audit logging). Provider cancel rules in the matrix need review.
