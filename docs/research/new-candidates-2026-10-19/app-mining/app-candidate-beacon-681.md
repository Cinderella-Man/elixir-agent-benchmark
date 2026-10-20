# app-candidate-beacon-681

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/BeaconCMS/beacon/pull/681 |
| Title | fix: page variant flashing |
| Project | BeaconCMS/beacon |
| Source type | Historical merged PR (bug fix; resolves issue #327) |
| PR head SHA | `775d8f21ff8850ad84222b0230141c2e7508f84d` (last of 5 commits) |
| First commit | `a570b449a7286f1db9df9d9c072179395bc1c587` |
| Parent of first commit (likely base) | `45c7b1938440907c3e94c1999d1401387670221f` |
| Merged at | 2024-12-03T23:40:23Z |
| License | MIT (DockYard, Inc.) — `LICENSE.md` |
| Elixir | `~> 1.14` (mix.exs `@version "0.2.2"` at head) |
| Verification | **Unverified** — issue/diff inspected; tests not executed |

## Why it is a case

Page variants (A/B templates) re-rolled between the dead render and the LiveView live mount, so refresh flashed different templates. Once a template/variant is chosen for a request, dead and live renders must use the same choice.

What must stay consistent:

- Variant roll is chosen once per request/session and reused by dead render (`Beacon.Plug`), template choice (`Beacon.Template.choose_template`), and live mount (`BeaconAssigns` / `PageLive`).
- Load vs render metadata modules (`Beacon.Template.LoadMetadata` / `RenderMetadata`) agree on which template/variant metadata is applied at each stage.
- `BeaconAssigns.new` signatures keep working for published pages, path info, and query params (existing tests).

## Implementation roles

| File | Role |
| --- | --- |
| `lib/beacon/template.ex` | Template/variant selection API (`choose_template`, metadata entry points) |
| `lib/beacon/template/load_metadata.ex` | **New** — metadata used when loading a page |
| `lib/beacon/template/render_metadata.ex` | **New** — metadata used when rendering |
| `lib/beacon/plug.ex` | **New** — puts `:beacon_variant_roll` in session |
| `lib/beacon/web/beacon_assigns.ex` | Build assigns including `variant_roll` |
| `lib/beacon/web/live/page_live.ex` | Live mount reuses the same roll |
| `lib/beacon/loader/page.ex` | Page load integration (supporting) |

Tests (separate): `test/beacon_web/beacon_assigns_test.exs` (adjusted; few new named cases).

## Draft ticket

> Refreshing a Beacon page that has variants can flash different template elements because the dead render and the live render pick different variants. Once a variant is chosen for a request it must stay the same for that page load. Fix it.

## Named acceptance checks

*(Curator must add these; upstream PR tests are thin.)*

1. **same-variant-dead-live** — given a page with two variants, the template chosen in the dead render equals the template used on the subsequent live mount for the same session/roll.
2. **roll-stable** — variant roll is not re-randomized between load metadata and render metadata for one request.
3. **assigns-preservation** — existing `BeaconAssigns` build cases (published page title, path info + query params, path params) still pass.
4. **multi-variant-choice** — `choose_template/2` still picks among N variants and falls back to primary when roll is absent.

## Incomplete + integrity control

- **Incomplete:** thread `variant_roll` into `BeaconAssigns` but leave `PageLive` (or `Beacon.Plug`) still picking a fresh random roll. Fail **same-variant-dead-live**.
- **Integrity:** unchanged tree fails **same-variant-dead-live** (flash); reference passes. **assigns-preservation** blocks solutions that break normal page builds.

## Preservation

- Pages without variants render as before.
- LiveData / SEO / other assigns unchanged.
- Session plug must not break non-Beacon endpoints (opt-in via router).

## Runtime / offline holds

- PostgreSQL for content; no cloud media needed if fixtures use local templates.
- HTML/FLash behavior needs controller/LiveView tests — runner browser contract **not** required if checks assert template identity rather than visual flash.
- `dev.exs` change is demo-only.

## Status

**discovered** — excellent cross-component consistency (plug → template metadata → assigns → LiveView). Upstream tests under-specify the bug; acceptance checks above must be authored.

## Next action

Author **same-variant-dead-live** as a Phoenix/LiveView test at base `45c7b193...`; run reference/unchanged to prove discrimination before freeze.
