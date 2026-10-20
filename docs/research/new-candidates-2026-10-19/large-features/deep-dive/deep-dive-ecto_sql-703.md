# Deep-dive dossier — ecto_sql #703 MyXQL `insert_mode: :ignore_errors`

**Case-prep status:** deep-inspected + experiments 2026-10-19/20 (clone, `git apply`, offline unit SQL tests **and** live MySQL integration).  
**Verdict:** **strong viable large-feature candidate.** Applied tree matches merge commit exactly. Unit SQL boundary is fully offline and green. MySQL integration boundary also green for the three `insert_mode` tests (ran against `mysql:8.0` in Docker). One post-merge rename (`:ignore_errors` → `:ignore`) must stay out of the frozen brief.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [elixir-ecto/ecto_sql](https://github.com/elixir-ecto/ecto_sql) |
| PR | [#703 MyXQL: allow use of INSERT IGNORE for on_conflict: :nothing](https://github.com/elixir-ecto/ecto_sql/pull/703) |
| Diff | `pull/703.diff` (15,049 bytes) |
| Author | mehiel |
| Created / Merged | 2025-12-15 / 2025-12-27 |
| Size | +200 / −27, **8 changed files** (6 impl + 1 unit test + 1 integration test) |
| License | **Apache-2.0** (`LICENSE.md` at base) |
| Elixir at base | `~> 1.14` (ecto_sql `3.13.2`) |

### Corrected SHAs (experiment-verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Base (apply point) | `82e2eb36c8a5236876613fa9ec78d500a5e4288d` | “Fix benchmarks (#707)”. Also the **merge parent**. |
| PR head | `a8e9f54d8389aa19d6343a64f2cb6631c8c39492` | Via `refs/pull/703/head`. “Update lib/ecto/adapters/myxql.ex”. |
| Merge (squash) | `af906441d22d369442354904c5127207bb72a58a` | “MyXQL: allow use of INSERT IGNORE for on_conflict: :nothing (#703)”. Parent == base. |
| Intermediate | `7fccc9f42317dfb3d60744594a92c9f31d786dc4` | “Add opt-in INSERT IGNORE support…” (exists). |
| Dead HTML SHAs | `8c7955d…`, `cb3f237…` | **bad objects** (force-pushed). Ignore. |

**PR commits (3):** `7478895` initial “Use INSERT IGNORE for on_conflict: :nothing” → `7fccc9f` opt-in `insert_mode` → `a8e9f54` myxql.ex tweak.

**Applied tree vs merge commit `af90644`:** **empty residual** after `git add -A` — `base + pull/703.diff` **byte-matches** the landed squash. Cleanest reconstruction of the four cases in this batch.

---

## 2. Shortest ticket / brief (curator-frozen)

> For MySQL, `on_conflict: :nothing` should optionally use `INSERT IGNORE` so ignored duplicate-key rows report zero affected rows instead of one. Expose that as `insert_mode: :ignore_errors` on insert/insert_all. Default `on_conflict: :nothing` behavior stays as today. Postgres and TDS adapters must keep working when the extra option is present (they can ignore it). `insert_all` row counts must be accurate for ignored duplicates.

Keep `on_conflict: :nothing` and `insert_mode: :ignore_errors` as the requested public API.  
Do **not** name `insert_keyword/1` or the connection callback arity.  
**Do not** mention the later rename to `:ignore` (post-merge commit `ca7c7f5`) — that is future work.

---

## 3. File roles (from `pull/703.diff`)

### Implementation (6 substantive)

| Path | Role |
| --- | --- |
| `lib/ecto/adapters/sql/connection.ex` | Behaviour `insert/8` gains `opts` + docs. |
| `lib/ecto/adapters/sql.ex` | `insert_all` passes `opts` into `conn.insert/8`. |
| `lib/ecto/adapters/myxql/connection.ex` | `insert_keyword(:ignore_errors)` → `"INSERT IGNORE INTO "`; `on_conflict/3` skips `ON DUPLICATE KEY UPDATE` when ignore mode. |
| `lib/ecto/adapters/postgres/connection.ex` | Accept/ignore `opts` on `insert/8`. |
| `lib/ecto/adapters/tds/connection.ex` | Accept/ignore `opts` on `insert/8`. |
| `lib/ecto/adapters/myxql.ex` | Result handling (`num_rows: 0` → `{:ok, []}`). |

### Tests (2)

| Path | Boundary | Contract |
| --- | --- | --- |
| `test/ecto/adapters/myxql_test.exs` | **Unit / offline** | `"insert with on duplicate key"`, `"insert with insert_mode: :ignore_errors"` (SQL strings). |
| `integration_test/myxql/upsert_all_test.exs` | **MySQL required** | `"insert_mode: :ignore_errors"`, `"… with mixed records"`, `"… with all duplicates"` (`{count, nil}` outcomes). |

**Counts:** 6 impl / 1 unit test / 1 integration test. +200/−27.

---

## 4. Grading boundary split (explicitly requested)

| Layer | Command | Needs | Role in grading |
| --- | --- | --- | --- |
| **L0 compile** | `mix compile` | none | Behaviour arity + all three adapters compile. |
| **L1 unit SQL (offline)** | `mix test test/ecto/adapters/myxql_test.exs` (+ postgres/tds unit files) | **no DB** | SQL text for default vs ignore mode; other adapters unchanged. **Primary acceptance for offline runners.** |
| **L2 MySQL integration (service)** | `ECTO_ADAPTER=myxql mix test integration_test/myxql/upsert_all_test.exs` | MySQL + `ecto` dep | Row-count accuracy (`{0, nil}` / mixed counts). **Stretch / optional service boundary.** |

**Recommendation:** score A1/A2/A5 from L1 offline. Score A3/A4 (row counts) from L2 only when a MySQL service is provisioned; do **not** replace L2 with mocks. If the runner has no MySQL, freeze L1 as the admission boundary and mark A3/A4 as “service-gated” in the curator record.

---

## 5. Named acceptance ↔ upstream tests

| ID | Obligation | Layer | Upstream evidence |
| --- | --- | --- | --- |
| A1 | `insert_mode: :ignore_errors` emits `INSERT IGNORE INTO` | L1 | `"insert with insert_mode: :ignore_errors"` |
| A2 | Default still `INSERT INTO … ON DUPLICATE KEY UPDATE` | L1 | `"insert with on duplicate key"` |
| A3 | Ignored duplicates contribute 0 to count | L2 | `"insert_mode: :ignore_errors with all duplicates"` |
| A4 | Mixed batch counts only new rows | L2 | `"… with mixed records"` |
| A5 | Postgres/TDS `insert/8` compile + SQL tests pass with opts ignored | L1 | `postgres_test.exs` / `tds_test.exs` |
| A6 | Third-party adapters with old arity need default `opts \\ []` or documented migration | L1 compile | behaviour + reference defaults |

### Compiling incomplete + named failure

**Incomplete A:** MyXQL emits `INSERT IGNORE` locally but `Ecto.Adapters.SQL.insert_all` does not pass `opts`.  
**Named failure:** L2 `"insert_mode: :ignore_errors"` (option never arrives) — or L1 only if tests call through `insert_all`. Prefer a check that goes through `insert_all`.

**Incomplete B:** Postgres also emits `INSERT IGNORE` (invalid).  
**Named failure:** L1 postgres SQL tests / A2/A5.

### Integrity / shortcut rejection

- Change the **default** `on_conflict: :nothing` SQL (A2).
- Always return `{0, nil}` for ignore mode even when rows were inserted (A3/A4).
- Break `:returning` / placeholder error paths in MyXQL.
- Silently treat unknown `insert_mode` values as “insert duplicates with no conflict handling”.

---

## 6. Experiment log (honest)

### E1 — Full diff

`ecto_sql-703.diff`: 8 files, +200/−27. Matches inventory.

### E2 — Corrected SHAs

See §1. Squash merge parent **is** the claimed base. Applied tree == merge tree (strongest match in this batch).

### E3 — Clone + `git apply` at base

```
git checkout 82e2eb36c8a5236876613fa9ec78d500a5e4288d
git apply --check .../ecto_sql-703.diff   # CHECK:0
git apply       .../ecto_sql-703.diff     # APPLY:0
git add -A
git diff --cached af906441d22d369442354904c5127207bb72a58a   # empty
```

**Result: PASS.** Applied tree == merge commit.

### E4 — Offline unit SQL (`mix test`) — Windows Elixir 1.20.4 / OTP 29

```
mix deps.get    # OK (ecto from git master, myxql, postgrex, tds, …)
mix compile     # OK (warnings only)

mix test test/ecto/adapters/myxql_test.exs
# Result: 142 passed

mix test test/ecto/adapters/postgres_test.exs test/ecto/adapters/tds_test.exs
# Result: 303 passed

mix test test/ecto/adapters/myxql_test.exs:1468 test/ecto/adapters/myxql_test.exs:1503
# Result: 2 passed, 140 excluded
#   ("insert with on duplicate key" + "insert with insert_mode: :ignore_errors")
```

**L1 boundary: PASS** (A1, A2, A5).

### E5 — MySQL integration (L2) — Docker `mysql:8.0`

```
docker run -d --name elx-mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -e MYSQL_DATABASE=ecto_test -p 3306:3306 mysql:8.0
# create database ecto_test; user root @ 127.0.0.1

ECTO_ADAPTER=myxql MYSQL_URL=root@127.0.0.1 mix test integration_test/myxql/upsert_all_test.exs --trace
# Result: 7 passed
#   including:
#     * insert_mode: :ignore_errors
#     * insert_mode: :ignore_errors with mixed records (some conflicts, some new)
#     * insert_mode: :ignore_errors with all duplicates
#     * on conflict ignore   (default {1,nil} workaround still correct)
```

**L2 boundary for #703 acceptance: PASS** (A3, A4).

Broader `ECTO_ADAPTER=myxql mix test` (whole integration suite): **422/433 passed, 63 excluded**. The 11 failures are in unrelated integration modules (not `upsert_all_test`). Do not use the full integration suite as the #703 acceptance net.

### E6 — Later commits on the same files (after `af90644`)

| SHA | What | Relevance |
| --- | --- | --- |
| `ca7c7f5` | **Rename `ignore_errors` → `ignore`** (“stay closer to the database definition”) | **API rename 1 day after merge.** Freeze `:ignore_errors` at this base; do not grade `:ignore`. |
| `1d906ce` (#718) | Fix warnings in 1.20 and require Elixir 1.15+ | Toolchain floor moves later. |
| many | SQL precedence / JSON / fragment work on `myxql/connection.ex`, `sql.ex`, unit tests | Out of scope; high churn on the same files. |

**Window:** clean for freeze at base `82e2eb3` + PR. Post-merge rename is the main trap for over-fitting acceptance to current upstream.

---

## 7. Preservation

- Existing MyXQL upsert tests for `ON DUPLICATE KEY UPDATE` remain green (L1 `"insert with on duplicate key"` + L2 `"on conflict ignore"`).
- Postgres/TDS insert SQL unchanged (303 unit tests).
- `Ecto.Adapters.SQL` statement caching / placeholders path still works (covered by remaining unit tests).

---

## 8. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| L1 unit tests | **No database.** Offline. |
| L2 integration | **MySQL required.** Verified with Docker `mysql:8.0`, empty root password, db `ecto_test`. |
| Ecto sibling | `mix.exs` pulls `ecto` from git `master` unless `ECTO_PATH` is set. For historical fidelity pin matching ecto at the PR date; experiment used current master and L1/L2 still passed. |
| Elixir floor at base | `~> 1.14`. Tested on 1.20.4 / OTP 29. |
| Apache-2.0 | Provenance notice. |
| Postgres/TDS live integration | Optional; unit SQL is enough for A5. |

---

## 9. Curator record fields

```yaml
case_id: ecto_sql-703-insert-ignore
project: elixir-ecto/ecto_sql
pr_url: https://github.com/elixir-ecto/ecto_sql/pull/703
base_sha: 82e2eb36c8a5236876613fa9ec78d500a5e4288d
pr_head_sha: a8e9f54d8389aa19d6343a64f2cb6631c8c39492
merge_sha: af906441d22d369442354904c5127207bb72a58a
merged_at: 2025-12-27
task_kind: bounded_feature
impl_files: 6
test_files_touched: 2
total_files: 8
license: Apache-2.0
elixir_floor: "~> 1.14"
tested_on: "Elixir 1.20.4 / OTP 29"
offline_unit: true
db_required_for_full_acceptance: "MySQL (L2); L1 fully offline"
git_apply: clean_at_base
applied_matches_merge: true
mix_test_unit_myxql: "142 passed"
mix_test_unit_pg_tds: "303 passed"
mix_test_named_insert_mode: "2 passed (default + ignore_errors SQL text)"
mix_test_integration_upsert_all: "7 passed against mysql:8.0"
mix_test_integration_full: "422/433 (11 unrelated failures)"
grading_boundary:
  offline: [A1, A2, A5, A6]
  mysql_service: [A3, A4]
later_api_rename: "ca7c7f5 :ignore_errors -> :ignore (out of scope)"
difficulty_hint: medium
scope_risk: cross_adapter_behaviour_arity
```

---

## 10. Next action

1. Pin base `82e2eb3…`; freeze brief with `insert_mode: :ignore_errors` (not `:ignore`).
2. Incomplete = SQL keyword without `opts` plumbing from `insert_all` → fail L2 ignore-count tests (or an `insert_all`-level L1 check).
3. Acceptance offline: `mix test test/ecto/adapters/myxql_test.exs` (and postgres/tds for A5).
4. Acceptance service (optional stretch): `ECTO_ADAPTER=myxql mix test integration_test/myxql/upsert_all_test.exs` with Docker MySQL.
5. Record the L1/L2 split in the case bundle so a no-MySQL runner still grades fairly.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Strong brief. `on_conflict: :nothing` optionally uses `INSERT IGNORE` so ignored duplicates report zero affected rows; `insert_mode: :ignore_errors` is the public option; default conflict SQL unchanged; Postgres/TDS accept and ignore the option; `insert_all` row counts accurate. Public names correctly frozen (`:ignore_errors`, **not** the later `:ignore`). Do not name `insert_keyword/1` or callback arity — already correct.

One wording check: "Postgres and TDS adapters must keep working when the extra option is present (they can ignore it)" is the right tolerance clause. Keep it — a solver who implements `INSERT IGNORE` on Postgres is wrong (invalid SQL), and L1 postgres tests catch it.

### 2. Named deterministic checks (ExUnit, no sleep)

This candidate has the best evidence in the batch: L1 offline SQL executed (142 myxql + 303 pg/tds), L2 MySQL integration executed (7 passed against `mysql:8.0`), applied tree **byte-matches** the squash merge.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `myxql ignore-mode-sql` | `insert_mode: :ignore_errors` | generated SQL | `INSERT IGNORE INTO …` |
| `myxql default-unchanged` | `on_conflict: :nothing` without the option | generated SQL | `INSERT INTO … ON DUPLICATE KEY UPDATE` (A2 preservation) |
| `myxql insert_all-plumbs-opts` | `Ecto.Adapters.SQL.insert_all` with the option | generated SQL / conn.insert args | option **arrives** at the connection — **this is the hole, see below** |
| `pg/tds compile+sql` | same option present | compile + SQL | adapters compile and their SQL is unchanged (A5) |
| `myxql ignore-counts-zero` *(service)* | all-duplicate batch | result | `{0, nil}` (A3, L2) |
| `myxql mixed-batch-counts-new` *(service)* | mixed batch | result | count = new rows only (A4, L2) |
| `preserve returning/placeholders` | existing MyXQL paths | SQL | unchanged |
| `preserve default-upsert` | `on conflict ignore` / `ON DUPLICATE KEY UPDATE` | L2 | still correct |

**The real hole.** Upstream L1 tests call the connection module's `all/1` on a planned query. They do **not** go through `Ecto.Adapters.SQL.insert_all`. The dossier's own Incomplete A ("MyXQL emits `INSERT IGNORE` locally but `insert_all` does not pass `opts`") would therefore **pass L1** and only fail L2. If the runner has no MySQL, that incomplete is invisible.

MUST add an offline check that drives `insert_all` (or otherwise asserts `opts` are plumbed). Without it, L1 is not a complete admission boundary.

### 3. Ambiguity / unfairness

- `:ignore_errors` frozen, `:ignore` excluded (post-merge `ca7c7f5`). Good.
- Row-count accuracy is L2. If graded without MySQL, unfair. The L1/L2 split must be recorded in the bundle so a no-MySQL runner freezes L1 as the boundary and marks A3/A4 service-gated.
- "they can ignore it" for Postgres/TDS — fair. Do not require Postgres to *understand* the option.
- Ecto sibling is pulled from git `master` unless `ECTO_PATH` is set. Historical fidelity needs a pin; the experiment used current master and still passed, which is comforting but not a freeze.

### 4. Shortcuts + compiling incomplete

- Incomplete A = SQL keyword without `opts` plumbing from `insert_all`. Compiles. **Passes L1 as currently written.** Fails `myxql insert_all-plumbs-opts` (authored) or L2 A3/A4.
- Incomplete B = Postgres also emits `INSERT IGNORE`. Fails `pg/tds compile+sql` / A2.
- Shortcut: change the default `on_conflict: :nothing` SQL. Caught by `myxql default-unchanged`.
- Shortcut: always return `{0, nil}` in ignore mode even when rows were inserted. Caught by `myxql mixed-batch-counts-new` (L2) — and by an authored L1 check if one can observe the planned SQL/result shape offline.
- Shortcut: silently treat unknown `insert_mode` values as bare insert. Integrity: unknown values should error or be rejected; state it or do not grade it.
- Shortcut: break `:returning` / placeholders. Caught by `preserve returning/placeholders`.

### 5. Flakiness

Low. L1 is pure SQL-string ExUnit. L2 needs a live MySQL (Docker `mysql:8.0`, empty root password, db `ecto_test` — already proven). The broader integration suite (422/433) has 11 unrelated failures — do **not** use it as the #703 net.

### 6. Preservation mix

Good: default upsert SQL, Postgres/TDS unchanged (303 unit tests), returning/placeholders. Add one L1 `insert_all` path for the **default** (no option) so plumbing regressions in both directions are caught.

### 7. Environment risk

Split and honest:
- **L1:** no DB, offline, excellent. Elixir `~> 1.14`, Apache-2.0, 6 impl files.
- **L2:** MySQL required. Verified. If the runner lacks MySQL, freeze L1 and mark A3/A4 service-gated — do not mock them away.
- Pin the ecto sibling for historical fidelity.

### 8. Verdict

**READY-WITH-FIX** — cleanest reconstruction in the batch (applied tree == merge), with L1+L2 executed and a clear grading split; blocked on an offline `insert_all`-path check so the natural incomplete cannot sneak past L1.

### 9. Must-fix list

1. **Hard gate:** author an offline check that drives `insert_all` (opts must arrive at the connection). L1 as written does not catch Incomplete A.
2. Freeze `:ignore_errors` in the brief; do not grade `:ignore`.
3. Record the L1/L2 split in the bundle; mark A3/A4 service-gated when there is no MySQL.
4. Pin the ecto sibling version for historical fidelity.
5. Incomplete = SQL keyword without `insert_all` plumbing; name `myxql insert_all-plumbs-opts` as the failure.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | L1 does not exercise `insert_all` plumbing — incomplete can pass offline |
