# Ecto SQL #741 — Adapter-level read-only transactions

**Status:** discovered
**Source type:** historical PR
**Project:** [elixir-ecto/ecto_sql](https://github.com/elixir-ecto/ecto_sql)
**PR:** [#741](https://github.com/elixir-ecto/ecto_sql/pull/741)
**Source revisions:** base = first parent of merge (pin at draft) → merge `f76125017345cff15c50a10cb9e95b16d51b051f`
**Author:** cdvx · **Merged:** 2026-07 (PR timeline 2026-07-13 → merge after 2026-07-15)
**Task kind / family:** feature / adapter SQL transaction contract
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

`mix ecto.query` (and similar tooling) privately ran queries inside a read-only transaction via ad-hoc `do_read_only_transaction` clauses that hard-coded Postgres and MyXQL. That helper was not part of the adapter contract: other adapters could not implement it, and application code could not request a read-only transaction at all.

The PR promotes read-only transactions to a proper adapter-level API: an optional `read_only_transaction/3` callback on `Ecto.Adapters.SQL.Connection`, implementations in the MyXQL and Postgres connection modules, and a public `Ecto.Adapters.SQL.read_only_transaction/4` façade that dispatches through the callback (raising a clear `ArgumentError` when the connection module does not export it).

## Implementation scope

| File | Role |
| --- | --- |
| `lib/ecto/adapters/sql/connection.ex` | Optional `@callback read_only_transaction/3` on the connection behaviour |
| `lib/ecto/adapters/sql.ex` | Public façade `read_only_transaction/4`; dispatch or raise for unsupported connections |
| `lib/ecto/adapters/myxql/connection.ex` | MyXQL implementation (`SET TRANSACTION READ ONLY` then run the fun) |
| `lib/ecto/adapters/postgres/connection.ex` | Postgres implementation (set read-only on the transaction connection) |
| `lib/mix/tasks/ecto.query.ex` | Drop the private multi-clause helper; call the new adapter API |
| `test/mix/tasks/ecto.query_test.exs` | Update task tests for the new path |

**Counts:** 4 substantive implementation files (behaviour + façade + two adapters) plus the mix-task caller and its test.

## Cross-component behavior to verify

- New optional callback: adapters that do not implement `read_only_transaction/3` still compile and still run ordinary transactions.
- Unsupported adapter: calling the façade raises `ArgumentError` naming the connection module (not a silent fall-through).
- MyXQL and Postgres both actually constrain the transaction to read-only, not just open a normal transaction.
- The mix task keeps working after the private helper is removed (lineage with #733 / #746 tooling — see holds).

## Draft ticket (short maintenance report)

> Read-only query transactions are hidden inside mix-task private helpers and only work for two hard-coded adapters. Promote this to an adapter-level API: connections may implement a read-only transaction helper, the SQL façade exposes it, and Postgres and MyXQL implement it. Callers on adapters that do not support it must get a clear error instead of a normal writeable transaction. Keep ordinary transactions unchanged.

Public names to freeze if graded: `Ecto.Adapters.SQL.read_only_transaction/4` and the optional `read_only_transaction/3` connection callback (PR body/API treats them as the product surface).

## Acceptance design (proposed, unexecuted)

- Postgres and MyXQL: run a fun under the façade and assert the session/transaction is read-only (attempting a write fails or the SET is visible).
- Connection module without the callback: façade raises `ArgumentError` mentioning the module; `transaction/4` still works.
- Optional-callback preservation: an adapter implementing only the old callbacks compiles and runs non-read-only transactions.
- Mix task path: a query still executes through the new API (no private helper left).

## Plausible incomplete (proposed)

Implement the callback and Postgres but forget MyXQL (or vice versa), or forget to raise for unsupported adapters and silently open a writeable transaction. Compiles; a named per-adapter or error-contract assertion fails.

## Integrity control (proposed)

Acceptance must not pass if "read-only" is a no-op wrapper around `transaction/4`, if unsupported adapters silently succeed, or if removing the mix-task private helper breaks `mix ecto.query`.

## Runtime / offline

- Elixir `~> 1.15` (from `mix.exs`). Unit/SQL-connection tests can run offline; live Postgres/MySQL integration is **optional** and must not be required for admission (same rule as filed ecto_sql #703).
- No network service beyond optional local DB. Node/browser not required.

## License / provenance

- Apache-2.0 (`ecto_sql` license). Public GitHub PR. No private edition.

## Holds / unknowns

- The mix-task file in the diff is the **caller** of the old private helper, not a second product feature. Do not grade `mix ecto.query` UX (that is #733 + #746 lineage: task introduction and explain/to-sql options). Keep this ticket about the adapter contract.
- TDS adapter is untouched in the PR; do not require a TDS implementation unless the brief says so.
- Exact SQL used per dialect (`SET TRANSACTION READ ONLY` vs transaction options) is an implementation choice — grade observable read-only behavior and the error contract, not the statement text.

## Coverage added

Adapter behaviour + multi-dialect coordination (SQL façade, MyXQL, Postgres) with an optional-callback extension point. Complements filed ecto_sql #703 (insert_mode across adapters) with a transaction-contract family instead of DML syntax.

## Next action

If drafting: pin Elixir/OTP from historical CI, freeze the façade and callback names, and add an "unsupported adapter raises" integrity case plus a one-adapter-missed incomplete control.

---

## Grilling (2026-10-19)

### Minimum ticket
Clear and appropriately brief. The product surface (`Ecto.Adapters.SQL.read_only_transaction/4` and optional `read_only_transaction/3` callback) is the requested outcome and belongs in the ticket — correct to freeze those names. Keep "Callers on adapters that do not support it must get a clear error instead of a normal writeable transaction" and "Keep ordinary transactions unchanged." Cut "mix-task private helpers" backstory to one clause; the solver does not need the archaeology.

### Named deterministic checks
Unexecuted. Required named set:
1. Postgres path: fun runs read-only (a write fails or SET is observable)
2. MyXQL path: same
3. connection module without the callback: facade raises `ArgumentError` naming the module
4. ordinary `transaction/4` unchanged on the same adapters
5. adapter implementing only old callbacks still compiles and runs non-read-only transactions
6. `mix ecto.query` still works through the new API (no private helper left)

(1)+(2)+(3) are the product. Without (3) the "silently open a writeable transaction" incomplete passes — that is the worst kind of false success.

### Ambiguity / unfairness
- "Read-only" observable behavior: do **not** grade the exact SQL (`SET TRANSACTION READ ONLY` vs transaction options). Dossier says this. Keep it binding. Grade that a write is rejected or the session/transaction is read-only by a dialect-appropriate observable.
- `ArgumentError` "mentioning the module" — if hidden checks require a specific message format, that is unfair. State "raises ArgumentError" in the brief; grade the exception type, not the message text, unless the message is frozen in the brief.
- TDS untouched: do not require it. Already said. Good.
- Do not grade `mix ecto.query` UX (explain/to-sql is other cases). Only "still executes".

### Shortcuts + compiling incomplete
Named incompletes: implement Postgres but not MyXQL (or vice versa); forget the raise and silently `transaction/4`. Both compile. Under-weighted shortcuts: implement the callback as a no-op wrapper around `transaction/4` (integrity must reject); implement the raise only on the facade but the mix task falls back to writeable transaction (check 6 must assert the new path is actually used); call the callback outside the connection checkout so the SET does not apply (same class of bug as ecto_sql-758 hooks).

### Flakiness
Unit tests offline; optional live PG/MySQL must **not** be required for admission. If checks use a live DB they will flake in CI without services — keep the required set on the in-tree test repo / connection modules. Low flake otherwise.

### Preservation
(4)+(5) are the preservation set. Add a named "adapters without the new callback still run ordinary transactions" and "existing MyXQL/Postgres transaction tests stay green". Mix task preservation (6) is named. Good.

### Env
Elixir `~> 1.15` claimed; historical CI at merge `f7612501` not pinned. Optional live DB is correctly non-required. **Nothing executed** — no apply, no compile, no test. Apache-2.0.

### Combined-lineage requirements
Not a lineage case. Keep #733/#746 mix-task UX lineage out; keep #703 insert_mode out. Dossier is correct.

### Verdict
**HOLD** — design is one of the cleaner "more" candidates, but zero execution and the unsupported-adapter error contract is not yet a named protected check.

### Must-fix before qualification
1. Pin base (first parent of `f7612501`) and toolchain; run `mix test` at base and base+patch offline.
2. Name checks (1)–(6), especially the `ArgumentError` on unsupported adapters and a write-rejection/read-only observable per adapter.
3. Freeze exception type (`ArgumentError`) in the brief; do not grade message text.
4. Integrity: reject no-op `transaction/4` wrappers and connection-checkout misses.
5. Apache-2.0 in provenance.
