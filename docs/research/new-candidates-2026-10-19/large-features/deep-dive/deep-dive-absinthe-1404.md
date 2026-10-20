# Deep-dive dossier — Absinthe #1404 document descriptions on operations and fragments

**Case-prep status:** deep-inspected + experiments 2026-10-20 (full clone + apply + mix test + spec probes).  
**Verdict:** viable candidate with **two contract corrections** before any bundle work: (1) reconstruction base is merge first-parent `8fba7023…`, not the dossier's `8e451950…`; (2) the solver brief must not say **only named** operations — GraphQL September 2025 also allows descriptions on anonymous non-shorthand operations, and the reference implementation **wrongly accepts descriptions on query shorthand** (spec forbids that). Render tests are valid (`inspect/2` delegates to `Language.Render`).

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [absinthe-graphql/absinthe](https://github.com/absinthe-graphql/absinthe) |
| PR | [#1404 feat: add description support for operations and fragments](https://github.com/absinthe-graphql/absinthe/pull/1404) |
| Diff / Patch | `pull/1404.diff` (21 824 B), `pull/1404.patch` (23 378 B) |
| Author | jwaldrip (Jason Waldrip) |
| PR body | not fetched (API rate-limited); patch is a single commit |
| Merged | 2026-04-03T12:09:19-04:00 |
| Head (PR branch) | `65ce8ccf6caaf696f38cfa1c95f997836420b88a` — **not in default clone** |
| Dossier claimed base | `8e451950ea87083f50a06abf7b4246284bbe347d` (**not** merge first parent) |
| **Merge commit (squash)** | `c029a611640a764b687f6e3b5ce647880eff99fd` — **MATCHES dossier** |
| **Merge first parent = correct base** | `8fba7023f944e093036b89131b9e47a4ad2f7ecc` (`chore(main): release 1.10.0 (#1396)`) |
| Size (first-parent..merge) | **7 files, +608 / −8** — **MATCHES dossier** |
| License | MIT (`LICENSE.md` at base; `package().licenses: ["MIT"]`) |
| Elixir / version at base | `~> 1.15`, Absinthe `1.10.0` |

---

## 2. Shortest ticket / brief (solver-visible) + spec-contract review

### Draft brief (from short dossier)

> GraphQL documents should accept string descriptions (including triple-quoted block strings) immediately before named operations and named fragments, matching the September 2025 spec. A described definition keeps that description on the parsed document and when the document is rendered back to SDL. Definitions without a description keep working exactly as today, including anonymous and shorthand queries.

### Spec contract check (required by task)

Fetched [GraphQL September 2025 §2.2 Descriptions](https://spec.graphql.org/September2025/#sec-Descriptions) and grammar sections:

| Spec fact | Text / grammar |
| --- | --- |
| Scope | “written descriptions on **all named definitions** in executable Document and GraphQL type systems” |
| Placement | “Description strings (often BlockString) occur **immediately before** the definition they describe.” |
| Effect | “MUST NOT affect the execution, validation, or response of a GraphQL document.” |
| Example | Example № 3: block-string description on **named query** + description on **named fragment**. |
| **Example № 4** | Description on an **anonymous mutation** (`mutation { likeStory… }`) — so descriptions are **not limited to named operations**. |
| Operations grammar | `OperationDefinition : Description? OperationType Name? VariablesDefinition? Directives? SelectionSet \| SelectionSet` |
| Fragments grammar | `FragmentDefinition : Description? fragment FragmentName TypeCondition Directives? SelectionSet` |
| **Shorthand rule** | §2.4: “**Descriptions are not permitted on query shorthand.**” |

**Is the brief sufficient without the PR number?** **Mostly yes, with two wording fixes:**

1. **Drop “named” as a hard limiter** (or say “operations and fragments, including unnamed operations that are not shorthand”). Spec Example № 4 and `Description?` on `OperationDefinition` cover anonymous non-shorthand operations. A solver who implements only named ops would still pass the 26 upstream tests (they never test anonymous+description) but would be incomplete vs the spec — an under-constrained gap.
2. **Replace “rendered back to SDL”** with “rendered back to document / GraphQL source”. SDL normally means schema; this feature is executable-document rendering (`Absinthe.Language.Render`). The tests call `inspect(doc, pretty: true)`, which **does** route through `Language.Render` (see §5), so the obligation is real — but the word “SDL” may send solvers to schema printers.
3. **State the shorthand ban if graded** (“descriptions are not permitted on query shorthand”). The reference implementation currently **accepts** a description on `{ field }` (probe below) — so either grade that as a non-requirement, add an explicit reject, or do not use a hidden check for it.

Keep visible: descriptions on operations and fragments; block strings and single-line strings; parse **and** render; absent description stays nil; existing shorthand/anonymous behavior unchanged.  
Do **not** name `put_description`, `Blueprint.Document.Operation`, `Language.Render`.

### Recommended brief rewrite

> GraphQL executable documents should accept string descriptions (including triple-quoted block strings) immediately before operation and fragment definitions, matching the September 2025 GraphQL specification. A described definition keeps that description on the parsed AST and when the document is rendered back to GraphQL source. Definitions without a description keep working exactly as today, including anonymous and shorthand queries. Descriptions are documentation only and must not change execution behavior. (Spec note: descriptions are not permitted on query shorthand.)

---

## 3. Source revisions — experiment log (SHAs)

Full clone of `absinthe-graphql/absinthe` (WSL, git 2.53.0):

| Claim | Experiment result |
| --- | --- |
| Merge `c029a611…` exists | YES. Subject `feat: add description support for operations and fragments (#1404)`. |
| Parents | **one parent only** (squash): `8fba7023f944e093036b89131b9e47a4ad2f7ecc`. |
| Dossier base `8e451950…` | Exists (`remove outdated CI`, 2026-03-17) and **is an ancestor** of first parent — but **not** the first parent. |
| Distance claimed-base → first-parent | **3 commits:** `8e451950` → `64468827` (`Fix Inspect implementation for Absinthe.Resolution on Elixir 1.19+ (#1409)`) → `1e85ed27` (`fix: camelize directive names in SDL render (#1419)`) → `8fba7023` (`release 1.10.0 (#1396)`). |
| Head `65ce8ccf…` | **NOT FOUND** in default clone (PR branch). |
| Diff first-parent..merge | 7 files, +608/−8 — matches dossier inventory exactly. |

**Pin base `8fba7023f944e093036b89131b9e47a4ad2f7ecc`** (includes the Inspect fix #1409 and release 1.10.0 that the PR was merged onto). Using `8e451950` still applies (see §6) but is historically wrong for “state of main just before the squash”.

---

## 4. File roles + inventory (from `pull/1404.diff`)

### Implementation (6 substantive)

| Path | Role |
| --- | --- |
| `src/absinthe_parser.yrl` | Grammar: `Definition -> DescriptionDefinition OperationDefinition : put_description('$2', '$1')` and same for `Fragment`. (Schema `TypeDefinition` descriptions already existed.) |
| `lib/absinthe/language/operation_definition.ex` | Language node `:description`; `Blueprint.Draft` convert copies it to Blueprint. |
| `lib/absinthe/language/fragment.ex` | Same for named fragments. |
| `lib/absinthe/blueprint/document/operation.ex` | Blueprint struct field `description: nil \| String.t()`. |
| `lib/absinthe/blueprint/document/fragment/named.ex` | Same for `Blueprint.Document.Fragment.Named`. |
| `lib/absinthe/language/render.ex` | Prefix rendered operations/fragments with `description(doc, op.description)` / `\|> description(fragment.description)`. |

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/absinthe/document_description_test.exs` | **New**, 584 lines, **26 named tests**: parse block/single-line/absent on query/mutation/subscription/fragment; Blueprint preservation; multi-definition / mixed docs; render via `inspect(doc, pretty: true)`; variables+directives. Moduledoc cites `https://spec.graphql.org/September2025/#sec-Descriptions`. |

### Mechanical

None beyond tests (no lockfile churn).

---

## 5. Cross-component behavior to verify (and Inspect chain)

Pipeline hop that must stay consistent:

1. **yecc grammar** attaches description text to the operation/fragment node.
2. **Language AST** stores `description`.
3. **Blueprint.Draft.convert** copies it onto Blueprint document nodes.
4. **Language.Render** prints the description before the definition.

**Render-test validity check (experiment):** `test "renders operation with description"` calls `inspect(doc, pretty: true)`, not `Absinthe.Language.Render` directly. Is that a shortcut?

```
lib/absinthe/language/document.ex (at merge):
  defimpl Inspect do
    defdelegate inspect(term, options), to: Absinthe.Language.Render
  end

lib/absinthe/language/render.ex:
  def inspect(term, %{pretty: true}) do
    term |> render() |> concat(line()) |> format(@line_width) |> to_string
  end
```

**Conclusion: `inspect/2` delegates to `Language.Render`.** An incomplete “parse without render” **fails** A6. The tests are discriminating, not a false shortcut.

---

## 6. Named acceptance assertions ↔ requirements

From `test/absinthe/document_description_test.exs` (26 tests; dossier A1–A7 map):

| Assertion (test name) | Requirement |
| --- | --- |
| `"parses a query/mutation/subscription with a block string description"` | A1 parse operations (block strings). |
| `"parses a query/mutation/subscription with a single-line string description"` | A1 single-line strings. |
| `"parses a fragment with a block string description"` / `…single-line…` | A2 parse fragments. |
| `"parses a query without description"` / `"parses an anonymous query without description"` / `"parses a fragment without description"` | A3 absent → nil. |
| `"parses a shorthand query without description"` | Shorthand still works; description nil. |
| `"operation description is preserved in Blueprint"` / `"fragment description is preserved in Blueprint"` | A4 Blueprint hop. |
| `"parses document mixing described and non-described definitions"` | A5 mixed documents. |
| `"renders operation with description"` / `"renders fragment with description"` | A6 render (via `inspect` → `Language.Render`). |
| `"query with description, variables, and directives"` / `"parses a fragment with directives and description"` | A7 preservation with directives/variables. |

---

## 7. Compiling incomplete + named failure

**Incomplete A — parse into Language + Blueprint, leave `Language.Render` unchanged:**

- A1–A5 pass. **Fails** `"renders operation with description"` and `"renders fragment with description"`.

**Incomplete B — render-side helpers without yecc productions:**

- **Fails** A1/A2 at parse (`description: nil` or parse error).

**Incomplete C — descriptions only on queries (not mutations/subscriptions/fragments):**

- **Fails** mutation/subscription/fragment parse tests.

**Named failures:** the three `"renders …"` / parse tests above.

---

## 8. Integrity / shortcut rejection + over-constraint scan

Reject patches that:

- Accept descriptions only on queries (not mutations/subscriptions/fragments).
- Drop descriptions at Language → Blueprint or Blueprint → render.
- Force a description on every definition (A3 must stay nil).
- Break shorthand query parsing or fragment rendering.

### Over-constrained / gap findings (experiments)

Probe script (`mix run spec_probe.exs` at base+patch, `elixir:1.17-otp-27`):

| Input | Spec | Reference behavior |
| --- | --- | --- |
| `"desc on shorthand"` before `{ user { id } }` | **NOT permitted** (§2.4) | **Accepted** — `description: "desc on shorthand"`, `shorthand: true`. Render prints the description before the shorthand. **Spec violation; untested by the 26 tests.** |
| `"desc on anonymous query"` before `query { … }` | Permitted (`Description?` + Example № 4 style) | Accepted; `name: nil`, `description` set. **Not covered by the 26 tests** (only “anonymous without description”). |
| `"Mark story…"` before anonymous `mutation { … }` (spec Example № 4) | Permitted | Accepted; render round-trips description + mutation body. |

**Implication for grading:**

- Do **not** require rejecting shorthand descriptions unless the brief states it (reference does not reject).
- Do **not** require anonymous-with-description only if you keep the brief as “named …”; if you cite the spec properly, either test it or accept both named-only and full-spec solutions — otherwise a hidden check would over-constrain.
- The 26 upstream tests are **not** a complete spec suite; treat them as one acceptance family, not the whole contract.

---

## 9. Experiments — `git apply` of `pull/1404.diff`

| Base | Classic `git apply --check` | `git apply --3way` | Verdict |
| --- | --- | --- | --- |
| **First parent `8fba7023…`** | **exit 0, all 7 paths cleanly** | **exit 0** | **Use this base** |
| Dossier claimed `8e451950…` | (3way reported all 7 “Applied … cleanly”) | **exit 0** | Applies, but historically stale |

Exact commands (WSL):

```bash
git clone --depth 1 https://github.com/absinthe-graphql/absinthe.git classic-absinthe
cd classic-absinthe
git fetch --depth 1 origin 8fba7023f944e093036b89131b9e47a4ad2f7ecc
git checkout 8fba7023f944e093036b89131b9e47a4ad2f7ecc
git apply --verbose --check /tmp/large-dd/absinthe-graphql_absinthe-1404.diff   # exit 0
git apply --verbose /tmp/large-dd/absinthe-graphql_absinthe-1404.diff           # exit 0
```

`src/absinthe_parser.yrl` applies cleanly; Mix compiles the yecc file (`Compiling 1 file (.yrl)` observed).

---

## 10. Experiments — `mix test` at base+patch

Environment: Docker `elixir:1.17-otp-27` (satisfies `~> 1.15`; yecc + ExUnit only, **no services**).

| Tree | Command | Result |
| --- | --- | --- |
| Base+patch | `mix test test/absinthe/document_description_test.exs` | **26 tests, 0 failures** |
| Base+patch | `mix test` (full) | **1468 tests, 0 failures** (seed 276040) / earlier run **1468 tests, 1 failure** (seed 229239) |
| Base (no patch) | `mix test` | **1442 tests, 0 failures** (seed 353397) |
| Base+patch | `mix test test/absinthe/phase/schema/inline_functions_test.exs` alone | **3 tests, 1 failure** — `"complexity is inlined when it's a literal"` |

**Flaky finding:** `Absinthe.Phase.Schema.InlineFunctionsTest` `"complexity is inlined when it's a literal"` failed in one full run and in isolation, but the full patched suite is **green on re-run** (1468/0) and base full suite is green (1442/0). Failure is in **schema complexity inlining**, unrelated to document descriptions. Treat as **pre-existing flakiness** (possible Elixir/OTP or seed sensitivity), not a #1404 regression. PR body claims “1468 tests green at head” — matches the green re-run total (1442 base + 26 new).

---

## 11. Later commits on the same files (reference-bug / drift scan)

`git log c029a611..HEAD -- <description paths>`:

| Path | Later commits |
| --- | --- |
| `src/absinthe_parser.yrl` | **none** |
| `lib/absinthe/language/operation_definition.ex` | **none** |
| `lib/absinthe/language/fragment.ex` | **none** |
| `lib/absinthe/blueprint/document/operation.ex` | **none** |
| `lib/absinthe/blueprint/document/fragment/named.ex` | **none** |
| `test/absinthe/document_description_test.exs` | **none** |
| `lib/absinthe/language/render.ex` | `20dacc6c fix: wrap long input objects and lists onto multiple lines (#1455)` — **render formatting** for long inputs/lists; not a description bugfix |

`git log --grep='description\|1404'` after merge: **empty**.

**Implication:** clean window for the description feature. #1455 is a general render-formatting fix (also touched `render_test.exs`); do not fold into this case.

---

## 12. Preservation

Executed green with the patch (when flaky test excluded or suite re-run):

- Existing parse/render of operations, fragments, directives, variables (full suite 1468/0 on re-run).
- Schema type descriptions (already supported before #1404) untouched by the diff.

---

## 13. Runtime / offline

| Hold | Evidence |
| --- | --- |
| Elixir `~> 1.15` | `elixir:1.17-otp-27` compiled + tested. |
| yecc / parser | `src/absinthe_parser.yrl` compiles under ordinary `mix compile`. |
| Services | **None.** Pure library + ExUnit. |
| MIT | `LICENSE.md` at base. |

---

## 14. Curator record (guidelines checklist)

```
Source type / project / source revisions / PR:
  historical merged PR (squash) / absinthe-graphql/absinthe
  base 8fba7023f944e093036b89131b9e47a4ad2f7ecc   # CORRECTED
  merge c029a611640a764b687f6e3b5ce647880eff99fd
Status: discovered → deep-inspected
Case version / inventory / exposure: n/a (no bundle)
Task kind / family: bounded feature / GraphQL parser + AST + render
Ticket kind: clarified implementation brief (rewritten in §2)
Implementation files: 6 (yrl, 2 language nodes, 2 blueprint nodes, render)
Tests / docs / mechanical: 1 new test module (26 tests); no mechanical churn
Cross-component behavior: grammar → Language AST → Blueprint → Language.Render
Visible source for each scored obligation: document_description_test.exs names
Starting-state / reference evidence:
  unchanged: base has no document_description_test; type descriptions already work
  reference: 26 tests + full suite executed (full suite flaky on one unrelated test)
Plausible partial: parse without render → fails "renders operation/fragment with description"
Preservation risks: shorthand/anonymous parse; existing schema descriptions; #1455 later render change
Runtime: pure library, no services (executed)
Three-round controls: NOT run (discovery stage)
Blind model policy: not started
Independent contract review: spec §2.2/§2.4 checked; brief "named only" + "SDL" wording fixed;
  shorthand-description spec gap documented (reference accepts; tests silent)
Coverage: grammar + AST + pretty-printer family — distinct from Cachex/Broadway/SQL
Admission reason / reconsideration: strong non-app large feature after SHA + brief fixes
Next action: rewrite brief (§2); pin 8fba7023; decide policy on anonymous+description and
  shorthand+description before freezing checks
```

---

## 15. Verdict for case creation

| Criterion | Assessment |
| --- | --- |
| Authentic coherent work | Yes — GraphQL September 2025 descriptions on executable definitions. |
| Coordinated implementation | Yes — yecc + AST + Blueprint + render must agree. |
| Visible contract | Mostly — 26 named tests; **gaps** on anonymous+description and shorthand ban. |
| Observable success | Yes — 26/0 executed; incomplete render fails named tests. |
| Reproducible environment | Yes — pure library, no services. |
| Provenance | MIT; SHA corrected; spec URL is public. |

**Keep, after brief rewrite + base SHA correction.** Best non-app large feature this pass. Decide explicitly whether anonymous-with-description is in scope and whether shorthand-with-description is rejected or ignored before freezing hidden checks.

---

## Brief correction (2026-10-19 lineage policy)

Per [LINEAGE-MERGE-POLICY.md](../LINEAGE-MERGE-POLICY.md): do **not** freeze an under-inclusive brief.

**Use this ticket wording:** descriptions attach to operations and fragments, including **anonymous non-shorthand** operations (GraphQL September 2025). Do not require names. State the shorthand-query policy explicitly in the brief (spec forbids descriptions on query shorthand; if we accept the reference's looser parse, say so � otherwise grade rejection).

Reference tree = post-#1404 head (SHA in this dossier). No forced merge with unrelated Absinthe PRs.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

The corrected brief (post lineage-policy rewrite) is the right one: descriptions on operations **and fragments**, including **anonymous non-shorthand** operations, parse **and** render, absent description stays nil, execution unchanged. Do not revert to "named only" — the dossier's own spec probe (Example № 4) already killed that.

**Unresolved product decision — shorthand.** Spec §2.4 forbids descriptions on query shorthand. The reference **accepts** them (probe: `description: "desc on shorthand"` on `{ user { id } }`). The brief currently carries "(Spec note: descriptions are not permitted on query shorthand.)" which reads as a requirement to reject. That is a policy contest between spec and reference.

Per LINEAGE-MERGE-POLICY, state the decision in the brief or do not grade it. **Recommended freeze:** descriptions attach to operations and fragments (named and anonymous non-shorthand); shorthand + description behavior is **not graded**. Accept both "reject at parse" and "accept and ignore/attach." No hidden check either way. If we instead want rejection, the reference is wrong and must be replaced — do not grade a check the reference fails.

Also keep "rendered back to GraphQL source / document," not "SDL" (already fixed).

### 2. Named deterministic checks (ExUnit, no sleep)

The 26 tests in `test/absinthe/document_description_test.exs` are executed green (26/0). They are discriminating: `inspect(doc, pretty: true)` really does route through `Language.Render` (dossier §5 verified the Inspect delegate). An incomplete "parse without render" fails `"renders operation with description"` / `"renders fragment with description"`.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `parse op block/single-line` | description before query/mutation/subscription | parsed node | `description` set |
| `parse fragment block/single-line` | description before named fragment | parsed node | `description` set |
| `parse anonymous non-shorthand` | description before `query { … }` / `mutation { … }` (no name) | parsed node | `description` set, `name: nil` |
| `absent stays nil` | no description (named, anonymous, fragment, shorthand) | `description` | `nil` |
| `blueprint hop` | described definition | Blueprint node | description copied |
| `render op/fragment` | described definition | `inspect(doc, pretty: true)` | description appears immediately before the definition |
| `mixed document` | described + undescribed definitions in one doc | parse + render | only the described ones carry text |
| `preserve directives/variables` | described op with vars + directives | parse | both preserved |
| `preserve shorthand` | bare `{ field }` with no description | parse | still works |
| `preserve type-system descriptions` | schema type descriptions (pre-existing) | parse | unchanged |

Gap to close: **add a named check for anonymous non-shorthand + description** (the 26 tests only cover "anonymous without description"). Without it, a named-only solver passes the upstream suite while violating the frozen brief.

### 3. Ambiguity / unfairness

- Shorthand policy (above) — the live unfairness risk. Do not hide a rejection check.
- "MUST NOT affect execution" is in the brief. Fine as a preservation clause; do not grade it with an execution differential unless you also assert it.
- Render formatting: later commit `20dacc6c` (#1455) changes long-input/list wrapping. Grade "description appears before the definition," not exact pretty-print layout.
- Do not name `put_description`, `Blueprint.Document.Operation`, `Language.Render` (already correct).

### 4. Shortcuts + compiling incomplete

- Incomplete A = Language + Blueprint, leave `Render` unchanged. Compiles. Fails `"renders operation with description"` / `"renders fragment with description"`.
- Incomplete B = render helpers without yecc productions. Fails parse tests (`description: nil` / parse error).
- Incomplete C = descriptions on queries only (not mutations/subscriptions/fragments). Fails those parse tests.
- Incomplete D = named-only. **Passes the 26 upstream tests.** Caught only by a new `parse anonymous non-shorthand` check. This is exactly why that check must exist.
- Shortcut: force a description on every definition. Caught by `absent stays nil`.
- Shortcut: break shorthand parsing. Caught by `preserve shorthand`.

### 5. Flakiness

One **pre-existing** flake: `Absinthe.Phase.Schema.InlineFunctionsTest` `"complexity is inlined when it's a literal"` failed once in a full run and in isolation, then went green on re-run (1468/0). Unrelated to descriptions. Record it as environment/seed noise; exclude from the acceptance net. Do not let it poison qualification, and do not "fix" it inside this case.

### 6. Preservation mix

Good: mixed documents, absent → nil, directives/variables, shorthand, schema type descriptions. The full suite (1442 base / 1468 patched) is the broad net. Add the anonymous+description case to the **positive** side (it is new behaviour, not preservation).

### 7. Environment risk

**Best in this batch.** Pure library, yecc + ExUnit, no services. Elixir `~> 1.15` (executed on 1.17-otp-27). MIT. Base SHA already corrected to `8fba7023`. Later-commit scan is clean (only #1455 render formatting, out of scope).

### 8. Verdict

**READY-WITH-FIX** — strongest non-app large feature this pass, with executed tests and a verified render chain; the shorthand policy and the anonymous+description gap must be frozen before checks.

### 9. Must-fix list

1. Freeze shorthand policy as **not graded** (accept both reject and loose-parse). Do not use a hidden check. If rejection is wanted, replace the reference.
2. Add a named check for **anonymous non-shorthand + description**. Without it, named-only solvers pass.
3. Grade render as "description appears before the definition," not exact pretty-print (guard against #1455 drift).
4. Pin base `8fba7023f944e093036b89131b9e47a4ad2f7ecc`. Brief already rewritten — use the §2 corrected wording.
5. Record `InlineFunctionsTest` as pre-existing flake; keep it out of the acceptance net.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Shorthand policy contest + anonymous+description gap |
