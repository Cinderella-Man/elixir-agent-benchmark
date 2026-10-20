# Pinchflat #646 — per-app download throughput limit

**Status:** discovered  
**Source type:** historical PR  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#646](https://github.com/kieraneglin/pinchflat/pull/646) — *[Enhancement] Add download rate limiting to app settings*  
**Author:** kieraneglin · **Merged:** 2025-03-11  
**Task kind / family:** feature / app settings → yt-dlp consumer policy  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `4554648ba7facfc8ed7cdff0ed1689052044d42f` | Title `…(#646)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `0fbf810cb672c588e019e8acd86cd07cc3bb2d94` | Sole parent — task base |

PR metadata: `commitsCount: 3`, same-day open/merge. Pinchflat squash-merges. Reconstruct at **`0fbf810c…`** and apply `pull/646.diff`, **excluding generated `priv/repo/erd.png`**.

## Why it is a good case

Users need a global cap on download bandwidth. The PR adds `download_throughput_limit` (string like `"100K"` / `"4.2M"`) to app settings, exposes it in the settings form, and passes yt-dlp `--limit-rate` from the shared command runner whenever the value is set. Coordinated across schema+form+runner; named tests already assert the CLI flag appears / does not appear. The ticket can ask for a throughput cap without naming `limit_rate` or the settings field. Distinct from the already-filed cookie policy (#640/#641) and download-error UI (#610).

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/settings/setting.ex` | Cast `:download_throughput_limit` (string) on the settings schema |
| `priv/repo/migrations/20250311222451_add_rate_limit_speed_to_settings.exs` | Add the column to `settings` |
| `lib/pinchflat/yt_dlp/command_runner.ex` | `rate_limit_opts/1`: when the setting is set, prepend `limit_rate:` alongside sleep-interval opts |
| `lib/pinchflat_web/controllers/settings/setting_html/setting_form.html.heex` | Settings UI input (placeholder `4.2M`, blank = disabled) |
| `test/pinchflat/yt_dlp/command_runner_test.exs` | Named checks for flag present / absent |

**Counts:** 4 substantive implementation files + 1 migration + 1 test file. Exclude `priv/repo/erd.png` (generated). Feature, not a mega-diff.

## Cross-component behavior to verify

- Setting persists and round-trips through the settings form.
- The yt-dlp command includes a rate limit **only when** the value is non-nil/non-empty.
- Sleep-interval options still apply and keep their relative order next to the new option (runner comment pins option order).
- Existing sources/downloads are unchanged when the setting is blank (default).

## Draft ticket (shortest sufficient)

> Let me cap how fast downloads run so they do not saturate my connection. Add an optional app-level download throughput limit I can set in settings (values like `50K` or `4.2M`, blank disables it). When set, every yt-dlp download honors that cap; when unset, behavior stays as today. Keep the existing sleep/throttle settings working.

This is a clarified implementation brief (product shape: optional string limit, blank = off). It does not name files or the yt-dlp flag.

## Proposed named acceptance checks

1. `command_runner includes-limit-rate-when-set` — `Settings.set(download_throughput_limit: "100K")`; run output contains `--limit-rate 100K` (or parsed equivalent).
2. `command_runner omits-limit-rate-when-unset` — nil setting; output does **not** contain `--limit-rate`.
3. `command_runner keeps-sleep-interval-opts` — sleep interval still emits its flags when a throughput limit is also set (order preserved).
4. `settings-form exposes-throughput-field` — field renders and accepts `4.2M` / blank.
5. `settings-persist-throughput` — value survives `Settings` get/put (migration-backed).

Upstream tests already cover 1–2; 3–5 may need small curator extensions.

## Plausible incomplete + integrity control

- **Incomplete:** schema+migration+form only; `command_runner` never reads the setting. Compiling; fails check 1.
- **Integrity:** reject patches that always pass `--limit-rate`, that drop sleep-interval opts when adding rate limit, or that treat blank as `0` and stall downloads.

## Preservation

- Default (nil) must not add any `--limit-rate` flag.
- Cookie / sleep-interval option builders keep working (same file, separate opts).
- Existing command-runner tests for cookies and sleep intervals stay green.

## Runtime / offline holds

- AGPL-3.0. SQLite + Oban; **yt-dlp mocked** (Mox / script stubs) — no YouTube.
- Exclude `priv/repo/erd.png` from applies and from graded diffs (generated diagram).
- Verify SQLite migration applies cleanly at the pinned base.

## Experiments (quick)

- `pull/646.diff` well-formed; file list matches the roles above. `git apply --check` in empty tree reports only missing base files (diff parses).
- Squash parent `0fbf810c…` taken from the squash commit page (1 parent). Re-check option-order comment in `command_runner.ex` when building incomplete control.

## Status: discovered

Well-defined 4+1 file feature with upstream named tests. Cleaner than another cookie/settings variant.

## Next action

Pin base `0fbf810c…` → apply diff minus `erd.png` → map checks 1–5 → incomplete = UI/schema only → three qualification rounds. Sibling of #640/#641/#610 but a **separate task family** (bandwidth policy vs cookies vs error UI).

## Grilling (2026-10-19)

### Minimum ticket
Solid clarified brief. Product shape is explicit (optional string like `50K` / `4.2M`, blank disables, every yt-dlp download honors it, sleep/throttle settings keep working) and it does not name `limit_rate`, the schema field, or files. That is the right level for a bounded feature. Two tightenings:
- "values like `50K` or `4.2M`" invites format-validation grading. Either say "any non-empty string is passed through to the downloader" or "validate it looks like a rate" — do not leave a hidden format policy in the checks.
- "every yt-dlp download" — the reference only touches the shared command runner. Do not also require a per-source override or a live bandwidth proof.

### Named deterministic checks
Unexecuted. Upstream already has 1–2; 3–5 need curator extensions:
1. `command_runner includes-limit-rate-when-set` — setting `100K` → command contains `--limit-rate 100K` (or parsed equivalent)
2. `command_runner omits-limit-rate-when-unset` — nil/blank → no `--limit-rate`
3. `command_runner keeps-sleep-interval-opts` — sleep-interval flags still emitted alongside the limit; relative order preserved if the runner comment pins it
4. `settings-form exposes-throughput-field` — field renders; accepts `4.2M` and blank
5. `settings-persist-throughput` — value survives `Settings` get/put (migration-backed)

Without (2) the always-pass-the-flag cheat passes. Without (3) a solver can drop sleep-interval opts while adding rate limit. Without (5) the UI-only incomplete passes. Without (4) a runner-only fix skips the user-facing setting — that is the stated product ("I can set in settings"), so keep (4).

Add a named blank-form → persist → runner-omits round-trip so "blank disables" is observed end-to-end, not just in two unit tests.

### Ambiguity / unfairness
- Format validation: see above. Default to pass-through of a non-empty string unless you put validation in the ticket. The placeholder `4.2M` is UI copy, not a policy.
- Do not grade the exact placeholder text or label wording.
- "every yt-dlp download" = the shared runner path the reference uses. Do not require scraping yt-dlp stdout for an effective rate.
- Sleep-interval option order: the runner comment is a real consistency constraint in the same file — fair to keep both flags working. Grade presence of both, and order only if the comment is solver-visible at the pinned base (it is).
- Blank vs nil: reference treats unset as disabled. Ticket says blank disables. Grade both nil and `""` as omit.
- Exclude `priv/repo/erd.png` from the reference apply and from any file-count / graded-diff claims. Generated.

### Shortcuts + compiling incomplete
Schema+migration+form only (as stated) compiles and is the right incomplete. Also: runner always passes `--limit-rate` even when unset (fails 2); treat blank as `0` and stall downloads (integrity — assert command omits the flag, not that it passes `0`); drop sleep-interval opts when adding rate limit (fails 3); runner reads the setting but the form never saves it (fails 4/5); per-download override invented and wired only there (out of scope — do not reward or punish if the shared path still works).

### Flakiness
Low. ExUnit + Ecto sandbox + SQLite. yt-dlp is **mocked** (Mox / script stub) — keep it that way; never spawn a real downloader. Assert on the built argv list, not on process output ordering from a fake binary, if the runner already exposes the command. No clocks, no Oban jobs in the graded checks. Migration must apply cleanly once; do not re-run migrations across tests.

### Preservation
Default (nil/blank) adds no `--limit-rate`. Cookie and sleep-interval builders keep working (same file, separate opts). Existing command-runner tests for cookies/sleep intervals stay green. Sources/downloads with the setting blank behave as today. Add a named "cookie opts still present when throughput limit is set" so a one-flag rewrite of `rate_limit_opts` fails.

### Env
AGPL-3.0-or-later — keep the notice. SQLite + Oban, yt-dlp mocked, no YouTube, no network. **Nothing executed** — no apply, no compile, no migration run. 4 implementation files + 1 migration is a good coordinated count (schema → form → runner). Sibling of #640/#641/#610; **separate task family** (bandwidth policy). Do not merge those PRs into this case.

### Verdict
**READY-WITH-FIX** — clearest product contract of this batch, upstream named tests, mocked external consumer, and a real schema→UI→runner relationship. Needs execution and a few check tightenings, not product redesign.

### Must-fix before qualification
1. Ticket: say pass-through vs validate on the rate string. Say blank/`""` disables.
2. Pin base `0fbf810c…`, apply diff **minus `erd.png`**, run unchanged/reference/incomplete. Unchanged fails 1/3/4/5; reference passes.
3. Incomplete = schema+form+runner missing. Integrity = always-flag, blank-as-`0`, dropped sleep opts, cookie opts dropped.
4. End-to-end blank round-trip + cookie preservation alongside the rate flag.
5. AGPL in provenance. Keep #640/#641/#610 out of this case; note sibling family only.
