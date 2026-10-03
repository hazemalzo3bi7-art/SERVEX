# Servex — Marketing System (DRAFT — NOT FINAL)

> ⚠️ **DRAFT — withheld pending reconciliation. Do not treat as final.**

**Decision basis:** `docs/DECISIONS_JORDAN_PIVOT.md` (D-035 → D-040), which **supersede** the
earlier Israel-first / English-first decisions (D-026 / D-027). D-026 and D-027 remain in
`docs/DECISIONS.md` as historical record and are **not** edited or renumbered.

This marketing package was generated **before** the Servex codebase was available and **before**
the Jordan-first pivot was formally decided. It is directionally aligned with the pivot
(Jordan · Arabic-first · RTL · Amman + Irbid) but has **not** been reconciled with the
actual codebase. See `docs/JORDAN_PIVOT_PLAN.md` §10 (Marketing implications).

## Reconciliation checklist (must pass before this package is marked final)

- [ ] Categories/services in the content config match the **final** catalog
      (open decision: 12 demo categories vs 6 DB categories — KI-019)
- [ ] Currency in all copy matches the final decision (JOD expected)
- [ ] Phone validation references `+962` only
- [ ] CTA links match real routes in `src/app/`
- [ ] Analytics taxonomy wired to real screens
- [ ] Referral draft SQL re-checked against the applied schema
      (owner approval required before applying — D-024)
- [ ] Arabic copy reviewed for RTL correctness on a real device

## Repository state

The package content is intentionally **not** committed to the repository at this stage.
Only this README is present as a placeholder; the full draft is held outside the repo until
it has been reconciled with the codebase and the pivot decision.
