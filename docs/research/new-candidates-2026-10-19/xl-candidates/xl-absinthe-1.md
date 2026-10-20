# XL candidate — absinthe #1176 schema declaration directives

**Status:** discovered
**Source type:** historical merged PR (GraphQL SDL / macro schema declaration support)
**Project:** [absinthe-graphql/absinthe](https://github.com/absinthe-graphql/absinthe)
**PR:** [#1176](https://github.com/absinthe-graphql/absinthe/pull/1176) — Allow schema declaration directives
**Author:** maartenvanvliet · **Merged:** 2022-08-09 by benwilson512
**Source revisions:** merge `a2766843d75b97bea922fb1e82d9be87392bfbfe`
**Size:** +352 / −96, **22 changed files** (14 substantive implementation)
**Task kind / family:** bounded feature / GraphQL schema pipeline (SDL + macro)
**Research date:** 2026-10-19
**License:** MIT (`package().licenses: ["MIT"]`)

---

## Why it is an XL LIMIT-TESTING case

GraphQL type-system directives on `schema { ... }` declarations were missing, blocking full Apollo Federation 2.0 on Absinthe. The PR adds schema declaration support across **two syntaxes** (SDL and macro) and **the entire schema compilation pipeline**. Consistency must hold across:

1. **`Absinthe.Blueprint.Schema`** — SchemaDeclaration struct and walking.
2. **`Absinthe.Phase.Schema.ApplyDeclaration`** — create/apply schema declaration (inferred from query/mutation/subscription when absent).
3. **`Absinthe.Phase.Schema.ApplyTypeExtensions`** — extend schema declarations and builtin root types (`query`, `mutation`, `subscription`).
4. **`Absinthe.Schema.Notation`** — `schema do ... end` macro syntax (works in `extend` blocks and at top level).
5. **`Absinthe.Schema.Notation.SDLRender`** — stop ad-hoc schema declaration rendering; render the real declaration.
6. **`Absinthe.Schema.Compiled` / `PersistentTerm`** — expose `__absinthe_schema_declaration__` after compile.
7. **`Absinthe.Type.BuiltIns.Introspection`** — fix schema description returning `__schema` object description instead of the schema's own.
8. **Validation** — `TypeReferencesExist` must accept schema declaration references.

14 implementation files across blueprint, phases, notation, SDL render, persistent term, and introspection — one coherent product outcome (declarable/extendable schema declarations).

## File inventory with roles

From `pull/1176.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/absinthe/blueprint/schema.ex` | SchemaDeclaration struct; walk declaration nodes. |
| `lib/absinthe/blueprint/transform.ex` | Walk SchemaDeclaration structs in transforms. |
| `lib/absinthe/phase/schema/apply_declaration.ex` | Create declaration when none defined; apply declared schema. |
| `lib/absinthe/phase/schema/apply_type_extensions.ex` | Extend schema declarations and builtin root types. |
| `lib/absinthe/phase/schema/compile.ex` | Compile path includes declaration. |
| `lib/absinthe/phase/schema/populate_persistent_term.ex` | Persist declaration for post-compile access. |
| `lib/absinthe/phase/schema/validation/type_references_exist.ex` | Accept schema declaration type references. |
| `lib/absinthe/pipeline.ex` | Pipeline phase ordering (ApplyDeclaration before ApplyTypeExtensions). |
| `lib/absinthe/schema.ex` | Public schema API surface for declarations. |
| `lib/absinthe/schema/compiled.ex` | Expose `__absinthe_schema_declaration__`. |
| `lib/absinthe/schema/notation.ex` | `schema do ... end` macro; top-level and extend support. |
| `lib/absinthe/schema/notation/sdl_render.ex` | Remove ad-hoc declaration rendering; render real declaration. |
| `lib/absinthe/schema/persistent_term.ex` | Persistent term access to declaration. |
| `lib/absinthe/type/built_ins/introspection.ex` | Fix schema description source. |

**Counts:** 14 substantive implementation files. Tests + CHANGELOG separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/absinthe/schema/notation_test.exs` | Macro `schema do ... end` at top level and in extend. |
| `test/absinthe/schema/notation/experimental/macro_extensions_test.exs` | Declaration extension in macro schema. |
| `test/absinthe/schema/notation/experimental/sdl_extensions_test.exs` | Declaration extension in SDL schema. |
| `test/absinthe/schema/schema_test.exs` | `__absinthe_schema_declaration__` and schema description fix. |
| `test/absinthe/schema/type_system_directive_test.exs` | Directives on schema declarations. |
| `test/absinthe/schema/sdl_render_test.exs` | SDL rendering of declarations. |
| `test/absinthe/integration/execution/introspection/full_test.exs` | Introspection description correctness. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| `CHANGELOG.md` | One-line entry. |

## Draft clarified feature brief

> GraphQL schema declarations (`schema { query: Query, mutation: Mutation }`) should support type-system directives and type extensions, in both SDL and macro syntax. When a macro schema has no explicit declaration, infer one from the query/mutation/subscription objects so extensions can apply. Expose the compiled schema declaration after compilation. The schema's introspected description must be the schema's own description, not the `__schema` object's. Extending builtin root types (`query`, `mutation`, `subscription`) must work.

Keep `schema do ... end`, SDL `schema { ... }`, and `__absinthe_schema_declaration__` as the requested public surface. Do **not** name internal phase modules or the Blueprint SchemaDeclaration struct fields.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **SDL directives:** `schema @feature(name: ":schema") { ... }` compiles and renders directives in SDL output. |
| A2 | **Macro declaration:** `schema do query: Query end` works at top level and inside `extend schema do ... end`. |
| A3 | **Inferred declaration:** macro schema without explicit `schema` block still supports type extensions on the schema declaration. |
| A4 | **Builtin root extension:** `extend type query { ... }` adds fields to the query root. |
| A5 | **Description fix:** introspection `__schema { description }` returns the schema declaration's description, not `__schema`'s. |
| A6 | **Post-compile access:** `__absinthe_schema_declaration__` is available on the compiled schema. |
| A7 | **SDL render:** no ad-hoc `schema { ... }` is invented when the user did not declare one; declared schema renders with its directives. |

## Incomplete control

**Compiling partial that misses one area:** implement SDL `schema` directives but forget the macro `schema do ... end` path (or vice versa).

- SDL tests (`sdl_extensions_test`, `type_system_directive_test`) may pass; **A2/A3** fail on macro syntax.
- Second partial: create the declaration but forget the description fix → **A5** fails.

## Integrity / shortcut rejection

Reject patches that:

- Break existing type extension tests for non-schema types (extend `type Foo`).
- Render a fabricated `schema { query: Query }` when the user declared directives on it (drops directives).
- Leave `__schema` description pointing at the wrong object (A5).
- Fail to mark root objects as referenced correctly (follow-up #1186 is a known residual — do not require it, but do not regress it if present in the base).

## Preservation of existing behavior

- Existing SDL and macro type extensions (from #1157) remain green.
- Type system directives on object/field types (from #1140) remain green.
- Introspection queries for non-schema types unchanged.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.15` at base (2022 era) | Current master claims `~> 1.17`; pin the 2022 base. |
| Tests | Pure ExUnit — no services. |
| yecc parser | `src/absinthe_parser.yrl` unchanged in this PR (declarations live in language/notation layers). |
| MIT | Provenance notice. |

Not verified here: compile/test/boot. Strong offline candidate — no external services.

## Status: discovered

14-file schema-pipeline feature with dual syntax (SDL + macro), external GraphQL spec as contract, and clear introspection outcome. Previously noted in large-features as "over the 5–10 window" — that is exactly the XL target.

## Next action

1. Pin base at merge parent of `a2766843d75b97bea922fb1e82d9be87392bfbfe` (2022-08).
2. Brief names `schema do ... end`, SDL `schema` directives, `__absinthe_schema_declaration__`, and description fix.
3. Incomplete = SDL path without macro `schema do ... end`.
4. Acceptance offline: `mix test test/absinthe/schema/` — no services required.

## Provenance notes

- Follow-up #1186 (`Ensure root objects are marked as referenced correctly`) landed 2022-08-26 from the same author — **not** part of this reference; mention only as out-of-scope residual if the base already contains it.
- Related earlier PRs #1140 (type system directives in macro syntax) and #1157 (type extensions) are prerequisites already in the tree at base; do not re-ask for them.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> GraphQL schema declarations should support type-system directives and type extensions, in both SDL and macro syntax. When a schema has no explicit declaration, infer one from the query/mutation/subscription objects so extensions can apply. After compile, the schema declaration must be readable from the compiled schema, and introspection must report the schema's own description (not the `__schema` object's). Extending builtin root types must work.

Clarified brief. Product decisions are already visible: dual syntax, inferred declaration, description ownership, root-type extension. Two tightenings:

- Do **not** leave "readable from the compiled schema" as prose only — if checks call `__absinthe_schema_declaration__/0` or `Absinthe.Schema.schema_declaration/1`, either name that accessor as the requested public surface or grade only via introspection/SDL render. The dossier names `__absinthe_schema_declaration__` in the brief; keep it, and also decide whether `Absinthe.Schema.schema_declaration/1` is required or optional.
- "The schema's own description" must say what happens when the declaration has **no** description (nil vs empty vs `__schema`'s leftover). Reference returns nil/absent from the declaration. State "nil when undeclared".

### 2. Deterministic checks

Pure ExUnit. No fakes needed. Setup is compile a schema module, then observe via `Absinthe.run` introspection or `Absinthe.Schema` accessors.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `sdl-directives-on-schema` | SDL schema with `schema @feature(...) { query: Query }` | compile + `sdl_render` | compiles; rendered SDL contains the directive |
| `sdl-render-omits-undeclared` | SDL schema with no `schema` block | `sdl_render` | no invented `schema { query: ... }` line |
| `macro-schema-top-level` | macro `schema do query: Query end` at top level | compile + declaration accessor | declaration field is `Query` |
| `macro-schema-in-extend` | base + `extend schema do mutation: Mutation end` | compile | both roots present |
| `inferred-declaration-allows-extension` | macro schema with **no** `schema` block + `extend schema do ... end` | compile | extension applies (does not crash/ignore) |
| `extend-type-query-adds-fields` | `extend type query { new_field: :string }` | `Absinthe.run` query | new field resolves |
| `introspection-description-is-schema` | schema declaration with `description "Custom"`; introspect `__schema { description }` | `Absinthe.run` | `"Custom"`, not `"Represents a schema"` |
| `introspection-description-nil-when-undeclared` | no description on declaration | same | nil/absent, **not** `__schema`'s |
| `declaration-accessor-present` | any compiled schema with declaration | `__absinthe_schema_declaration__` (if kept in brief) | returns the declaration struct/map |
| `preservation-extend-type-foo` | existing `extend type Foo` (non-root) | existing suite | still works |
| `preservation-type-directives` | object/field type-system directives (#1140) | existing suite | still green |

Without `sdl-render-omits-undeclared`, a solver can always print a fabricated `schema { query: Query }` and pass render tests. Without `introspection-description-nil-when-undeclared`, keeping the old `__schema` description fallback passes A5 when a description is absent. Without `preservation-*`, a rewrite that drops #1140/#1157 passes.

### 3. Ambiguity / unfairness

- `__absinthe_schema_declaration__` and `Absinthe.Schema.schema_declaration/1` are two different accessors in the reference. The dossier names only the former. Pick one as required public API or grade behaviour via introspection only. Do not require both unless both are in the brief.
- SchemaDeclaration **struct field names** (`:field_definitions`, `:directives`, `:schema_declaration` on the blueprint) are internal. Do not assert on them.
- "Directives render in SDL output" needs a concrete assertion shape (directive name present as `@feature`). Exact whitespace/ordering of SDL render is a trap — assert presence/parse, not byte equality.
- A5 "schema's own description" is a **product bugfix stapled onto a feature**. It is small and in-family, keep it, but the nil-when-undeclared rule must be stated or the check is a hidden policy.
- Follow-up #1186 (root objects marked referenced) is explicitly out of scope. Do not require it; do not fail if a solver incidentally fixes it.
- Type references in the declaration (`query: Query`) go through `TypeReferencesExist`. A solver could skip that validation change and still compile simple schemas. If the reference accepts declaration refs that would otherwise fail validation, add a named check with a declaration referencing a type — or accept either and do not score it.

### 4. Shortcuts

- SDL path only, macro `schema do` missing → fails `macro-schema-*` and `inferred-declaration-*`. Good incomplete.
- Declaration support but description still read from `__schema` → fails description checks. Good second partial.
- Always emit `schema { query: Query, ... }` in SDL render regardless of declaration → fails `sdl-render-omits-undeclared`.
- Infer declaration but make `extend schema` a no-op → fails `inferred-declaration-allows-extension` / `macro-schema-in-extend`.
- Copy directives into the struct but drop them at render → fails `sdl-directives-on-schema`.
- Implement declaration only for SDL schemas and refuse macro → same as first incomplete.
- Compiling incomplete is easy to get wrong: the ApplyDeclaration/ApplyTypeExtensions phase order matters. A solver who puts extensions before declaration creation will pass simple tests and fail extend-on-inferred. Keep that as a named check.

### 5. Flakiness

Low. Pure compile + query. No services, no timers, no async races. PersistentTerm population is compile-time; tests must compile schema modules in the test process and not race schema compilation across `async: true` files that share module names. Use unique schema module names per test.

### 6. Coverage mix

- Positive: SDL directives, macro declaration, extend, inferred declaration, root extension, description.
- Negative: undeclared schema does not invent render; description nil when undeclared.
- Preservation: `extend type Foo`, type-system directives, normal introspection.
- Mixed: one schema with declaration + description + extend type query in a single fixture so a single-path fix fails.

### 7. Environment

- MIT. Pure ExUnit. **No services.** Strong offline candidate.
- Elixir `~> 1.15` at 2022 base — pin the image. Current master's `~> 1.17` is irrelevant.
- yecc parser unchanged — good.
- **Nothing executed.** No apply, no compile, no suite run. Qualification must prove the base builds offline with 2022-era deps.
- One concern: Absinthe test suite is large; keep the graded surface to `test/absinthe/schema/` + the introspection file named in the dossier. Do not grade the whole suite as the task oracle.

### 8. XL-specific

14 impl files is **mostly real coordination** — blueprint walk → phase create/apply → notation macro → SDL render → persistent term → introspection is one pipeline, and a change in one layer without the others breaks a named check. Two adjacent bits are small and feel stapled: `TypeReferencesExist` one-liner and the introspection description fix. You could split off the description fix as a 1–2 file micro-case; the remaining ~12 is still an honest XL pipeline case. Outcome is still **one story** (declarable/extendable schema declarations). Do **not** split SDL vs macro into two cases — the dual-syntax consistency *is* the coordination requirement.

### 9. Verdict

**READY-WITH-FIX** — coherent dual-syntax pipeline, pure ExUnit, clear observable outcomes; needs accessor naming, nil-description policy, and execution before qualification. Not HOLD: no environment or fairness cliff.

### 10. Must-fix before qualification

1. Decide required public accessor: `__absinthe_schema_declaration__/0` **or** `Absinthe.Schema.schema_declaration/1` **or** introspection-only. Put the chosen one(s) in the brief.
2. State nil-description-when-undeclared policy in the brief.
3. Named checks must include `sdl-render-omits-undeclared`, `introspection-description-nil-when-undeclared`, and preservation of #1140/#1157.
4. Pin base at merge parent of `a2766843…`; run unchanged (fail feature checks), reference (pass), incomplete=SDL-only (fail macro/inferred), incomplete=description-not-fixed (fail A5).
5. Assert SDL render by parse/presence, not byte equality. Unique schema module names per test.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Hidden accessor / nil-description policy; unexecuted 2022 toolchain |
