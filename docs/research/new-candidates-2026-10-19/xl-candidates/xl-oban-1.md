# XL candidate — oban #347 dynamic repositories

**Status:** discovered
**Source type:** historical merged PR (Ecto dynamic repo integration)
**Project:** [oban-bg/oban](https://github.com/oban-bg/oban)
**PR:** [#347](https://github.com/oban-bg/oban/pull/347) — Support dynamic repos
**Author:** sasa1977 · **Merged:** 2020-10-10
**Source revisions:** merge around `bc77f76445b130651e9038fbd28fa4d4f6780275` / `9293b8a7b38f3a30a67a1ee6934493ef1175d857`
**Size:** +398 / −129, **14 changed files** (10 substantive implementation)
**Task kind / family:** bounded feature / OTP + Ecto repo resolution
**Research date:** 2026-10-19
**License:** Apache-2.0 (`package().licenses: ["Apache-2.0"]`)

---

## Why it is an XL LIMIT-TESTING case

Ecto supports [dynamic repositories](https://hexdocs.pm/ecto/replicas-and-dynamic-repositories.html) (repo resolved per-call via a function returning a pid). Oban hard-coded `conf.repo` everywhere, so multi-tenant setups with one Oban per dynamic repo could not work. This PR introduces a **`Oban.Repo` facade** that resolves the repo at call time via `:get_dynamic_repo`, and threads that facade through every DB-touching component. Consistency must hold across:

1. **`Oban.Repo`** (new, 184 lines) — wrappers for `transaction`, `update`, `update_all`, `query`, `insert`, `insert_all`, `delete`, `delete_all`, `all`, `one`, `stream` that resolve the dynamic repo and apply schema prefix + log level.
2. **`Oban.Config`** — `:get_dynamic_repo` option (zero-arity function or nil) with validation.
3. **`Oban.Query`** — all raw SQL goes through `Oban.Repo` (71 additions / 92 deletions of direct `repo.` calls).
4. **`Oban.Crontab.Scheduler`** — lock-and-insert via `Repo.transaction`.
5. **`Oban.Migrations`** — version query via `Repo.query` with prefix-aware config.
6. **`Oban.Notifier`** — notification queries through `Repo`.
7. **`Oban.Plugins.Pruner`** — pruning via `Repo`.
8. **`Oban.Queue.Producer`** — job fetch/insert via `Repo`.
9. **`Oban.Testing`** — test helpers resolve the dynamic repo.
10. **`Oban`** — public option type gains `:get_dynamic_repo`.

10 implementation files, one coherent product outcome (every DB call respects the configured dynamic repo).

## File inventory with roles

From `pull/347.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/oban/repo.ex` | **New** — `Oban.Repo` facade with dynamic repo resolution + prefix/log. |
| `lib/oban/config.ex` | `:get_dynamic_repo` option type, default, validation. |
| `lib/oban/query.ex` | All queries route through `Oban.Repo`. |
| `lib/oban/crontab/scheduler.ex` | `Repo.transaction` for lock-and-insert. |
| `lib/oban/migrations.ex` | `Repo.query` for schema version detection. |
| `lib/oban/notifier.ex` | Notifier queries through `Repo`. |
| `lib/oban/plugins/pruner.ex` | Pruner deletes via `Repo`. |
| `lib/oban/queue/producer.ex` | Producer fetch/insert via `Repo`. |
| `lib/oban/testing.ex` | Testing helpers use `Repo`. |
| `lib/oban.ex` | Public `@type option` gains `:get_dynamic_repo`. |

**Counts:** 10 substantive implementation files. Tests + guides + README separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/integration/dynamic_repo_test.exs` | End-to-end: Oban with `get_dynamic_repo` performs jobs against the resolved repo. |
| `test/support/repo.ex` | Test repo with dynamic registration support. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| `README.md` | "Dynamic repositories" section with usage example. |
| `guides/writing_plugins.md` | Plugin example updated to use `Oban.Repo`. |

## Draft clarified feature brief

> Oban should work with Ecto dynamic repositories. Add a `:get_dynamic_repo` start option that accepts a zero-arity function returning the repo pid (or nil to use the configured repo module). Every database operation Oban performs — job queries, migrations, notifier, pruner, crontab scheduler, queue producer, testing helpers — must resolve the repo through this option at call time, and must apply the configured schema prefix and log level. Plugins should use a documented repo wrapper so they also respect dynamic repos.

Keep `:get_dynamic_repo` and the `Oban.Repo` module name as the requested public API. Do **not** name internal helper functions like `with_dynamic_repo/2`.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Option accepted:** `Oban.start_link(repo: MyRepo, get_dynamic_repo: fn -> pid end)` starts without error. |
| A2 | **Validation:** `get_dynamic_repo` must be nil or a zero-arity function; anything else raises `ArgumentError`. |
| A3 | **Job execution:** a job enqueued and performed with a dynamic repo hits the resolved repo (not the module default). |
| A4 | **Crone/scheduler:** crontab inserts go through the resolved repo. |
| A5 | **Pruner:** pruning deletes from the resolved repo. |
| A6 | **Prefix preserved:** schema prefix is applied on every query via the facade. |
| A7 | **Testing helpers:** `assert_enqueued` / testing utilities work with a dynamic repo. |
| A8 | **Default preserved:** without `:get_dynamic_repo`, all behaviour is unchanged (repo module used directly). |

## Incomplete control

**Compiling partial that misses one area:** implement `Oban.Repo` and wire `Oban.Query` through it, but forget `Oban.Crontab.Scheduler` and `Oban.Plugins.Pruner`.

- Query tests pass; **A4/A5** fail (scheduler/pruner still call `conf.repo` directly).
- Second partial: wire everything but drop prefix handling in `Oban.Repo` → **A6** fails.

## Integrity / shortcut rejection

Reject patches that:

- Break the no-dynamic-repo default path (A8).
- Accept `:get_dynamic_repo` but never call it (repo always resolves to `conf.repo`).
- Lose schema prefix or log level in the facade.
- Change the public `Oban.Query` API shape in a way that breaks existing plugins.

## Preservation of existing behavior

- Single-repo Oban instances behave exactly as before.
- Existing integration tests (non-dynamic) remain green.
- Plugin guide example still works after the `Oban.Repo` update.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir ~1.10 / OTP ~23 at base (2020) | Older toolchain — verify image compatibility. |
| PostgreSQL | Integration test needs a local Postgres (standard Oban test setup). |
| Ecto / Postgrex | Hex deps; pin the 2020-era versions. |
| Apache-2.0 | Provenance notice. |

Not verified here: compile/test/boot. Postgres required for the integration test; unit-level config/Repo tests are service-free.

## Status: discovered

10-file cross-cutting OTP feature with a clear public option (`:get_dynamic_repo`), a new facade module, and measurable per-component routing outcomes. Strong background-jobs + Ecto diversity pick.

## Next action

1. Pin base at merge parent of the 2020-10 merge commit; resolve Elixir/OTP image for that era.
2. Brief names `:get_dynamic_repo` and `Oban.Repo`; states prefix + log preservation.
3. Incomplete = `Oban.Repo` + `Oban.Query` without scheduler/pruner wiring.
4. Acceptance: `mix test test/integration/dynamic_repo_test.exs` (needs Postgres) + config validation unit tests.

## Provenance notes

- Same author later contributed Oban #331 (registry names) — different family; not part of this case.
- The `Oban.Repo` module became the standard plugin API in later Oban versions; the 2020 base does not yet have it — solvers must create it.
- Error message in the PR has a typo ("expected `:gethostname`") — do not grade on exact error text; accept any clear ArgumentError.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Oban should work with Ecto dynamic repositories. Add a `:get_dynamic_repo` start option that accepts a zero-arity function returning the repo pid, or nil to keep using the configured repo module. Every database operation Oban performs — job queries, migrations, notifier, pruner, crontab scheduler, queue producer, testing helpers — must resolve the repo through this option at call time, and must apply the configured schema prefix and log level. Plugins should use a documented repo wrapper so they also respect dynamic repos.

Clarified brief. Product decisions are visible: option name, arity, nil default, exhaustive call-site list, prefix+log preservation, plugin wrapper is public. Keep `:get_dynamic_repo` and `Oban.Repo` as the requested public API. Two tightenings:

- "documented repo wrapper" is vague — say the wrapper module name is the requested plugin API (`Oban.Repo`) or grade only "plugins can call a public facade that honours the option". The dossier already keeps `Oban.Repo` in the brief; keep it.
- "log level" is easy to drop and hard to observe. Either name a check that asserts `:log` is forwarded (e.g. telemetry / a spy repo) or drop log from the scored obligations and mention it as non-goal. Do not hide it.

### 2. Deterministic checks

ExUnit + **Postgres** (integration). **Fake:** a second Ecto repo (or a wrapper that counts calls on a pid) registered dynamically — the upstream `test/support/repo.ex` already has dynamic registration support. Use `Mox` or a call-counting repo process if you want per-call-site resolution without a real second database.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `option-accepted` | `Oban.start_link(repo: MyRepo, get_dynamic_repo: fn -> pid end)` | start | no error |
| `option-validation` | `get_dynamic_repo: :not_a_fun` | start | `ArgumentError` (any message) |
| `option-default-nil` | no `:get_dynamic_repo` | start + job run | uses `conf.repo` module as today |
| `job-uses-resolved-repo` | dynamic repo pid ≠ default; enqueue+execute a job | job row / query hits | resolved repo is used |
| `scheduler-uses-resolved-repo` | crontab plugin enabled | insert via crontab | goes to resolved repo |
| `pruner-uses-resolved-repo` | pruner plugin enabled | delete | goes to resolved repo |
| `notifier-and-migrations` | start + migration version query | queries | via resolved repo / facade |
| `prefix-applied` | `prefix: "oban"` + dynamic repo | SQL / repo calls | prefix present on every query |
| `testing-helpers` | `assert_enqueued` with dynamic repo | helper | works against resolved repo |
| `plugin-facade-public` | external plugin calls `Oban.Repo.all(...)` | public facade | honours dynamic repo + prefix |
| `preservation-single-repo` | existing non-dynamic integration tests | suite | green |

Without `scheduler-uses-resolved-repo` + `pruner-uses-resolved-repo`, the stated incomplete (Query wired, scheduler/pruner not) is invisible. Without `prefix-applied`, dropping prefix in the facade passes. Without `option-default-nil`, a solver can force everyone through the facade and break the simple path.

### 3. Ambiguity / unfairness

- Error text: reference says `"expected :gethostname"` (typo). Dossier already refuses to grade the string — **keep that**. Grade `ArgumentError` only.
- `Oban.Repo` function set (which wrappers exist: `transaction/2`, `update/3`, `query/2`, …) is a hidden API if checks call specific wrappers. The ticket says "plugins should use a documented repo wrapper" — so the **module name** is fair game, the exact wrapper list is not. Grade via plugin-style call (`Oban.Repo.all/2` or whatever the brief names) plus end-to-end job behaviour, not via a function-list assertion.
- "log level" — see ticket tightenings. Hidden unless checked visibly or dropped.
- Prefix: the ticket states it. Good. But "every query" needs at least one named check with a non-default prefix; do not assume solvers will infer it from docs.
- 2020-era Oban: `Oban.Query` is a public-ish module used by plugins. "Do not change the public `Oban.Query` API shape" in the dossier is a **structural** constraint — either put it in the brief or drop it from integrity. A solver who introduces `Oban.Repo` and keeps `Oban.Query` thin is fine; a solver who renames `Oban.Query` internals should not fail if end behaviour holds. Prefer behaviour over shape.

### 4. Shortcuts

- `Oban.Repo` + `Oban.Query` wired, scheduler/pruner still call `conf.repo` → fails those checks. Correct incomplete.
- Accept `:get_dynamic_repo` but never call it (always `conf.repo`) → fails `job-uses-resolved-repo`.
- Wire everything but drop prefix in the facade → fails `prefix-applied`.
- Wire the facade but break the no-option path (always go through a nil-safe wrapper that raises) → fails `option-default-nil` / preservation.
- Testing helpers left on `conf.repo` → fails `testing-helpers`.
- Implement a facade that resolves the repo once at boot, not per-call → fails if the test's `get_dynamic_repo` returns different pids over time. **Add that mixed test**: two sequential calls returning pid A then pid B must hit both. That is the real dynamic-repo invariant.

### 5. Flakiness

Medium. Postgres required. Crontab scheduler and pruner are **jobs/timers** — use explicit sync (`Oban.drain_queue` / plugin `perform` directly) rather than waiting for ticks. Notifier is a PubSub/Postgres listener — if you check it, assert query routing not delivery timing. Do not sleep. Integration test at upstream is one file; expand curator checks with explicit plugin invocation.

### 6. Coverage mix

- Positive: option accepted, job/scheduler/pruner/testing/facade routing, prefix.
- Negative: invalid option raises; `:get_dynamic_repo` ignored is not acceptable.
- Preservation: default path unchanged; existing integration suite green.
- Mixed: `get_dynamic_repo` returning different pids across calls (true dynamic), plus one prefix-enabled instance and one default instance in the same test run.

### 7. Environment

- **PostgreSQL required** (runner has it — good).
- Apache-2.0. Ecto/Postgrex pin to 2020-era — confirm offline Hex cache.
- **Elixir ~1.10 / OTP ~23** at base is the real risk. If the runner image cannot build 2020 Oban, this case dies. Verify image compatibility **before** anything else.
- **Nothing executed.** No apply, no compile, no migration.

### 8. XL-specific

10 impl files is **real coordination, not inflated**. The product outcome is "every DB touchpoint respects the dynamic repo + prefix + log"; the file count is the actual call-site graph (Query, Scheduler, Migrations, Notifier, Pruner, Producer, Testing, public options). That is exactly the 10–20 XL target and cannot honestly split into two independent 2–5 cases without losing the "all call sites agree" invariant. Outcome is one story. The new `Oban.Repo` facade is the hub — that is the relationship to verify.

### 9. Verdict

**READY-WITH-FIX** — best cross-cutting OTP/Ecto story in this batch; blocked only on 2020 toolchain proof, log-level visibility, and a true dynamic-pid mixed check.

### 10. Must-fix before qualification

1. Prove the 2020 Elixir/OTP image builds this base offline. If not, defer the whole case.
2. Decide log-level: named check or out of scored obligations.
3. Add mixed test where `get_dynamic_repo` returns different pids on successive calls.
4. Incomplete = `Oban.Repo` + Query without scheduler/pruner. Integrity = option accepted but unused; prefix dropped; default path broken.
5. Grade `ArgumentError` without message. Do not grade `Oban.Query` shape.
6. Drain/call plugins explicitly — no waiting on crontab ticks.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | 2020 toolchain may not run; log-level and Query-shape hidden contracts |
