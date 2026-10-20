# More2 candidate — craftplan PR #43 (product deletion cascade + recipe removal buttons)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (linked issue #41; product/recipe management)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/43 |
| Title | fix(catalog): restore product deletion and recipe removal |
| Author | **puemos** (maintainer) |
| Merged | 2026-09-26 (squash) |
| Merge commit SHA | `f126e34cc2db6bfce7d4882e0a04526ece066ab8` |
| **Base SHA (parent of squash)** | `eaf42f6a57cf17fe49516cec1ea51b26d8dfc6a9` |
| Squash parents | **1 parent** — squash verified via API commit object |
| Diff | https://github.com/puemos/craftplan/pull/43.diff |
| Linked issue | [#41](https://github.com/puemos/craftplan/issues/41) (products with recipes could not be deleted) |
| Commits in PR | 1 (squash) |
| Scale | 13 files, +1067 / −37 |

**Lineage note:** independent of the already-filed #46/#51/#53/#55 chain (this squash landed **before** that stack). Reconstruct at **`eaf42f6a…`** alone. Do not fold into the order-edit (#46) or intermediate-production (#55) cases.

License at base: **AGPL-3.0**. Mix: Elixir `~> 1.20`, Ash 3 + Ash Postgres + LiveView.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> Products that have a recipe cannot be deleted — the delete fails because recipe records still reference the product. Deleting a product should remove its recipe versions and everything owned by those recipes, while still refusing deletion when orders or other products depend on it. Also, removing a component or labor step from a recipe form is unreliable: the row disappears but the form still validates as if it were there. Fix it.

Do **not** name `on_delete: :delete_all`, `CascadeProductRecipeDeletion`, `form_component_recipe`, `remove_form`, or file paths. Leave “how cascade is implemented” and “how the form should submit removals” to the solver.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/catalog/bom.ex` | Product→BOM reference becomes cascading delete (`on_delete: :delete`). |
| `lib/craftplan/catalog/bom_component.ex` | BOM→components reference cascades. |
| `lib/craftplan/catalog/bom_rollup.ex` | BOM→rollups and product→rollups references cascade. |
| `lib/craftplan/catalog/labor_step.ex` | BOM→labor steps reference cascades. |
| `lib/craftplan_web/live/manage/product_live/form_component_recipe.ex` | Replace hidden-checkbox row removal with explicit remove buttons (desktop + mobile ids) so removing a row does not re-submit stale nested forms and trip validation. |

**Cross-component behavior:** Ash relationship `on_delete` policy ↔ Postgres FK cascade migration must agree, or product destroy still fails at the DB layer. Recipe form row removal must not leave the nested change-set in a state that blocks submit (stale-row validation). Retain restrictions for **orders** and other products that reference the BOM — cascade only what the product owns.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/craftplan/catalog/product_deletion_test.exs`, `test/craftplan_web/manage_products_recipe_simple_live_test.exs` |
| Migration (1) | `priv/repo/migrations/20260926174200_cascade_product_recipe_deletion.exs` |
| Ash resource snapshots (4, generated) | `priv/resource_snapshots/repo/catalog_{bom_components,bom_rollups,boms,labor_steps}/*.json` |
| Mechanical (1) | `VERSION` bump to 0.7.1 |

**Implementation count:** **5** files (4 Ash resources + 1 LiveView form). Migration/snapshots are mechanical/generated; tests counted separately.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| C1 | Destroying a product that has recipe version(s) succeeds; all owned BOM versions, components, labor steps, and cost rollups are gone. |
| C2 | Destroying a product is still **refused** (or safely blocked) when an order references it. |
| C3 | Destroying a product is still blocked when another product references its BOM/rollup as a dependency (restriction retained). |
| C4 | Removing a component row from the recipe form leaves a submittable form; saved recipe no longer has that component. |
| C5 | Removing a labor step row behaves the same (desktop and mobile affordances). |
| C6 | Removing rows and then saving an **empty** recipe is allowed and persists. |
| C7 | Preservation: creating/editing a recipe with components and labor steps still works; version history of remaining products is untouched. |

Upstream tests cover C1 and C4–C6. C2–C3 and C7 need positive/negative preservation witnesses (mixed population: deletable product, order-linked product, recipe edit without deletion).

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** add remove buttons in the LiveView form but leave Ash/FK cascade unchanged — C4–C5 pass, C1 fails (product delete still errors).

**Second incomplete:** cascade the Ash references and migration but skip `bom_rollup.product` — C1 partially fails (rollups of the product remain / FK error).

**Third incomplete:** cascade everything including order-referencing products — C2 fails (orders lose their product or delete is wrongly allowed).

**Integrity:** standard `System.halt(0)` early-exit; require executed named results on `product_deletion_test` + recipe LiveView tests, not only compile.

---

## 6. Preservation

- Products without recipes delete as before.
- Orders and other dependents still protect against delete (do not widen cascade to non-owned tables).
- Recipe create/edit, nested component/labor addition, and saved version browsing unchanged.
- Mixed population: product with recipe + no orders (deletable), product with order (not deletable), recipe form with 0/1/N rows.

---

## 7. Runtime / offline holds

Same class as other craftplan cases:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; SQL Sandbox. |
| Ash 3 stack | Heavy local deps; cache `mix.lock` offline; `bcrypt_elixir` / `picosat_elixir` native. |
| External services | None for these tests (exclude SeaweedFS/MinIO). |
| Browser | Not required; LiveViewTest only. |

**Not verified:** compilation, green base suite, offline dep fetch, or migration apply at this revision. Snapshot JSON is generated — keep out of graded implementation diffs.

---

## 8. Status / next action

**Status:** screened — strongest **coordinated multi-file** craftplan bugfix not already filed (5 implementation files, one catalog-delete story, clear incomplete controls). Prefer after an Ash/Postgres fixture is proven on a smaller craftplan case (#52 is a good companion).

**Next action:** pin base `eaf42f6a…`, apply `pull/43.diff`, map C1–C7, build incomplete = form-only / partial-cascade / over-cascade. AGPL-3.0 in provenance. Do not combine with #46/#55.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Products that have a recipe cannot be deleted — the delete fails because recipe records still reference the product. Deleting a product must remove the recipe versions and everything those recipes own (components, labor steps, cost rollups), while still refusing deletion when orders or other products depend on it. Separately, removing a component or labor step from a recipe form is unreliable: the row disappears but the form still validates as if it were there. Fix both.

Maintenance report. States cascade scope (owned recipe rows) and the retained restrictions (orders / other products). Does not name `on_delete: :delete`, module names, or files.

**Hidden requirements flagged:**
- **Two bugs in one ticket.** Linked issue #41 is deletion; the form-removal bug is a second story. Guidelines reject "unrelated changes bundled into one task". Defend as one "recipe ownership / recipe editing" story in the dossier, or split. If kept, the ticket must present them as one user-visible recipe-management problem (as above) so the solver is not guessing scope.
- "everything those recipes own" must be explicit: BOM versions, components, labor steps, and **rollups tied to that product**. A solver who cascades components but not rollups is plausible. The checklist C1 names them — those names must also appear in the ticket or be discoverable from the schema/ash resources in the workspace (they are, via `catalog_*` tables). Prefer naming the owned kinds in the ticket.
- Cascade mechanism (Ash `on_delete` **and** the Postgres FK migration must agree) is implementation. Do not require both; require the observable: destroy succeeds and owned rows are gone.

### 2. Deterministic checks

ExUnit + Ash + SQL Sandbox + LiveViewTest. No browser. No jobs.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `product destroy-removes-recipe-tree` | Product with BOM version(s), components, labor steps, rollups; no orders | `Ash.destroy/2` | `:ok`; product gone; all owned rows gone; unrelated material still present |
| `product destroy-refused-when-ordered` | Product referenced by an order item | `Ash.destroy/2` | error; product and order item remain |
| `product destroy-refused-when-depended` | Another product references this product's BOM/rollup | `Ash.destroy/2` | error; both products remain |
| `recipe remove-component-persists` | LiveView recipe form with ≥1 component; click remove; save | active BOM version | saved recipe has no that component; form submittable (not disabled / no validation error) |
| `recipe remove-labor-persists` | Same for labor step (desktop + mobile affordances) | same | same |
| `recipe save-empty-allowed` | Remove all rows; save | active version | empty components + labor steps persist; unit cost 0 |
| `recipe edit-without-delete-preserved` | Add/edit rows; save | active version | create/edit still works (preservation) |

Fake provider: none. PostgreSQL required.

**Note:** upstream `product_deletion_test` already covers destroy + refused cases; LiveView tests cover removal. Curator adds the depend-on-other-product case and a mixed preservation witness if upstream lacks it.

### 3. Ambiguity / unfairness

- "still refusing" vs "safely blocked": the reference returns `{:error, _}` from Ash. A DB-level FK error would also "block" but is a worse product outcome. Ticket says "refusing deletion" — grade a controlled error (changeset/ash error), not an exception. State "return an error, do not crash".
- Cascade to rollups that reference **other** products via `product_id`: the reference cascades `catalog_bom_rollups.product_id` and `.bom_id`. Is a rollup "owned by the recipe" or "owned by the product"? Ticket says "everything those recipes own" — rollups are per-product cost rollups of a BOM. Make the owned set explicit to avoid a solver who leaves rollups behind.
- Form removal mechanism (hidden checkbox vs button) is implementation. Grade "remove + save persists and form remains submittable", not DOM ids. The reference's `remove-component-#{index}` ids must not be required.
- Snapshot JSON files are generated — exclude from graded diff.

### 4. Shortcuts

- Form-only remove buttons; Ash/FK unchanged. Compiles. Fails `product destroy-removes-recipe-tree`. Planned incomplete #1.
- Cascade BOM + components + labor but skip rollups. Fails destroy-owned-rows (rollups remain / FK error). Planned incomplete #2.
- Cascade everything including order-referencing products (drop the restriction). Fails `product destroy-refused-when-ordered`. Integrity.
- Hard-delete product row with `Repo.delete_all` bypassing Ash, leaving orphans. Fails owned-rows assertions.
- Mark rows deleted in the form but keep them in the nested params (the original bug). Fails `recipe remove-component-persists`.

### 5. Flakiness / nondeterminism

Low–medium. Ash versioning / active BOM version creation may involve timestamps or ordered versions — assert on `active.components == []` etc. as upstream does, not on version numbers. LiveView tests: use `element/3` + `render_click`, no sleeps. Do not depend on desktop vs mobile CSS breakpoints for pass/fail; run both affordances as upstream does (parameterised test).

### 6. Coverage mix

- Positive: deletable product with recipe; remove rows and save; empty recipe.
- Negative: order-linked product; dependency-linked product.
- Preservation: products without recipes delete as before; recipe create/edit with rows; other products' version history untouched.
- Mixed population in one test file: deletable / ordered / depended products side by side so an over-cascade patch fails.

### 7. Environment risk

- **AGPL-3.0.** PostgreSQL required.
- **Ash 3 + Ash Postgres + LiveView**, Elixir `~> 1.20`. Native deps: `bcrypt_elixir`, `picosat_elixir`. Cache `mix.lock` offline. **Nothing is verified** — compilation, green base suite, offline dep fetch, and migration apply are all unknowns. This is the dominant risk.
- Migration is autogenerated by `mix ash_postgres.generate_migrations` — the solver may regenerate snapshots. Grade behaviour, not snapshot files.
- No SeaweedFS/MinIO for these tests. No browser.

### 8. Verdict

**READY-WITH-FIX** — strongest coordinated craftplan bugfix, clear incomplete matrix, but the two-bug bundle must be justified as one story and the Ash/Postgres fixture is unproven.

### 9. Must-fix list

1. Justify deletion + form-removal as one recipe-management story in the dossier (or split into two cases).
2. Put the owned-row kinds (components, labor steps, rollups) and "return an error, do not crash" in the ticket.
3. Do not grade DOM ids or snapshot JSON.
4. Incomplete controls: form-only; partial cascade (skip rollups); over-cascade (drop order restriction) — each must fail a named check.
5. Prove Ash/Postgres fixture offline before qualification; record Elixir/OTP/dep cache.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Two-bug bundling + unproven Ash 3 / PG fixture |
