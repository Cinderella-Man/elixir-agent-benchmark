# app-candidate-mydia-1150

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1150 |
| Title | fix(jobs): stop metadata refresh jobs snoozing forever |
| Project | getmydia/mydia |
| Source type | Historical merged PR (Oban job lifecycle bug) |
| PR head SHA | `26514c40378d2a487180915b82d25a564d26cf6c` (last of 3 commits) |
| First commit | `b1c5b887ff99b942e9cc12dbe544652c86cb144e` |
| Parent of first commit (likely base) | `b1f755225b6696f59c93cdf040fc98d389b62bdd` |
| Merged at | 2026-10-15T15:42:27Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body/diff inspected; tests not executed |

## Why it is a case

`MetadataRefresh` and `AiringEpisodeRefresh` snoozed a random startup delay when `attempt == 1`. Oban 2.24 rolls `attempt` back on snooze, so every wake-up looked like attempt 1 and snoozed again — neither job completed after the dependency bump (episodes stuck on "TBA", weekly metadata pass stopped).

What must stay consistent:

- Startup jitter is shared via `Mydia.Jobs.StartupJitter` and keys off `meta["snoozed"]`, not `attempt`.
- Both refresh workers use the helper; a first execution may snooze once, then the wake-up runs the pass.
- A real failure retry still runs the pass (attempt-based retry is not broken).
- Migration cancels only previously stuck snooze-looped refresh jobs, not unrelated scheduled work.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/mydia/jobs/startup_jitter.ex` | **New** — `delay/2` uses snoozed meta; helpers |
| `lib/mydia/jobs/metadata_refresh.ex` | Use StartupJitter instead of `attempt == 1` gate |
| `lib/mydia/jobs/airing_episode_refresh.ex` | Same |
| `priv/repo/migrations/..._cancel_snooze_looped_refresh_jobs.exs` | Cancel stuck rows (bounded) |

Tests (separate): `startup_jitter_test.exs`, `metadata_refresh_test.exs`, `airing_episode_refresh_test.exs` (+ source guard: every snooze in `lib/` goes through StartupJitter; no worker gates snooze on attempt).

## Draft ticket

> Metadata and airing-episode refresh jobs never finish: every time they wake they look like a first attempt and snooze again, so shows stay titled "TBA" and the weekly metadata pass never runs. Make startup jitter run once and then let the job do its work, including after retries. Fix it.

## Named acceptance checks

1. **snooze-once-then-run** — a job that has never snoozed snoozes a startup delay once; the wake-up runs the pass (e.g. `{2, :snooze, delay}` then success).
2. **already-snoozed-runs** — a job with `meta["snoozed"] > 0` and `attempt == 1` runs the pass immediately (does not snooze again).
3. **retry-after-failure-runs** — a retried job that snoozed before failing still runs the pass.
4. **both-workers** — same behavior for `MetadataRefresh` and `AiringEpisodeRefresh`.
5. **source-guard** — no `lib/` worker snoozes based on attempt number; all snoozes go through `StartupJitter`.
6. **migration-bounded** — cancel migration affects only the stuck refresh job rows (not all scheduled jobs).

## Incomplete + integrity control

- **Incomplete:** fix `MetadataRefresh` only; leave `AiringEpisodeRefresh` on `attempt == 1`. Fail **both-workers** for airing refresh.
- **Integrity:** unchanged tree fails **snooze-once-then-run** (loops). Reference passes. **retry-after-failure-runs** blocks “never snooze.”

## Preservation

- Jobs still perform their refresh pass when they run.
- Non-refresh Oban jobs unaffected.
- Empty/no-jobs cases still succeed.

## Runtime / offline holds

- Oban + DB (SQLite local / PostgreSQL CI) — offline with `testing: :manual` / drained queue as upstream tests do.
- **Metadata relay / TVDB-TMDB network not required** if tests assert snooze/perform control flow with stubs.
- Hold any check that needs live external metadata.

## Status

**discovered** — precise Oban 2.24 behavior change, shared helper + two workers + bounded migration; named tests cover the matrix.

## Next action

Pin Oban version at base (2.24+); run `startup_jitter_test.exs` and the source-guard test; execute the three-round qualification with the named outcomes.
