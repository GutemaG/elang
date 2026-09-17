---
intent: 007-amole-currency
phase: inception
created: '2026-09-17T16:10:00Z'
---

# Units: amole-currency

## Overview

2 units, backend/frontend split — but far smaller than the original build prompt assumed on the frontend side, since the out-of-Beans modal already correctly handles the spend/insufficient-balance UI (bolt `007-core-lesson-loop-ui`). The frontend unit here is a single dashboard addition, not a modal retrofit.

## Units

### 001-amole-service (backend, ddd-construction-bolt)

**Purpose**: Replace the mutable `amole_balance` column with an `amole_transactions` ledger; add award triggers to `complete_lesson`; retrofit the existing spend/balance code to the ledger.
**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4
**Complexity**: Real DDD work — this amends a shipped aggregate (`UserBeans`) and a shipped use case (`complete_lesson`), plus a migration with data backfill. Not a greenfield addition.

### 002-amole-ui (frontend, simple-construction-bolt)

**Purpose**: Add the Amole balance display to the home dashboard.
**Assigned Requirements**: FR-5
**Complexity**: Low — `OutOfBeansSheet` already does everything the original build prompt asked of the frontend; this unit is just the dashboard display, reusing the beans-status data the dashboard already fetches.
**Depends on**: `001-amole-service` (the balance value must come from the retrofitted endpoint, though its response shape is unchanged).

## Dependency Graph

```text
001-amole-service --> 002-amole-ui
```

## Notes

Unlike intent `006`, there is no external-provisioning blocker here — both bolts can proceed straight to Construction once Inception is reviewed.
