# Large feature — Mydia #1119 per-show TV metadata provider fallback

**Status:** discovered
**Source type:** historical merged PR (closes issue #1117)
**Project:** [getmydia/mydia](https://github.com/getmydia/mydia) — personal media companion
**PR:** [#1119](https://github.com/getmydia/mydia/pull/1119) — feat: fall back to the other TV metadata provider (TVDB/TMDB) per show
**Issue:** [#1117](https://github.com/getmydia/mydia/issues/1117) — Fallback metadata providers for TV shows (TMDB / IMDb)
**Author:** arsfeld · **Created:** 2026-10-12 · **Merged/closed:** 2026-10-12
**Source revisions:** base (merge first parent) `071360c6c765b4db02337943dd8d9ba6eee47bd6` → merge `890223727f0701eef9a6ad006e88e30f417fdfa6` (head `8057d437da8dc2f15ebb7a320b9944a9c9dd7897`, 14 commits)
**Task kind / family:** bounded feature / multi-provider metadata matching + pin policy + import/fix-match UI
**Research date:** 2026-10-19
**License:** AGPL-3.0 (GNU Affero GPL v3 at base)

---

## Why it is a LIMIT-TESTING case

This is the strongest large-feature candidate in this pass. A single user-facing capability — “a TV show missing from the library’s metadata provider should still match via the other provider, and stay on that provider” — forces a **policy rule that must stay consistent across five subsystems**:

1. **Per-show pin state** (`media_items.metadata_source_pinned`) and who sets/clears it (`ProviderSwitch.pin_for/2`).
2. **Importer fallback** (`MetadataMatcher`): search the other provider only on empty results, never on relay errors; hold cross-provider unattended matches for review; still auto-import new episodes of an already-pinned local show.
3. **Refresh/re-identify decision**: pinned shows refetch their own provider; unpinned shows re-identify against the library provider.
4. **Fix Match**: default search provider is the show’s stored provider, not the library’s; switching providers goes through the existing episode-safe switch.
5. **Import “Change match” and Fix Match modals**: TVDB/TMDB toggle only for TV searches; non-library results carry a badge; a fileless show has no library provider so a Fix Match switch does not pin.

A solver who implements only the fallback search, or only the pin boolean, or only one of the two modals, will compile and still fail named checks in another subsystem. That is exactly the coordinated multi-file work the guidelines want. The upstream PR body states the product decisions (fallback only on empty; no IMDb; unattended cross-provider held for review; fileless shows do not pin), so the ticket can stay short without hiding policy in hidden tests.

## File inventory with roles

Counts below are from `pull/1119.diff`. Tests are listed separately; `lib/mydia/media/README.md` is documentation of the domain rules (useful source evidence, not implementation).

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/mydia/media/media_item.ex` | Schema field `metadata_source_pinned` (boolean, default false). |
| `priv/repo/migrations/20261011231535_add_metadata_source_pinned_to_media_items.exs` | Plain boolean add; up/down for both SQLite adapters. |
| `lib/mydia/media/provider_switch.ex` | `pin_for/2` (pin when show lives on the non-library provider), `library_provider/1`, `provider_refresh_decision/…` (refetch vs re-identify). |
| `lib/mydia/media/fix_match.ex` | Fix Match search/adopt: `provider_for/2` defaults to stored provider for pinned shows; `search/6`, `adopt/6` honour provider override. |
| `lib/mydia/library/metadata_matcher.ex` | Importer matching; **fallback to the other provider on empty primary result**; no fallback on relay error. |
| `lib/mydia/library/candidate_promotion.ex` | Promotion stamps the pin when it creates a show on the non-library provider. |
| `lib/mydia/library/match_scoring.ex` | Shared scoring helpers (title/year/popularity) used by both providers. |
| `lib/mydia/library/file_ingest.ex` | Ingest path that feeds matching (provider-aware). |
| `lib/mydia/metadata/tv_provider.ex` | Provider parse/label/`other/1`/`for_library` helpers. |
| `lib/mydia_web/live/import_media_live/match_search.ex` | Import “Change match” search state: provider toggle, async search. |
| `lib/mydia_web/live/import_media_live/match_search_modal.ex` | Modal UI: TVDB/TMDB toggle (TV only), badges for non-library results. |
| `lib/mydia_web/live/import_media_live/components.ex` + `index.ex` + `index.html.heex` | Import surface wiring for fallback group warning / toggle. |
| `lib/mydia_web/live/media_live/show.ex` + `show.html.heex` + `show/fix_match_events.ex` + `show/fix_match_modal.ex` + `show/modals.ex` | Fix Match surface: pinned-provider badge, provider toggle, episode-safe switch. |

**Counts:** ~12–15 substantive implementation paths (schema+migration, pin policy, matcher/fallback, promotion, provider helpers, two LiveView families). Several UI files are thin wiring of the same policy — not “ten copies of a string”, but one rule expressed at each boundary.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/mydia/library/metadata_matcher_fallback_test.exs` | Empty primary → other provider; **relay error does not fallback**; both empty → no match; no provider → no fallback. |
| `test/mydia/media/provider_pin_test.exs` | Pin on create/switch to non-library provider; clear when switched back; unpinned re-identified; pinned re-fetched in place. |
| `test/mydia/media/fix_match_test.exs` | Pinned show searches its own provider; unpinned searches library provider; switch pins / un-pins; movies ignore provider override. |
| `test/mydia/library/candidate_promotion_test.exs` | Cross-provider confident match stays candidate (held for review); local-show match exempt; promotion stamps pin. |
| `test/mydia_web/live/import_media_provider_toggle_test.exs` | Toggle present for TV only; picking TMDB result stamps TMDB; non-library result dropped when tagged wrong. |
| `test/mydia_web/live/media_live/fix_match_test.exs` + `show/fix_match_events_test.exs` | Fix Match toggle/pin UI contract. |
| `test/mydia/library/batch_matcher_test.exs`, `file_ingest_test.exs` | Supporting matcher/ingest behaviour. |
| `test/support/metadata_stub_provider.ex` | **Offline stub provider** — no live TVDB/TMDB required. |

### Generated / docs

| Path | Note |
| --- | --- |
| `lib/mydia/media/README.md` | Domain rules documentation (useful visible source for the brief; not graded as implementation). |

## Draft clarified feature brief

> A TV show that one metadata provider does not carry should still be matchable when the other provider has it. When the library’s provider returns no match for a show, search the other provider once and use that result. A relay/availability error on the first provider must not trigger the fallback. Once a show lives on the provider its library does not use, keep it on that provider for refresh and Fix Match; switching it back to the library’s provider clears that pin. Under unattended import, a cross-provider TV match is held for review (except new episodes of an already-stored show). Expose a TVDB/TMDB toggle in the import “Change match” and Fix Match UIs for TV searches only. Movies and IMDb are out of scope. Keep existing same-provider matching and unattended import working.

Public names that **are** the product (keep visible): TVDB/TMDB labels, the idea of a per-show pinned provider. Do **not** name `metadata_source_pinned`, `ProviderSwitch`, `pin_for/2`, or file paths in the solver ticket.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Fallback-on-empty:** primary provider returns no TV match, secondary has one → import/match uses the secondary result. |
| A2 | **No-fallback-on-error:** primary relay error → error surfaces; secondary is **not** searched (outage cannot re-match a library). |
| A3 | **Pin stamp:** show created/switched onto the non-library provider is pinned; switching back to the library provider clears the pin. |
| A4 | **Refresh honours pin:** pinned show refetches its own provider (no re-identify); unpinned show re-identifies against the library provider. |
| A5 | **Fix Match provider default:** pinned show searches its stored provider; unpinned searches the library provider. |
| A6 | **Unattended guard:** cross-provider TV match is held for review regardless of confidence; a match against an existing local show is **not** held. |
| A7 | **UI toggles:** import Change-match and Fix Match show a TVDB/TMDB toggle for TV only; picking a non-library result goes through the episode-safe switch and pins; fileless show’s Fix Match switch does not pin. |
| A8 | **Preservation:** same-provider matches still import unattended; library-wide provider migration still moves **unpinned** shows; movies unchanged. |

## Incomplete control

**Compiling partial that misses one subsystem:** implement the importer fallback + pin field + migration, but leave `provider_refresh_decision` still re-identifying every show (or leave Fix Match always searching the library provider).

- A1 may pass; **A4/A5** fail (pinned show is re-identified / searched on the wrong provider).
- A second partial: implement fallback but always fallback even on relay errors → **A2** fails.

## Integrity / shortcut rejection

Reject patches that:

- Fall back on **any** primary failure (including relay/timeout errors) — that is the outage re-match bug the issue cares about.
- Set the pin for movies, or for shows already on the library provider.
- Drop the unattended-review guard for cross-provider matches (auto-import a foreign-provider show).
- Disable Fix Match or Change-match entirely as a way to avoid the toggle contract.
- Hard-code “TMDB only” or “TVDB only” instead of honouring library provider.

## Preservation of existing behavior

- Same-provider TV matching, scoring (`match_scoring.ex`), and unattended import of ordinary matches.
- Movie matching and import (no provider toggle, no pin).
- Library-wide provider change migrates unpinned shows as before.
- Existing Fix Match episode-safety when switching providers.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| PostgreSQL **or** SQLite | Mydia stack from shortlist is Ecto + SQLite (`ecto_sqlite3`); migration is a plain boolean add — verify test sandbox applies it on both adapters if dual-DB is in play. |
| No live TVDB/TMDB | **Already solved in-tree:** `test/support/metadata_stub_provider.ex` + Bypass-style tests in `metadata_matcher_fallback_test.exs` (“bypass” in test names). Offline holds look favorable. |
| LiveView tests | Standard Phoenix LiveViewTest; no browser required for A1–A8. |
| Oban / Guardian | Present in app; matching/UI tests should not need live workers if jobs are invoked directly. |
| Elixir `~> 1.20` | Pin toolchain accordingly. |
| AGPL-3.0 | Record notice in provenance. |

Not verified in this pass: compilation, test execution, offline dependency fetch, or runtime boot.

## Status: discovered

Best large-feature candidate this pass. Ready for draft ticket freeze and qualification once the Mydia runtime (Elixir 1.20 + SQLite + deps) is prepared.

## Next action

1. Pin base `071360c6c765b4db02337943dd8d9ba6eee47bd6`; confirm `mix test` at that revision with the stub provider and no network.
2. Freeze the brief above (keep product policies visible; no internal names).
3. Build unchanged / reference / incomplete (refresh-pin miss) / integrity (fallback-on-error) controls; run three qualification rounds.
4. Independent contract review focusing on A2 (error vs empty) and A6 (unattended guard) — those are the easiest to get unfair.
