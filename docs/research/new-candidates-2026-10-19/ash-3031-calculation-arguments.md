# Ash #3031 — Validate calculation arguments once and preserve input errors

**Status:** admitted as `ash-pr-3031` (2026-10-20), with three matching qualification rounds and one successful Astra run explicitly authorized by the user\
**Source type:** historical PR  
**Project:** [ash-project/ash](https://github.com/ash-project/ash)  
**PR:** [#3031](https://github.com/ash-project/ash/pull/3031)  
**Source revisions:** actual squash parent `abc634f5a725fadad850dacefc4284dd1d803fad` → merge `190987ec134a6a01b72d3eb8d9dcb26577b15873`\
**Author:** barnabasJ · **Merged:** 2026-10-15  
**Task kind / family:** bug_fix / query calculation arguments  
**Research date:** 2026-10-19

Curation corrected the discovery note's older branch base `bc4f2bbd99ca4a2077908a49f036a65dc42b5828`, which includes unrelated changes. The selected parent-to-squash pair changes five implementation files and one test file. The MIT notice is present at `LICENSES/MIT.txt`. See the [curation evidence](../../../verification/case-curation-2026-10-20/ash-pr-3031/README.md) for current qualification and model-run status.

## Authentic work

Calculation arguments could be **validated twice** while parsing filters. With expression arguments, the first pass wraps literals in type hints; the second pass could reject a literal as an unsupported expression or crash preprocessing an array. Normalized literals could lose constrained values. Custom-type callback rejections did not consistently become useful input errors.

Coordinated fix: leave validation to the resource-calculation constructor, preserve cast/constrained literals alongside expressions, skip literal-array preprocessing for expressions, structured errors for bad containers/callbacks.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/ash/query/calculation.ex` | Constructor / argument validation |
| `lib/ash/query/query.ex` | Filter/sort argument handling |
| `lib/ash/filter/filter.ex` | Expression vs literal paths |
| `lib/ash/query/function/type.ex` | Type-hint interaction |
| `lib/ash/sort/sort.ex` | Sort argument containers |
| `test/calculations/calculation_argument_test.exs` | Large new suite |

**Counts:** 5 substantive implementation files, 1 large test file. Fits the **2–5 coordinated implementation** guideline at the top of the range.

## Cross-component behavior to verify

- Same calculation invoked once via query and once via filter expression → consistent validation, no double cast.
- Literal arguments keep constrained values after normalization.
- Expression arguments are not mistaken for literals (and vice versa).
- Custom-type callback rejection surfaces as an input error, not a crash.
- Malformed filter/sort argument containers produce structured errors.

## Draft ticket (clarified brief)

> Calculation arguments are validated more than once while filters and sorts are built. Expression arguments can be reinterpreted as literals (or crash array preprocessing), constrained literals can lose their values, and some custom-type failures are not useful input errors. Validate calculation arguments once at the calculation boundary, keep literal versus expression arguments distinct, and turn malformed argument containers and callback rejections into structured input errors. Keep ordinary calculation, filter and sort behavior unchanged.

## Acceptance design (proposed, unexecuted)

- Named upstream-style cases: expression arg, literal arg, constrained literal, custom-type reject, malformed container.
- Assert **error shape** (structured input error) rather than private maps.
- Preserve normal calculations and sorts that already worked.

## Plausible incomplete (proposed)

Fix filter double-validation but leave `sort.ex` containers unchanged; or skip double validation by dropping expression support.

## Integrity control (proposed)

Reject disabling calculation arguments, or swallowing callback errors as success.

## Runtime / offline

- Ash is a large framework; historical `mix.exs` at base must be pinned carefully (SPDX header says MIT).
- ExUnit with Ash’s test helpers; PostgreSQL is often used by Ash tests — **confirm whether this specific test file needs a real repo** or can use the in-memory/DSL surface. If it needs a DB, that is supported by the runner (PostgreSQL) but must be part of the prepared baseline.
- Expect heavier dependency compile than Thousand Island/Redix.

## License / provenance

- MIT (SPDX in `mix.exs`). Public GitHub.

## Holds / unknowns

- Ash version at base and test helper DB requirements need a preparation probe before promising offline qualification.
- Very large test file (+790) — curate a protected subset with full requirement mapping rather than running everything blindly.
- Prior Ash PRs were only lightly screened in auth research; this is the first Ash **query** candidate here.

## Coverage added

Framework query/calculation semantics — larger coordinated task family.

## Next action

Only after a low-prep library succeeds, probe Ash test setup. Do not start expansion with Ash if Thousand Island/Redix/PubSub are still unprepared.
