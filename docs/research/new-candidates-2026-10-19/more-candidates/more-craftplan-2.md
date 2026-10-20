# More candidate — craftplan PR #46 (order edit links, status edits, preserved prices, confirmed delete)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (linked issue #44)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/46 |
| Title | fix(orders): make order updates and deletion accessible |
| Author | **puemos** (maintainer) |
| Merged | 2026-09-27 (squash) |
| Merge commit SHA | `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c` |
| **Base SHA (parent of squash)** | `2615dafc9e61801b049dc535a44de5256b9d9bfe` |
| Squash parents | **1 parent** on commit HTML — squash verified |
| Diff | https://github.com/puemos/craftplan/pull/46.diff |
| Linked issue | [#44](https://github.com/puemos/craftplan/issues/44) (order update/delete accessibility) |
| Commits in PR | 1 (squash) |

**Important:** this squash is the **parent of PR #51’s base**. If both cases are admitted, freeze #46 at `ad9fb484…` and #51 at `46c0a6fa…` as already filed — do not silently stack.

License at base: **AGPL-3.0**. Mix: Elixir `~> 1.20`, Ash 3 + Ash Postgres + LiveView.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> Orders are hard to manage after they are created. From the orders list and from a customer’s order history I need an explicit way to open the order form. On the form I must be able to change fulfillment status and payment status. When I remove a line item and save, the remaining items must keep the prices they were sold at (do not reprice them from the catalog). On the order detail page I need a confirmed delete that removes the order and its items. Orders that are linked to production must not be deletable. Fix it.

Do **not** name `cascade_destroy`, `payment_status` attribute path, `unit_price` hidden field, or file paths.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/orders/order.ex` | Accept `payment_status` on create/update; replace default `destroy` with a cascading destroy of items (and production-link protection stays in the destroy path). |
| `lib/craftplan_web/live/manage/order_live/form_component.ex` | Status + payment status selects; item rows use the persisted `unit_price` (not catalog `products_map` price); remove-item button. |
| `lib/craftplan_web/live/manage/order_live/show.ex` | `#edit-order` link, `#delete-order` with confirm, `delete_order` handler + flash/navigate. |
| `lib/craftplan_web/live/manage/order_live/index.ex` | Per-row `#edit-order-#{id}` link to the edit form. |
| `lib/craftplan_web/live/manage/customer_live/show.ex` | Per-row `#edit-customer-order-#{id}` link in the customer’s order history. |

**Cross-component behavior:** Ash order actions (status/payment accept + cascade destroy) ↔ form that preserves sold prices ↔ three surfaces that expose edit/delete (index, show, customer show). A form that reprices from the catalog silently rewrites history; a destroy without item cascade leaves orphans; production-linked orders must stay protected.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (1) | `test/craftplan_web/manage_orders_details_edit_interactions_live_test.exs` (+123 lines) |
| Mechanical | `VERSION` → 0.7.3 |

**Implementation count:** **5** files (1 Ash resource + 4 LiveViews) — matches the coordinated multi-file preference.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| O1 | Orders index and customer order history each expose a working edit link to the order form. |
| O2 | Order detail page exposes edit and a confirmed delete (`data-confirm` present). |
| O3 | Form can change fulfillment `status` and `payment_status`; both persist on save. |
| O4 | Removing a line item and saving keeps **original** unit prices on remaining items (catalog price change after create must not reprice). |
| O5 | Delete removes the order **and** its items (no orphan item rows). |
| O6 | Production-linked order **cannot** be deleted (error/flash); order remains. |
| O7 | Non-production order deletes successfully, flashes, and navigates to the orders list. |
| O8 | Preservation: creating an order still works; totals/invoice for untouched orders unchanged. |

Upstream focused LiveView tests cover O1–O7 at the HTML/LiveView boundary. O8 is a required preservation witness.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** add edit links + status/payment selects and cascade destroy, but leave the form’s unit price bound to the catalog `products_map` — O4 fails while UI looks complete.

**Second incomplete:** form preserves prices and destroy cascades, but delete is not blocked for production-linked orders — O6 fails.

**Third incomplete:** domain destroy + show-page delete work, but index/customer history still lack edit links — O1 fails.

**Integrity:** standard `System.halt(0)` early-exit; require executed named results including the LiveView interaction tests, not only Order unit tests.

---

## 6. Preservation

- Order create path, totals, invoice PDF generation.
- Line items that were never edited keep their stored prices and quantities.
- Production batch allocation behavior for orders that cannot be deleted (O6) — they must still be visible/editable where the reference allows.
- Mixed population: production-linked vs free orders; edited vs pristine line items; payment-only edits vs item removals.

---

## 7. Runtime / offline holds

Same as other craftplan cases:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; SQL Sandbox. |
| Ash 3 stack | Cache `mix.lock` offline; native bcrypt/picosat. |
| External services | None for these tests (exclude SeaweedFS/MinIO). |
| Browser | Not required; LiveViewTest only. |

**Not verified:** compilation, green base suite, offline dep fetch. Upstream validation claims 8 focused order LiveView/domain tests on then-current main — re-run at the pinned base before freeze.

**Optional apply experiment (this pass):** `git clone` of `puemos/craftplan`, `git fetch --depth 1` of base `2615dafc…`, `git apply --check --verbose` of `pull/46.diff` → **exit 0** (all 7 files check clean, including `test/craftplan_web/manage_orders_details_edit_interactions_live_test.exs`).

---

## 8. Status / next action

**Status:** screened — strongest **coordinated multi-file** craftplan bugfix after the already-filed #51/#53 pair. Five implementation files, one user story (manage orders end-to-end), clear incomplete controls (price preservation / production-link guard / surface coverage).

**Next action:** pin base `2615dafc…` (parent of `ad9fb484…`), prepare Ash/Postgres fixture, build the three incomplete controls, then three qualification rounds. AGPL-3.0 in provenance. Do not combine with #51 into one case — different user stories.

---

## Grilling (2026-10-19)

### Minimum ticket
Good length and shape (maintenance report). Keep "remaining items must keep the prices they were sold at (do not reprice them from the catalog)" and "Orders that are linked to production must not be deletable" — those are the two product rules that prevent unfair hidden checks. Trim only: "From the orders list and from a customer's order history I need an explicit way to open the order form" → "I need a way to open the order form from the orders list and from a customer's order history." Fine either way.

### Named deterministic checks
O1–O8 are clear and the dossier says upstream focused LiveView tests cover O1–O7. That is better than most "more" candidates. Still, "8 focused order LiveView/domain tests on then-current main" is **not** proof they pass at the pinned base `2615dafc…`. Re-run them. Required names to lock before freeze:
1. edit link present on index and customer history (O1)
2. edit + confirmed delete on detail (O2)
3. status and payment_status persist (O3)
4. price preservation after item removal (O4) — the discriminator
5. delete cascades items (O5)
6. production-linked order not deletable (O6) — second discriminator
7. free order deletes + flash + navigate (O7)
8. create/totals preservation (O8)

O4 and O6 are the two incompletes' killers. If either is missing from protected checks, the "looks complete but reprices / deletes linked orders" patches pass.

### Ambiguity / unfairness
- Price preservation: the brief states it. Do not grade the hidden-field mechanism (`unit_price` in the form) — grade the **persisted** prices after save. A solver who uses a different binding strategy must pass.
- Production-link guard: "must not be deletable" is visible. Accept any user-visible refusal (changeset error, flash, no-op) as long as the order remains. Do not require a specific flash string.
- "Confirmed delete" — grade `data-confirm` presence or an equivalent explicit confirm UX; do not require the exact confirm text.
- payment_status attribute naming: the brief says "payment status" (product language). Good. Do not require the Ash attribute name.

### Shortcuts + compiling incomplete
The three named incompletes (reprice from catalog; no production guard; missing surfaces) are real and compile. Under-weighted shortcuts: cascade delete items but also wipe production links and allow delete (O6 must still refuse); preserve prices on edit but reprice on create-time calculations only — that is fine and should not be a failure; show delete button for production-linked orders but no-op the click without feedback — O6 must require the order to remain **and** some visible refusal.

### Flakiness
LiveViewTest only; no browser. Ash + Postgres sandbox. Flake risk is setup (bcrypt/picosat native, Ash snapshot) not assertions. Keep tests in the focused file; do not run full suite as the graded boundary.

### Preservation
O8 is named-ish. Keep: create path, totals, invoice generation, line items that were never edited, production batch allocation visibility for protected orders. Mixed population: production-linked vs free; edited vs pristine items; payment-only edits vs item removals.

### Env
Elixir `~> 1.20` + Ash 3 + Postgres — **same unproven wall** as craftplan #55 and Mydia. One good sign: `git apply --check` of `pull/46.diff` at base `2615dafc…` is **exit 0** (7 files clean). Still no compile, no green base suite, no offline dep cache. AGPL-3.0.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. Do **not** combine with #51 — dossier is correct that they are different user stories; freeze #46 at `ad9fb484…` and #51 at its own base. Do not stack onto #55.

### Verdict
**READY-WITH-FIX** as the craftplan runtime qualifier candidate — best-shaped craftplan case in this pass — but still blocked on Elixir 1.20 + Ash execution.

### Must-fix before qualification
1. Provide Elixir ~> 1.20 + Postgres + Ash offline cache; run the focused order tests at base and base+patch. Green both sides.
2. Lock O4 and O6 as named protected checks with behavior-based assertions (persisted prices; order remains on refused delete).
3. Define "confirmed delete" grading as confirm-UX presence, not exact text.
4. Add named O8 preservation (create/totals).
5. Qualify this case **before** craftplan #55; do not reverse the order.
