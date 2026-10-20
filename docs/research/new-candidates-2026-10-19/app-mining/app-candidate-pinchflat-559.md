# Pinchflat #559 — yt-dlp rate limiting and throttle-safe media persistence

**Status:** discovered  
**Source type:** historical PR (FR #401; related triage #549)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#559](https://github.com/kieraneglin/pinchflat/pull/559)  
**Source revisions:** base `fb2798896385ed51da44e74435f23bea587d468e` → merge `e9f6b459530ac9729d2880d2dfbec15dc4f7b6aa`  
**Author:** kieraneglin · **Merged:** 2025-01-14  
**Task kind / family:** bounded feature / settings → CLI options + media validation under throttle  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Why it is a good case

Two related user problems bundled coherently by the maintainer: (1) configurable sleep/rate limiting for yt-dlp requests; (2) when YouTube throttles, indexing must not persist junk “youtube video #…” titles / media rows. Settings schema + form + command runner + media changeset + worker non-retry for bot-check errors must agree. Cross-component and testable with the existing runner mock.

## Implementation file roles

| File | Role |
| --- | --- |
| `priv/repo/migrations/20250110231704_add_extractor_sleep_interval_to_settings.exs` | Add `extractor_sleep_interval_seconds`. |
| `lib/pinchflat/settings/setting.ex` | New field, required, `validate_number > 0` (0 disables — see holds). |
| `lib/pinchflat_web/controllers/settings/setting_html/setting_form.html.heex` | “Extractor Settings” + sleep interval input. |
| `lib/pinchflat/yt_dlp/command_runner.ex` | `sleep_interval_opts/1` injects jittered `--sleep-requests/--sleep-interval/--sleep-subtitles`; `:skip_sleep_interval` for UI-blocking paths. |
| `lib/pinchflat/utils/number_utils.ex` | `add_jitter/2`. |
| `lib/pinchflat/media/media_item.ex` | Reject titles starting with `youtube video #` (throttle marker). |
| `lib/pinchflat/downloading/media_download_worker.ex` | Non-retryable errors include `"Sign in to confirm"`. |
| `lib/pinchflat/sources/sources.ex` | Source-details lookup skips sleep interval (UI latency). |

Tests: number_utils, command_runner, media, worker, settings, sources, slow_indexing. `erd.png` generated.

**Counts:** ~6–8 implementation files (settings schema/form, command runner, utils, media schema, worker, sources), tests separate.

## Cross-component behavior to verify

- Sleep interval 0/off ⇒ no sleep flags; positive interval ⇒ sleep flags present with jitter > 0; UI path opts out of sleep.
- Throttled-looking titles are rejected by the media changeset (not saved).
- Bot-check download errors complete the job without retry storm.
- Settings form round-trips the new field.

## Draft ticket (clarified implementation brief)

> Add a user-configurable delay between yt-dlp extractor requests (seconds, 0 = off) and apply it to yt-dlp runs, except on UI-blocking source lookups. When indexing is throttled, do not save media items whose titles are placeholder “youtube video #…” junk. Treat “sign in to confirm you are not a bot” download failures as non-retryable until the next indexing pass. Keep normal indexing and downloads working when the delay is off.

## Proposed named acceptance checks

1. `command-runner injects-sleep-flags` — with interval > 0, run opts include sleep_* keys.
2. `command-runner skips-sleep-when-disabled-or-opted-out` — 0 or `skip_sleep_interval: true` ⇒ no sleep opts.
3. `number-utils jitter-positive` — `add_jitter(n)` ≥ n for n > 0; `add_jitter(0) == 0`.
4. `media-item rejects-placeholder-titles` — changeset error on `youtube video #123`.
5. `worker non-retry-on-bot-check` — job completed, not retried.
6. **Preservation:** media items with normal titles still insert; sleep 0 keeps prior CLI option sets.

## Plausible incomplete + integrity control

- **Incomplete:** add setting + form but never pass flags into `CommandRunner.run/5`.
- **Integrity:** reject patches that always sleep even when 0, or that reject all titles containing “video”.

## Preservation

Existing command-runner and media insert tests.

## Runtime / offline holds

- yt-dlp mocked; no YouTube.
- SQLite migration for settings.
- **Contract ambiguity risk:** `validate_number(:extractor_sleep_interval_seconds, greater_than: 0)` vs UI help “set to 0 to disable”. Hidden checks must accept 0=off as the ticket states. Flag before admission.
- Randomized jitter — tests must assert presence/relative size, not exact values.

## Status: discovered

Good multi-file feature; needs the 0=off policy frozen in the brief.

## Next action

If Pinchflat settings/job family is wanted, draft with explicit 0=off language. Consider splitting bot-check non-retry only if the sleep feature feels too broad.
