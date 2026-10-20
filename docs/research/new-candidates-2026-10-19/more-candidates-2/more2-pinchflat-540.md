# Pinchflat #540 — optional large feature: overhaul indexing (force + download archive)

**Status:** discovered  
**Source type:** historical PR  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#540](https://github.com/kieraneglin/pinchflat/pull/540) — *[Enhancement] Overhaul indexing to be more efficient*  
**Author:** (upstream) · **Merged:** 2025-01-02  
**Task kind / family:** feature (5–10 window) / slow-indexing workers + yt-dlp collection + forced reindex  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `9185f075ca3dc9fe37721b9d3f4a6188183007d8` | Title `…(#540)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `09d1653f4b8d506b4dc9f03c1e8daf01ee0b6fa5` | Matches PR API `base` — task base |

Reconstruct at **`09d1653f…`** and apply `pull/540.diff`. No `erd.png` in this diff.

Previously noted as a **reserve** in `more-candidates/more-candidates-README.md` (“5 impl + tests (~10 paths)”). Filed here as the batch’s optional 5–10 well-defined feature.

## Why it is a good case

Indexing is the core background workflow: workers decide when to reindex, kill stale jobs, use a per-source download archive for channels, and honour a user “force” action. This PR makes forced indexes skip the archive, treats yt-dlp exit code 101 as success, passes indexing opts through helpers, and tightens scheduling when a source has never been indexed. Coordinated across worker, helpers, command runner, media collection, UI action, and three test files with many named cases — a real multi-file behavioural contract, not a settings flag.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/slow_indexing/media_collection_indexing_worker.ex` | Force-aware perform path; never-indexed / scheduled / no-op branches |
| `lib/pinchflat/slow_indexing/slow_indexing_helpers.ex` | `index_and_enqueue_download_for_media_items/2` opts; file follower; archive decision |
| `lib/pinchflat/utils/filesystem_utils.ex` | Archive file helpers |
| `lib/pinchflat/yt_dlp/command_runner.ex` | Archive invocation; **101 exit code = success** |
| `lib/pinchflat/yt_dlp/media_collection.ex` | Collection indexing entry |
| `lib/pinchflat_web/controllers/sources/source_html/actions_dropdown.html.heex` | Force-index UI |
| `test/pinchflat/slow_indexing/media_collection_indexing_worker_test.exs` | Scheduling / force / never-indexed |
| `test/pinchflat/slow_indexing/slow_indexing_helpers_test.exs` | Archive formatting / force skip |
| `test/pinchflat/yt_dlp/command_runner_test.exs` | 101 exit code |
| `test/support/scripts/yt-dlp-mocks/101_exit_code.sh` | Mock script |

**Counts:** 6 implementation files + 3 test files + 1 mock script. Upper edge of the 5–10 feature window.

## Cross-component behavior to verify

- Forced index runs even when the source is not due, and does **not** use the download archive.
- Channel sources use a correctly formatted download archive on normal indexes; non-channels do not.
- yt-dlp exit code 101 is treated as success (archive already complete).
- Never-indexed sources always index once; scheduled sources reschedule; unscheduled already-indexed sources no-op unless forced.
- Stale source rows still discard the job without crashing.

## Draft ticket (shortest sufficient)

> Improve source indexing so a user can force a full reindex that ignores the download archive, while normal channel indexing still uses the archive and treats yt-dlp’s “already in archive” exit code as success. Sources that have never been indexed must always run once; scheduled sources reschedule; unscheduled already-indexed sources do nothing unless forced. Keep download-enqueueing for newly found media working.

Clarified implementation brief (force vs archive vs exit-code policy). Does not name workers or flags.

## Proposed named acceptance checks

1. `worker force-indexes-without-archive` — force arg indexes even when unscheduled and omits archive.
2. `worker never-indexed-always-runs` / `worker unscheduled-noops-unless-forced`.
3. `helpers archive-for-channels-only` + `helpers archive-omitted-when-forced`.
4. `runner treats-101-as-success` — mock script exit 101 does not fail the index.
5. `worker enqueues-downloads-for-pending` (preservation) — new media still enqueued.
6. `worker reschedules-by-frequency` (preservation).

Upstream tests already name most of these.

## Plausible incomplete + integrity control

- **Incomplete:** worker passes `force` into helpers but `command_runner` always builds the archive (or never treats 101 as success). Compiling; fails checks 1 or 4.
- **Integrity:** reject patches that always skip the archive (breaks channel efficiency), that fail on 101, or that break reschedule/no-op branches.

## Preservation

- Non-forced channel indexing keeps archive behaviour.
- Fast-indexing kickoff and notifications unchanged.
- Existing indexing worker tests that do not mention force stay green.

## Runtime / offline holds

- AGPL-3.0. SQLite + Oban; yt-dlp mocked via `test/support/scripts/yt-dlp-mocks/` (including the 101 script) — **no YouTube**.
- Larger than the other batch items; still one coherent indexing story with a clear force/archive/exit-code contract.
- Do not fold into cookie (#640/#641) or download-error (#610) families.

## Experiments (quick)

- `pull/540.diff` well-formed; 10 paths as listed. Diff parses.
- Squash parent `09d1653f…` from commit page (`parents:[…]`, “1 parent”); equals PR API `base`.

## Optional git apply

```
git checkout 09d1653f4b8d506b4dc9f03c1e8daf01ee0b6fa5
git apply pull/540.diff
```

## Status: discovered

Optional 5–10 file feature for the batch. Rich named tests; slightly larger brief than the 2–5 file items.

## Next action

Pin `09d1653f…` → apply `pull/540.diff` → map checks 1–6 → incomplete = force flag without archive/101 policy → three qualification rounds. Keep as the single large-feature slot beside the coordinated 2–5 file cases.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Source indexing should let a user force a full reindex that ignores the download archive, while normal channel indexing still uses the archive so already-downloaded items are skipped and yt-dlp's "already in archive" exit code counts as success. A source that has never been indexed must always run once; a scheduled source reschedules after each run; an unscheduled already-indexed source does nothing unless forced. Newly found media must still be enqueued for download.

Clarified brief, 4 sentences. Product decisions stated: force skips archive, normal channel indexing uses archive, exit-code-101-as-success, never-indexed / scheduled / unscheduled-unless-forced matrix, download enqueue preserved. Does not name workers, helpers, or yt-dlp flags.

**Hidden requirements flagged:**
- "download archive" is an yt-dlp concept the ticket must keep (it is the user-visible efficiency story) — but do not name `--download-archive` or `break_on_existing`. Fine as written.
- Exit code **101** is yt-dlp-specific. The ticket says "already in archive exit code" without the number. Either state "exit code 101" (it is the external contract, not the fix) or accept any "already complete" success mapping. Prefer stating 101 — it is API surface, not implementation.
- Archive applies to **channel** sources only in the reference (`collection_type: :playlist` gets `[]`). Ticket says "normal channel indexing" — good, but make sure checks cover playlist-type sources staying archive-free so a solver who archives everything fails.

### 2. Deterministic checks

ExUnit + Oban + yt-dlp mock scripts (existing pattern, including the new `101_exit_code.sh`). No real network.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `worker force-indexes-unscheduled` | Source already indexed, `index_frequency_minutes: 0`, job args `%{"force" => true}` | perform path | indexing runs (mock invoked) |
| `worker never-indexed-always-runs` | `last_indexed_at: nil`, frequency 0 | perform path | indexing runs |
| `worker unscheduled-noops-unless-forced` | already indexed, frequency 0, no force | perform path | indexing does **not** run |
| `helpers archive-omitted-when-forced` | Channel source, `was_forced: true` | command opts | no `download_archive` key |
| `helpers archive-for-channels-only` | Channel source normal; playlist source normal | command opts | channel has archive file containing prior media ids; playlist has none |
| `runner treats-101-as-success` | Mock script exits 101 | index result | success / no raise |
| `worker enqueues-new-media` | Index returns new items | DownloadingHelpers | downloads enqueued (preservation) |
| `worker reschedules-by-frequency` | Scheduled source | next job | rescheduled at source frequency (preservation) |

Fake provider: yes — `test/support/scripts/yt-dlp-mocks/` executables (already the project's pattern). The 101 script is part of the reference; a solver may need an equivalent stub for their own tests — **graded checks should invoke the runner with a stub that exits 101**, not require a specific mock filename.

### 3. Ambiguity / unfairness

- Exact archive file format (`"youtube #{media_id}"`) is implementation. Assert the archive is used / omitted and that previously-seen ids are present, not the literal line format — unless you also state the format (do not).
- "101 = already in archive" vs "101 = cancelled by max-downloads" is yt-dlp docs. Ticket states "already in archive exit code counts as success" — enough. Do not grade comments.
- Force behaviour on never-indexed sources: both branches run. No contest.
- Whether force also skips **fast** indexing kickoff is out of scope — say "fast-indexing kickoff unchanged" or do not grade it.

### 4. Shortcuts

- Thread `force` into helpers but `command_runner` always builds the archive. Fails `helpers archive-omitted-when-forced`.
- Never treat 101 as success. Fails `runner treats-101-as-success`.
- Always skip the archive (over-optimise). Fails `helpers archive-for-channels-only` and breaks channel efficiency — integrity.
- Force flag indexes everything unconditionally (including unscheduled non-forced). Fails `worker unscheduled-noops-unless-forced`.
- Partial: worker branches correct but archive file never written / empty. Fails archive content assertion.

### 5. Flakiness / nondeterminism

Medium (for this batch). Oban jobs: use the project's test mode (inline/draining), never `Process.sleep`. `Ecto.StaleEntryError` path is already rescued — one check that a stale source discards cleanly is optional. File follower for yt-dlp output is async in the reference — either avoid the file-follower path in graded checks or synchronize on the written file with a deterministic helper. Prefer the non-follower helpers path.

### 6. Coverage mix

- Positive: force runs; never-indexed runs; 101 success; archive written for channels.
- Negative: unscheduled no-op; force omits archive; playlist gets no archive.
- Preservation: download enqueue for new media; reschedule; non-forced channel archive path.
- Mixed: one source exercised through force **and** a later normal index (archive appears only on the normal run).

### 7. Environment risk

- **AGPL-3.0-or-later.** SQLite + Oban. yt-dlp mocked via shell scripts — need a POSIX-ish shell in the fixture (Windows host is the curator machine; the runner is Linux — fine, but note it).
- Larger diff (6 impl + 3 test + 1 mock). Guidelines allow 5–10 coherent features; this is one indexing story. Do not also fold cookie/download-error families.
- No YouTube, no network.

### 8. Verdict

**READY-WITH-FIX** — rich named tests and a real multi-branch contract, but the ticket must pin the 101 contract and the archive-by-collection-type rule, and the incomplete control needs to be a compiling partial (force without archive/101 policy), not a half-deleted worker.

### 9. Must-fix list

1. State "exit code 101 counts as success" in the ticket (API surface, not fix naming).
2. State that normal **channel** indexing uses the archive and playlist/non-channel does not.
3. Graded checks must not depend on mock script filenames; inject a 101-exiting stub.
4. Incomplete = force threading without archive-omit / 101 policy (compiling).
5. Synchronize or avoid file-follower; use Oban test mode.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Branch matrix incompletes + async file-follower nondeterminism |
