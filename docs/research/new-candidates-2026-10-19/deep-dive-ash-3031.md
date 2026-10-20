# Deep-dive dossier — Ash #3031 calculation arguments

**Case-prep status:** deep-inspected 2026-10-19 (API + raw diff + commit history).  
**Verdict:** strong coordinated-fix case (5 impl files). **New test file does NOT need PostgreSQL** (`Ash.DataLayer.Ets`). Watch three later commits to the same files within three days.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [ash-project/ash](https://github.com/ash-project/ash) |
| PR | [#3031 fix: validate calculation arguments once and preserve input errors](https://github.com/ash-project/ash/pull/3031) |
| Diff | https://github.com/ash-project/ash/pull/3031.diff |
| Author | [barnabasJ](https://github.com/barnabasJ) (CONTRIBUTOR), merged by **zachdaniel** |
| PR body | Long, precise (quoted below) |
| Created / Merged | 2026-10-15T12:55:04Z / 2026-10-15T22:42:51Z |
| Branch | `barnabasJ:codex/issue-01-test-layout-20261015` |
| Base SHA | `bc4f2bbd99ca4a2077908a49f036a65dc42b5828` |
| Head SHA | `a4f8cb835b6d0ad2245fc59eb22626c24d6f435c` |
| Merge commit | `190987ec134a6a01b72d3eb8d9dcb26577b15873` |
| Size | **21 commits**, +919 / −93, **6 changed files** |
| License | **MIT** (SPDX headers on `mix.exs` and on the new test file; `package().licenses: ["MIT"]`). Root `LICENSE*` filename **not verified** at base (404 on `LICENSE`, `LICENSE.md`, `LICENSE.txt` via raw). Package `files` list includes `LICENSE*`, so some `LICENSE*` path exists — expand at prep. |
| Elixir requirement at base | `~> 1.11` (Ash version `3.36.0`) |

Linked issues: none declared in the PR. The branch name (`codex/issue-01-test-layout-20261015`) suggests an internal issue tracker, not a public GitHub issue.

### PR body (essentials, verbatim fragments)

> Calculation arguments could be validated twice while parsing filters. With expression arguments present, the first pass wraps literals in type hints, so the second pass could reject a literal as an unsupported expression or crash while preprocessing an array. Normalized literals could also lose their constrained value, and bare custom-type callback rejections did not consistently become useful input errors.
>
> Leave argument validation to the resource-calculation constructor, preserve cast and constrained literal values alongside expression arguments, and skip literal-array preprocessing for expressions. Handle malformed filter/sort argument containers and callback rejections with structured errors. Preserve expression rejection in `filter_input` for both map and tuple calculation forms.

Validation claimed in the body (at test-consolidation commit `2b07ebb9e677c899dd578488129abaf7a253ad3d`):

- `mix test test/calculations test/sort/sort_test.exs --seed 15101`: 170 passed, including all 53 issue-specific features.
- `mix compile --warnings-as-errors`: passed.
- `mix format --check-formatted test/calculations/calculation_argument_test.exs`: passed.

---

## 2. Shortest ticket / brief

> Calculation arguments are validated more than once while filters and sorts are built. With an expression argument present, the first pass wraps literals in type hints, so a second pass can reject a literal as an unsupported expression or crash while preprocessing an array. Normalized literals can lose their constrained values. Bare custom-type callback rejections do not consistently become useful input errors. Validate calculation arguments once at the resource-calculation constructor (`Ash.Query.Calculation.from_resource_calculation/3`), keep cast/constrained literals intact beside expression arguments, skip literal-array preprocessing for expressions, and turn malformed filter/sort argument containers and callback rejections into structured input errors. Preserve expression rejection in `filter_input` for both map and tuple calculation forms. Keep ordinary calculation, filter and sort behavior unchanged.

---

## 3. File roles + key quotes

| File | Role |
| --- | --- |
| `lib/ash/query/calculation.ex` | Constructor owns validation once; new `allow_expr?` opt |
| `lib/ash/query/query.ex` | `validate_calculation_arguments/3` literal vs expr handling |
| `lib/ash/filter/filter.ex` | Filter map/tuple forms; `calculation_input/1`; `transform_calculation_input/3` |
| `lib/ash/query/function/type.ex` | Keep type hint for already-cast literals (`casted?: true`) |
| `lib/ash/sort/sort.ex` | Sort argument containers (`input_calculation/3`) |
| `test/calculations/calculation_argument_test.exs` | **New** consolidated suite (+790 lines, 2 modules) |

Key quotes from the diff:

- `calculation.ex` new opt: *"Whether arguments that allow expressions may be given expressions."* (`allow_expr?: [type: :boolean, default: true]`).
- `calculation.ex` args schema: *"Arguments to pass to the calculation, keyed by argument name as an atom or a string"* with `type: {:map, :any, :any}` so unknown keys reach `NoSuchInput`.
- `type.ex`: *"Validated calculation literals retain their type hint for data layers without coercing the already cast and constrained value again."* → `def evaluate(%{arguments: [val, _, _], extra: %{casted?: true}}), do: {:known, val}`.
- `filter.ex` `calculation_input/1`: rejects non-map/non-keyword with `InvalidFilterValue.exception(value: input, message: "calculation input must be a map")`.
- `query.ex` restructure: the `has_one_expr?` branch now stores `%Ash.Query.Function.Type{arguments: [casted, …], extra: %{casted?: true}}` (the **casted** value, not the raw one) and a new `:error` branch yields `InvalidCalculationArgument` *"is invalid"*.
- New test module headers carry `# SPDX-License-Identifier: MIT`.

---

## 4. Named acceptance assertions ↔ requirements

Upstream named tests (module `Ash.Test.Calculations.CalculationArgumentExprTest` and `Ash.Test.Calculations.CalculationArgumentErrorsTest`) mapped to requirements:

| Requirement | Named tests |
| --- | --- |
| Literal array + expression sibling works in load / filter / query filter / map filter / tuple filter | `"loads through another expression calculation"`, `"filters through another expression calculation"`, `"works when the array argument allows expressions"`, `"works in a query filter"`, `"works in a filter statement"`; tuple: `"accepts a literal array argument alongside an expression argument"` |
| String-keyed argument names | `"accepts string-keyed arguments"`; `"are accepted in filter input"`, `"are accepted in sort input"`, `"are accepted when loading the calculation"` |
| `filter_input` rejects expressions (`allow_expr?` boundary) | `"does not accept expressions as calculation arguments"`; tuple form: `"does not accept expressions"` — message must include `"does not support expressions"` |
| Array-valued **expression** argument skips literal-array preprocessing | `"works in a filter"`, `"works when loading the calculation"` (under `"an expression for an array argument"`) |
| Malformed containers → structured `Ash.Error.Invalid`, not crash | parameterized: `"in filter input #{inspect} is an invalid filter"` (`nil`, `"x"`, `[1, 2]`); `"in the tuple filter form …"` (`"x"`, `[1, 2]`); `"in sort input …"` (`"x"`, `[1, 2]`, `5`) |
| Unknown keys → `NoSuchInput` | `"with keys that aren't argument names is an invalid filter"` |
| Normalized literals keep constrained values | `"filter alongside an expression argument"`, `"load alongside an expression argument"`, `"normalize with literal siblings"` (custom `Label` type trims `" match "` → `"match"`) |
| Required/optional/default + normalized nil | `"reject a required string normalized to nil with …"`, `"reject a provided string normalized to nil instead of using its default with …"`, `"allow an optional string normalized to nil with …"`, `"preserve default callbacks with expression siblings"` |
| Custom-type values not double-cast | `"preserve constrained custom values without recasting them"` (Label `cast_input` only accepts strings; second cast would fail) |
| General expression coercion unchanged | `"keep expression string coercion distinct from literal normalization"` → `Ash.Expr.eval(expr(type(" match ", :string))) == {:ok, " match "}` |
| Callback rejections become input errors across load/filter/sort | `Ash.Test.Calculations.CalculationArgumentErrorsTest`: `"#{operation} returns input errors for rejected #{description}"` × {scalar constraints, collection casting, collection constraints, nested collection casting} |
| Collection callback messages survive | `"collection callback messages survive calculation argument validation"` — must include `"labels were rejected"` |
| Normalized args used for load/filter/sort | `"#{calculation} uses normalized arguments for loads, filters and sorts"` |

---

## 5. Compiling incomplete + named failure

**Incomplete A — fix filter double-validation only; leave `sort.ex` containers unchanged.**  
Fails: `"in sort input #{inspect} is an invalid sort"` cases and `"are accepted in sort input"`.

**Incomplete B — skip double validation by dropping expression support (`allow_expr?` always false).**  
Fails: `"works in a filter"` / `"works when loading the calculation"` under `"an expression for an array argument"`, and every `after: cutoff_calc` / `expr(cutoff_calc)` sibling test.

**Incomplete C — keep wrapping the *raw* (uncasted) value in `%Function.Type{}`.**  
Fails: `"preserve constrained custom values without recasting them"` (Label would be recast from `" match "` and fail) and `"normalize with literal siblings"`.

**Incomplete D — treat expression args as literal arrays (no `Ash.Expr.expr?` guard).**  
Fails: `"works in a filter"` for `tags_are?(tags: tags)` — *"must bypass literal-array preprocessing"*.

**Named failure for A:** `test "in sort input [1, 2] is an invalid sort"`.  
**Named failure for C:** `test "preserve constrained custom values without recasting them"`.

---

## 6. Integrity control

- Reject disabling calculation arguments entirely.
- Reject swallowing custom-type callback errors as success (the `Labels were rejected` message must surface).
- Reject "fixing" double validation by validating **zero** times (unknown keys must still yield `NoSuchInput`).
- Reject changing general `type/2` expression coercion (`" keep expression string coercion distinct…"` must stay `{:ok, " match "}`).
- Reject requiring PostgreSQL for these tests — they use `Ash.DataLayer.Ets`.
- Reject a solution that only handles map-form `filter_input` and leaves the tuple form accepting expressions.

---

## 7. Preservation

- Ordinary calculations, filters, sorts that already worked stay green (`mix test test/calculations test/sort/sort_test.exs` is the PR's own gate; full suite is the real preservation net).
- `filter_input` continues to reject expressions for arguments that do not allow them (`"does not support expressions"`).
- Defaults apply only when an argument is **omitted**, not when a provided value normalizes to nil.
- `Ash.Query.Calculation.from_resource_calculation/3` remains the single validation boundary.
- SPDX/REUSE headers on new files (Ash is REUSE-compliant).

---

## 8. Runtime / offline

- **New test file does NOT need PostgreSQL.** Both modules declare `use Ash.Resource, …, data_layer: Ash.DataLayer.Ets` with `ets do private? true end`. In-memory only.
- Broader Ash suite *can* use other data layers / DBs; for **this case's** acceptance stick to `test/calculations/calculation_argument_test.exs` (and optionally `test/sort/sort_test.exs`) — no DB service required.
- ExUnit `async: true`. Fixtures created per-test via `Ash.Changeset.for_create` / `Ash.create!` into ETS.
- Elixir `~> 1.11`. Deps are heavy compared to Redix/nimble_parsec (`spark`, `ecto`, `crux`, `reactor`, `splode`, …) — **compile time is the real prep cost**, not services.
- PR body's own gate: `mix test test/calculations test/sort/sort_test.exs --seed 15101` → 170 passed.

---

## 9. Reference challenges / later fixes / flaky risks

### Later commits to the same files after merge `190987e` (CRITICAL)

| SHA | Date | Files | What | Risk |
| --- | --- | --- | --- | --- |
| **`da464b8`** | 2026-10-16 | `lib/ash/query/calculation.ex` (+ likely resource DSL) | *"feat: allow annotating calculations as `authorize? true`"* | Touches the same constructor file the day after. Feature add, not a fix to argument validation. If the snapshot is `190987e` this is absent (good). If a later base is used, `from_resource_calculation` options schema gains fields. |
| **`5b7d8ec`** | ~2026-10-17/18 (parent `07981c3`) | `lib/ash/sort/sort.ex`, `lib/ash/query/query.ex`, `lib/ash/actions/read/read.ex`, `lib/ash/data_layer/ets/ets.ex`, + tests | *"fix: various issues with sort + aggregate type determination"* — **removes** `aggregate_type/2` from `sort.ex` (−47) in favor of `get_type/2` / `Ash.Query.Aggregate.aggregate_type/3`; ETS now loads calculation/aggregate fields before aggregating; `query.ex` uses `Ash.Resource.Info.resource?/1` instead of `function_exported?(module, :__info__, 1)`. | **Same files as #3031, different bug family (aggregates/sort types).** Not a fix to calculation-argument double validation. High collision risk if a case snapshot is taken after this commit while tests expect #3031-only behavior. Do not import the `unrelated_aggregates_test` additions into the #3031 case. |
| **`8922691`** | 2026-10-18 | `lib/ash/query/query.ex` (+ specs) | #3041 *"fix: include return_query? tuples and error returns in read, page and apply_to specs"* | Spec/docs-shaped; low behavioral risk. |

No further commits to `calculation.ex` / `query.ex` / `sort.ex` visible after those on the Oct 18 history page (repo `pushed_at` 2026-10-19).

### Intra-PR history (21 commits)

The PR preserves a long feature/fix history then consolidates tests:

- Consolidation commit `2b07ebb9e677c899dd578488129abaf7a253ad3d` (tests only).
- Final commit `a4f8cb835b6d0ad2245fc59eb22626c24d6f435c` is **comments/blank lines only** (author states executable content unchanged).
- Author's note: *"the original feature/fix history is preserved"* — useful if a multi-commit case wants intermediate states; otherwise squash to the merge.

### Flaky risks

- Low for the new suite: ETS + `async: true` + per-test fixtures. No timing.
- Parameterized tests use `unquote(Macro.escape(after_value))` for `@cutoff` vs `expr(cutoff_calc)` — keep both arms.
- The suite is large (790 lines, 53 issue-specific features). Prefer the named acceptance subset in §4 over "run the whole file and diff" unless the curator wants breadth.

### Unverified

- Root `LICENSE*` filename at base (404 on common names). SPDX headers and `package().licenses` are reliable.
- Full 40-char SHAs for `da464b8`, `5b7d8ec`, `8922691` not captured from HTML (short SHAs only).
- `test/sort/sort_test.exs` contents at base not re-read; the PR does not modify it, but the author's validation command includes it.

---

## 10. Curator record fields

```yaml
case_id: ash-3031-calculation-arguments
project: ash-project/ash
pr_url: https://github.com/ash-project/ash/pull/3031
base_sha: bc4f2bbd99ca4a2077908a49f036a65dc42b5828
merge_sha: 190987ec134a6a01b72d3eb8d9dcb26577b15873
head_sha: a4f8cb835b6d0ad2245fc59eb22626c24d6f435c
merged_at: 2026-10-15T22:42:51Z
task_kind: bug_fix_coordinated
impl_files: 5
test_files_touched: 1
total_files: 6
license: MIT (SPDX + package.licenses)
license_file: unverified filename at base (LICENSE* in package files)
elixir: "~> 1.11"
offline: true
db_required_for_new_tests: false
data_layer_in_new_tests: Ash.DataLayer.Ets
services_required: []
pr_body_empty: false
linked_issues: []
intra_pr_note: "21 commits; tests consolidated at 2b07ebb9; head a4f8cb835 is comment-only"
later_commits_same_files:
  - sha: da464b8
    date: 2026-10-16
    note: "authorize? true on calculations; calculation.ex"
  - sha: 5b7d8ec
    date: 2026-10-17/18
    note: "sort+aggregate type determination; removes sort.ex aggregate_type/2; query.ex resource?/1"
  - sha: 8922691
    pr: 3041
    date: 2026-10-18
    note: "return_query? specs; query.ex"
difficulty_hint: high
scope_risk: five_impl_files_heavy_deps
validation_command: "mix test test/calculations test/sort/sort_test.exs --seed 15101"
```

---

## 11. Next action

1. Do **not** start corpus expansion with Ash; prove a low-prep library first (Redix #356 or nimble_parsec #154).
2. When preparing, freeze at merge `190987e` so `da464b8` / `5b7d8ec` / `8922691` are out of tree.
3. Confirm no PostgreSQL is needed by running only `test/calculations/calculation_argument_test.exs` — expected green with `Ash.DataLayer.Ets`.
4. Curate the named acceptance set in §4 (especially the expr-vs-literal pairs and the custom-type `casted?: true` case) rather than the full 790-line file.
5. Write the brief with the `allow_expr?` / `filter_input` boundary explicit so hidden tests do not overfit private helpers.
