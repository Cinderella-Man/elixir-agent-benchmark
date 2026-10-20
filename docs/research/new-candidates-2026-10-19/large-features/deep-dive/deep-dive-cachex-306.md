# Deep-dive dossier — Cachex #306 scheduled LRW eviction policy

**Case-prep status:** deep-inspected + experiments 2026-10-19/20 (clone, `git apply`, `mix test`).  
**Verdict:** **viable large-feature candidate with a contract correction.** The PR **does change the default LRW policy to Scheduled** in its final commit — the large-feature sheet’s “default remains evented” claim is wrong relative to the PR head. Diff applies cleanly at the claimed base; acceptance tests green.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [whitfin/cachex](https://github.com/whitfin/cachex) |
| PR | [#306 Add a scheduled LRW policy for low memory use](https://github.com/whitfin/cachex/pull/306) (closes #303, #300) |
| Diff | `pull/306.diff` (25,525 bytes, 9 files) |
| Author | whitfin (owner/maintainer) |
| Created / Merged | 2023-01-08/09 / 2023-01-09 |
| Size (PR diff) | +417 / −202, **9 files** (5 impl + 4 test; one test is a rename) |
| Size (full base..head) | +423 / −212, **12 files** (adds CI/README/mix.exs mechanical) |
| License | **MIT** |
| Elixir at base | `~> 1.5` (Cachex `3.4.0`) |

### Corrected SHAs (experiment-verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Claimed base (apply point) | `fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e` | **Works for `git apply`** but is **not** an ancestor of head and **not** the merge-base. It is 6 CI/build commits ahead of the true merge-base on main. |
| True merge-base | `8c556854f8889bf06a27cdab7524b592658b6a58` | `git merge-base fc4f2a0 65a10ca` |
| PR head | `65a10ca487dfe8f2c826748573a72cfa047edf3a` | `refs/pull/306/head` == this. Message **“Set default LRW policy to scheduled”**. Parent `f6b4111`. |
| Landing (“merge”) | `7b4062bd8d139114ac865535a151165bc0c7d28d` | Single parent `c123577` — rebase-style landing, **not** a two-parent merge. |
| Other HTML SHA | `b0d0e45…` | **bad object** (force-pushed away). Ignore. |

**PR commits (5):**

```
25ef3a5 Split up LRW event logic into new module
4efca6c Align policy interfaces around hook usage
0e14f02 Add a scheduled LRW policy implementation
f6b4111 Update signatures and specs
65a10ca Set default LRW policy to scheduled   ← 1-line default flip
```

**Apply check:** `base + pull/306.diff` matches head on the 9 PR files. Residual vs head is only `.github/workflows/ci.yml`, `README.md`, `mix.exs` (mechanical; head has older CI matrix because the branch predates those main updates). After `git add -A`, those 3 files are the only difference — not part of the feature.

---

## 2. Shortest ticket / brief (curator-frozen) — WITH CONTRACT FIX

> Add a least-recently-written eviction policy that enforces cache limits on a schedule instead of on every write hook, for lower memory use. It must still evict oldest-writer entries when the cache crosses its limit, support a batch size for how many keys to drop at a time, and leave the existing evented LRW behavior available as a selectable policy. Caches without an upper bound must not evict. Using `Cachex.Policy.LRW` as the limit policy should run the scheduled implementation (matching upstream’s final default); selecting `Cachex.Policy.LRW.Evented` must restore the old hook-based behavior.

**Contract correction vs large-feature sheet:**

| Sheet claim | Experiment fact |
| --- | --- |
| “Default limit policy remains evented LRW” | **False at PR head.** Final commit `65a10ca` changes `lib/cachex/policy/lrw.ex` `defdelegate hooks(limit), to: __MODULE__.Evented` → `to: __MODULE__.Scheduled` (1 line). Comment still says “Backwards compatibility with < v3.5.x defaults” which is misleading. |
| “Do not grade `enforce_bounds`” | Still correct — public name was open; do not grade that symbol. |
| Prefer naming `Cachex.Policy.LRW.Scheduled` | OK as requested public module. |

If the curator instead wants evented default, the brief must **explicitly** say so and the reference patch must drop `65a10ca` — otherwise the reference fails its own A5 “evented preserved as default” wording. Recommended: **accept Scheduled as `Cachex.Policy.LRW` default**, keep Evented selectable.

---

## 3. File roles (from `pull/306.diff`)

### Implementation (5 substantive)

| Path | Role |
| --- | --- |
| `lib/cachex/policy.ex` | Behaviour cleanup (drop unused `child_spec/1` / `strategy/0`; keep `hooks/1`). |
| `lib/cachex/policy/lrw.ex` | Shared LRW prune algorithm + docs; **delegates `hooks/1` to Scheduled** (after final commit). |
| `lib/cachex/policy/lrw/evented.ex` | **New home** of the previous hook-based LRW policy. |
| `lib/cachex/policy/lrw/scheduled.ex` | **New** timer policy: `:batch_size`, `:frequency`, bound enforcement + expired-key reclaim. |
| `lib/cachex/services.ex` | Start/stop policy servers with the cache. |

### Tests (4 paths; one is rename)

| Path | Contract |
| --- | --- |
| `test/cachex/policy/lrw/scheduled_test.exs` | **New:** `"evicting with no upper bound"`, `"evicting when a cache crosses a limit"`, `"evicting by removing expired keys"`. |
| `test/cachex/policy/lrw/evented_test.exs` | Renamed from `test/cachex/policy/lrw_test.exs`; evented behavior preserved. |
| `test/cachex/policy_test.exs` | Policy behaviour surface. |
| `test/cachex/services_test.exs` | Service wiring (policy server start/stop). |

**Counts:** 5 impl / 3 test + 1 rename. Mechanical outside PR diff: ci.yml, README.md, mix.exs.

---

## 4. Cross-component consistency

1. `Cachex.Policy` behaviour still provides `hooks/1`; third-party policies that only implement `hooks/1` must compile.
2. Shared LRW algorithm in `lrw.ex` used by both Evented and Scheduled.
3. `Cachex.Services` must actually **start the policy server** for Scheduled (timer lives there) — implementing the module without service start is the natural incomplete.
4. No-limit caches must not evict; cross-limit must trim least-recently-**written** first.

---

## 5. Named acceptance ↔ upstream tests

| ID | Obligation | Upstream evidence |
| --- | --- | --- |
| A1 | 5000 keys stay when no max size | `"evicting with no upper bound"` |
| A2 | Cross limit trims; oldest-written evicted first | `"evicting when a cache crosses a limit"` |
| A3 | Schedule also reclaims expired entries | `"evicting by removing expired keys"` |
| A4 | `limit: Cachex.Policy.LRW.Scheduled` runs without hook-message flooding | module + services wiring |
| A5 | Evented still available and works | `evented_test.exs` |
| A6 | `:batch_size` / `:frequency` honored | moduledoc contract + scheduled options |

**Default-policy acceptance (added after experiment):** `limit: Cachex.Policy.LRW` runs Scheduled (`hooks/1` delegate). If graded, state it in the brief as above.

### Compiling incomplete + named failure

**Incomplete A:** implement `Scheduled` + shared prune, leave `Cachex.Services` not starting the policy server.  
**Named failure:** `"evicting when a cache crosses a limit"` (no timer → no eviction).

**Incomplete B:** copy evented hook policy under the Scheduled name.  
**Named failure:** A4 semantics (hook flooding / delay characteristics) — curator note, not ticket.

### Integrity / shortcut rejection

- Evict when no limit set (A1).
- Drop newest instead of least-recently-written.
- Remove evented or break its selectable path (A5).
- Unbounded `Enum` scans that defeat “low memory” — score functional eviction, not latency.

---

## 6. Experiment log (honest)

### E1 — Full diff

`cachex-306.diff`: 9 files, +417/−202. Full `merge-base..head` is 12 files (+423/−212) including 3 mechanical. Use the 9-file feature set for impl counts.

### E2 — Corrected SHAs

See §1. Critical: claimed base `fc4f2a0` is **not** the merge-base (`8c55685`) and is **not** an ancestor of head (`git merge-base --is-ancestor` exits 1). It still applies cleanly because the 6 intervening main commits do not touch the 9 PR files.

### E3 — Clone + `git apply` at claimed base

```
git checkout fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e
git apply --check .../cachex-306.diff   # CHECK:0
git apply       .../cachex-306.diff     # APPLY:0
# files: policy.ex, lrw.ex, lrw/evented.ex(new), lrw/scheduled.ex(new),
#        services.ex, lrw_test.exs→evented_test.exs(rename), scheduled_test.exs(new),
#        policy_test.exs, services_test.exs
```

**Result: PASS** at claimed base. (Also would pass at merge-base `8c55685` — not re-run; residual risk low.)

### E4 — `mix test`

Windows Elixir 1.20.4 / OTP 29.

```
mix deps.get   # OK
mix test test/cachex/policy/lrw/scheduled_test.exs \
         test/cachex/policy/lrw/evented_test.exs \
         test/cachex/policy_test.exs
# Result: 7 passed

mix test --seed 0
# Result: 196/197 passed
# Failed: 1 test — test inspecting cache memory (Cachex.Actions.InspectTest)
```

**Acceptance tests: PASS.** Full suite: 1 unrelated failure (`InspectTest` memory inspection on OTP 29 / newer `:erlang.memory` shapes) and one earlier random-seed flake in cluster tests (janitor `:no_cache` MatchError). **Neither is in the PR file set.** Record as environment-age noise, not reference defects.

### E5 — Later commits on the same files (after `7b4062b`)

Notable (from `git log 7b4062b..origin/main -- <PR files>`):

| SHA | What | Relevance |
| --- | --- | --- |
| `e700e96` / `3a0d7a9` | **#341 named warmers landing** | Touches `services.ex` — lineage (see below). |
| `809396f` | Simplify policy/hook APIs inside LRW handling | Post-#306 cleanup of the same surface. |
| `1be71d4` | Strip out `:qlc` from LRW implementation | Perf/impl change to shared algorithm. |
| `dc543da` | Replace `:batch_size` with `:buffer` across the API | **Renames a graded option name** later. Do not grade `:buffer` at this base. |
| `46d471b` | Strip out `:stats` and `:limit` as cache options | Later API reshape. |

**Window:** freeze at base + PR; do not require post-merge renames (`:buffer`, qlc removal).

### E6 — Lineage with #341 (explicitly requested)

| | #306 | #341 |
| --- | --- | --- |
| Date | 2023-01-09 | 2024-03-24 |
| Shared file | `lib/cachex/services.ex` | same |
| Role in `services.ex` | Policy-server supervision | Hook/warmer `link/1` helpers |
| Ancestry | #306 lands first | #341 base **contains** #306 |

**Do not double-count** if the corpus inventory treats “Cachex services wiring” as one family: they are two product outcomes (eviction policy vs warmer naming) that both touch `services.ex`. Prefer one case per family or an explicit combined lineage note. See `deep-dive-cachex-341.md` §6 for the same table.

---

## 7. Preservation

- `Cachex.Policy.LRW` stays importable (now a thin facade + shared algorithm).
- Evented behavior selectable via `Cachex.Policy.LRW.Evented`.
- Policy behaviour `hooks/1` still works for third-party policies.
- Caches without limit do not evict.

---

## 8. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Services | **None.** ETS + ExUnit. Offline. |
| Timing | Scheduled tests use short waits / assert style already in upstream; ran in 6.2s for the 3 policy files. |
| Toolchain | Elixir 1.20.4 / OTP 29 OK. |
| Public name `enforce_bounds` | Do not grade (author unsure in PR body). |
| Default policy | **Scheduled via `Cachex.Policy.LRW`** at head — see §2. |
| MIT | Provenance notice. |

---

## 9. Curator record fields

```yaml
case_id: cachex-306-scheduled-lrw
project: whitfin/cachex
pr_url: https://github.com/whitfin/cachex/pull/306
base_sha_apply: fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e
merge_base_sha: 8c556854f8889bf06a27cdab7524b592658b6a58
pr_head_sha: 65a10ca487dfe8f2c826748573a72cfa047edf3a
landing_sha: 7b4062bd8d139114ac865535a151165bc0c7d28d
merged_at: 2023-01-09
task_kind: bounded_feature
impl_files: 5
test_files_touched: 4
total_files: 9
license: MIT
elixir_floor: "~> 1.5"
tested_on: "Elixir 1.20.4 / OTP 29"
offline: true
db_required: false
git_apply: clean_at_claimed_base
git_apply_note: "claimed base is not merge-base; still applies"
default_policy_at_head: "Cachex.Policy.LRW -> Scheduled (commit 65a10ca)"
contract_correction: "sheet said evented default; head flips to scheduled"
mix_test_acceptance: "7 passed (scheduled+evented+policy)"
mix_test_full: "196/197 (InspectTest env failure)"
later_commits_same_files: many
later_option_rename: "dc543da :batch_size -> :buffer (out of scope)"
lineage_related_prs: ["https://github.com/whitfin/cachex/pull/341"]
lineage_shared_files: ["lib/cachex/services.ex"]
difficulty_hint: medium-high
scope_risk: policy_module_move_plus_service_wiring
```

---

## 10. Next action

1. Freeze brief with the **default = Scheduled** correction (or explicitly drop `65a10ca` from the reference and keep evented default).
2. Pin apply base `fc4f2a0…` (or switch to merge-base `8c55685…` and re-verify apply).
3. Incomplete = policy module without service start → fail `"evicting when a cache crosses a limit"`.
4. Acceptance: `test/cachex/policy/lrw/scheduled_test.exs` + `evented_test.exs` preservation.
5. If keeping both Cachex cases, record lineage (shared `services.ex`, ancestor order) in the corpus mix note.

---

## Contract correction (2026-10-19 lineage policy)

Per [LINEAGE-MERGE-POLICY.md](../LINEAGE-MERGE-POLICY.md): the ticket must match the **final** product, not a mistaken mid-PR default.

**Do not** freeze "default remains Evented." At head, Cachex.Policy.LRW uses the **Scheduled** implementation when that policy is in play (final commit 65a10ca). Write the brief for the scheduled eviction outcome and how the policy is selected; incomplete can be Evented-only LRW.

Optional: if a cleaner combined story with #341 is wanted later, they share lib/cachex/services.ex only � prefer **two cases**, not one mash-up.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

The contract correction is load-bearing and already applied: **do not freeze "default remains Evented."** At PR head the final commit `65a10ca` flips `Cachex.Policy.LRW` to the Scheduled implementation. The current brief matches head (Scheduled default, Evented selectable, no-limit caches do not evict, batch size). Good.

Remaining ticket gap: the brief says "support a batch size for how many keys to drop at a time" but is silent on **`frequency`** (the schedule interval). The reference has both `:batch_size` and `:frequency`. Either state both or drop `:frequency` from grading. A solver who exposes only `:batch_size` and hardcodes the interval is defensible under the current wording.

Do not grade `enforce_bounds` (already correct — author was unsure). Do not grade the later `:batch_size` → `:buffer` rename (`dc543da`).

### 2. Named deterministic checks (ExUnit, no sleep)

Executed: scheduled + evented + policy → 7 passed; full suite 196/197 with one unrelated `InspectTest` failure. Acceptance is real.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `no-bound-no-evict` | 5000 keys, no max size | cache contents | nothing evicted |
| `cross-limit-trims-oldest-written` | cross the limit | which keys drop | least-recently-**written** first |
| `schedule-reclaims-expired` | expired entries present | contents | expired reclaimed by the schedule |
| `scheduled-as-LRW` | `limit: Cachex.Policy.LRW` | which implementation runs | Scheduled (hooks/1 delegate) |
| `evented-selectable` | `limit: Cachex.Policy.LRW.Evented` | behaviour | old hook-based LRW works |
| `batch-size-honored` | `:batch_size` set | eviction chunking | matches the option |
| `frequency-honored` | `:frequency` set (only if graded) | timer cadence | matches the option |
| `preserve third-party-hooks` | custom policy implementing only `hooks/1` | compile + run | still works |
| `preserve no-limit-caches` | cache without an upper bound | ops | unchanged |

**Sync hazard:** Scheduled eviction is a timer. The dossier says tests use "short waits / assert style already in upstream" and ran in 6.2s for the three policy files. If those waits are `Process.sleep`, they do not meet the no-sleep bar and will flake under load. Rewrite as: put keys → trigger/assert via a controllable tick or a short `:timer`-free sync (e.g., `Cachex` action that forces a policy pass, or `assert` with a bounded `receive`/poll deadline). If upstream truly has no sleep and uses immediate post-warm assertions, say so explicitly in the receipt.

### 3. Ambiguity / unfairness

- `:frequency` visibility (above).
- Default = Scheduled is now stated. Good. A solver who keeps Evented as `Cachex.Policy.LRW`'s delegate fails `scheduled-as-LRW` — that is fair because the brief says so.
- "low memory use" is the *motivation*, not a graded outcome. Do not score memory/latency (guidelines defer perf-only work; this case has a separate correctness consequence — eviction — so it qualifies).
- Batch size semantics (drop N at a time vs drop down to N) should match the reference. State "how many keys to drop at a time" is already in the brief — keep that phrasing.

### 4. Shortcuts + compiling incomplete

- Incomplete A = implement `Scheduled` + shared prune, leave `Cachex.Services` not starting the policy server. Compiles. Fails `cross-limit-trims-oldest-written` (no timer → no eviction).
- Incomplete B = copy the evented hook policy under the Scheduled name. Compiles. May pass naive eviction checks; caught by `scheduled-as-LRW` semantics (no hook flooding) — grade the scheduled-vs-hook distinction lightly and rely on `evented-selectable` + `scheduled-as-LRW`.
- Shortcut: evict when no limit is set. Caught by `no-bound-no-evict`.
- Shortcut: drop newest instead of least-recently-written. Caught by `cross-limit-trims-oldest-written`.
- Shortcut: remove or break Evented. Caught by `evented-selectable`.
- Shortcut: unbounded Enum scan to "look efficient." Do not score latency — score functional eviction only.

### 5. Flakiness

Medium until §2's sync question is answered. Timer-based policy + "short waits" is the classic flake source. Acceptance must be the three named policy tests, **not** the full suite. Full suite has one environmental failure (`InspectTest` memory shape on OTP 29) and a past janitor `:no_cache` MatchError cluster flake — both outside the PR file set.

### 6. Preservation mix

Good: no-limit caches, Evented selectable, third-party `hooks/1` policies, ordinary put/get. Keep Evented **and** Scheduled as positive examples in one run — that is the mixed population that stops a solver from just renaming Evented.

### 7. Environment risk

Good. ETS + ExUnit, offline, no services. Elixir 1.20.4 / OTP 29 (floor `~> 1.5`). MIT. 5 impl files — inside the preferred band. Claimed apply base `fc4f2a0` is **not** the merge-base but applies cleanly; pin it deliberately or move to `8c55685` and re-verify.

**Lineage:** shared `services.ex` with #341; #306 is an ancestor. Two cases, one corpus note (see cachex-341 grilling).

### 8. Verdict

**READY-WITH-FIX** — executed acceptance and a corrected default-policy brief; the `:frequency` visibility and the timer-sync question must be settled before freeze.

### 9. Must-fix list

1. State `:frequency` in the ticket, or drop it from grading. Do not grade it silently.
2. Confirm the scheduled tests are not `Process.sleep`-based; rewrite any that are into bounded sync. Record the receipt.
3. Acceptance net = `scheduled_test` + `evented_test` + `policy_test` only. Exclude `InspectTest`.
4. Incomplete = policy module without service start; name `cross-limit-trims-oldest-written`.
5. Pin apply base deliberately (`fc4f2a0` with the non-ancestor note, or `8c55685` re-verified).

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | `:frequency` hidden + timer-based test flake |
