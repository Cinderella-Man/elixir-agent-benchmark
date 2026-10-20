# Ecto SQL #758 — Migration `before_transaction/1` and `after_transaction/1` callbacks

**Status:** discovered
**Source type:** historical PR
**Project:** [elixir-ecto/ecto_sql](https://github.com/elixir-ecto/ecto_sql)
**PR:** [#758](https://github.com/elixir-ecto/ecto_sql/pull/758)
**Source revisions:** base = first parent of merge (pin at draft) → merge `bf126d6be628dafdf54409464e5607a665dc9c15`
**Author:** a-nassim · **Merged:** 2026-10-08
**Task kind / family:** feature / migration lifecycle
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

Some SQL settings only work **outside** a migration transaction. The PR body's motivating case is SQLite: `PRAGMA foreign_keys` is ignored inside a transaction, yet the documented table-rebuild procedure needs foreign keys off before the migration runs and restored after.

Upstream `Ecto.Migration` already had in-transaction hooks (`after_begin/0`, `before_commit/0`) but nothing that runs on the same connection around the transaction. The PR adds optional `before_transaction/1` and `after_transaction/1` callbacks that receive the repo and run in a `repo.checkout` on the same connection the transaction will use.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/ecto/migration.ex` | Declare the two optional callbacks, document contract (which helpers are unavailable) and the restore-after pattern |
| `lib/ecto/migrator.ex` | Wrap `repo.transaction/2` in `repo.checkout/2` and invoke the hooks around it |
| `test/ecto/migrator_test.exs` | Named coverage for hook order, rollback, raise-in-`before_transaction`, no-transaction path |
| `test/support/test_repo.exs` | Test-repo support for the new callbacks |

**Counts:** 2 substantive implementation files, 2 test/support files.

## Cross-component behavior to verify

- Optional callbacks: migrations that do not export them keep today's transaction path unchanged.
- Hooks run on the **same connection** as the transaction (a setting made in `before_transaction` is visible inside the migration).
- `after_transaction/1` runs whether the transaction committed **or** rolled back, and even when `before_transaction/1` raised (so restore is reliable).
- When the migration does not run in a transaction (adapter without DDL transactions, or the non-transactional path), neither hook runs — same rule as `after_begin` / `before_commit`.
- Documented helper unavailability (`repo/0`, `prefix/0`, `direction/0`, `execute/1`, `flush/0`) is a contract, not an accident.

## Draft ticket (short maintenance report)

> I need a way to change session settings around a migration transaction — for example turn `PRAGMA foreign_keys` off before SQLite table rewrites and restore it afterwards. Today `after_begin`/`before_commit` only run inside the transaction, which is too late. Please add migration hooks that run on the same connection immediately before the transaction opens and after it closes (committed or rolled back), so a setting made before can be undone after. Migrations that do not define them must behave exactly as today.

Public names to freeze if graded: `before_transaction/1`, `after_transaction/1` (PR body treats them as the product API).

## Acceptance design (proposed, unexecuted)

- Migration module exporting both hooks: assert order `before → transaction body → after`, and that `after` sees a committed and a rolled-back run.
- Raise inside `before_transaction/1`: `after_transaction/1` still runs; the migration does not start.
- Migration module with neither hook: transaction path and result identical to baseline.
- Non-transactional migration (or adapter without DDL transactions): neither hook is invoked.

## Plausible incomplete (proposed)

Implement `before_transaction/1` only and forget the `after` restore, or run hooks outside `checkout` so the setting does not apply to the transaction. Compiles; a named ordering/visibility assertion fails.

## Integrity control (proposed)

Acceptance must not pass if hooks run on a different connection than the transaction, if `after_transaction` is skipped on rollback, or if defining only one callback breaks the no-hook path.

## Runtime / offline

- Elixir `~> 1.15` (from `mix.exs` at research time). Unit migrator tests need no live database if the test repo is in-tree.
- No network service. PostgreSQL/MySQL integration is optional and must not be required for admission.
- Node/browser not required.

## License / provenance

- Apache-2.0 (`ecto_sql` license). Public GitHub PR. No private edition.

## Holds / unknowns

- Exact call contract when `before_transaction` raises was specified in the PR docs ("`after_transaction` runs even if `before_transaction` raised") — grade that, not a softer interpretation.
- TDS adapter path: PR implements via the generic `repo.transaction` wrap; do not score adapter-specific SQL settings beyond the documented SQLite/PRAGMA motivation unless the brief says so.
- Adjacent already-filed ecto_sql identities (#703 insert_mode, #699, #748 BooleanExpr join ons) are unrelated; do not merge.

## Coverage added

Migration lifecycle / connection-scoped configuration. Not another SQL-dialect adapter task.

## Next action

If drafting: pin Elixir/OTP from historical CI at merge, write the ticket with the two callback names as the requested public interface, and add an "after skipped on rollback" incomplete control.

---

## Grilling (2026-10-19)

### Minimum ticket
Good short maintenance report. The PR-motivating SQLite `PRAGMA foreign_keys` example is useful context but is almost a hint about the use case; keep it or replace with "session settings that only work outside a transaction". The requested public names `before_transaction/1` and `after_transaction/1` are the product API and belong in the ticket — the dossier is right to freeze them. Keep "Migrations that do not define them must behave exactly as today."

### Named deterministic checks
Unexecuted prose again. Before this moves, these must be named ExUnit tests:
1. hooks run in order before → body → after (committed run)
2. hooks run in order on rolled-back run
3. raise in `before_transaction/1` → `after_transaction/1` still runs; migration does not start
4. migration with neither hook → identical baseline behavior
5. migration with only one hook defined → defined hook runs; path still valid
6. non-transactional path → neither hook runs
7. setting applied in `before_transaction` is visible inside the transaction (same connection)

(7) is the actual product point (PRAGMA) and the easiest to get wrong (hooks outside `checkout`). Without (3) and (7) the incomplete "before only" or "hooks on a different connection" passes.

### Ambiguion / unfairness
- Helper unavailability (`repo/0`, `prefix/0`, `direction/0`, `execute/1`, `flush/0`) is called "a contract, not an accident" — good. If hidden checks require raising when those are called from hooks, **state that in the brief**. Otherwise a solver who lets `repo/0` work inside hooks is being graded on a hidden rule. Recommendation: state "these migration helpers are not available in the hooks" in the brief, and grade only that the documented restore-after pattern works; do not require specific raise behavior unless stated.
- "after_transaction runs even if before_transaction raised" is in the PR docs and the dossier says grade that. It must also be **in the solver brief** or it is a hidden requirement. Put it in the ticket in one clause.
- Do not score SQLite-specific PRAGMA behavior as required; the generic hook contract is the product. PRAGMA is motivation.

### Shortcuts + compiling incomplete
Named incompletes: before-only (no after restore); hooks outside checkout (setting not visible); after skipped on rollback. All compile. Under-weighted shortcut: implement hooks but invoke them only on migrate-up (not down); add a direction check. Another: run `after` before the transaction actually commits — ordering check (1) must observe commit/rollback state.

### Flakiness
Unit migrator tests with in-tree test repo should be deterministic. If any check uses a live DB, pin it out of the required set. Low flake once hooks are exercised synchronously.

### Preservation
"Same as today" for no-hook migrations is the key preservation and is named (4). Also keep ordinary migrate/rollback results unchanged and existing `after_begin`/`before_commit` behavior untouched. Add a named "existing after_begin/before_commit still fire inside the transaction" check so hook work does not swallow the old callbacks.

### Env
Elixir `~> 1.15` claimed from current mix.exs; **historical CI at merge `bf126d6b` is not pinned**. No services required for unit tests. **Nothing executed** — no apply, no compile, no test. Apache-2.0.

### Combined-lineage requirements
Not a lineage case. Do not merge with #703 / #699 / #748 (adjacent ecto_sql work) — dossier is correct.

### Verdict
**HOLD** — clean small design, zero execution, helper-unavailability and raise-in-before rules are not yet visible in the solver brief.

### Must-fix before qualification
1. Pin base SHA (first parent of `bf126d6b`) and Elixir/OTP from that era's CI; run `mix test` at base and base+patch.
2. Convert the seven obligations above into named protected checks, especially (3) raise-still-restores and (7) same-connection visibility.
3. Put "after_transaction runs even if before_transaction raised" and "documented migration helpers are unavailable in hooks" into the solver brief (or drop the helper-unavailability grading).
4. Add named `after_begin`/`before_commit` preservation check.
5. Apache-2.0 in provenance.
