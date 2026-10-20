# TeslaMate #5827 — Label unnamed cars by VIN consistently across pages

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#5827](https://github.com/teslamate-org/teslamate/pull/5827)  
**Source revisions:** base `1b9f95c3439059caedfeb71f74a8a63d38ed7a68` → merge `0468646db74ddb6312c3ba2de689abc3d15dfb15`  
**Author:** JakobLichterfeld · **Merged:** 2026-10-03  
**Task kind / family:** bug_fix (presentation consistency) / LiveView car labeling  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Why it is a good case

Unlabeled cars (no display name) must be titled by VIN everywhere, matching the car summary behavior that already exists. The work extracts a shared `CarTitle` helper and rewires several LiveViews/templates so summary, charge cost, settings, and the vehicle-reload hint agree. Cross-component: one formatting rule, multiple UI surfaces + gettext strings + tests. It is not “typos” — it is a product consistency defect users hit when several nameless cars exist.

## Implementation file roles

| File | Role |
| --- | --- |
| `elixir/lib/teslamate_web/live/car_title.ex` | **New** shared helper: `format/2` returns `{title, vin_label}`; unnamed car → full VIN as title/label; named car → name + short VIN suffix. `title/1` for `%Car{}`. |
| `elixir/lib/teslamate_web/live/car_live/summary.ex` | Remove local `format_car_title/2`; use `CarTitle`. |
| `elixir/lib/teslamate_web/live/car_live/summary.html.heex` | Call `CarTitle.format/2` for display. |
| `elixir/lib/teslamate_web/live/charge_live/cost.ex` + `cost.html.heex` | Use shared labeling on charge cost page. |
| `elixir/lib/teslamate_web/live/settings_live/index.ex` + `index.html.heex` | Use shared labeling in settings car list/order. |
| `elixir/lib/teslamate_web/live/vehicle_reload.ex` | Use shared labeling in reload hint text. |

Tests: `test/teslamate_web/live/charge_cost_live_test.exs`, `test/teslamate_web/live/vehicle_reload_test.exs` (and any summary settings tests adjusted). Gettext `.po` updates are mechanical.

**Counts:** 4+ substantive implementation paths (helper + summary, charge cost, settings, vehicle_reload); templates count as implementation. Tests separate.

## Cross-component behavior to verify

- Nameless car: title is the VIN on summary, charge cost, settings, reload hint.
- Named car: name is shown; VIN label is the last six characters (short form) next to it.
- Moving formatting into `CarTitle` must not change the already-correct summary behavior (positive preservation).

## Draft ticket (shortest sufficient)

> When a car has no name, some pages still show an empty label or a different placeholder instead of the VIN. The car summary already labels nameless cars by VIN; make the charge cost page, settings, and the vehicle reload hint use the same rule. Keep named cars showing their name plus the short VIN label. Fix it.

## Proposed named acceptance checks

1. `car-title unnamed-full-vin` — `CarTitle.format(nil, vin)` / live pages show full VIN as title.
2. `car-title named-short-vin-label` — named car keeps name and six-character VIN label.
3. `charge-cost-page labels-unnamed-car` — LiveView test for charge cost with nameless car.
4. `vehicle-reload-hint labels-unnamed-car` — reload hint text uses same helper output.
5. **Preservation:** summary page rendering for a named car remains unchanged.

## Plausible incomplete + integrity control

- **Incomplete:** extract `CarTitle` and fix summary only; charge cost/settings still empty (checks 3–4 fail).
- **Integrity:** reject patches that show the full VIN for named cars too, or that drop the VIN label entirely.

## Preservation

Existing summary and settings LiveView tests.

## Runtime / offline holds

- LiveView tests only; no Tesla API.
- Gettext message churn is noise — count separately.

## Status: discovered

Multi-file UI consistency candidate (Phoenix LiveView coverage). Weaker “deep investigation” than geofence/auth cases; good for corpus family diversity.

## Next action

Take after geofence/auth if LiveView presentation coverage is wanted. Ticket must include the named-car short-VIN rule so the outcome is not under-specified.
