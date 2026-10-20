# App candidate — craftplan PR #53 (nested subassembly allergens)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (with linked issue)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/53 |
| Title | fix(catalog): resolve allergens through nested subassemblies |
| Author | **puemos** (maintainer) |
| Branch | `feat/49-subassembly-allergens` |
| Created | 2026-10-07T13:48:08Z |
| Merged / closed | 2026-10-07T17:47:37Z |
| Merge commit SHA | `1d6c388969f56be009337a1e7ea77d521fa06258` |
| **Base SHA (parent of merge)** | `b9544737fb57e3cb1631f15caa3fce577e34cef8` |
| Diff | https://github.com/puemos/craftplan/pull/53.diff |
| Linked issue | [#49](https://github.com/puemos/craftplan/issues/49) — product allergen list ignores sub-assemblies while cost rollup / batch consumption / label ingredients resolve them |
| Commits | 1 |
| Tooling note | PR body is a maintainer write-up; no AI-co-author trailer observed in the inspected body. Treat code + tests as evidence. |

License at base: **AGPL-3.0** (see root `LICENSE`). Mix at base: Elixir `~> 1.20`, Ash 3 + Ash Postgres + Ash Authentication + Absinthe + Phoenix LiveView.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> A product's allergen list only covers direct materials. Subassembly materials show up as ingredients and in batch cost/quantity rollups, but their allergens are missing from the product page and from batch labels. Make allergen declarations include materials reached through nested subassemblies, matching the ingredients and quantities already resolved elsewhere. Fix it.

**Clarifiers that a hidden check may need (state in visible brief, do not over-specify implementation):**

- Allergens from nested materials appear on the finished product and on the batch label, sorted and deduplicated by name.
- A later allergen edit changes the live product declaration, but an already-persisted batch `label_snapshot` stays frozen (labels are historical).
- Products with no active recipe still declare no allergens.
- Cyclic recipes must not hang or double-count root materials.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/catalog/product/calculations/allergens.ex` | Ash calculation `Product.Calculations.Allergens`: stop loading only direct material allergens; flatten the active BOM and load allergens for the resulting material set. Keeps authorize/actor context. |
| `lib/craftplan/catalog/services/bom_rollup.ex` | `BOMRollup.flatten_components/3` becomes public and starts the recursion with the root product in the cycle-guard path, so nested components are actually loaded at every depth. |

**Cross-component behavior that must stay correct:** product LiveView allergen display ↔ batch `label_snapshot["allergens"]` ↔ `label_snapshot["ingredients"]` ↔ rollup quantities. One traversal should drive nested ingredient quantities and allergen sets so labels cannot disagree with materials.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/craftplan/catalog/product_allergens_test.exs`, `test/craftplan_web/subassembly_allergens_live_test.exs` |
| Docs / generated | none in this diff |

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| A1 | Nested material allergen appears on the finished product (not only direct materials). |
| A2 | Shared / diamond subassemblies deduplicate allergens by name and sort them. |
| A3 | Exact nested quantities in `BOMRollup.flatten_components/3` and `:rollup` match the multiplication through the recipe tree (e.g. flour 60, milk 20, eggs 10 in the upstream fixture). |
| A4 | Batch `label_snapshot["allergens"]` and `["ingredients"]` include nested materials at open time. |
| A5 | After adding an allergen later, the live product declaration updates, but the persisted batch snapshot does **not**. |
| A6 | Product with no active recipe contributes no allergens (including as a child). |
| A7 | Cyclic recipes terminate and do not duplicate root material quantities. |
| A8 | LiveView: product page and batch label page show the nested allergen and ingredient (boundary witness, not only the calculation helper). |

Upstream tests already assert A1–A7 in `product_allergens_test.exs` and A8 in `subassembly_allergens_live_test.exs`. Preserve mixed populations (nested + direct + shared + missing recipe) so a fix that flattens only one level or that disables allergens cannot pass.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** change `allergens.ex` to walk one extra level of `product` components by hand, without making `BOMRollup.flatten_components/3` load nested `components` and without seeding the root product into the cycle path. Nested depth-2 materials (the upstream flour-through-blend case) still miss allergens and quantities; direct-only cases may still pass. Must fail A1/A3/A8.

**Alternative incomplete:** fix only the calculation path but leave LiveView/batch label reading a stale direct-only list — fail A4/A8.

**Integrity:** the ordinary `System.halt(0)` early-exit patch in a compiled `lib/` file; qualification must still require executed named results.

---

## 6. Preservation

- Direct-material allergens, existing sort/`uniq_by(& &1.name)` behavior, empty-recipe `[]`.
- `flatten_components/3` callers (cost rollup, batch consumption, ingredient snapshots) keep their quantity semantics; only the previously silent nested omission is repaired.
- Authorization: calculation keeps `actor` / `authorize?` from the Ash context; do not require an unauthenticated Material read.
- Positive mixed population is mandatory (nested + shared + direct + no-recipe), per Plausible 6441 lesson.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required (`Craftplan.Repo`, SQL Sandbox in `config/test.exs`). Runner already supports Postgres. |
| **Ash 3 stack** | Ash + Ash Postgres + Ash Authentication + Ash Phoenix + Absinthe. Heavy but local; no cloud account. Native `bcrypt_elixir` / `picosat_elixir` / `heroicons` git sparse dep must be cached offline. |
| Storage integration | CI mentions SeaweedFS/MinIO storage integration. Selected catalog tests do not need object storage; **do not** require it for this case. |
| External APIs | None for the selected tests. Mail is Swoosh.Test. |
| Node/assets | LiveView tests use Floki/lazy_html only; no browser Chromium required. |

**Not verified here:** that the base tree compiles on a pinned Elixir 1.20/OTP image, that `mix test` is green at base, or that deps fetch offline from the historical lockfile. Ash major-version churn is the main preparation risk.

---

## 8. Status / next action

**Status:** screened — strong coordinated 2-file implementation candidate with an upstream issue, mixed-population tests, and a real product label boundary.

**Next action:** pin base `b9544737…`, cache deps from `mix.lock`, run unchanged/reference on PostgreSQL only, build the incomplete control above, then three fresh qualification rounds. Record AGPL-3.0 in provenance. Independent contract review of the short ticket before any hidden checks.
