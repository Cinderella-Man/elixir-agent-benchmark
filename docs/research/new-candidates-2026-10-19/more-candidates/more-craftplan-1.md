# More candidate — craftplan PR #55 (native intermediate production with lot tracing)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (larger coherent feature)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/55 |
| Title | Produce and stock intermediate materials with lot tracing |
| Author | **puemos** (maintainer) |
| Created / merged | 2026-10-08 (squash) |
| Merge commit SHA | `024ceb7d177201a85a7a91d5f5c2bb9fecd3215d` |
| **Base SHA (parent of squash)** | `4097496dbce048f6534be10ccad68eb64e16a8f8` |
| Squash parents | **1 parent** on commit HTML — squash verified |
| Diff | https://github.com/puemos/craftplan/pull/55.diff |
| Commits in PR | 1 (squash) |

Related prior work (not merged into this task): PR #40 lot genealogy / recall. Keep #55 alone; #40 is already in the tree at base.

License at base: **AGPL-3.0**. Mix: Elixir `~> 1.20`, Ash 3 + Ash Postgres + LiveView.

---

## 2. Ticket (shortest sufficient, clarified implementation brief)

> Producing an intermediate still means manually consuming raw inputs and receiving a separate stock lot, so the link between input lots and the produced lot is lost. Let me produce a stocked intermediate material from a versioned material recipe in one step: plan a batch against a recipe, record actual yield and input usage, and stock the output lot. The output lot must keep its connection to the consumed input lots. Calculate the output unit cost from the actual inputs, refuse to consume unavailable stock, and keep completed recipe/input history immutable. I also need to trace supplier lots through intermediate batches to finished products and customer orders, including a CSV export of that chain. Do not break ordinary finished-goods production or existing inventory stock.

Do **not** name `Intermediates`, `ProduceMaterialBatch`, `MaterialRecipe`, `MaterialBatchInput`, or file paths in the solver ticket.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/inventory/intermediates.ex` | **New** domain facade: latest/versioned recipes, batch listing, component normalization, batch validation against recipe and stock. |
| `lib/craftplan/inventory/changes/prepare_material_recipe.ex` | **New** Ash change: freeze/version a material recipe (immutable after use). |
| `lib/craftplan/inventory/changes/produce_material_batch.ex` | **New** Ash change: one-transaction produce — validate inputs, consume input lots, create output lot with cost from actual inputs, snapshot recipe/components. |
| `lib/craftplan/inventory/material_recipe.ex` | **New** Ash resource: versioned recipe (material, yield, components). |
| `lib/craftplan/inventory/material_batch.ex` | **New** Ash resource: produced intermediate batch (output lot, recipe snapshot, status). |
| `lib/craftplan/inventory/material_batch_input.ex` | **New** Ash resource: input lot × quantity × unit_cost link for genealogy. |
| `lib/craftplan/inventory.ex` | Expose new resource actions on the Inventory facade. |
| `lib/craftplan/production/batching.ex` | Planner must understand intermediate batches/inputs so ordinary production can consume stocked intermediates. |
| `lib/craftplan/traceability.ex` | Extend genealogy through intermediate batches to products/orders. |
| `lib/craftplan/csv/exporters/traceability.ex` | CSV export of the extended lot chain. |
| `lib/craftplan_web/live/manage/inventory_live/production.ex` | **New** Production tab LiveView: plan batch, record yield/usage, stock output. |
| `lib/craftplan_web/live/manage/inventory_live/show.ex` | Material detail surfaces production/history; removes old manual-workaround affordances. |
| `lib/craftplan_web/components/material_detail.ex` | Detail components for recipes/batches/inputs. |
| `lib/craftplan_web/live/manage/traceability_live/index.ex` | Trace UI walks intermediate links. |
| `lib/craftplan_web/navigation.ex`, `lib/craftplan_web/router.ex` | Production tab route + nav entry. |

**Cross-component behavior:** recipe versioning ↔ produce transaction (input consumption + output lot + cost + snapshot) ↔ planner/traceability consumers ↔ Production LiveView. A produce path that stocks the output but drops `MaterialBatchInput` rows breaks forward/backward trace; a planner that cannot consume intermediates leaves the feature unusable for finished goods.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (3) | `test/craftplan/intermediate_production_test.exs`, `test/craftplan_web/intermediate_production_live_test.exs`, `test/craftplan_web/navigation_test.exs` |
| Migration (1) | `priv/repo/migrations/20261007200432_add_native_material_production.exs` |
| Ash resource snapshots (3, generated) | `priv/resource_snapshots/repo/inventory_material_batch_inputs/*`, `inventory_material_batches/*`, `inventory_material_recipes/*` |
| Docs/media (mechanical) | `docs/**` (~15 paths, screenshots/demo zip/mp4) — **exclude from implementation count** |
| Mechanical | `VERSION` bump to 0.7.5 |

**Implementation count:** ~15 code paths (domain + web + router). Larger than the 2–5 preference; admitted as the **one larger coherent feature** this batch if the Ash runtime is already proven (pair with a smaller craftplan case first if needed).

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| P1 | Define a versioned material recipe with distinct input materials and a yield; output cannot be its own input. |
| P2 | Plan a produce batch from that recipe; record actual yield and per-input usage; stock the output lot. |
| P3 | Output lot unit cost = sum(input qty × input unit_cost) / actual yield. |
| P4 | Consume the named input lots from stock; refuse the batch when any input lot lacks stock. |
| P5 | `MaterialBatchInput` rows link output lot → each input lot (genealogy). |
| P6 | Completed recipe and batch input history are immutable (no rewrite of snapshot/components). |
| P7 | Forward trace: supplier lot → intermediate batch → finished product lot. |
| P8 | Backward trace: finished product/order lot → intermediate inputs → supplier lots. |
| P9 | CSV export includes the intermediate hop(s) in the chain. |
| P10 | Production LiveView: plan → record yield/usage → stocked; error path for unavailable stock is visible. |
| P11 | Preservation: ordinary finished-goods production batch (no intermediates) and existing inventory stock movements still work. |

Upstream tests cover P2–P6 and LiveView P10 at the domain/HTTP boundary; P7–P9 need curator assertions against traceability + CSV if upstream does not fully cover hops.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** implement produce (P2–P4) and stock the output lot, but **do not** persist `MaterialBatchInput` links or extend traceability — UI/stocking look fixed; P5, P7–P9 fail.

**Second incomplete:** domain produce + genealogy work, but Production LiveView still only supports the manual workaround / does not expose the Production tab — P10 fails.

**Third incomplete:** forward trace works but CSV exporter still emits only the old product-level chain — P9 fails.

**Integrity:** standard `System.halt(0)` early-exit; require executed named results including LiveView/CSV, not only `Intermediates` unit tests.

---

## 6. Preservation

- Existing finished-goods production batches and BOM/allocation behavior (P11).
- Existing inventory lot stock, manual receive/adjust paths.
- Traceability for pure finished-goods chains (no intermediate hop) unchanged in shape.
- Ash policy/actor checks on new resources match existing Inventory auth style.
- Mixed population: materials with/without recipes; batches with partial stock; completed vs planned.

---

## 7. Runtime / offline holds

Same as other craftplan cases:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; SQL Sandbox. |
| Ash 3 stack | Heavy local deps; cache `mix.lock` offline; `bcrypt_elixir` / `picosat_elixir` native. |
| External services | None for these tests (exclude SeaweedFS/MinIO). |
| Browser | Not required; LiveViewTest only. |
| Assets | Docs screenshots/demo media are **not** scored. |

**Not verified:** compilation, green base suite, offline dep fetch, or Ash resource-snapshot/migration apply at this revision. Migration is large (three new resources); keep DDL mechanical in counts but treat snapshot JSON as generated.

---

## 8. Status / next action

**Status:** screened — the **larger feature** candidate for this pass. Coherent single product outcome (native intermediate production + genealogy), multi-layer (Ash resources/changes ↔ planner/traceability ↔ LiveView ↔ CSV). Prefer only after a smaller craftplan Ash/Postgres qualification proves the runtime.

**Next action:** pin base `4097496d…`, prove Ash fixture with craftplan #46 or #52 first, then three qualification rounds. Keep docs/media out of the implementation count. AGPL-3.0 in provenance. Optional `git apply --check` of `pull/55.diff` on a clean clone at base (not executed this pass).

---

## Grilling (2026-10-19)

### Identity flag
**This is craftplan PR #55 — the large feature, not a "more candidate" sibling.** Treat it as the large-features slot. Do not put it in the same admission batch as craftplan #46 as if they were equals; #55 is ~15 code paths, three new Ash resources, a migration, a LiveView surface, planner changes, and traceability/CSV extension. The dossier's own text admits it is "larger than the 2–5 preference" and "prefer only after a smaller craftplan Ash/Postgres qualification proves the runtime." That advice is binding.

### Minimum ticket
The brief is a multi-outcome product essay (recipe versioning + produce + cost + genealogy + forward/backward trace + CSV + UI + immutability + preservation). That is honest for a large feature but it is not "shortest sufficient". It is acceptable as a **clarified implementation brief** per guidelines — record `brief_kind: clarified_implementation_brief` — but only if every clause is either scored or explicitly out of scope. Right now P1–P11 are all implicitly scored. Either score all of them or cut to the core (produce one-step + genealogy + cost + refuse-unavailable + one trace direction) and push CSV/UI polish to optional.

### Named deterministic checks
P1–P11 are unexecuted proposals. For a large feature that is a long runway. Minimum named set before any model run:
1. recipe versioned and immutable after use (P6)
2. produce consumes input lots and stocks output lot in one transaction (P2/P4)
3. cost formula from actual inputs (P3) — assert the formula, not just "non-nil"
4. `MaterialBatchInput` links exist (P5)
5. refuse produce when any input lot lacks stock (P4 negative)
6. forward trace supplier→intermediate→product (P7)
7. backward trace order/product→intermediate→supplier (P8)
8. CSV contains the intermediate hop (P9)
9. Production LiveView plan→record→stocked (P10)
10. ordinary finished-goods production unchanged (P11)

Without (5) and (6–8) the "stock but no genealogy" incomplete passes. P7–P9 are flagged as needing curator assertions — that is a **grading gap**, not a footnote.

### Ambiguity / unfairness
- "Calculate the output unit cost from the actual inputs" — formula must be visible or the check is a hidden arithmetic policy. State `sum(qty × unit_cost) / actual_yield` in the brief or accept any documented alternative and grade by a published invariant.
- "Keep completed recipe/input history immutable" is fair if the starting Ash resources show what mutable looks like. Do not grade Ash policy idioms.
- CSV chain shape is a representation choice. Do not byte-grade the CSV. Grade that the intermediate hop appears (lot IDs present).
- "Do not break ordinary finished-goods production" is the right preservation sentence; keep it.

### Shortcuts + compiling incomplete
The dossier names three incompletes (no genealogy links; no Production UI; CSV stuck on old chain). All compile. Under-weighted shortcuts: consume inputs but create the output lot without going through the one-transaction change (partial writes on failure); hard-code cost to recipe cost instead of actual; allow output to be its own input (P1 must reject). Add a crash/partial-write check: failing mid-produce must not leave consumed inputs without an output lot.

### Flakiness
Ash + Postgres + LiveViewTest. Flake risk is Ash resource snapshot/migration apply at this revision, and bcrypt/picosat native builds at setup time — those are **env** failures. Keep tests synchronous; no browser. Docs/demo media must not run as tests.

### Preservation
P11 is essential and must be named, not implied. Also preserve: existing inventory stock movements, manual receive/adjust, and traceability shape for pure finished-goods chains. Mixed population: materials with/without recipes; partial stock; planned vs completed batches.

### Env
**Unproven and heavy.** Elixir `~> 1.20` (same wall as Mydia/Nerves). Ash 3 + Ash Postgres + native bcrypt/picosat. Migration is large (three new resources). No `git apply --check`, no compile, no green base suite, no offline dep cache. Ash resource snapshots are generated — exclude from implementation counts (dossier does). AGPL-3.0.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. Do **not** merge PR #40 (lot genealogy/recall) — dossier correctly keeps #55 alone; #40 is already in the tree at base. Do not stack with craftplan #46/#51 — different user stories.

### Verdict
**HOLD** — this is the large-feature candidate and it is not qualification-ready: zero execution, wide ungraded surface, Elixir 1.20 unproven, Ash runtime unproven.

### Must-fix before qualification
1. Prove Ash/Postgres runtime on a **smaller** craftplan case first (#46 is the intended first project qualification). Do not make #55 the Ash maiden voyage.
2. `git apply --check` of `pull/55.diff` at base `4097496d…`; record result.
3. Convert P1–P11 to named protected checks, especially refuse-unavailable, genealogy links, cost formula, and both trace directions. Author the P7–P9 assertions yourself if upstream lacks them.
4. State the cost formula in the brief (or an equivalent visible invariant).
5. Add partial-write/failure-atomicity integrity check on produce.
6. Three qualification rounds only after (1–5). AGPL-3.0 in provenance. Keep docs/media out of counts.
