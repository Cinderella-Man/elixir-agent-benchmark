# Ecto SQL #738 + #753 + #760 — SQL operator precedence for `not` / `in` / `is_nil`

**Status:** discovered
**Source type:** historical PR lineage (3 related merges)
**Project:** [elixir-ecto/ecto_sql](https://github.com/elixir-ecto/ecto_sql)
**PRs:**
- [#738](https://github.com/elixir-ecto/ecto_sql/pull/738) *Parenthesize NOT operands in SQL adapters* — lukaszsamson, merged `04191cba289b76da5575b3516bc676ec9bae3419` (2026-07)
- [#753](https://github.com/elixir-ecto/ecto_sql/pull/753) *Fix NOT precedence for in and is_nil* — lukaszsamson, merged `23857635127b8e94031847dd7522923e48b80150` (2026-09-06)
- [#760](https://github.com/elixir-ecto/ecto_sql/pull/760) *Parenthesize in expressions used as operands* — ybai08, merged `254792d0fb4dc02757a07428127eada77591cf72` (2026-10-17)

**Source revisions:** pre-#738 base → apply all three PR diffs in order (or pin at #760 merge and reverse-verify). Merge SHAs above are squash commits (1 parent each).
**Task kind / family:** bug_fix / SQL generation operator precedence
**Research date:** 2026-10-19
**Exposure:** public historical PRs

## Authentic work

Ecto compiles query expressions to SQL. When a `not`, `in`, or `is_nil` expression is itself an operand of another operator (or is the left-hand side of `IN` / `IS NULL`), missing parentheses let SQL operator precedence change the meaning of the query.

Three follow-up PRs close the holes in sequence:

1. **#738** — `not x` used as an operand of a binary operator (`(not x) < y`) was emitted as `NOT x < y`, which SQL reads as `NOT (x < y)`. Fix: parenthesize `{:not, _, [_]}` in the operand-position helpers of all three adapters (Postgres `maybe_paren`, MyXQL `op_to_binary`, TDS `op_to_binary`).
2. **#753** — `is_nil(not x)` and `(not x) in [...]` (Postgres) still lost parentheses because `in` / `is_nil` compiled their left side with `expr/3` instead of `maybe_paren/3`. Fix: use `maybe_paren` on those left operands.
3. **#760** — `x in [...]` used as an operand of another operator (`x in [1,2] in [true]`) was emitted unparenthesized. Fix: parenthesize `{:in, _, [_, _]}` in operand position (MyXQL + Postgres).

Per [LINEAGE-MERGE-POLICY](../large-features/LINEAGE-MERGE-POLICY.md), this is one case: the ticket describes the final coherent outcome (correct precedence for these three constructs), and the intermediate states are natural incomplete controls.

## Implementation scope (combined reference)

| File | Role |
| --- | --- |
| `lib/ecto/adapters/postgres/connection.ex` | `maybe_paren/3` clauses for `:not` and `:in`; `in`/`is_nil` compile left operand via `maybe_paren` |
| `lib/ecto/adapters/myxql/connection.ex` | `op_to_binary/3` clauses for `:not` and `:in` |
| `lib/ecto/adapters/tds/connection.ex` | `op_to_binary/3` clause for `:not` |
| `test/ecto/adapters/postgres_test.exs` | Named SQL-string assertions for `(not x) < y`, `is_nil(not x)`, `(not x) in ...`, `x in ... in ...` |
| `test/ecto/adapters/myxql_test.exs` | Same family for MyXQL dialect |
| `test/ecto/adapters/tds_test.exs` | `(not x) < y` for TDS dialect |

**Counts:** 3 substantive implementation files (one per adapter), 3 test files. Tests assert exact generated SQL strings — no live database required.

## Cross-component behavior to verify

- All three adapters parenthesize `not` when it is an operand of a comparison (`(not x) < y`).
- Postgres: `is_nil(not x)` and `(not x) in [true, false]` / `in ^list` / `in field` / `in subquery` keep the NOT parenthesized.
- MyXQL and Postgres: `in` used as an operand of another `in` (or comparison) is parenthesized.
- Ordinary expressions without these constructs produce the same SQL as before (no extra parentheses).
- Non-splice fragments, ordinary `and`/`or` filters, and existing `is_nil` / `in` queries are unchanged.

## Draft ticket (short maintenance report)

> Generated SQL can change meaning when `not`, `in`, or `is_nil` expressions appear as operands of other operators: the parentheses that preserve the intended precedence are missing, so e.g. `(not x) < y` becomes `NOT x < y`. Please fix the adapters so these constructs are parenthesized whenever they are used in operand position, consistently across the Postgres, MyXQL and TDS adapters. Ordinary expressions that do not need parentheses should keep the SQL they produce today.

## Acceptance design (proposed, unexecuted)

- Plan `select([r], (not r.x) < r.y)` on each adapter and assert the SQL contains `(NOT (...)) < ...` (not `NOT ... < ...`).
- Plan `is_nil(not r.x)` on Postgres and assert `(NOT (...)) IS NULL`.
- Plan `(not r.x) in [true, false]` and `in ^[true, false]` on Postgres; assert NOT is parenthesized.
- Plan `r.x in [1, 2] in [true]` on MyXQL/Postgres; assert the inner `IN` is parenthesized.
- Preservation: a simple `select([r], r.x + 2)` and a plain `where: r.x == 1` still produce the original SQL strings.

## Plausible incomplete (proposed)

Ship only #738 (`not` as operand) and omit the #753 left-side fix and/or the #760 `in`-as-operand fix. Compiles; the corresponding named SQL assertion fails (e.g. `is_nil(not r.x)` or `x in ... in ...`).

## Integrity control (proposed)

Acceptance must not pass if parentheses are added to every expression (SQL string comparison fails on the preservation cases), if only one adapter is fixed while the ticket says all three, or if `not`/`in` are parenthesized in non-operand position in a way that changes the asserted SQL of ordinary queries.

## Runtime / offline

- Elixir `~> 1.15` (from `mix.exs`). Pure ExUnit SQL-string tests; no live Postgres/MySQL/MSSQL required for these assertions (same rule as filed ecto_sql #703/#741).
- Node/browser not required.

## License / provenance

- Apache-2.0 (`ecto_sql`). Public GitHub PRs. No private edition.
- Three upstream authors (lukaszsamson ×2, ybai08). Attribute all three in provenance; do not score as three cases.

## Holds / unknowns

- #753's Postgres-only `in`/`is_nil` left-side fix does not add equivalent clauses to MyXQL/TDS `in` compilation. Do not invent a requirement that all three adapters implement every clause; grade the observable SQL for the constructs the ticket names, and accept defensible per-dialect differences already present in the reference.
- Exact paren style (`(NOT (x))` vs `(NOT x)`) is dialect emission — grade that precedence is preserved, not a particular spacing, unless the visible tests pin the string (upstream tests do pin strings; a reference-aligned grader may use those, an alternative grader may parse).
- Related skip-list identities: ecto_sql 748 (BooleanExpr join ons) is a different family. Do not merge.

## Coverage added

SQL generation correctness across three adapters — a query-builder/dialect family not yet represented by the filed ecto_sql cases (insert_mode #703, read-only transactions #741, migration callbacks #758).

## Next action

If drafting: pin pre-#738 base, apply #738 → #753 → #760, freeze the three-adapter SQL-string contract, and use "only #738 applied" as the incomplete control.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

The draft is close. Keep the problem statement (precedence changes meaning when `not`/`in`/`is_nil` are operands) and the preservation clause. Two wording defects:

- **"consistently across the Postgres, MyXQL and TDS adapters" over-promises.** #753's `is_nil`/`in` left-side fix is **Postgres-only** in the reference. A solver who also fixes MyXQL/TDS `is_nil(not x)` is *better*, not wrong. If "consistently" is read as "every clause in every adapter," the ticket demands work the reference does not do, and hidden tests that pin the asymmetric reference become unfair.
- The ticket does not need to name `maybe_paren` / `op_to_binary` (it does not — good). It *may* name the three adapters as scope, since that is the requested outcome.

Rewrite to: fix operand-position parenthesization for these constructs **wherever each adapter compiles them**; ordinary SQL must not gain extra parentheses. Accept superset fixes.

### 2. Named deterministic checks (ExUnit, no sleep)

Acceptance design is **proposed and unexecuted**. `_work/ecto_sql-738.diff`, `753.diff`, `760.diff` exist and show the upstream assertions — those are the right shape, but nothing has been run.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `pg not-operand-paren` | `select([r], (not r.x) < r.y)` planned on Postgres | generated SQL | contains `(NOT (...)) < ...`, not `NOT ... < ...` |
| `myxql not-operand-paren` | same on MyXQL | generated SQL | same precedence shape |
| `tds not-operand-paren` | same on TDS | generated SQL | same precedence shape |
| `pg is_nil-of-not` | `is_nil(not r.x)` | generated SQL | `(NOT (...)) IS NULL` |
| `pg not-in-list` | `(not r.x) in [true, false]` and `in ^[true, false]` and `in field` and `in subquery` | generated SQL | NOT stays parenthesized |
| `pg+myxql in-as-operand` | `r.x in [1,2] in [true]` | generated SQL | inner `IN` parenthesized |
| `preserve simple-select` | `select([r], r.x + 2)` on each adapter | generated SQL | byte-identical to pre-change |
| `preserve plain-where` | `where: r.x == 1` | generated SQL | unchanged |

No live DB. Pure `plan/1` + `all/1` SQL strings. Fully deterministic.

**Grading hazard (real):** upstream tests pin exact strings including spacing, e.g. `(NOT (s0."x")) < s0."y"`. A solver emitting `(NOT s0."x") < s0."y"` is precedence-correct and fails string equality. Either (a) state in the ticket that graded SQL strings are exact, or (b) grade via a small paren-aware normalizer / parse. Do **not** hide exact-string pinning in checks.

### 3. Ambiguity / unfairness

- Per-dialect asymmetry (above) is the main unfairness risk. Grade the constructs the ticket names; accept extra fixes; never require a non-fix.
- Exact paren style / spacing (above).
- "Operand position" is fine in prose ("as operands of other operators") but do not grade a solver who also parenthesizes `not` in non-operand position *if* the asserted ordinary SQL is unchanged — the preservation cases cover this.
- #760 also changed an existing assertion (`x in ^list` under `or` gains parens). If that prior string is a hidden preservation check, a #760-complete solver fails it. Update preservation expectations to the post-#760 strings.

### 4. Shortcuts + compiling incomplete

- Incomplete A = #738 only. Compiles. Fails `pg is_nil-of-not` and `pg+myxql in-as-operand`.
- Incomplete B = #738+#753, omit #760. Compiles. Fails `in-as-operand`.
- Shortcut: parenthesize every expression. Caught by `preserve simple-select` / `preserve plain-where`.
- Shortcut: fix Postgres only. Caught by `myxql`/`tds` checks.
- Shortcut: parenthesize `not` in `expr/3` globally (changes ordinary SQL). Caught by preservation.

### 5. Flakiness

**Zero.** SQL-string tests, no processes, no timers, no services.

### 6. Preservation mix

Proposed mix is correct in direction (simple select + plain where unchanged). Strengthen it: keep one ordinary `is_nil` and one ordinary `in` query **without** a `not`/`in` operand, asserting the pre-#760 unparenthesized form where the reference leaves it alone — except the specific `or`/`in` string #760 *did* change, which must move to the "changed" bucket.

### 7. Environment risk

Excellent. Elixir `~> 1.15`, no DB, no Node. Pure ExUnit. Apache-2.0. Three upstream authors — attribute all three; do not score three cases.

**Evidence gap:** acceptance is still "proposed, unexecuted." Diffs in `_work` are the only artifact. No `mix test` receipt exists.

### 8. Verdict

**READY-WITH-FIX** — real coordinated 3-adapter correctness work with a clean lineage story, but unexecuted checks, exact-string over-constraint risk, and a ticket that over-promises cross-adapter symmetry.

### 9. Must-fix list

1. Execute the combined apply (#738 → #753 → #760) and the named checks; record outcomes. Do not ship unexecuted acceptance.
2. Fix ticket wording: drop "consistently across all three adapters"; say each adapter's operand-position constructs must keep precedence. Accept superset fixes.
3. Decide grader for SQL text: exact upstream strings (and then say so) **or** precedence-preserving comparison. Do not silently pin spacing.
4. Incomplete A = #738-only; name `pg is_nil-of-not` as the failing assertion. Incomplete B = omit #760; name `in-as-operand`.
5. Reconcile the `or`/`in` preservation string that #760 itself changed — it cannot be a "unchanged" check.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Unexecuted checks + exact-SQL over-constraint + false cross-adapter symmetry |
