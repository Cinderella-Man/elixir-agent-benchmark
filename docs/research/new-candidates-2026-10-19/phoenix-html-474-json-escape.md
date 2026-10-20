# Phoenix.HTML #474 — Add json_escape

**Status:** discovered  
**Source type:** historical PR (+ follow-up #475)  
**Project:** [phoenixframework/phoenix_html](https://github.com/phoenixframework/phoenix_html)  
**PRs:** [#474](https://github.com/phoenixframework/phoenix_html/pull/474) (feature), [#475](https://github.com/phoenixframework/phoenix_html/pull/475) (arity follow-up)  
**Source revisions:** base `677e5720758ab1671ee33d0487ada07780b1d057` → merge `6548938fa8892699dbc17b7e93bd5801c7131ded`  
**Author:** josevalim · **Merged:** 2026-08-18 (follow-up 2026-09-04)  
**Task kind / family:** feature / HTML-JSON safety helper  
**Research date:** 2026-10-19

## Authentic work

Adds a public `json_escape` helper so JSON embedded in HTML can be escaped safely. Immediate follow-up #475 adjusts the function arity after escaping. Classic small security-adjacent API work in a widely used library.

PR body empty on #474 (Valim merge); #475 title is “Transition json_escape/5 to 4-arity after escaping”.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/phoenix_html.ex` | `json_escape` implementation |
| `test/phoenix_html_test.exs` | Behavior tests |

**Counts:** 1 implementation file (+1-line follow-up), 1 test file. **Focused feature.**

## Cross-component behavior to verify

- Dangerous HTML/JS context characters in JSON strings are escaped as intended (quotes, `</script>`, etc. — exact set is the public contract).
- Valid JSON structure/values survive escaping for the intended embedding use (or document that output is escaped text, not parseable JSON — **must match the real API**).
- Follow-up arity: public callers and tests use the post-#475 shape if that lineage is included.

## Draft ticket (clarified brief)

> Add a helper to escape JSON that will be embedded in HTML so it cannot break out of its script/HTML context. [If including #475: match the final public arity/API after escaping.] Preserve existing HTML escaping helpers.

**Contract hold:** the exact public name (`json_escape`), arity after #475, and what “escaped” means for the return value are product decisions. They must appear in the brief if scored; do not leave them only in hidden tests.

## Acceptance design (proposed, unexecuted)

- Table of inputs: script breakout attempts, quotes, ampersands, unicode; assert escaped output.
- Ordinary helper preservation (existing `html_escape` etc.).
- If the API is meant to be used inside `<script>` JSON, assert the composed embedding is safe, not only unit-escape of isolated strings.

## Plausible incomplete (proposed)

Escape `<` and `>` but not `</script>` sequences / U+2028-style breakouts; or change arity without updating all public entry points.

## Integrity control (proposed)

Reject returning input unchanged, or HTML-escaping JSON in a way that makes it invalid for the documented embedding.

## Runtime / offline

- Phoenix.HTML Mix project; no network, no DB.
- Very low prep cost.

## License / provenance

- MIT (Phoenix family; confirm LICENSE path at SHA).
- Author José Valim; follow-up is same lineage.

## Holds / unknowns

- Body empty on the feature PR → independent review of the API is required.
- Security-flavored tasks need a precise contract so graders do not require one exact escape table when multiple safe encodings exist.
- `#468` (structs as select option values) is a **different** form feature; not combined here.

## Coverage added

HTML/JSON safety API — small diversity case, not another LiveView task.

## Next action

Read #474+#475 diffs, freeze the final API, then draft a brief that names that API. Good tiny feature if the corpus needs one.
