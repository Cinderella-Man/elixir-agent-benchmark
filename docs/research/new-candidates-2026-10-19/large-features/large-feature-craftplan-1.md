# Large feature — Craftplan #51 cancel unconsumed production batches

**Status:** discovered
**Source type:** historical merged PR (issue #47)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan) — artisanal D2C micro-business management
**PR:** [#51](https://github.com/puemos/craftplan/pull/51) — fix(production): allow canceling unconsumed batches
**Issue:** [#47](https://github.com/puemos/craftplan/issues/47) — “there is a state called «Canceled», but … no way to actually cancel a batch”
**Author:** puemos (maintainer) · **Created:** 2026-10-07 · **Merged/closed:** 2026-10-07
**Source revisions:** base (merge first parent) `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c` → merge `46c0a6fa88ed5bd195531460129ddddbe055b663` (1 commit)
**Task kind / family:** bounded feature / domain action + allocation release + LiveView lifecycle controls
**Research date:** 2026-10-19
**License:** AGPL-3.0 (Elixir `~> 1.20`, Ash 3 + Ash Postgres + Ash auth + Absinthe + LiveView)

---

## Why it is a LIMIT-TESTING case

The batch filter already shows a **“Canceled”** state but there is no cancel action (issue #47). Cancelling is not a status flip: it must **release order allocations** so those quantities can be planned again, must **not** deduct inventory, and must refuse batches with recorded material consumption. After cancel, the batch is no longer startable/consumable/completable.

Hard coordination across Ash domain + planner + UI:

1. New Ash `update :cancel` with status filter and allocation `touches_resources`.
2. Change module: reject cancel when consumption exists; clear allocations via `manage_relationship`.
3. Fix `batch_consumed?/2` so recorded lot usage is actually detected (`Ash.exists?`).
4. Orders facade `cancel_batch/3` alongside start/complete.
5. LiveView show page: cancel button, flash/status, and **lifecycle controls disappear**.

A UI-only cancel that leaves allocations held is a classic plausible incomplete — the planner still blocks the materials. Five substantive implementation files that must agree.

## File inventory with roles

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/craftplan/orders/production_batch.ex` | Ash `update :cancel` (status `[:open, :in_progress]`, `touches_resources` on allocations); tighten `:start`/`:consume` so canceled batches cannot re-enter the lifecycle. |
| `lib/craftplan/orders/changes/batch_cancel.ex` | **New** Ash change: reject cancel when `Batching.batch_consumed?/2`; clear `allocations` via `manage_relationship(..., type: :direct_control)`. |
| `lib/craftplan/orders.ex` | Expose `cancel_batch/3` on the Orders facade. |
| `lib/craftplan/production/batching.ex` | `batch_consumed?/2` result handling corrected (`Ash.exists?/2` boolean). |
| `lib/craftplan_web/live/manage/production_batch_live/show.ex` | Cancel button + `handle_event("cancel_batch", …)`; lifecycle controls disappear after cancel. |

**Counts:** 5 substantive implementation files (domain action, change, facade, batching helper, LiveView). Tests and docs separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/craftplan/production_batching_test.exs` | Domain cancel/replan: allocations released, stock unchanged, consumption guard, lifecycle rejection. |
| `test/craftplan_web/production_batch_live_actions_test.exs` | Cancel button, flash/status, controls disappear. |

### Docs

| Path | Note |
| --- | --- |
| `docs/src/pages/docs/production-batching.md` | Documentation — not counted as implementation. |

## Draft clarified feature brief

> The batch filter already has a “Canceled” state, but I cannot cancel a batch from the UI. Let me cancel an open or in-progress production batch that has not recorded material consumption. Canceling must release its order allocations so those quantities can be planned again, and it must not deduct inventory. Completed batches and batches with recorded consumption cannot be canceled. After canceling, the batch is no longer startable, consumable or completable.

Do **not** name `BatchCancel`, `cancel_batch`, or file paths in the solver ticket. “Canceled” is existing product vocabulary and stays visible.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| B1 | Cancel open batch → status `:canceled`, allocations removed, order items return to plannable state. |
| B2 | Cancel does **not** deduct lot stock (stock unchanged). |
| B3 | In-progress batch cancels **until** consumption is recorded. |
| B4 | Batch with recorded consumption **cannot** be canceled (error); status and already-consumed stock stay. |
| B5 | Canceled batch rejects `start`, `complete`, and `consume` (including stale requests). |
| B6 | A replacement batch can re-allocate the released order-item quantities. |
| B7 | LiveView: cancel works; flash/status show canceled; start/complete controls disappear. |
| B8 | **Preservation:** ordinary start → complete happy path and existing allocation/cost behaviour still work. |

## Incomplete control

**Compiling partial that misses one subsystem:** add `update :cancel` + LiveView button and set status to `:canceled`, but **do not** release `allocations` and **do not** guard on `batch_consumed?`.

- UI looks fixed; **B1** (allocations), **B3/B4** (consumption) fail.
- Second incomplete: domain cancel is correct but LiveView still shows Start/Complete after cancel → **B7** fails.

## Integrity / shortcut rejection

Reject patches that:

- Allow cancel after consumption (stock already moved).
- Deduct inventory on cancel (double-negative of B2).
- Leave allocations held so the planner cannot re-plan (B1/B6).
- Mark completed batches canceled, or allow start/consume after cancel.

## Preservation of existing behavior

- Existing start/complete/consume lifecycle tests stay green.
- Allocation and cost behaviour on ordinary batches unchanged.
- Filter UI still lists ordinary states (open/in_progress/completed).

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| PostgreSQL | Ash Postgres. |
| Ash 3 + native `bcrypt_elixir` / `picosat_elixir` | Cache `mix.lock` offline; exclude SeaweedFS/MinIO storage from selected tests. |
| Heroicons git sparse dep | Must be cached. |
| Elixir `~> 1.20` | Toolchain pin. |
| AGPL-3.0 | Provenance notice. |

Not verified here: compile/test/boot, Ash sandbox behaviour.

## Status: discovered

Excellent bounded feature (5 implementation files, authentic issue, domain + UI + planner state). Preferred Craftplan entry if only one Craftplan case is kept. Distinct family from Craftplan #53 (allergen calculation) — do not treat as duplicate coverage, but share one Ash/Postgres runtime.

## Next action

1. Pin base `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c`.
2. Keep the brief’s product rules (unconsumed only; release allocations; no stock deduction) without Ash action names.
3. Incomplete = status-only cancel; integrity = cancel-after-consumption or allocations left held.
4. Resolve Ash+Postgres runtime once with #53, then qualify both.
