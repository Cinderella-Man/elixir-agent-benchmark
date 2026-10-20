# app-candidate-mydia-1168

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1168 |
| Title | fix(jobs): return float averages from timestamp diff macros on PostgreSQL |
| Project | getmydia/mydia |
| Source type | Historical merged PR (production crash bug) |
| PR head SHA | `24fa67d35f395857eac8b63d267f4401bbd45478` (1 commit) |
| Parent of first commit (likely base) | `9fb3ce007f8fcdd1b2bf7ce8daf43436885ce7ad` |
| Merged at | 2026-10-17T04:39:36Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body/diff inspected; tests not executed |

## Why it is a case

On PostgreSQL, `EXTRACT(EPOCH ...)` and `AVG` return numeric types that broke `Mydia.Jobs.get_job_stats/1` with `ArithmeticError` when mounting the Jobs page (0.16.0 crash reports). The timestamp-diff macros must yield float averages consistently across SQLite and PostgreSQL.

What must stay consistent:

- `Mydia.DB` timestamp diff / average helpers return values that Jobs stats arithmetic accepts on both adapters.
- `get_job_stats/1` returns integer `avg_duration_ms` (existing shape) for completed jobs and zero when none completed.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/mydia/db.ex` | Timestamp-diff macros / average casting (PostgreSQL numeric → float) |

Tests (separate): `test/mydia/db_test.exs`, `test/mydia/jobs_test.exs` (avg_duration_ms cases).

## Draft ticket

> The Jobs page crashes on PostgreSQL installs with an arithmetic error while computing average job duration. Duration averages must work on both SQLite and PostgreSQL and keep returning whole-millisecond averages. Fix it.

## Named acceptance checks

1. **avg-duration-int** — `get_job_stats/1` returns an integer `avg_duration_ms` for completed jobs (PostgreSQL path).
2. **avg-duration-zero** — returns zero `avg_duration_ms` when no job completed.
3. **no-arithmetic-error** — mounting stats with numeric-typed DB aggregates does not raise `ArithmeticError`.
4. **sqlite-preservation** — same helpers still behave on SQLite.

## Incomplete + integrity control

- **Incomplete:** cast in one aggregate path but leave another timestamp-diff macro returning `Decimal`/`numeric` so a second stats field still crashes. Fail **no-arithmetic-error** on that field.
- **Integrity:** unchanged tree fails on PostgreSQL (**avg-duration-int** / **no-arithmetic-error**). Reference passes. SQLite case is preservation.

## Preservation

- Jobs listing and other stats fields unchanged.
- Empty completed set is zero, not nil/crash.

## Runtime / offline holds

- **Needs PostgreSQL for the discriminating check** (SQLite may already pass — that is the bug). Runner must start Postgres.
- No cloud/media.
- Small diff (1 impl file) — acceptable as focused one-file task per guidelines; pair with a larger Mydia candidate in the corpus mix.

## Status

**discovered** — authentic production crash with a narrow, deterministic fix; high signal if dual-DB fixtures exist. File-count is thin (1 implementation file) — keep as focused case, not the sole Mydia representative.

## Next action

Reproduce `ArithmeticError` on PostgreSQL at base `9fb3ce00...`; confirm CI matrix (SQLite + Postgres) in the project at that revision.
