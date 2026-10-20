# Phoenix.LiveDashboard #487 — Nested list view of application processes

**Status:** discovered  
**Source type:** historical PR  
**Project:** [phoenixframework/phoenix_live_dashboard](https://github.com/phoenixframework/phoenix_live_dashboard)  
**PR:** [#487](https://github.com/phoenixframework/phoenix_live_dashboard/pull/487)  
**Source revisions:** base `4468d1344412c81aacb89a39684296856c87cffc` → merge `ae6ed8927cb2fa73bff07943ca2261e357b6b3e5`  
**Author:** nathanl · **Merged:** 2026-05-07  
**Task kind / family:** feature / observability UI  
**Research date:** 2026-10-19

## Authentic work

Adds a compact nested list of an application’s processes with expand/collapse and search. User-visible LiveDashboard capability (screen recording in PR). Implementation is concentrated in the app-info LiveView component plus CSS; tests on the applications page.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/phoenix/live_dashboard/info/app_info_component.ex` | Nested process tree UI behavior |
| `assets/css/app/components/_app_info.scss` | Presentation (count separately from logic) |
| `test/phoenix/live_dashboard/pages/applications_page_test.exs` | Page-level checks |
| `CHANGELOG.md` | Docs |

**Counts:** 1 substantive Elixir implementation file + 1 stylesheet + 1 test file. Logic is one file; CSS is presentation.

## Cross-component behavior to verify

- Process tree reflects actual supervision/application structure (not a flat dump).
- Expand/collapse and search filter the visible set without losing tree relationships.
- Existing applications page behavior preserved (other app info sections).
- Works with LiveView assigns/socket already used by the page.

## Draft ticket (feature brief)

> On an application’s info page, I want a nested view of that application’s processes that I can expand/collapse and search. Keep the rest of the applications page working.

## Acceptance design (proposed, unexecuted)

- LiveView test (or component test) with a known process hierarchy: assert nested rendering, toggle, search.
- Assert unrelated application info still renders.
- Avoid brittle exact HTML snapshots; prefer presence/absence of process names/relationships.

## Plausible incomplete (proposed)

Implement nested rendering but search flattens/loses parents; or expand/collapse only toggles CSS without updating visible set.

## Integrity control (proposed)

Reject a static hardcoded tree or a list that ignores the actual application’s processes.

## Runtime / offline

- LiveDashboard’s own tests use Phoenix LiveView test helpers — no browser binary required if acceptance stays at LiveView test level.
- If a **browser** case is desired (`runtime.browser: true`), that is a separate, heavier contract (pinned Chromium). Prefer ExUnit LiveView tests first.
- No DB.

## License / provenance

- MIT (Crumm / McCord / Valim). Public PR with demo video.

## Holds / unknowns

- One logic file + CSS: do not inflate implementation count with the stylesheet unless the brief requires the visual layout.
- Search/expand semantics need a short brief clause if hidden tests check exact filter rules.
- Sibling PRs (#495 crash fix, #491 custom info module) are different tasks; #495 is a 1-line fix — not used as this case.

## Coverage added

LiveDashboard / observability UI — product surface different from Livebook/Plausible apps already in inventory.

## Next action

Keep as UI reserve. If only one LiveDashboard case is wanted, this is the strongest user-visible feature in this pass; grade at LiveView test boundary first.
