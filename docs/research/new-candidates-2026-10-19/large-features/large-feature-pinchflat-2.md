# Large feature — Pinchflat #610 persist and display download errors on media items

**Status:** discovered
**Source type:** historical merged PR (feature request #602)
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat) — YouTube media manager
**PR:** [#610](https://github.com/kieraneglin/pinchflat/pull/610)
**Author:** kieraneglin · **Merged:** 2025-02-12
**Source revisions:** base (merge first parent) `fe5c00dbeff0adcc3f35ec9639c47a8f8b3338c4` → merge `e7adc9d68f40ad75819e00e26542fb3b6b24e0d1`
**Task kind / family:** bounded feature / failure state persistence + multi-surface UI
**Research date:** 2026-10-19
**License:** AGPL-3.0

---

## Why it is a LIMIT-TESTING case

Users cannot tell *why* a download failed (FR #602). The feature adds durable `last_error` on media items, writes it on failure, clears it on success, and surfaces it on the media show page **and** in the source and history tables (with a tooltip). The limit-testing work is **pipeline state ↔ persistence ↔ several read surfaces**:

1. Download pipeline (including non-binary error terms) must stringify and store a readable reason.
2. Worker error handling must stay aligned with retry vs non-retry behaviour (not swallowed by the new field).
3. Successful download must **clear** a previous error (no stale red text).
4. Three UI surfaces (media show, source media table, history table) must render the error when present and **not crash / not show a section** when nil.
5. Table queries/preloads must actually select `:last_error` or the tooltip is empty.

A partial that persists the error but never renders it, or renders only on media show, is a plausible incomplete. File count (~8–10) reflects persistence + utils + a tooltip component + three surfaces — not mechanical copies.

## File inventory with roles

From `pull/610.diff` (15 paths; `erd.png` generated — ignore).

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `priv/repo/migrations/20250210201413_add_last_error_to_media_item.exs` | Add `last_error` string. |
| `lib/pinchflat/media/media_item.ex` | Schema field + allowed fields. |
| `lib/pinchflat/downloading/media_downloader.ex` | Set `last_error` on error paths; clear on success; wrap non-binary messages. |
| `lib/pinchflat/downloading/media_download_worker.ex` | Align worker error handling with persisted error (retry vs non-retry unchanged). |
| `lib/pinchflat/utils/string_utils.ex` | `wrap_string/1` for inspect vs binary. |
| `lib/pinchflat_web/components/custom_components/text_components.ex` | Tooltip component (+ button component tweak). |
| `lib/pinchflat_web/controllers/media_items/media_item_html/show.html.heex` | Show last_error section. |
| `lib/pinchflat_web/controllers/pages/page_html/history_table_live.ex` | Tooltip on failed rows. |
| `lib/pinchflat_web/controllers/sources/source_html/media_item_table_live.ex` | Tooltip + preloads/select include `:last_error`. |
| `lib/pinchflat_web/controllers/sources/source_html/show.html.heex` (+ media profile show) | UI wiring. |

**Counts:** ~8–10 implementation paths (worker/downloader/schema/migration/utils/UI). Several UI files are thin wiring of the same field. Tests separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/pinchflat/downloading/media_downloader_test.exs` | Stores error on failure; clears on success; recovered and unrecoverable paths. |
| `test/pinchflat/utils/string_utils_test.exs` | Non-binary stringification. |
| Upstream media/UI tests | Rendering expectations (curator should add LiveView/HTML checks at the real boundary). |

### Generated

| Path | Note |
| --- | --- |
| `erd.png` | Generated — ignore. |

## Draft clarified feature brief

> When a download fails I cannot tell why. Save the failure reason on the media item and show it in the app: on the media item page and in the source and history tables. Clear the saved reason when a later download succeeds. Successful items must not show a stale error. Non-binary error terms should still store a readable string. Keep existing retry/recover behaviour.

Do **not** name `last_error`, `wrap_string/1`, tooltip modules, or file paths in the solver ticket.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Store on failure:** failed download ⇒ media item has a non-empty readable error string. |
| A2 | **Clear on success:** fixture with old error; successful download ⇒ reason is cleared/nil. |
| A3 | **Both failure kinds:** recoverable and unrecoverable failures both persist a reason. |
| A4 | **Media show:** page includes the error text when present; omits the section when nil. |
| A5 | **Tables:** source media table and history table can show the reason (tooltip data present; no crash when nil). |
| A6 | **Preservation:** successful download still updates metadata/filepath; retry/recover behaviour unchanged. |

## Incomplete control

**Compiling partial that misses one subsystem:** persist `last_error` in the downloader/schema but never render it (or render only on media show, not tables).

- A1 may pass; **A4/A5** fail.
- Second partial: store error but also store it on success / never clear → **A2** fails.

## Integrity / shortcut rejection

Reject patches that:

- Set the error on successful downloads (stale errors).
- Block download completion solely because of the new field.
- Show empty tooltip/section when the field is nil (must omit or stay inert).
- Change retry classification as a side effect of persisting the message.

## Preservation of existing behavior

- Existing downloader success/metadata tests stay green.
- Media items with no error render without a new empty section.
- Worker retry vs non-retry paths unchanged.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| yt-dlp mocked | No YouTube. |
| SQLite migration | Verify `add_last_error` applies in test DB. |
| Floki / LiveViewTest | UI checks at HTML/LiveView level (Floki is a test dep). |
| AGPL-3.0 | Provenance notice. |

Not verified here: compile/test/boot.

## Status: discovered

Strong persistence + multi-surface UI feature. Complements #640 (policy) and #559 (settings/throttle) as distinct Pinchflat families — resolve SQLite/Oban runtime once for the project.

## Next action

1. Pin base `fe5c00dbeff0adcc3f35ec9639c47a8f8b3338c4`.
2. Draft brief without naming the column; prefer LiveView/HTML assertions over pixel tests.
3. Incomplete = persist-only; integrity = never-clear / show-when-nil.
4. Qualify after Pinchflat runtime is confirmed.
