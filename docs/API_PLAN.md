# API PLAN (not built)
UI -> `services/*` interfaces (mock now). Later: Supabase client for CRUD under RLS; Edge Functions for privileged logic (pricing, state transitions, payments webhooks, invoice generation). Job transitions must be validated server-side using the same state-machine definition.
