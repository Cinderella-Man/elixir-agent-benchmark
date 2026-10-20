# Deep-dive dossier — Cachex #341 named warmers + selective `warm/2`

**Case-prep status:** deep-inspected + experiments 2026-10-19/20 (clone, `git apply`, `mix test`).  
**Verdict:** **viable large-feature candidate.** Diff applies cleanly at base; full suite green on Elixir 1.20/OTP 29. Shares `lib/cachex/services.ex` with #306 (lineage documented below — do not double-count as one case).

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [whitfin/cachex](https://github.com/whitfin/cachex) |
| PR | [#341 Allow warmers to be have named processes](https://github.com/whitfin/cachex/pull/341) (fixes #334) |
| Diff | `pull/341.diff` (13,495 bytes) |
| Author | whitfin (owner/maintainer) |
| Created / Merged | 2024-03-24 / 2024-03-24 |
| Size | +127 / −87, **10 changed files** (8 impl + 2 test) |
| License | **MIT** (`package().licenses: ["MIT"]`) |
| Elixir at base | `~> 1.5` (Cachex `3.6.0` mix.exs) |

### Corrected SHAs (experiment-verified)

| Role | SHA | Verified how |
| --- | --- | --- |
| Base (apply point) | `b22cb1ffcd0763f011f1ed3868b8589147050052` | `git checkout` OK; message “Update options of quoted implementations” |
| PR head (branch tip) | `3f6283852e3cbdd335431f90f36fd2ea725bef34` | `refs/pull/341/head` no longer points here (branch gone); commit object exists. Parent `21e2b16`. Message “Refactor out common blocks in services”. |
| Landing on `main` (3 commits) | `3a0d7a9dbf8dd7c9217fa6521e3c87227708445f` → `9a16ca4f63de42d2a09270e0d67c974529d72daa` → `e700e966da6017337318bea205058144c9d5d332` | All on `main`. `3a0d7a9` parent **is** the base `b22cb1f`. `e700e96` is **not** a merge commit (single parent `9a16ca4`) — it is the last of three linear landings. |

**SHA note:** the large-feature sheet listed `e700e96` as “merge”. That is the **last landing commit**, not a two-parent merge. Prefer citing the landing triple or the PR head `3f62838`. Applied tree (`base + pull/341.diff`) **byte-matches** PR head `3f62838` (`git diff --cached 3f62838` empty after `git add -A`).

---

## 2. Shortest ticket / brief (curator-frozen)

> Let a cache warmer register under an optional process name so multiple warmers can be supervised and addressed without colliding on the module atom. When a name is given, warmers start under that name; when it is omitted, keep today’s unnamed/pid behavior. `Cachex.warm/2` should be able to warm only selected warmers by module or name. Invalid warmer names must fail validation. Keep existing warmer modules and full-cache warm working.

Public API to keep visible: `name:` option on warmer spec, `Cachex.warm/2` `only:` filter.  
Do **not** name `Incubator`, `Informant`, `Steward`, or record internals in the ticket.

---

## 3. File roles (from `pull/341.diff`)

### Implementation (8 substantive)

| Path | Role |
| --- | --- |
| `lib/cachex/spec.ex` | `:warmer` record gains `name: GenServer.server()` (type + default `nil`). |
| `lib/cachex/spec/validator.ex` | Name must be `nil` / atom / pid; module still implements `Cachex.Warmer`. |
| `lib/cachex/services/incubator.ex` | Child spec passes `name:` only when set. |
| `lib/cachex/services/informant.ex` | Shared linking logic moved toward `Cachex.Services`. |
| `lib/cachex/services/steward.ex` | Same shared linking for warmers. |
| `lib/cachex/services.ex` | New `link/1`, `attach_child/2`, `find_pid/2` parent-link helpers. |
| `lib/cachex/actions/warm.ex` | `only` filtering by module or name. |
| `lib/cachex.ex` | Public `Cachex.warm/2` option surface. |

### Tests (2)

| Path | Contract |
| --- | --- |
| `test/cachex/actions/warm_test.exs` | Warm with/without `only`; named vs unnamed. |
| `test/cachex/options_test.exs` | Option/record parsing including warmer `name`. |

**Counts:** 8 impl / 2 test. No mechanical files. Size +127/−87.

---

## 4. Cross-component consistency (the limit-test)

1. Spec record `name` default `nil` ↔ validator accepts nil/atom/pid ↔ incubator start options.
2. Named warmer is reachable as that name after cache start; unnamed still pid-based.
3. `Cachex.warm(cache, only: ModuleOrName)` filters; without `only` warms all.
4. Shared linking in `Services.link/1` must keep **hooks** working after the informant/steward refactor (not just warmers).

A compiling partial that names the process but drops `only` filtering is the natural incomplete (A1–A3 pass, A4 fails).

---

## 5. Named acceptance ↔ upstream tests

| ID | Obligation | Upstream evidence |
| --- | --- | --- |
| A1 | Named start: `name: :my_warmer` reachable after cache start | `warm_test.exs` named-warmer cases |
| A2 | Unnamed preserved (`name: nil`) | existing warmer tests still green |
| A3 | Non-atom/non-pid names rejected | `options_test.exs` / validator |
| A4 | `Cachex.warm(cache, only: ModuleOrName)` warms only that warmer | `warm_test.exs` `only` cases |
| A5 | `warm/2` without `only` warms every warmer | `warm_test.exs` full-warm cases |
| A6 | Ordinary puts/gets, hooks, non-warmer caches unchanged | full suite (200 tests) |

### Compiling incomplete + named failure

**Incomplete A:** add `name` to `:warmer` + incubator, leave `warm/2` without `only`.  
**Named failure:** `test "warming a cache with a limited set of warmers"` (or equivalent `only` case) in `test/cachex/actions/warm_test.exs`.

**Incomplete B:** `only` filter present but incubator always passes `name: module`.  
**Named failure:** unnamed multi-instance warmer collision / A2 cases.

### Integrity / shortcut rejection

- Reject requiring every warmer to be named (breaks existing modules).
- Reject `only` that ignores the filter.
- Reject breaking `Cachex.Warmer` behaviour checks (`interval/0`, `execute/1`).
- Reject forced duplicate names crashing cache start.

---

## 6. Experiment log (honest)

### E1 — Full diff captured

`cachex-341.diff` = 10 files, +127/−87. Matches large-feature inventory exactly.

### E2 — Corrected SHAs

See §1. Landing is **3 linear commits** on main (`3a0d7a9`, `9a16ca4`, `e700e96`), not a merge commit. PR head `3f62838` still exists as an object; `refs/pull/341/head` currently resolves to the base (branch deleted after landing).

### E3 — Shallow/full clone + `git apply` at base

```
git clone https://github.com/whitfin/cachex.git cachex-341
git checkout b22cb1ffcd0763f011f1ed3868b8589147050052
git apply --check .../cachex-341.diff   # CHECK:0
git apply       .../cachex-341.diff     # APPLY:0
git add -A
git diff --cached 3f6283852e3cbdd335431f90f36fd2ea725bef34   # empty
```

**Result: PASS.** Applied tree == PR head.

### E4 — `mix test` (toolchain)

WSL had no native Elixir (Windows Elixir on PATH, `erl` missing; `sudo` password required). Used **Windows Elixir 1.20.4 / OTP 29** against the applied tree snapshotted to a Windows path.

```
mix deps.get     # OK
mix compile      # OK (type warnings on 1.20, no errors)
mix test test/cachex/actions/warm_test.exs test/cachex/options_test.exs
# Result: 15 passed
mix test
# Result: 200 passed
```

**Result: PASS** (full suite). Acceptance tests included.

### E5 — Later commits on the same files (after `e700e96`)

82 subsequent commits touch the PR file set as of 2026-10-20 (repo has moved toward v4: tagging removal, `explain/1` rename, etc.). Notable:

| SHA | What | Relevance |
| --- | --- | --- |
| `688837f` (#403) | **Fix cache warmer for long running tasks** — touches `lib/cachex/actions/warm.ex` (+ test) | Direct warmer-semantics follow-up **one year later**. Ticket must not require the #403 behavior. |
| `e700e96` / `3a0d7a9` / `9a16ca4` | The #341 landing itself | — |
| many | v4 API churn on `spec.ex`, `services.ex`, `cachex.ex` | Do not grade later symbol names (`explain/1`, no-tag APIs). |

**Window:** clean for case freeze at base `b22cb1f` + PR diff. Later fixes are out of scope unless the brief explicitly wants them.

### E6 — Lineage with Cachex #306 (explicitly requested)

| | #306 scheduled LRW | #341 named warmers |
| --- | --- | --- |
| Merged | 2023-01-09 | 2024-03-24 |
| Shared file | `lib/cachex/services.ex` | `lib/cachex/services.ex` |
| What it does to `services.ex` | Start/stop **policy servers** with the cache | Pull up **hook/warmer linking** (`link/1`, `attach_child/2`) |
| Is the other an ancestor? | **#306 is an ancestor of #341** (`7b4062b` is ancestor of `3a0d7a9`) | base `b22cb1f` already contains #306 |

**Lineage verdict:** related family (OTP service coordination in Cachex) but **independent product outcomes** (warmers vs eviction policy). They may be **two cases**, but:
- Do **not** count them as two independent “service wiring” tasks in corpus mix without noting the shared file.
- Do **not** double-count `services.ex` work as two distinct multi-file stories if a combined inventory is taken — the roles differ (policy supervision vs hook linking).
- Prefer keeping both only if the corpus wants two Cachex families (limits vs warmers); otherwise pick one.

---

## 7. Preservation

- Existing warmer modules without `name` keep working (issue #334 is additive).
- Hook/informant linking for non-warmer hooks must survive the shared-link refactor.
- `Cachex.warm/2` with no options remains “warm all”.
- Full suite (200 tests) is the preservation net; warm/options tests are the acceptance core.

---

## 8. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Services | **None.** ETS + ExUnit. Fully offline. |
| Toolchain used | Elixir 1.20.4 / OTP 29 (newer than `~> 1.5` floor). Compile warnings only. |
| Timing | No sleeps required for warm tests in the experiment run. |
| MIT | Provenance notice. |

---

## 9. Curator record fields

```yaml
case_id: cachex-341-named-warmers
project: whitfin/cachex
pr_url: https://github.com/whitfin/cachex/pull/341
base_sha: b22cb1ffcd0763f011f1ed3868b8589147050052
pr_head_sha: 3f6283852e3cbdd335431f90f36fd2ea725bef34
landing_shas: [3a0d7a9dbf8dd7c9217fa6521e3c87227708445f, 9a16ca4f63de42d2a09270e0d67c974529d72daa, e700e966da6017337318bea205058144c9d5d332]
merged_at: 2024-03-24
task_kind: bounded_feature
impl_files: 8
test_files_touched: 2
total_files: 10
license: MIT
elixir_floor: "~> 1.5"
tested_on: "Elixir 1.20.4 / OTP 29"
offline: true
db_required: false
git_apply: clean_at_base
applied_matches_pr_head: true
mix_test_targeted: "15 passed"
mix_test_full: "200 passed"
later_commits_same_files: 82
later_warm_fix: "688837f (#403) long-running warmer fix — out of scope"
lineage_related_prs: ["https://github.com/whitfin/cachex/pull/306"]
lineage_shared_files: ["lib/cachex/services.ex"]
lineage_note: "#306 is ancestor; different product outcome (LRW policy vs warmer names)"
difficulty_hint: medium-high
scope_risk: multi_module_otp_coordination
```

---

## 10. Next action

1. Pin base `b22cb1ff…`, freeze brief as in §2 (keep `name` + `only` visible).
2. Incomplete = named start without selective warm (`only` missing) → fail A4.
3. Acceptance: `test/cachex/actions/warm_test.exs` + `test/cachex/options_test.exs`.
4. If both #341 and #306 are kept, write a corpus-level lineage note (shared `services.ex`, ancestor relation) so mix dashboards do not double-count.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Good brief. `name:` on warmer specs, `Cachex.warm/2` `only:` filter, unnamed warmers keep pid behaviour, full-cache warm still works. Public API is visible and internals (`Incubator`/`Informant`/`Steward`) stay out.

**Gap:** "Invalid warmer names must fail validation" — invalid **according to what rule?** The reference accepts `nil` / atom / pid and rejects anything else. The ticket does not say the domain. A solver who accepts strings is defensible and would fail a hidden check. State it: "a warmer name must be an atom or a pid (or omitted)."

### 2. Named deterministic checks (ExUnit, no sleep)

Executed: `warm_test.exs` + `options_test.exs` → 15 passed; full suite → 200 passed (Elixir 1.20.4 / OTP 29). No sleeps required in the experiment run. This is real receipt evidence, not a proposal.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `named-warmer-starts` | warmer with `name: :my_warmer`; start cache | process lookup | reachable under `:my_warmer` |
| `unnamed-preserved` | warmer with no `name` (and multiple instances) | start + lookup | pid-based, no collision |
| `name-domain-accepted` | `name: atom` and `name: pid` | validation | accepted |
| `name-domain-rejected` | `name: "string"` / `name: 1` / other | validation | fails (raise / error tuple — match the project's validation style) |
| `warm only-by-module` | `Cachex.warm(cache, only: ModA)` | warmer `execute` calls | only ModA runs |
| `warm only-by-name` | `Cachex.warm(cache, only: :my_warmer)` | same | only that warmer runs |
| `warm no-filter-warms-all` | two warmers, no `only:` | calls | both run |
| `preserve warmer-behaviour` | `Cachex.Warmer` with `interval/0` + `execute/1` | compile + start | still required |
| `preserve hooks` | ordinary hook (non-warmer) after the shared-link refactor | hook firing | unchanged (the `Services.link/1` refactor is the real regression risk) |
| `preserve puts/gets` | non-warmer cache | ordinary ops | unchanged |

### 3. Ambiguity / unfairness

- Name domain (above) — the one real gap.
- `only:` "by module or name" is clear enough. Do not require both filter kinds if a solver implements one and the ticket names both — actually the ticket does name both ("by module or name"), so both are fair.
- Do not grade #403 (`688837f`, long-running warmer fix) — different semantics, one year later.
- Do not grade later v4 symbols (`explain/1`, no-tag APIs).
- Duplicate names: ticket is silent. Do not grade a specific collision policy unless stated; the integrity note ("forced duplicate names crashing cache start" must not pass) is about not *requiring* a crash, which is fine.

### 4. Shortcuts + compiling incomplete

- Incomplete A = `name` on `:warmer` + incubator, no `only:` filter. Compiles. Fails `warm only-by-module` / `warm only-by-name`.
- Incomplete B = `only:` present but incubator always passes `name: module`. Compiles. Fails `unnamed-preserved` / multi-instance case.
- Shortcut: require every warmer to be named. Caught by `unnamed-preserved`.
- Shortcut: `only:` ignores the filter. Caught by `warm only-by-module`.
- Shortcut: break `Cachex.Warmer` behaviour checks. Caught by `preserve warmer-behaviour`.
- Shortcut: the `Services.link/1` refactor breaks ordinary hooks. Caught by `preserve hooks` — this is the highest-value preservation check in the case.

### 5. Flakiness

Low. ETS + ExUnit, no timers, no services, no sleeps observed. The hook-linking refactor is the only concurrency-sensitive surface; keep `preserve hooks` in the net.

### 6. Preservation mix

Strong: unnamed warmers, full warm, `Cachex.Warmer` behaviour, ordinary hooks, non-warmer caches. The 200-test full suite is a credible net. Keep hooks explicitly — a solver who reimplements linking badly can pass warm tests and still break hooks.

### 7. Environment risk

Excellent. Fully offline, no DB. Elixir 1.20.4 / OTP 29 tested (floor `~> 1.5`, warnings only). MIT. 8 impl files is above the 2–5 band but coherent (spec record → validator → incubator → shared services → warm action → public API). Legitimate large-feature slot.

**Lineage:** shares `lib/cachex/services.ex` with #306. Independent product outcomes (warmer names vs eviction policy). Keep as **two cases** with a corpus-level lineage note so mix dashboards do not double-count "Cachex services wiring."

### 8. Verdict

**READY-WITH-FIX** — executed, offline, discriminating incomplete, strong preservation net; one ticket gap (name domain) before freeze.

### 9. Must-fix list

1. State the name domain in the ticket: optional name must be an atom or a pid; anything else fails validation.
2. Keep `preserve hooks` as a named protected check (the shared-link refactor is the real regression risk).
3. Incomplete = name without `only:`; name `warm only-by-module` as the failure.
4. Do not grade #403 or later v4 API names.
5. If both Cachex cases ship, write the shared-`services.ex` lineage note in the corpus mix.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Unstated name domain in the ticket |
