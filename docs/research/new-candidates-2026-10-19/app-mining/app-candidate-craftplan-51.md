# App candidate — craftplan PR #51 (cancel unconsumed production batches)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (with linked issue request)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/51 |
| Title | fix(production): allow canceling unconsumed batches |
| Author | **puemos** (maintainer) |
| Branch | `feat/47-cancel-production-batch` |
| Created | 2026-10-07T13:35:36Z |
| Merged / closed | 2026-10-07T17:46:20Z |
| Merge commit SHA | `46c0a6fa88ed5bd195531460129ddddbe055b663` |
| **Base SHA (parent of merge)** | `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c` |
| Diff | https://github.com/puemos/craftplan/pull/51.diff |
| Linked issue | [#47](https://github.com/puemos/craftplan/issues/47) — “there is a state called «Canceled», but … no way to actually cancel a batch” |
| Commits | 1 |

License at base: **AGPL-3.0**. Mix at base: Elixir `~> 1.20`, Ash 3 stack (same as PR #53).

---

## 2. Ticket (shortest sufficient, clarified feature brief)

> The batch filter already has a “Canceled” state, but I cannot cancel a batch from the UI. Let me cancel an open or in-progress production batch that has not recorded material consumption. Canceling must release its order allocations so those quantities can be planned again, and it must not deduct inventory. Completed batches and batches with recorded consumption cannot be canceled. After canceling, the batch is no longer startable, consumable or completable. Fix it.

Do **not** name `BatchCancel`, `cancel_batch`, or file paths in the solver ticket.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/orders/production_batch.ex` | New Ash `update :cancel` action (status filter `[:open, :in_progress]`, `touches_resources` on allocations). Also tightens `:start` / `:consume` so canceled batches cannot re-enter the lifecycle. |
| `lib/craftplan/orders/changes/batch_cancel.ex` | **New** Ash change: reject cancel when `Batching.batch_consumed?/2`, and clear `allocations` via `manage_relationship(..., type: :direct_control)`. |
| `lib/craftplan/orders.ex` | Exposes `cancel_batch/3` on the Orders facade alongside start/complete. |
| `lib/craftplan/production/batching.ex` | `batch_consumed?/2` result handling corrected so recorded lot usage is actually detected (`Ash.exists?/2` boolean). |
| `lib/craftplan_web/live/manage/production_batch_live/show.ex` | Cancel button + `handle_event("cancel_batch", …)` on the batch detail page; lifecycle controls disappear after cancel. |

**Cross-component behavior:** domain cancel action ↔ allocation release ↔ consumption guard ↔ LiveView controls. Releasing allocations without the consume guard would allow canceling a batch whose stock already moved; a UI-only cancel would leave the planner still holding the quantities.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/craftplan/production_batching_test.exs` (adds cancel/replan tests), `test/craftplan_web/production_batch_live_actions_test.exs` (adds cancel button tests) |
| Docs (1, mechanical) | `docs/src/pages/docs/production-batching.md` |

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| B1 | Cancel open batch → `status == :canceled`, allocations removed, order items return to plannable state (`:todo`). |
| B2 | Cancel does **not** deduct lot stock (stock unchanged). |
| B3 | In-progress batch cancels **until** consumption is recorded. |
| B4 | Batch with recorded consumption **cannot** be canceled (error); status stays `:in_progress`; stock already consumed remains. |
| B5 | Canceled batch rejects `start`, `complete`, and `consume` (including stale requests). |
| B6 | A replacement batch can re-allocate the released order-item quantities. |
| B7 | LiveView: `#cancel-batch` works, flash/status show canceled, and start/complete controls disappear. |
| B8 | Preservation: ordinary start → complete happy path and existing allocation/cost behavior still work. |

Upstream domain tests cover B1–B6; LiveView tests cover B7. B8 is a required preservation witness (keep a representative existing lifecycle test green).

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** add `update :cancel` + LiveView button and set status to `:canceled`, but **do not** release `allocations` and **do not** guard on `batch_consumed?`. UI looks fixed; B1 (allocations), B3/B4 (consumption) fail.

**Second incomplete:** domain cancel releases allocations and guards consumption, but LiveView still shows Start/Complete after cancel — fail B7.

**Integrity:** standard `System.halt(0)` early-exit in a compiled file; require executed named results.

---

## 6. Preservation

- Start / complete / consume paths and their existing error behavior.
- Inventory stock and cost allocation for non-cancel flows (upstream “open, consume manually, complete” test).
- Canceled batches stay immutable (traceability records intact) — do not physically delete allocations’ audit meaning more than the reference does (direct_control clear of the join rows is the reference outcome).
- Mixed population: open vs in-progress vs consumed vs completed batches.

---

## 7. Runtime / offline holds

Same as craftplan #53:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; SQL Sandbox. |
| Ash 3 stack | Same heavy local deps; cache `mix.lock` offline. |
| External services | None for these tests (Swoosh.Test mail). |
| Browser | Not required; LiveViewTest only. |

**Not verified:** compilation, green base suite, offline dep fetch, or that `Ash.exists?/2` behavior matches the assumed boolean at this Ash version. The `batch_consumed?` fix is a real latent bug worth keeping in the task narrative only as observed outcome (“consumed batches can still be canceled”), not as a named helper.

---

## 8. Status / next action

**Status:** screened — excellent bounded feature (5 implementation files, authentic issue, domain + UI + planner state). Preferred craftplan entry if only one craftplan case is kept.

**Next action:** pin base `ad9fb484…`, prepare Ash/Postgres fixture, build both incomplete controls, then three qualification rounds. Keep the docs edit out of the implementation count. AGPL-3.0 in provenance.
