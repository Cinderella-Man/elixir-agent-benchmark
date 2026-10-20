# Deep-dive dossier — Craftplan #51 cancel unconsumed production batches

**Case-prep status:** deep-inspected + experiments 2026-10-20 (full clone + apply + mix test).  
**Verdict:** viable candidate. Dossier SHAs are **correct**. Patch applies cleanly. Domain + LiveView tests execute green at base+patch (Elixir 1.20 + Postgres).

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [puemos/craftplan](https://github.com/puemos/craftplan) |
| PR | [#51 fix(production): allow canceling unconsumed batches](https://github.com/puemos/craftplan/pull/51) |
| Issue | [#47](https://github.com/puemos/craftplan/issues/47) — “there is a state called «Canceled», but … no way to actually cancel a batch” |
| Diff / Patch | `pull/51.diff` (12 075 B), `pull/51.patch` (12 895 B) |
| Author | puemos (Shy Alter, maintainer) |
| PR body | empty / not fetched (API rate-limited); patch Subject is `fix(production): let abandoned batches return to planning` |
| Created / Merged | 2026-10-07 (same day) |
| Branch | `feat/47-cancel-production-batch` (head `ff52fcab4e9b804c426b0dea09ac049ff663c2fe`) |
| **Base = merge first parent** | `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c` — **MATCHES dossier** |
| **Merge commit (squash)** | `46c0a6fa88ed5bd195531460129ddddbe055b663` — **MATCHES dossier** |
| Size (first-parent..merge) | **8 files, +157 / −5** |
| License | AGPL-3.0 |
| Elixir / stack | `~> 1.20`, Ash 3 + Ash Postgres + Ash auth + Absinthe + LiveView; native `bcrypt_elixir`, `picosat_elixir` |

Note on titles: GitHub PR title / merge subject = `fix(production): allow canceling unconsumed batches`; the PR-branch commit subject (in `.patch`) = `fix(production): let abandoned batches return to planning`. Same tree (md5 of `base..head` diff == `base..merge` diff).

---

## 2. Shortest ticket / brief (solver-visible)

> The batch filter already has a “Canceled” state, but I cannot cancel a batch from the UI. Let me cancel an open or in-progress production batch that has not recorded material consumption. Canceling must release its order allocations so those quantities can be planned again, and it must not deduct inventory. Completed batches and batches with recorded consumption cannot be canceled. After canceling, the batch is no longer startable, consumable or completable.

Keep visible: product rules (unconsumed only; release allocations; no stock deduction; lifecycle lockout). “Canceled” is existing UI vocabulary.  
Do **not** name `BatchCancel`, `cancel_batch`, `touches_resources`, `manage_relationship`, or file paths.

---

## 3. Source revisions — experiment log (SHAs)

Full clone of `puemos/craftplan` (WSL, git 2.53.0):

| Claim | Experiment result |
| --- | --- |
| Merge `46c0a6fa…` exists | YES. Subject `fix(production): allow canceling unconsumed batches`. |
| Parents | **one parent only** (squash): `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c`. |
| Dossier base = merge first parent | **YES — `BASE_MATCH_FIRST_PARENT: YES`** |
| Head `ff52fcab…` | **Found** on `remotes/origin/feat/47-cancel-production-batch`. Parent is `ad9fb48`. |
| Head tree vs merge tree | `git diff ff52fcab 46c0a6fa` empty (same content); `md5` of `ad9fb48..ff52fcab` == `ad9fb48..46c0a6fa` (`8eb7f20a7f4a42a52bbd8d384ecddb30`). |

**Pin base `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c`.**

---

## 4. File roles + inventory (from `pull/51.diff`)

### Implementation (5 substantive)

| Path | Role |
| --- | --- |
| `lib/craftplan/orders/production_batch.ex` | Adds `update :cancel` (`attribute_in(:status, [:open, :in_progress])`, `filter`, `touches_resources [OrderItemBatchAllocation]`, custom change, `set_attribute(:status, :canceled)`). Tightens `:start` (`status == :open`) and `:consume` (`status in [:open, :in_progress]`) so canceled batches cannot re-enter. |
| `lib/craftplan/orders/changes/batch_cancel.ex` | **New** Ash change: `before_action` rejects cancel when `Batching.batch_consumed?/2`; `manage_relationship(:allocations, [], type: :direct_control)` clears allocations. |
| `lib/craftplan/orders.ex` | Orders facade: `define :cancel_batch, action: :cancel` alongside `start_batch` / `complete_batch`. |
| `lib/craftplan/production/batching.ex` | Fixes `batch_consumed?/2`: drops incorrect `{:ok, exists?}` unwrap — `Ash.exists?/2` already returns boolean. |
| `lib/craftplan_web/live/manage/production_batch_live/show.ex` | Cancel button (`#cancel-batch`, `phx-click="cancel_batch"`, `data-confirm`), `handle_event("cancel_batch", …)`, flash; lifecycle controls gated on `status in [:open, :in_progress]` so they disappear after cancel. |

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/craftplan/production_batching_test.exs` | **+2 tests** (59 lines): `"cancel releases allocations without consuming stock and permits replanning"`; `"in-progress batches can be canceled until consumption is recorded"`. |
| `test/craftplan_web/production_batch_live_actions_test.exs` | **+2 tests** (30 lines): cancel button on open batch removes lifecycle controls; cancel button on in-progress batch. |

### Docs

| Path | Note |
| --- | --- |
| `docs/src/pages/docs/production-batching.md` | One bullet describing Cancel Batch — documentation only. |

**Counts:** 5 implementation, 2 test, 1 doc. Matches dossier.

---

## 5. Cross-component behavior to verify

1. **Ash action** — status filter + allocation release + consumption guard must agree.
2. **Planner state** — released allocations must become re-plannable; stock must not move.
3. **LiveView lifecycle** — after cancel, Start/Complete controls disappear; flash shows canceled.

A UI-only cancel that leaves allocations held is the classic plausible incomplete: the planner still blocks materials (dossier’s incomplete control).

---

## 6. Named acceptance assertions ↔ requirements

From the two new test modules (usable as named acceptance):

| Assertion (test name) | Requirement |
| --- | --- |
| `"cancel releases allocations without consuming stock and permits replanning"` | B1 allocations released; B2 stock unchanged (`10000`); B5 start/complete/cancel rejected on canceled; B6 replacement batch can re-allocate `10`/`5`; item status returns to `:todo`. |
| `"in-progress batches can be canceled until consumption is recorded"` | B3 in-progress cancels; B4 after `consume_batch`, cancel errors and status stays `:in_progress`; stock `9500` after consumption; post-cancel `:consume` rejected. |
| `"cancel button cancels an open batch and removes lifecycle controls"` | B7 LiveView: `#batch-summary` shows `canceled`; `#cancel-batch`, `button[phx-click=start_batch]`, `#complete-batch-section` gone; allocations empty. |
| `"cancel button cancels an in-progress batch"` | B7 for in-progress path. |
| Existing `"start action…"` / complete/consume tests | B8 preservation of ordinary lifecycle. |

---

## 7. Compiling incomplete + named failure

**Incomplete A — status-only cancel** (`update :cancel` + LiveView button set `:canceled`, **no** allocation release, **no** `batch_consumed?` guard):

- Compiles. UI looks fixed.
- **Fails** `"cancel releases allocations without consuming stock and permits replanning"` (allocations non-empty; replan `create_order_item_batch_allocation` fails).
- **Fails** `"in-progress batches can be canceled until consumption is recorded"` (cancel succeeds after consumption).

**Incomplete B — domain correct, LiveView still shows Start/Complete after cancel:**

- **Fails** `"cancel button cancels an open batch and removes lifecycle controls"` (`refute has_element?(… "button[phx-click=start_batch]")`).

**Named failures:** the four tests listed in §6.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Allow cancel after consumption (stock already moved) — B4.
- Deduct inventory on cancel — B2 (stock must stay `10000`).
- Leave allocations held so planner cannot re-plan — B1/B6.
- Mark completed batches canceled, or allow `start`/`consume` after cancel — B5.

---

## 9. Experiments — `git apply` of `pull/51.diff`

| Base | Classic `git apply --check` | `git apply --3way` | Verdict |
| --- | --- | --- | --- |
| **`ad9fb484…` (first parent)** | **exit 0, all 8 paths cleanly** | **exit 0** | **Use this base** |

Exact commands (WSL):

```bash
git clone --depth 1 https://github.com/puemos/craftplan.git classic-craftplan
cd classic-craftplan
git fetch --depth 1 origin ad9fb484e9e19076aae2c8c4dc48a736535e3a3c
git checkout ad9fb484e9e19076aae2c8c4dc48a736535e3a3c
git apply --verbose --check /tmp/large-dd/puemos_craftplan-51.diff   # exit 0
git apply --verbose /tmp/large-dd/puemos_craftplan-51.diff           # exit 0
```

New file `lib/craftplan/orders/changes/batch_cancel.ex` applies as a clean add.

---

## 10. Experiments — `mix test` at base+patch

Environment: Docker `elixir:1.20-otp-28` (matches `~> 1.20`), `postgres:16` on `localhost:5432`, `MIX_ENV=test`, `mix ecto` via AshPostgres setup in test helper.

**Setup:**

```bash
mix local.hex --force && mix local.rebar --force
apt-get install build-essential   # native bcrypt_elixir / picosat_elixir
mix deps.get
mix compile
mix test test/craftplan/production_batching_test.exs
mix test test/craftplan_web/production_batch_live_actions_test.exs
```

**Results at `ad9fb48` + patch:**

| Command | Result |
| --- | --- |
| `mix test test/craftplan/production_batching_test.exs` | **9 passed, 0 failures** |
| `mix test test/craftplan_web/production_batch_live_actions_test.exs` | **15 passed, 0 failures** |

Compile warnings only (cloak_ecto type hint). Hex notes a `ymlr` advisory (docs/dependency, not test-blocking).

**Not verified here:** full Craftplan suite, SeaweedFS/MinIO storage paths (excluded from these tests), Ash sandbox edge cases beyond the two files.

---

## 11. Later commits on the same files (reference-bug / drift scan)

`git log 46c0a6fa..HEAD -- <cancel paths>`:

| Path | Later commits |
| --- | --- |
| `lib/craftplan/orders/production_batch.ex` | **none** |
| `lib/craftplan/orders/changes/batch_cancel.ex` | **none** |
| `lib/craftplan/orders.ex` | **none** |
| `lib/craftplan/production/batching.ex` | `024ceb7 feat(inventory): trace stocked intermediates from production to customers` (large inventory/traceability feature — touches `batching.ex` among many files; **not a cancel bugfix**) |
| `lib/craftplan_web/live/manage/production_batch_live/show.ex` | **none** |
| both test files | **none** |

`git log --grep=cancel` after merge: **empty**.

**Implication:** clean window for a cancel-focused case. No follow-up fix to #51 semantics as of `024ceb7` / HEAD. The `batching.ex` touch in `024ceb7` is a different feature family (traceability) — do not treat as a reference bug.

---

## 12. Preservation

Executed green with the patch:

- Full `production_batching_test.exs` (9 tests) — includes ordinary start/complete/consume/cost paths besides the 2 new cancel tests.
- Full `production_batch_live_actions_test.exs` (15 tests) — includes existing lifecycle actions.

---

## 13. Runtime / offline

| Hold | Evidence |
| --- | --- |
| PostgreSQL 16 | Executed in Docker. |
| Elixir `~> 1.20` | `elixir:1.20-otp-28` (1.20.4). `elixir:1.18` **fails** compile (`declared … only Elixir ~> 1.20`). |
| Native deps `bcrypt_elixir`, `picosat_elixir` | Need `build-essential`; compiled OK. |
| Ash 3 + Ash Postgres | `mix test` runs AshPostgres setup automatically. |
| Heroicons git sparse dep | Present in lockfile; resolved by `mix deps.get`. |
| AGPL-3.0 | Provenance notice required. |
| SeaweedFS/MinIO storage | Not exercised by these two test files. |

---

## 14. Curator record (guidelines checklist)

```
Source type / project / source revisions / PR:
  historical merged PR (squash) / puemos/craftplan
  base ad9fb484e9e19076aae2c8c4dc48a736535e3a3c
  merge 46c0a6fa88ed5bd195531460129ddddbe055b663
Status: discovered → deep-inspected
Case version / inventory / exposure: n/a (no bundle)
Task kind / family: bounded feature / domain action + allocation release + LiveView
Ticket kind: clarified implementation brief (above)
Implementation files: 5 (Ash action, change, facade, batching helper, LiveView)
Tests / docs: 2 test files (+4 tests), 1 doc line
Cross-component behavior: Ash cancel ↔ allocation release ↔ planner re-plan ↔ UI controls
Visible source for each scored obligation: production_batching_test + live_actions_test
Starting-state / reference evidence:
  unchanged: filter already shows "Canceled" (issue #47); no cancel action
  reference: 9 + 15 tests executed green at base+patch
Plausible partial: status-only cancel → fails allocation/consumption tests
Preservation risks: ordinary start/complete/consume; allocation/cost behaviour
Runtime: Postgres + Elixir 1.20 + native build tools (executed)
Three-round controls: NOT run (discovery stage)
Blind model policy: not started
Contract review: product rules stated without Ash action names; error text not required
Coverage: Ash domain + LiveView lifecycle — distinct from Craftplan #53 allergen calc
Admission reason / reconsideration: strongest Craftplan pick; share Ash/Postgres runtime with #53
Next action: screen with incomplete A (status-only) against named cancel tests
```

---

## 15. Verdict for case creation

| Criterion | Assessment |
| --- | --- |
| Authentic coherent work | Yes — issue #47, visible “Canceled” state with no action. |
| Coordinated implementation | Yes — 5 files; allocation release + consumption guard + UI must agree. |
| Visible contract | Yes — 4 new named tests spell out B1–B7. |
| Observable success | Yes — executed green; incomplete A/B have named failures. |
| Reproducible environment | Yes with Elixir 1.20 + Postgres + native toolchain. |
| Provenance | AGPL-3.0; SHAs already correct. |

**Keep.** Preferred Craftplan entry. Note AGPL in provenance and pin Elixir 1.20.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Best product brief in the batch. The rules are visible and complete: unconsumed only (open or in-progress), cancel **releases order allocations** so quantities can be re-planned, **must not deduct inventory**, completed/consumed batches cannot be canceled, and after cancel the batch is no longer startable/consumable/completable. "Canceled" is existing UI vocabulary. No Ash internals named. This is the standard the other dossiers should hit.

One soft word: "cannot be canceled" should say the action is **rejected** (not silently ignored). The tests already assert an error and status staying `:in_progress` after a consumed-batch cancel — a no-op cancel would fail those — so this is non-blocking. Tighten it anyway.

### 2. Named deterministic checks (ExUnit, no sleep)

Executed green at `ad9fb48` + patch: `production_batching_test.exs` 9/0, `production_batch_live_actions_test.exs` 15/0. Four new named tests cover B1–B7. No sleeps.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `cancel-releases-allocations` | open batch with allocations | allocations + planner | allocations cleared; replacement batch can re-allocate `10`/`5`; item status back to `:todo` |
| `cancel-no-stock-deduction` | same | inventory | stock still `10000` |
| `cancel-in-progress-until-consumption` | in-progress batch, then `consume_batch` | cancel result | cancels before consumption; **errors** after; status stays `:in_progress` post-error; stock `9500` after consumption |
| `cancel-locks-lifecycle` | canceled batch | `start` / `consume` / `complete` / `cancel` | all rejected |
| `cancel-button-open` | LiveView open batch | DOM | `#batch-summary` shows `canceled`; `#cancel-batch`, `button[phx-click=start_batch]`, `#complete-batch-section` gone |
| `cancel-button-in-progress` | LiveView in-progress batch | DOM | same |
| `preserve start-complete-consume` | ordinary lifecycle | domain | unchanged (existing tests in the same files) |
| `preserve completed-batch` | completed batch | cancel | rejected (explicit — currently only implied) |

Both directions are covered. The mixed case (cancel succeeds, then a replacement batch re-plans) is exactly the "fix that disables a feature" guard from the guidelines.

### 3. Ambiguity / unfairness

- "cannot be canceled" → say "reject the cancel" (above). Non-blocking.
- Error text is not required. Good — do not start pinning Ash error shapes.
- Whether cancel of a completed batch errors vs no-ops: tests imply error. State "reject" and it is settled.
- Second cancel of an already-canceled batch: unspecified. Do not grade unless stated.

### 4. Shortcuts + compiling incomplete

- Incomplete A = status-only cancel (`update :cancel` + button set `:canceled`, no allocation release, no consumption guard). Compiles; UI looks fixed. Fails `cancel-releases-allocations` **and** `cancel-in-progress-until-consumption`.
- Incomplete B = domain correct, LiveView still shows Start/Complete. Fails `cancel-button-open` (`refute has_element?(… "button[phx-click=start_batch]")`).
- Shortcut: allow cancel after consumption (stock already moved). Caught by `cancel-in-progress-until-consumption`.
- Shortcut: deduct inventory on cancel. Caught by `cancel-no-stock-deduction`.
- Shortcut: leave allocations held. Caught by `cancel-releases-allocations`.
- Shortcut: mark completed batches canceled, or allow `start`/`consume` after cancel. Caught by `cancel-locks-lifecycle` / `preserve completed-batch`.

This is the cleanest incomplete-control story in the set.

### 5. Flakiness

Low. Domain tests are synchronous Ash/Postgres; LiveView tests are DOM assertions. No timers. Postgres is the only service. Full suite was **not** run — the two targeted files are the acceptance net, which is fine if stated.

### 6. Preservation mix

Strong: the same two files also carry ordinary start/complete/consume/cost paths (9 and 15 tests green). Explicit `preserve completed-batch` should be named rather than implied. Optional: one mixed test that cancels then re-plans and starts a replacement batch end-to-end (B6 already covers re-allocate).

### 7. Environment risk

Heavier than the libraries but **executed successfully**:
- Elixir `~> 1.20` (1.18 fails compile — pin 1.20).
- PostgreSQL 16 (Docker proven).
- Native `bcrypt_elixir` / `picosat_elixir` need `build-essential`.
- Ash 3 + AshPostgres auto-setup in test helper.
- Heroicons git sparse dep resolves via `mix deps.get`.
- **AGPL-3.0** — record in provenance.
- SeaweedFS/MinIO storage paths not exercised by these two files — fine, do not widen.

5 impl files — inside the band. SHAs are correct (base `ad9fb48` = merge first parent; head tree == merge tree). Clean later-commit window.

### 8. Verdict

**READY** — authentic issue-driven work, visible product rules, executed green checks, two named compiling incompletes with clear failures, strong preservation, reproducible env. Only a one-word ticket tightening remains, and it is not load-bearing.

### 9. Must-fix list (non-blocking before qualification)

1. Change "cannot be canceled" to "the cancel is rejected" in the ticket.
2. Name `preserve completed-batch` explicitly (completed batch → cancel rejected).
3. Pin Elixir 1.20 + Postgres 16 in the bundle; note AGPL-3.0.
4. Keep the acceptance net at the two named test files; do not claim a full-suite result that was never run.
5. Incomplete A (status-only) is the primary control; name `cancel-releases-allocations` as its failure.

| Verdict | Top risk |
| --- | --- |
| **READY** | Minor ticket wording only; env is heavy but proven |
