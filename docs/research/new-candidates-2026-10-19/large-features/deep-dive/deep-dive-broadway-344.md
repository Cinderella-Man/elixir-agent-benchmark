# Deep-dive dossier — Broadway #344 pluggable config storage

**Case-prep status:** deep-inspected + experiments 2026-10-19/20 (clone, `git apply`, `mix test`).  
**Verdict:** **viable candidate with a known reference test-isolation defect.** Feature works; `config_storage_test` passes; but that test’s `on_exit` writes `config_storage: nil` into app env and then **every later Broadway start fails** (`nil.put/2`) unless tests are isolated. Two later PRs (#345, #349) are follow-up fixes on the same surface.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [elixir-broadway/broadway](https://github.com/elixir-broadway/broadway) |
| PR | [#344 feat: refactor persistent term usage to behaviour](https://github.com/elixir-broadway/broadway/pull/344) (addresses #342) |
| Diff | `pull/344.diff` (11,601 bytes) |
| Author | Ziinc |
| Created / Merged | 2024-11-27 / 2024-11-29 |
| Size | +250 / −15, **6 changed files** (5 impl + 1 test) |
| License | **Apache-2.0** |
| Elixir at base | `~> 1.7` (Broadway `1.1.0`) |

### Corrected SHAs (experiment-verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Base (apply point) | `8d29ca4e4d8e05eede10608a336ad70215d4886d` | Message “Fix warnings”. Apply clean. |
| PR head | `f370304c533fca35cbc225856c3a1764e00bd834` | Available via `refs/pull/344/head`. “feat: atom config, docs consolidation”. |
| Merge (squash) | `1151db21d51433b592b55421cd9689d8c81ca339` | “Refactor persistent term usage to behaviour (#344)”. Single parent `f043234` = **#343 `format_discarded`**. |
| Other HTML SHA | `fb69a7a…` | Exists (an intermediate PR commit). |

**PR commits (5):** `8d7e1ff` refactor persistent_term → behaviour → `a75f503` ets-based storage → `5411d1c` read_concurrency → `99b335a` docs → `f370304` atom config, docs consolidation.

**Applied tree vs PR head:** **exact match** (empty `git diff --cached f370304`).

**Applied tree vs merge commit `1151db2`:** residual on `lib/broadway.ex` and `lib/broadway/topology/producer_stage.ex` is **#343 `format_discarded` content already on main** when #344 was squash-merged — not part of #344. Reconstruct with `base + pull/344.diff` (or PR head), not with the merge tree, if the starting point is pre-#343.

---

## 2. Shortest ticket / brief (curator-frozen)

> Broadway must be able to store running topology configuration in ETS instead of `:persistent_term`, selected with application config (`config_storage: :ets` or `:persistent_term`, plus storage options such as a custom ETS table name). Starting and stopping Broadway servers must create and remove configuration in the chosen store so many dynamic Broadway names do not accumulate global persistent_term data. Default behavior stays persistent_term. Existing Broadway pipelines must keep resolving their configuration the same way.

Keep public config keys `config_storage` and `config_storage_opts` visible if graded.  
Do **not** name `Broadway.ConfigStorage.Ets` unless the brief treats the behaviour as public API (PR ships it `@moduledoc false` — prefer grading observable config + lifecycle).

---

## 3. File roles (from `pull/344.diff`)

### Implementation (5 substantive)

| Path | Role |
| --- | --- |
| `lib/broadway/config_storage.ex` | Behaviour (`setup/0` optional, `list/0`, `put/2`, `get/1`, `delete/1`) + `get_module/0` / `get_options/0`. |
| `lib/broadway/config_storage/ets.ex` | ETS impl (default table `:broadway_co`, `table_name` opt). |
| `lib/broadway/config_storage/persistent_term.ex` | Default impl (previous behavior). |
| `lib/broadway/topology.ex` | start writes / config reads / terminate deletes through the store. |
| `lib/broadway.ex` | Documents `:config_storage` / `:config_storage_opts`. |

### Tests (1)

| Path | Contract |
| --- | --- |
| `test/broadway/config_storage_test.exs` | `"ets default options"`, `"ets custom name"` (`async: false`). |

**Counts:** 5 impl / 1 test. +250/−15.

---

## 4. Cross-component consistency

1. `ConfigStorage.get_module/0` resolves `:ets` / `:persistent_term` / custom module.
2. Topology `init` writes config; `config/1` reads; `terminate` deletes — no leak across start/stop.
3. Default remains persistent_term (OTP 21.3+ check lives on that path).
4. Custom `table_name` option honored by ETS impl.

**Natural incomplete:** implement ConfigStorage + ETS unit tests but leave Topology calling `:persistent_term` directly → A1/A2 pass, A3 (lifecycle) fails.

---

## 5. Named acceptance ↔ upstream tests

| ID | Obligation | Upstream evidence |
| --- | --- | --- |
| A1 | ETS store put/get/list/delete | `"ets default options"` |
| A2 | Custom `table_name` | `"ets custom name"` |
| A3 | Topology start/stop registers and removes config | needs a small start/stop leak check (curator-added; not in upstream test file) |
| A4 | Default omitted → persistent_term | previous suite / OTP check |
| A5 | Unknown/malformed storage config does not silently corrupt default | `get_module/0` fallback |
| A6 | Ordinary producer/batcher tests still pass on default store | broadway suite (see experiment caveat) |

### Compiling incomplete + named failure

**Incomplete A:** ETS module + unit tests, Topology still `:persistent_term`.  
**Named failure:** start/stop leak check (A3).

**Incomplete B:** wire topology reads but not `terminate` deletes.  
**Named failure:** leak assertion after stop.

### Integrity / shortcut rejection

- Make ETS the silent default (A4).
- Leave persistent_term entries after terminate when ETS is selected (or vice versa).
- Crash ETS setups on missing `setup/0` due to OTP check placement.
- Change pipeline message processing under the guise of storage.

---

## 6. Experiment log (honest)

### E1 — Full diff

`broadway-344.diff`: 6 files, +250/−15. Matches inventory.

### E2 — Corrected SHAs

See §1. Head `f370304` **does exist** (fetch `pull/344/head`). Merge is a squash onto a main that already had #343.

### E3 — Clone + `git apply` at base

```
git checkout 8d29ca4e4d8e05eede10608a336ad70215d4886d
git apply --check .../broadway-344.diff   # CHECK:0
git apply       .../broadway-344.diff     # APPLY:0
git add -A
git diff --cached f370304c533fca35cbc225856c3a1764e00bd834   # empty
```

**Result: PASS.** Applied tree == PR head.

### E4 — `mix test` (Windows Elixir 1.20.4 / OTP 29)

```
mix deps.get   # OK (gen_stage, telemetry, nimble_options, …)

mix test test/broadway/config_storage_test.exs
# Result: 2 passed          ← feature acceptance PASS

mix test
# Result: 31/129 passed, 98 failed
# Error: ** (UndefinedFunctionError) function nil.put/2 is undefined
#        at Broadway.Topology.init/1
```

**Root cause (inspected, not guessed):** `config_storage_test.exs` setup does:

```elixir
prev = Application.get_env(Broadway, :config_storage)   # nil when unset
on_exit(fn ->
  Application.put_env(Broadway, :config_storage, prev)  # writes explicit nil!
end)
```

`Application.get_env(Broadway, :config_storage, :persistent_term)` returns the default **only if the key is absent**. After `put_env(..., nil)` the key is present with value `nil`, so `get_module/0` falls through `mod -> mod` and returns `nil`. Every subsequent `Broadway.Topology.init` then calls `nil.put/2`.

**Re-run excluding the storage test / with storage test not first:**

```
mix test test/broadway_test.exs test/broadway/caller_test.exs test/broadway/topology_test.exs
# Result: 106/107 passed
```

Remaining failures across broader runs were **rate-limiting timing tests** (`rate limiting buffers demand…`, `rate limiting works when stopping a pipeline…`) — flaky on this machine, unrelated to config storage.

**Grading implication:** run `config_storage_test` in a **separate OS process / `mix test` invocation** from the rest of the suite, or teach the test to `Application.delete_env` when `prev` is nil. Do not treat the 98 failures as a feature defect; they are reference test isolation.

### E5 — Later commits on the same files (after `1151db2`)

| SHA | PR | What | Relevance |
| --- | --- | --- | --- |
| `3305b1c` | #345 | **Ensure config storage is loaded** — 1-line in `topology.ex` (`function_exported?` vs loaded module) | Direct follow-up fix to #344. |
| `52d3276` | #346 | Rename `"Ets"` docs/string to `"ETS"` | Cosmetic. |
| `b6eeef7` | #349 | **Setup config storage on boot, closes #349** — moves `setup/0` out of Topology.init into app boot | Second follow-up fix (Valim). |
| others | #350–#379 | docs, telemetry, batcher options | Unrelated to storage contract. |

**Window:** #345 and #349 are **known incompleteness of the #344 design**. Do not require them in the ticket unless the brief is widened. Flag as follow-up risk if a model “fixes” setup-by-loading and diverges from the reference.

---

## 7. Preservation

- Default `:persistent_term` path unchanged for existing apps.
- Pipeline API (producers, batchers, acknowledgers) untouched.
- Full Broadway suite is the preservation net — **but see E4 isolation requirement**.

---

## 8. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Services | **None.** Offline. |
| `async: false` storage tests | App env mutation — **must run isolated** (see E4). |
| Toolchain | Elixir 1.20.4 / OTP 29; compiles with warnings (`Logger.remove_backend/1` deprecation in test_helper). |
| Apache-2.0 | Provenance notice. |
| Rate-limit tests | Flaky under load; exclude from acceptance or allow retries. |

---

## 9. Curator record fields

```yaml
case_id: broadway-344-config-storage
project: elixir-broadway/broadway
pr_url: https://github.com/elixir-broadway/broadway/pull/344
base_sha: 8d29ca4e4d8e05eede10608a336ad70215d4886d
pr_head_sha: f370304c533fca35cbc225856c3a1764e00bd834
merge_sha: 1151db21d51433b592b55421cd9689d8c81ca339
merged_at: 2024-11-29
task_kind: bounded_feature
impl_files: 5
test_files_touched: 1
total_files: 6
license: Apache-2.0
elixir_floor: "~> 1.7"
tested_on: "Elixir 1.20.4 / OTP 29"
offline: true
db_required: false
git_apply: clean_at_base
applied_matches_pr_head: true
mix_test_acceptance: "2 passed (config_storage_test)"
mix_test_full_without_storage_test: "106/107 (1 rate-limit flake)"
mix_test_full_with_storage_test: "31/129 — reference test isolation defect (nil app env)"
reference_defect: "config_storage_test on_exit puts config_storage: nil"
later_followup_fixes: ["3305b1c #345 load storage", "b6eeef7 #349 setup on boot"]
difficulty_hint: medium
scope_risk: test_isolation_and_followup_fixes
```

---

## 10. Next action

1. Pin base `8d29ca4…`; freeze brief as in §2.
2. Incomplete = ETS module without topology wiring → fail start/stop leak (A3).
3. Acceptance: `test/broadway/config_storage_test.exs` **in a fresh OS process**, plus a small start/stop leak check, plus default preservation on a suite run that does **not** execute the storage test in the same VM.
4. Curator must either patch the storage test’s `on_exit` to `delete_env` when prev is nil (check-protected) or document process isolation in the runner. Do not ship the 98-failure full-suite result as a grading baseline without that note.

---

## Grading note (not a ticket change)

Per [LINEAGE-MERGE-POLICY.md](../LINEAGE-MERGE-POLICY.md): the 98/129 suite failure is **reference test isolation** (on_exit puts config_storage: nil), not a second product PR to merge.

**Action:** isolate config_storage_test (separate mix test invocation) or patch its on_exit to delete_env when previous is nil. Keep the product ticket as pluggable :ets/:persistent_term storage + topology lifecycle. #345/#349 remain follow-ups unless they change that product surface � then reconsider a combined lineage.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Product surface is right: `config_storage: :ets | :persistent_term`, storage options (custom ETS table name), start/stop create and remove config, **default stays persistent_term**, existing pipelines resolve config the same way. Public keys `config_storage` / `config_storage_opts` stay visible. Do not name `Broadway.ConfigStorage.Ets` (it ships `@moduledoc false`) — grade observable config + lifecycle. Correct as written.

Follow-ups #345 (ensure storage module is loaded) and #349 (setup on boot) are **known incompleteness of the #344 design**. A solver who implements setup-on-boot is being *better*, not wrong. Checks must accept both "setup in `Topology.init`" and "setup at application boot." Do not pin the placement.

### 2. Named deterministic checks (ExUnit, no sleep)

Upstream `config_storage_test.exs` has 2 tests, both passing (`"ets default options"`, `"ets custom name"`). **But the full suite is 31/129** when that test shares a VM — its `on_exit` does `Application.put_env(Broadway, :config_storage, prev)` where `prev` is `nil`, and `get_env/3`'s default only applies when the key is **absent**. Every later `Topology.init` then calls `nil.put/2`. This is a **reference test-isolation defect**, not a feature defect (LINEAGE-MERGE-POLICY: fix grading isolation; do not change the product ticket).

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `ets default-options` | `config_storage: :ets` | put/get/list/delete | works with default table |
| `ets custom-name` | `config_storage_opts: [table_name: :my_table]` | same | custom table honored |
| `topology start-stop-leak` | start Broadway with `:ets`, then stop | ETS/persistent_term contents | config **created on start and removed on stop** — **no upstream test name; curator must author this** |
| `default-is-persistent-term` | no `config_storage` key | `get_module/0` / behaviour | persistent_term path; OTP version check intact |
| `unknown-storage-not-corrupt` | malformed / unknown module | `get_module/0` | does not silently return `nil` and crash the world |
| `preserve default-pipeline` | ordinary producers/batchers on default store | suite | green |
| `preserve message-processing` | pipeline under `:ets` | producer → batcher → ack | unchanged (storage must not alter processing) |

Grading split that must land before any bundle work (either one is sufficient):
- Run `config_storage_test` in a **separate OS process / `mix test` invocation** from the rest of the suite, **or**
- Patch the test's `on_exit` to `Application.delete_env` when `prev` is `nil` (check-protected).

Do **not** ship the 31/129 full-suite result as a preservation baseline.

### 3. Ambiguity / unfairness

- #345/#349 placement (above) — accept both.
- "storage options such as a custom ETS table name" is slightly implementation-leaning but it is the observable option. Fine.
- Unknown/malformed storage: ticket is silent on the fallback. If graded, say "a misconfigured storage module must not silently corrupt the default" in the brief; otherwise drop the check.
- Rate-limiting tests (`rate limiting buffers demand…`, `rate limiting works when stopping a pipeline…`) are flaky under load on this machine. Exclude from acceptance or allow retries.

### 4. Shortcuts + compiling incomplete

- Incomplete A = ConfigStorage + ETS unit tests, Topology still calls `:persistent_term`. Compiles. Fails `topology start-stop-leak`.
- Incomplete B = topology reads wired but `terminate` does not delete. Compiles. Fails `topology start-stop-leak` on the stop side.
- Shortcut: make ETS the silent default. Caught by `default-is-persistent-term`.
- Shortcut: leave persistent_term entries behind when ETS is selected (or vice versa). Caught by `topology start-stop-leak`.
- Shortcut: crash ETS setups because the OTP version check sits on the wrong path. Caught by `unknown-storage-not-corrupt` / `preserve default-pipeline`.
- Shortcut: change message processing under the guise of storage. Caught by `preserve message-processing`.

### 5. Flakiness

**High in the current tree, for grading purposes.** Two separate sources:
1. The `on_exit` `nil` app-env write — deterministic *contamination* across tests, not random flake, but it makes any shared-VM suite run meaningless.
2. Rate-limit timing tests — genuine flake under load.

Fix (1) with isolation or `delete_env`. Fix (2) by excluding those tests from the acceptance net. After both, the feature tests themselves are deterministic and offline.

### 6. Preservation mix

Good bones (default persistent_term, pipeline API). The contamination bug means the preservation net currently **cannot be trusted** in one VM. Once isolated, keep: default store, ordinary producer/batcher/ack, and a start/stop leak check on **both** stores.

### 7. Environment risk

Good hardware story: offline, no services, Elixir `~> 1.7`, Apache-2.0. 5 impl files — inside the band. Compiles with warnings (`Logger.remove_backend/1` deprecation in test_helper). The real env risk is **grading harness**, not runtime: the isolation fix is required work (per lineage policy, this is harness, not a ticket change).

### 8. Verdict

**READY-WITH-FIX** — real pluggable-storage feature with a clean product ticket and an executed 2-test acceptance path; blocked on a grading-isolation fix and an authored start/stop leak check before qualification. Not HOLD: the defect is diagnosed and the fix is known.

### 9. Must-fix list

1. **Hard gate:** isolate `config_storage_test` (separate `mix test` invocation) **or** patch its `on_exit` to `delete_env` when previous is `nil`. Do not ship 31/129.
2. Author a named `topology start-stop-leak` check (A3 has **no** upstream test name).
3. Accept #345/#349-style setup-on-boot as a valid alternative; do not pin setup placement.
4. Incomplete = ETS module without topology wiring; name `topology start-stop-leak`.
5. Exclude rate-limit timing tests from the acceptance net (or allow retries).

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Reference test isolation (nil app env) + missing leak check |
