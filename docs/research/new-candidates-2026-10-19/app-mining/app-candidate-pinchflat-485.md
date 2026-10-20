# Pinchflat #485 — Do not download livestreams until they are finished processing

**Status:** discovered  
**Source type:** historical PR (fixes issues #395, #480)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#485](https://github.com/kieraneglin/pinchflat/pull/485)  
**Source revisions:** base `d9c48370df338eedb0637f8f76e3e0e0cc99cf6d` → merge `bfb27427cece06896fa9036cf86fdea311152ad0`  
**Author:** kieraneglin (owner) · **Merged:** 2024-11-26  
**Task kind / family:** bug_fix / download readiness vs job retry  
**Research date:** 2026-10-19  
**License:** AGPL-3.0 (LICENSE)

## Why it is a good case

User problem from real issues: livestream VODs get downloaded too early (missing minutes / “from start” problems). The PR separates **should download** (`Media.pending_download?`) from **ready to download** (`live_status` via yt-dlp simulate). That decision spans the yt-dlp media adapter, the downloader, and the Oban worker retry policy — and must leave normal (non-live) downloads unchanged. Strong multi-file, offline-testable (YtDlpRunnerMock).

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/yt_dlp/media.ex` | New `get_downloadable_status/1` — simulate/skip_download query for `live_status`; map `is_live`/`is_upcoming`/`post_live` → `:ignorable`, `was_live`/`not_live`/nil → `:downloadable`. |
| `lib/pinchflat/downloading/media_downloader.ex` | Pre-check status before `YtDlpMedia.download/3`; map `:ignorable` to `{:error, :unsuitable_for_download}`; log without treating as hard yt-dlp failure. |
| `lib/pinchflat/downloading/media_download_worker.ex` | Treat `:unsuitable_for_download` as non-retry job completion (recheck on next indexing). |

Tests: `test/pinchflat/yt_dlp/media_test.exs`, `test/pinchflat/downloading/media_downloader_test.exs`, `test/pinchflat/downloading/media_download_worker_test.exs` (Mox `YtDlpRunnerMock`).

**Counts:** 3 substantive implementation files, 3 test files.

## Cross-component behavior to verify

- Unfinished live media (`is_live` / `is_upcoming` / `post_live`) does **not** invoke the download runner and completes the job without retry.
- Finished / never-live media still downloads exactly as before.
- Unknown `live_status` is an error, not a silent skip.
- Status check uses the same cookies/runner conventions as other yt-dlp calls (**partially later PR #517** — do not fold #517 into this task).

## Draft ticket (shortest sufficient)

> Live streams get downloaded before they finish processing, so I miss the start or get a partial file. Do not start the download until the media is actually ready; if it is not ready yet, do not hammer retries — pick it up on a later indexing pass. Ordinary non-live videos must still download normally. Fix it.

## Proposed named acceptance checks

1. `downloadable-status maps-live-states` — unit map for each `live_status` value (including `nil` for non-YouTube).
2. `downloader skips-download-for-live` — `:is_live` → `{:error, :unsuitable_for_download}` and zero download-run calls.
3. `downloader downloads-was-live` — `:was_live` proceeds to download path.
4. `worker completes-without-retry-on-unsuitable` — Oban job state `completed`, not retried.
5. **Preservation:** normal media still returns `{:ok, updated_item}` from download.

## Plausible incomplete + integrity control

- **Incomplete:** implement `get_downloadable_status` but forget worker non-retry (jobs still retry/fail).
- **Integrity:** reject patches that skip downloads for `was_live`/`not_live`, or that swallow unknown live_status as `:ignorable`.

## Preservation

Existing download worker / downloader tests for recoverable vs non-recoverable errors.

## Runtime / offline holds

- **yt-dlp must stay mocked** (`:yt_dlp_runner` → `YtDlpRunnerMock`). Live YouTube is a hard hold.
- SQLite (`ecto_sqlite3`) + Oban + Mox — file DB likely offline without a service; **verify** runner support for SQLite (guidelines currently list PostgreSQL/ClickHouse; SQLite may work as embedded but is unverified).
- Elixir `~> 1.17` at nearby revisions.

## Status: discovered

Top Pinchflat bug-fix candidate this pass.

## Next action

Confirm SQLite/Oban/Mox test bootstrap offline, then draft. Do not include #517 cookie-precheck follow-up in the same task.
