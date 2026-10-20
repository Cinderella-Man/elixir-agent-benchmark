# NimbleParsec #154 — Allow choice fallback after traversal errors

**Status:** discovered  
**Source type:** historical PR  
**Project:** [dashbitco/nimble_parsec](https://github.com/dashbitco/nimble_parsec)  
**PR:** [#154](https://github.com/dashbitco/nimble_parsec/pull/154)  
**Source revisions:** base `083498e808ed40be8d48e8af58b7860dd3909c63` → merge `5b8bb30d2d0fa449035f433231eea71952489d23`  
**Author:** mvanhorn · **Merged:** 2026-08-11  
**Task kind / family:** bug_fix / parser compiler routing  
**Research date:** 2026-10-19

## Authentic work

`post_traverse/3` callbacks may return `{:error, reason}`. The compiler turned that into the parsec’s **final** error instead of routing through the active `catch_all` / `choice` fallback like other unbound combinators. Result: a `choice/2` whose first branch consumes input and then errors in a traversal callback does **not** try a later branch from the original input.

This is a coherent compiler-contract bug with a clear behavioral outcome (fallback after traversal error).

## Implementation scope

| File | Role |
| --- | --- |
| `lib/nimble_parsec/compiler.ex` | Honor catch_all continuation for traversal errors |
| `test/nimble_parsec_test.exs` | Regressions |

**Counts:** 1 substantive implementation file, 1 test file. **Focused compiler task.**

## Cross-component behavior to verify

- `choice` + traversal error on a consuming branch → later branch runs from the start input.
- Traversal **success** still returns the transformed result without needless fallback.
- Other combinators’ error routing unchanged (preservation of existing compiler tests).
- Repeated / nested `choice` and empty-input cases stay correct.

## Draft ticket (short maintenance report)

> When a `post_traverse` callback returns `{:error, reason}`, a surrounding `choice` does not try its next branch — the error becomes final. Make traversal errors fall back like other parser failures in a choice, without changing successful traversal results. Fix it.

## Acceptance design (proposed, unexecuted)

- Named tests in the spirit of upstream: first branch consumes then traversal-errors → second branch matches; first branch traversal-succeeds → no fallback.
- Preserve existing parsec suite (especially choice/lookahead/repeat).

## Plausible incomplete (proposed)

Route traversal errors through catch_all but also fall back on **successful** traversals (wrong); or fix only `choice` and break `repeat`/`lookahead` error paths.

## Integrity control (proposed)

Reject disabling `post_traverse` errors entirely (always `:ok`), or catching errors at runtime parse time instead of fixing compiler routing (if the project compiles combinators — match the real architecture at the SHA).

## Runtime / offline

- Elixir `~> 1.12` at base (from `mix.exs`).
- Pure library + ExUnit. No services. Excellent low-prep diversity case.

## License / provenance

- MIT (Dashbit; confirm LICENSE filename at SHA).
- PR body explains the contract mismatch clearly.

## Holds / unknowns

- One-file: keep focused; do not merge with unrelated NimbleParsec PRs (#153 test-only, #155 slice change) to inflate scope.
- “Compiler” sounds heavy but the diff is small (16/-5 in one file); difficulty is semantic, not size.

## Coverage added

Parser-generator / macro-compiler error routing — a task family absent from the current inventory.

## Next action

Strong focused reserve if the corpus wants non-web, non-DB reasoning diversity. Prepare like any small Mix library.
