# Large feature — ecto_sql #703 MyXQL INSERT IGNORE via `insert_mode: :ignore_errors`

**Status:** discovered
**Source type:** historical merged PR (on_conflict accuracy for MySQL)
**Project:** [elixir-ecto/ecto_sql](https://github.com/elixir-ecto/ecto_sql)
**PR:** [#703](https://github.com/elixir-ecto/ecto_sql/pull/703) — MyXQL: allow use of INSERT IGNORE for on_conflict: :nothing
**Author:** mehiel · **Merged:** 2025-12-27
**Source revisions:** base `82e2eb36c8a5236876613fa9ec78d500a5e4288d` → head `a8e9f54d8389aa19d6343a64f2cb6631c8c39492` → merge `af906441d22d369442354904c5127207bb72a58a`
**Size:** +200 / −27, **8 changed files**
**Task kind / family:** bounded feature / SQL adapter insert path
**Research date:** 2026-10-19
**License:** Apache-2.0 (`package().licenses: ["Apache-2.0"]`; `LICENSE.md` at base)

---

## Why it is a LIMIT-TESTING case

Default MySQL `on_conflict: :nothing` uses `ON DUPLICATE KEY UPDATE x = x`, which reports **1 row affected even when a duplicate is skipped**. The feature adds an explicit `insert_mode: :ignore_errors` that emits `INSERT IGNORE` so ignored duplicates return **{0, nil}**. Consistency must hold across:

1. **`Ecto.Adapters.SQL.Connection` behaviour** — `insert/8` gains `opts`.
2. **`Ecto.Adapters.SQL`** — `insert_all` passes opts into `conn.insert/8`.
3. **`Ecto.Adapters.MyXQL.Connection`** — `insert_keyword(:ignore_errors)` and conflict rendering.
4. **`Ecto.Adapters.Postgres.Connection` / `Tds.Connection`** — accept the extra opts argument without breaking.
5. **Unit SQL tests + integration upsert tests** — string SQL and `{count, nil}` outcomes.

Six implementation files (behaviour + three adapters + SQL façade), clear public option from the PR body (Jose Valim’s suggestion for the opts parameter). Unit tests do not need MySQL; integration tests do.

## File inventory with roles

From `pull/703.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/ecto/adapters/sql/connection.ex` | Behaviour callback arity + docs for `opts`. |
| `lib/ecto/adapters/sql.ex` | Pass `opts` from `insert_all` into `conn.insert/8`. |
| `lib/ecto/adapters/myxql/connection.ex` | `insert_mode` → `INSERT IGNORE INTO`; `on_conflict/3`. |
| `lib/ecto/adapters/postgres/connection.ex` | Accept/ignore `opts` on `insert/8`. |
| `lib/ecto/adapters/tds/connection.ex` | Accept/ignore `opts` on `insert/8`. |
| `lib/ecto/adapters/myxql.ex` | Adapter-level result handling (`num_rows: 0` → `{:ok, []}`). |

**Counts:** 6 substantive implementation files. Tests + one integration case separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/ecto/adapters/myxql_test.exs` | SQL text for default vs `insert_mode: :ignore_errors` (`"insert with insert_mode: :ignore_errors"`, `"insert with on duplicate key"`). |
| `integration_test/myxql/upsert_all_test.exs` | Live `{count, nil}` for mixed/all-duplicate batches (`"insert_mode: :ignore_errors"`, `"… with mixed records"`, `"… with all duplicates"`). |

### Mechanical / docs

| Path | Note |
| --- | --- |
| (callback docs in `sql/connection.ex`) | Contract text for adapters. |

## Draft clarified feature brief

> For MySQL, `on_conflict: :nothing` should optionally use `INSERT IGNORE` so ignored duplicate-key rows report zero affected rows instead of one. Expose that as `insert_mode: :ignore_errors` on insert/insert_all. Default `on_conflict: :nothing` behavior stays as today. Postgres and TDS adapters must keep working when the extra option is present (they can ignore it). `insert_all` row counts must be accurate for ignored duplicates.

Keep `on_conflict: :nothing` and `insert_mode: :ignore_errors` as the requested public API. Do **not** name `insert_keyword/1` or the connection callback arity.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **SQL text:** MyXQL with `insert_mode: :ignore_errors` emits `INSERT IGNORE INTO` (unit `"insert with insert_mode: :ignore_errors"`). |
| A2 | **Default preserved:** without the option, still `INSERT INTO … ON DUPLICATE KEY UPDATE` (`"insert with on duplicate key"`). |
| A3 | **Row counts:** ignored duplicates contribute 0 to the count (integration `"… with all duplicates"`). |
| A4 | **Mixed batch:** some conflicts + some new rows → count is only the new ones (`"… with mixed records"`). |
| A5 | **Other adapters:** Postgres/TDS `insert/8` still compile and pass their SQL unit tests with opts ignored. |
| A6 | **Behaviour:** third-party adapters that only match the old arity need a default `opts \\ []` or documented migration — reference adds defaults; preserve their compile story. |

## Incomplete control

**Compiling partial that misses one area:** implement MyXQL `INSERT IGNORE` locally but forget to pass `opts` from `Ecto.Adapters.SQL.insert_all/8`.

- Unit tests that call `SQL.insert(..., opts)` may pass; **A1/A3** fail at the real `insert_all` path (option never arrives).
- Second partial: change Postgres to emit `INSERT IGNORE` (invalid) → **A2/A5** fail.

## Integrity / shortcut rejection

Reject patches that:

- Change the **default** `on_conflict: :nothing` SQL (A2).
- Always return `{0, nil}` for ignore mode even when rows were inserted (A3/A4).
- Break `:returning` / placeholder error paths in MyXQL.
- Ignore `insert_mode` values other than `:ignore_errors` in a way that silently inserts duplicates without conflict handling.

## Preservation of existing behavior

- Existing MyXQL upsert tests for `ON DUPLICATE KEY UPDATE` remain green.
- Postgres/TDS insert SQL unchanged.
- `Ecto.Adapters.SQL` statement caching / placeholders path still works.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.14` at base | ecto_sql `3.13.2`. |
| Unit tests | **No database** — `test/ecto/adapters/myxql_test.exs` builds SQL strings. |
| Integration tests | **MySQL required** for `integration_test/myxql/upsert_all_test.exs`; Postgres/TDS siblings optional. Prefer unit acceptance if the runner lacks MySQL. |
| Apache-2.0 | Provenance notice. |
| Ecto core sibling | Repo README expects matching `ecto` checkout for integration; pin both. |

Not verified here: compile/test/boot. Prefer unit-SQL acceptance family for offline cases; treat live MySQL as a stretch check.

## Status: discovered

Six-file cross-adapter feature with a precise public option and measurable row-count outcome. Strong SQL-adapter diversity pick.

## Next action

1. Pin base `82e2eb36c8a5236876613fa9ec78d500a5e4288d` (ecto_sql) + matching ecto if integration is used.
2. Brief names `insert_mode: :ignore_errors` and accurate ignore counts.
3. Incomplete = SQL keyword without opts plumbing from `insert_all`.
4. Acceptance offline: `mix test test/ecto/adapters/myxql_test.exs`; mark integration as optional service.
