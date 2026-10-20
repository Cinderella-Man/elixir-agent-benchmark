# Large feature — Absinthe #1404 document descriptions on operations and fragments

**Status:** discovered
**Source type:** historical merged PR (implements GraphQL September 2025 § Descriptions)
**Project:** [absinthe-graphql/absinthe](https://github.com/absinthe-graphql/absinthe)
**PR:** [#1404](https://github.com/absinthe-graphql/absinthe/pull/1404) — feat: add description support for operations and fragments
**Author:** jwaldrip · **Merged:** 2026-04-03
**Source revisions:** base `8e451950ea87083f50a06abf7b4246284bbe347d` → head `65ce8ccf6caaf696f38cfa1c95f997836420b88a` → merge `c029a611640a764b687f6e3b5ce647880eff99fd`
**Size:** +608 / −8, **7 changed files**
**Task kind / family:** bounded feature / GraphQL parser + AST + SDL render
**Research date:** 2026-10-19
**License:** MIT (`package().licenses: ["MIT"]`; `LICENSE.md` at base)

---

## Why it is a LIMIT-TESTING case

Clear public spec outcome: **executable documents may carry descriptions on named operations and named fragments** (GraphQL September 2025). The value must survive a full pipeline hop:

1. **yecc grammar** (`absinthe_parser.yrl`) — `DescriptionDefinition` immediately before an operation or fragment.
2. **Language AST** (`Language.OperationDefinition`, `Language.Fragment`) — store `description` and convert it into Blueprint.
3. **Blueprint document nodes** (`Blueprint.Document.Operation`, `Blueprint.Document.Fragment.Named`) — expose `description` to later phases.
4. **SDL / document render** (`Language.Render`) — print the description block before the definition.

A partial that only parses or only renders is plausible and compiles. Six implementation files (including the yecc grammar), one large new test module (26 named tests), no services. This is a different reasoning family from Cachex/Broadway/SQL work: grammar + AST + pretty-printer coordination.

## File inventory with roles

From `pull/1404.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `src/absinthe_parser.yrl` | Grammar: `Definition -> DescriptionDefinition OperationDefinition` / `Fragment` via `put_description/2`. |
| `lib/absinthe/language/operation_definition.ex` | Language node `:description`; `Draft.convert/2` copies it onto Blueprint.Operation. |
| `lib/absinthe/language/fragment.ex` | Language node `:description`; convert onto Blueprint.Fragment.Named. |
| `lib/absinthe/blueprint/document/operation.ex` | Blueprint struct field + type `description: nil \| String.t()`. |
| `lib/absinthe/blueprint/document/fragment/named.ex` | Same for named fragments. |
| `lib/absinthe/language/render.ex` | Prefix rendered operations/fragments with `description/2` when present. |

**Counts:** 6 substantive implementation files. One new test module; no mechanical lockfile churn.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/absinthe/document_description_test.exs` | **New**, 584 lines, 26 named tests: parse block/single-line/absent descriptions on query/mutation/subscription/fragment; Blueprint preservation; multi-definition docs; render round-trip. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| (none beyond tests) | PR body is the product description; no standalone guide in the diff. |

## Draft clarified feature brief

> GraphQL documents should accept string descriptions (including triple-quoted block strings) immediately before named operations and named fragments, matching the September 2025 spec. A described definition keeps that description on the parsed document and when the document is rendered back to SDL. Definitions without a description keep working exactly as today, including anonymous and shorthand queries.

Public names to keep visible: descriptions on **operations** and **named fragments**; **block strings** and single-line strings; parse **and** render. Do **not** name `put_description`, `Blueprint.Document.Operation`, or `Language.Render`.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Parse operations:** block-string and single-line descriptions attach to query/mutation/subscription (upstream `"parses a query with a block string description"`, `"parses a mutation with a block string description"`, `"parses a subscription with a block string description"`). |
| A2 | **Parse fragments:** descriptions attach to named fragments (`"parses a fragment with a block string description"`). |
| A3 | **No description stays nil:** anonymous, shorthand, and undescribed definitions (`"parses a query without description"`, `"parses an anonymous query without description"`, `"parses a fragment without description"`). |
| A4 | **Blueprint preservation:** description survives into Blueprint (`"operation description is preserved in Blueprint"`, `"fragment description is preserved in Blueprint"`). |
| A5 | **Mixed documents:** described + undescribed definitions in one document (`"parses document mixing described and non-described definitions"`). |
| A6 | **Render:** description is emitted before the definition (`"renders operation with description"`, `"renders fragment with description"`). |
| A7 | **Preservation:** existing parse/render of operations, fragments, directives, variables (`"query with description, variables, and directives"`, `"parses a fragment with directives and description"`). |

## Incomplete control

**Compiling partial that misses one area:** parse descriptions into Language nodes and Blueprint, but leave `Language.Render` unchanged.

- A1–A5 pass; **A6** fails (`"renders operation with description"`).
- Second partial: render-side only helpers without yecc productions → **A1/A2** fail at parse.

## Integrity / shortcut rejection

Reject patches that:

- Accept descriptions only on queries (not mutations/subscriptions/fragments).
- Drop descriptions when converting Language → Blueprint or Blueprint → render.
- Force a description on every definition (A3 must stay nil).
- Break existing shorthand query parsing or fragment rendering.

## Preservation of existing behavior

- Documents without descriptions parse and render unchanged.
- Schema type descriptions (already supported) are not the target; do not regress them.
- Full Absinthe suite at base is the real preservation net; the new module is the acceptance family.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.15` at base | From `mix.exs` (Absinthe version `1.9.0`). |
| yecc / parser compile | `src/absinthe_parser.yrl` must build; ordinary Mix compile covers it. |
| Services | None. Pure library + ExUnit. |
| MIT | Provenance notice. |

Not verified here: compile/test/boot. PR body claims 1468 tests green at head.

## Status: discovered

Strong multi-module library feature with a named external spec and 26 upstream tests. Best non-app large feature this pass.

## Next action

1. Pin base `8e451950ea87083f50a06abf7b4246284bbe347d`.
2. Brief keeps “operations and named fragments” + parse/render; no internal helper names.
3. Incomplete = parse without render (or fragment-only).
4. Acceptance family: `mix test test/absinthe/document_description_test.exs` plus a small existing parse/render suite for preservation.
