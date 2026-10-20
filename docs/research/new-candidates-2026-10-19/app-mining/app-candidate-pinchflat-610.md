# Pinchflat #610 — Persist and display download errors on media items

**Status:** discovered  
**Source type:** historical PR (FR #602)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#610](https://github.com/kieraneglin/pinchflat/pull/610)  
**Source revisions:** base `fe5c00dbeff0adcc3f35ec9639c47a8f8b3338c4` → merge `e7adc9d68f40ad75819e00e26542fb3b6b24e0d1`  
**Author:** kieraneglin · **Merged:** 2025-02-12  
**Task kind / family:** bounded feature / failure state + UI surfaces  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Why it is a good case

Users cannot see *why* a download failed (FR #602). The feature adds durable `last_error` on media items, writes it on failure, clears it on success/recovery, and surfaces it on media show, source tables, and history — with a tooltip component. Cross-component: download pipeline → schema/migration → LiveView tables/pages. Clear positive preservation (successful downloads leave `last_error` nil) and negative checks (error string stored/shown).

## Implementation file roles

| File | Role |
| --- | --- |
| `priv/repo/migrations/20250210201413_add_last_error_to_media_item.exs` | Add `last_error` string. |
| `lib/pinchflat/media/media_item.ex` | Schema field + allowed fields. |
| `lib/pinchflat/downloading/media_downloader.ex` | Set `last_error` on error paths; clear on success; wrap non-binary messages. |
| `lib/pinchflat/downloading/media_download_worker.ex` | Align worker error handling with persisted error (retry vs non-retry still separate). |
| `lib/pinchflat/utils/string_utils.ex` | `wrap_string/1` for inspect vs binary. |
| `lib/pinchflat_web/components/custom_components/text_components.ex` | Tooltip component (+ button component tweak). |
| `lib/pinchflat_web/controllers/media_items/media_item_html/show.html.heex` | Show last_error section. |
| `lib/pinchflat_web/controllers/pages/page_html/history_table_live.ex` | Tooltip on failed rows. |
| `lib/pinchflat_web/controllers/sources/source_html/media_item_table_live.ex` | Tooltip + preloads/select include `:last_error`. |
| `lib/pinchflat_web/controllers/sources/source_html/show.html.heex` + media_profile show | UI wiring. |

Tests: `media_downloader_test.exs`, `string_utils_test.exs`. `erd.png` generated.

**Counts:** ~8–10 implementation paths (worker/downloader/schema/migration/utils/UI); several UI files are thin wiring. Tests separate.

## Cross-component behavior to verify

- Download failure (recoverable or not) stores a readable error on the media item.
- Successful download clears a previous error.
- UI shows the error on media detail and in source/history tables without crashing when nil.
- Non-binary error terms are stringified consistently.

## Draft ticket (clarified implementation brief)

> When a download fails I cannot tell why. Save the failure reason on the media item and show it in the app: on the media item page and in the source and history tables. Clear the saved reason when a later download succeeds. Successful items must not show a stale error. Keep existing retry/recover behavior.

## Proposed named acceptance checks

1. `downloader stores-last-error-on-failure` — failed download ⇒ `media_item.last_error` contains message.
2. `downloader clears-last-error-on-success` — fixture with old error; success ⇒ `last_error == nil`.
3. `downloader stores-recovered-and-unrecoverable` — both paths set non-nil error strings.
4. `media-show renders-last-error` — LiveView/html contains error text when present, omits section when nil.
5. `tables include-last-error` — query/preload supports tooltip data (can be structural).
6. **Preservation:** successful download still updates metadata/filepath as before.

## Plausible incomplete + integrity control

- **Incomplete:** persist `last_error` but never render it (UI checks fail); or render only on media show and not tables.
- **Integrity:** reject patches that set `last_error` on success, or that block download completion because of the field.

## Preservation

Existing downloader tests for success/metadata updates.

## Runtime / offline holds

- yt-dlp mocked; no YouTube.
- SQLite migration — verify.
- Tooltip/LiveView UI checks may need HTML assertions (`Floki` is a test dep — good).

## Status: discovered

Strong feature spanning persistence + several UI surfaces.

## Next action

Draft after Pinchflat runtime (SQLite/Oban) is confirmed. Prefer UI checks at LiveView/HTML level rather than pixel tests.
