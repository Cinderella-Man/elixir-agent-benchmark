# More2 candidate — craftplan PR #52 (batch-sheet scientific notation is optional)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (linked issue #48; production batch-sheet readability)
**Project:** [puemos/craftplan](https://github.com/puemos/craftplan)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/puemos/craftplan/pull/52 |
| Title | fix(production): make batch-sheet scientific notation optional |
| Author | **puemos** (maintainer) |
| Merged | 2026-10-07 (squash) |
| Merge commit SHA | `b9544737fb57e3cb1631f15caa3fce577e34cef8` |
| Squash parent (first parent at merge) | `46c0a6fa88ed5bd195531460129ddddbe055b663` (= already-filed **#51** squash) |
| **PR base (for standalone reconstruction)** | `ad9fb484e9e19076aae2c8c4dc48a736535e3a3c` (= already-filed **#46** squash) |
| Squash parents | **1 parent** — squash verified via API commit object |
| Diff | https://github.com/puemos/craftplan/pull/52.diff |
| Linked issue | [#48](https://github.com/puemos/craftplan/issues/48) |
| Commits in PR | 1 (squash) |
| Scale | 8 files, +626 / −22 |

**Lineage / freeze warning:** this squash sits **on top of #51**, and the PR was opened from **#46**. Skip-list reserves #52 as a case; it is **not** already filed in `more-candidates/`. If both #51 and #52 are admitted, freeze **separately**:
- standalone #52 case: reconstruct at **`ad9fb484…`** and apply only `pull/52.diff` (verify apply; if dirty because #51 touched the same files, either drop to the combined tree and drop #51 as a separate case, or keep #51 out of this starting tree).
- Do **not** silently stack #51’s solution into a #52 ticket.

License at base: **AGPL-3.0**. Mix: Elixir `~> 1.20`, Ash 3 + Ash Postgres + LiveView.

---

## 2. Ticket (shortest sufficient, clarified implementation brief)

> Printable production batch sheets print large quantities in scientific notation (`1E+4` instead of `10000`), which shop floors cannot use. Print ordinary decimals by default on every batch-sheet quantity (planned/order quantities, material requirements, lot usage, waste, and labor). Let an administrator turn scientific notation back on in General Settings; the preference must apply to every sheet section the same way. Stored quantities and configured units must not change. Fix it.

Do **not** name `batch_sheet_scientific_notation`, `format_decimal`, `D.to_string`, or file paths. Stating “administrator setting” is the requested product outcome (settings UI is in scope); leave the flag name and formatter to the solver.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/craftplan/production/batch_sheet.ex` | Thread a notation preference through every `build_*` section; `format_decimal/2` chooses `:normal` vs `:scientific` (normalized Decimal). |
| `lib/craftplan/settings/settings.ex` | New boolean attribute on the Settings resource (`batch_sheet_scientific_notation`, default false). |
| `lib/craftplan_web/live/manage/settings_live/form_component.ex` | Checkbox + help text in General Settings; save/reload both states. |
| `priv/repo/migrations/20261007133702_readable_batch_sheet.exs` | Add the settings column (default false). |
| `lib/craftplan/production/batch_sheet.ex` consumers | `build_data/4` takes the flag; orders, bom_components, labor_steps, lots all format through the same helper. |

**Cross-component behavior:** Settings resource ↔ settings LiveView ↔ batch-sheet renderer. A sheet that formats only `planned_qty` and not lots/labor leaves the bug visible; a setting that saves but is not read at render time fails the product outcome.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/craftplan/batch_sheet_test.exs`, `test/craftplan_web/manage_settings_interactions_live_test.exs` |
| Migration (1) | `priv/repo/migrations/20261007133702_readable_batch_sheet.exs` |
| Ash resource snapshot (1, generated) | `priv/resource_snapshots/repo/settings/20261007133703.json` |
| Docs (1, mechanical) | `docs/src/pages/docs/settings.md` |

**Implementation count:** **3** core (batch_sheet + settings resource + settings form) + migration. Slightly under the 2–5 preference; keep as a **focused settings→production** diversity pick (clear contract, named upstream checks, Ash fixture companion to #43/#55).

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| B1 | Default (setting off): `10000` prints as `10000`, `60` as `60` — not `1E+4` / `6E+1`. |
| B2 | Setting on: the same values print in scientific notation (`1E+4`, `6E+1`). |
| B3 | Both modes cover **every** sheet section: planned/order quantities, material requirements, lot usage, waste, labor. |
| B4 | Small / ordinary decimals stay exact in default mode (no forced scientific). |
| B5 | Settings UI: default unchecked; saving true persists and reloads checked; saving false persists and reloads unchecked. |
| B6 | Stored quantities and configured units are unchanged (only the printed form differs). |

Upstream tests cover B1–B5. B6 needs a preservation witness (read back the stored Decimal / unit after building a sheet).

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** format only `planned_qty` and leave lots/labor in `:scientific` — B3 fails.

**Second incomplete:** default is scientific and the setting turns it off (inverted policy) — B1 fails.

**Third incomplete:** settings column and form exist, but `BatchSheet.build_data` ignores the flag — B2/B5 partial fail (UI saves, sheet unchanged).

**Integrity:** standard `System.halt(0)` early-exit; require executed `batch_sheet_test` + settings interaction test.

---

## 6. Preservation

- Configured units and stored stock/quantity values unchanged (B6).
- Other settings fields still save.
- Existing batch-sheet PDF/export path still runs (formatting only).
- Mixed population: 10000, 60, 0.5, 1.25, missing/zero quantities in both modes.

---

## 7. Runtime / offline holds

Same class as other craftplan cases:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; SQL Sandbox. |
| Ash 3 stack | Cache `mix.lock` offline; native bcrypt/picosat. |
| External services | None for these tests. |
| Browser | Not required; LiveViewTest only. |

**Not verified:** compilation, green base suite, offline deps, or `git apply` of `pull/52.diff` onto `ad9fb484…` (do this before freezing). Snapshot JSON is generated.

---

## 8. Status / next action

**Status:** screened — **reserved** candidate (explicitly allowed by the second-pass skip note; not filed in `more-candidates/`). Focused 3-file settings↔production contract with a strong incomplete matrix. Use as the small Ash/Postgres proving case before #43 or #55.

**Next action:** prove `pull/52.diff` applies on `ad9fb484…` (standalone) **or** decide the combined-with-#51 freeze explicitly; pin base; map B1–B6; incomplete = section-partial / inverted default / UI-only. AGPL-3.0. Do not mix with #51/#53 tickets.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Printable production batch sheets print large quantities in scientific notation (`1E+4` instead of `10000`), which shop floors cannot use. Print ordinary non-exponent decimals by default on every quantity the sheet shows. Let an administrator turn scientific notation back on in General Settings; the preference must apply uniformly to every quantity on the sheet. Stored quantities and configured units must not change. Fix it.

Clarified brief. Product decisions stated: default is ordinary decimals, admin opt-in setting, uniform across the sheet, stored data untouched. Does not name `batch_sheet_scientific_notation`, `format_decimal`, or files.

**Hidden requirements flagged:**
- Draft ticket enumerated the sections ("planned/order quantities, material requirements, lot usage, waste, and labor") — that is close to naming the fix surface. "every quantity the sheet shows" is enough and leaves discovery open; keep the enumeration in curator checks only.
- Exact rendering of "ordinary decimals": reference uses `Decimal.normalize/1` + `D.to_string(..., :normal)`, so `1000`, `0.001`, `0.000001`. A solver emitting `"1000.0"` or trimming differently is plausible. Either state "no exponent notation; plain decimal digits" and grade with a regex, or freeze the Decimal semantics in the ticket (worse). Prefer regex: `^[0-9]+(\.[0-9]+)?$` in default mode and presence of `E` in scientific mode.
- Setting default is **false** (ordinary). Stated — good. Inverted default is a named incomplete.

### 2. Deterministic checks

ExUnit + Ash + LiveViewTest. Pure batch-sheet data builder + settings form. No PDF binary comparison.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `sheet default-ordinary-decimals` | Settings flag false (or unset); sheet with quantities 10000 / 60 / 0.5 / 0.000001 | `BatchSheet.build_data` maps | no exponent form (`E`/`e`) in any quantity field; large/small values render as plain decimals |
| `sheet scientific-when-enabled` | Flag true | same | the same values use exponent form (e.g. `1E+4`) |
| `sheet uniform-across-sections` | Flag true; sheet populated with planned qty, order qty, component qty/waste, lot usage, labor duration/units | every quantity field | every section flips together (not just planned qty) |
| `settings default-unchecked-persists` | Fresh settings | LiveView form | checkbox unchecked by default; save true → persists and reloads checked; save false → persists and reloads unchecked |
| `storage-unchanged` | Build sheet after both modes | repo read-back | stored Decimal quantities and units identical (preservation) |
| `other-settings-preserved` | Existing settings fields | form save | other settings still save (preservation) |

Fake provider: none. PostgreSQL.

### 3. Ambiguity / unfairness

- Exact strings (`"1E+3"` vs `"1.0E+3"` vs `"1e+3"`) — **do not** grade Decimal's exact scientific spelling. Grade "contains exponent marker" vs "contains none", or accept a small set of spellings. The upstream tests pin `"1E+3"` / `"1E+6"` — overfit if used as hidden checks as-is.
- `0.000001` staying non-scientific in **both** modes is reference behaviour (Decimal `:scientific` does not kick in at that scale). Ticket says "scientific notation when applicable" in the docs patch — do not require scientific for tiny values; say "when the formatter would use an exponent" or grade only the large values for the on-mode.
- Whether the setting is a global Settings row vs per-org is forced by the existing Settings resource — fine.
- Docs file (`docs/src/pages/docs/settings.md`) is mechanical — out of the graded contract.

### 4. Shortcuts

- Format only `planned_qty`; lots/labor stay scientific. Fails `sheet uniform-across-sections`. Planned incomplete.
- Invert default (scientific, setting turns it off). Fails `sheet default-ordinary-decimals`.
- Settings column + form exist; `build_data` ignores the flag. Fails `sheet scientific-when-enabled`.
- Hardcode `"10000"` string maps in tests only (cheating via test-side fixtures) — not a solver shortcut; integrity covers `System.halt(0)` early-exit and requires executed named results.
- Always print scientific regardless of flag. Fails default-mode check.

### 5. Flakiness / nondeterminism

Low. Decimal formatting is deterministic. LiveView settings form is synchronous. No clocks/jobs. Keep PDF export out of graded checks (binary/layout noise).

### 6. Coverage mix

- Positive: default ordinary on large values; scientific when enabled; settings round-trip both booleans.
- Negative / uniformity: every section flips together.
- Preservation: stored quantities/units; other settings fields; mixed numeric population (10000, 60, 0.5, 1.25, 0.000001, zero/missing) in **both** modes in one test.

### 7. Environment risk

- **AGPL-3.0.** PostgreSQL. Ash 3 stack + native bcrypt/picosat — same unproven fixture risk as craftplan-1. Use this as the **smaller proving case** before #43.
- Snapshot JSON generated — keep out of graded diffs.
- **Lineage freeze:** squash parent is already-filed #51's squash; PR opened from #46. Reconstructing `pull/52.diff` onto `ad9fb484…` may conflict if #51 touched the same files. Decide standalone vs combined-with-#51 **before** building the bundle; do not silently stack #51's solution into this ticket.

### 8. Verdict

**READY-WITH-FIX** — tight settings↔production contract and a strong incomplete matrix; exact-string overfit and the #51 freeze must be resolved first.

### 9. Must-fix list

1. Grade ordinary vs scientific via regex / exponent-presence, not exact Decimal strings (or accept a spelling set).
2. Drop the section enumeration from the ticket; keep it in checks only.
3. Decide standalone `ad9fb484…` vs combined-with-#51 freeze; verify `pull/52.diff` applies.
4. Incomplete controls: section-partial; inverted default; UI-only flag ignored by renderer.
5. Prove Ash/PG fixture (companion to #43).

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Exact-string overfit + #51 lineage freeze ambiguity |
