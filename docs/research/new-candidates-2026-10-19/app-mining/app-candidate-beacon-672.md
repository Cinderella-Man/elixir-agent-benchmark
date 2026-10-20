# app-candidate-beacon-672

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/BeaconCMS/beacon/pull/672 |
| Title | Page warming |
| Project | BeaconCMS/beacon |
| Source type | Historical merged PR (bounded feature; resolves #666) |
| PR head SHA | `6aa3f6da7fc354a0a23123adf6ced5be679aa219` (last of 3 commits) |
| First commit | `68bae7f2993b98b772f1a459bfde7385a2c7f194` |
| Parent of first commit (likely base) | `f0413a0861c17b54abfd11100a6279fc5cfff40a` |
| Merged at | 2024-11-27T00:23:06Z |
| License | MIT (DockYard, Inc.) |
| Elixir | `~> 1.14` |
| Verification | **Unverified** — diff inspected; tests not executed |

## Why it is a case

On Beacon boot, optionally warm published pages so the first visitor does not pay full compile/render cost. Configured via `Beacon.Config :page_warming` with `{:shortest_paths, n}`, `{:specific_paths, list}`, or `:none`. Must only warm published pages and must not break boot when warming is disabled.

What must stay consistent:

- Config option validation/defaults vs. `Beacon.Boot` behavior.
- `Content.list_published_pages_for_paths/2` (and shortest-path ordering) vs. what warming requests.
- Boot stays async (Task) so startup is not blocked by warming.
- Unpublished pages in a specific-path list are skipped.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/beacon/config.ex` | `:page_warming` option, defaults, validation |
| `lib/beacon/boot.ex` | Live-mode boot triggers warming (async Task) |
| `lib/beacon/content.ex` | `list_published_pages_for_paths/2` and path-length sort support |

Tests (separate): `test/beacon/content_test.exs` (`list_published_pages sort by path length`, `list_published_pages_for_paths/2`).

## Draft ticket

> First hits on Beacon pages are slow because pages are not warmed at boot. Add optional page warming on startup: warm the n shortest published paths, or a configured list of paths (skip unpublished), or disable it entirely. Keep startup from blocking on the warmup.

## Named acceptance checks

1. **shortest-paths-selects-n** — with `{:shortest_paths, 3}`, exactly three published pages with the shortest paths are warmed (or listed for warming).
2. **specific-paths-skips-unpublished** — configured paths warm only published pages.
3. **none-disables** — `:none` (default) performs no warming and boot succeeds.
4. **boot-async** — warming runs without blocking `Beacon.Boot.init` completion (Task/supervision evidence).
5. **preservation** — existing page listing/publish APIs still return published pages as before.

## Incomplete + integrity control

- **Incomplete:** implement `{:shortest_paths, n}` and `:none` but ignore `{:specific_paths, list}` (or warm unpublished too). Fail **specific-paths-skips-unpublished**.
- **Integrity:** unchanged tree fails warming selection checks; reference passes. **none-disables** + **preservation** block “warm everything always.”

## Preservation

- Sites with `:page_warming` unset keep prior boot behavior.
- Content APIs used by the editor/visual editor unchanged.

## Runtime / offline holds

- PostgreSQL content fixtures only — offline feasible.
- No CDN/network required if warming is exercised through `Content` + Boot tests rather than real HTTP.
- CHANGELOG.md touch is documentation — not counted as implementation.

## Status

**discovered** — clear product brief from upstream, 3 implementation files, query + config + boot relationship is testable offline.

## Next action

Confirm Boot/Task synchronization strategy for **boot-async**; add named config tests if upstream only covers `Content`.
