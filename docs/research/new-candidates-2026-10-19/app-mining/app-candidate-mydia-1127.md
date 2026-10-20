# app-candidate-mydia-1127

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1127 |
| Title | fix(watch-sync): import watches on copies mapped after they were played |
| Project | getmydia/mydia |
| Source type | Historical merged PR (bug fix follow-up to #1083; fixes #1097) |
| PR head SHA | `b8ea5095be1976418e1403b1f05f52e0dc41306b` (last of 4 commits) |
| First commit | `2c58c453926ed7f82e96dbb5f2d9f5b7f34b8699` |
| Parent of first commit (likely base) | `a0218e29bc765683d3d90d268114a1074878be68` |
| Merged at | 2026-10-12T22:07:26Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body/diff inspected; tests not executed |

## Why it is a case

After #1083 mapped every copy, some posters still lacked the watched badge until re-marked watched in Jellyfin. Incremental runs only list items played since the last sync. A copy that had no mapping when its watch was first listed was counted "not found"; the later mapping crawl could not resurface its old `LastPlayedDate`.

What must stay consistent:

- Full listing is triggered when any mapping was added since the user's last **finished successful** run (quiet runs stay incremental).
- Marker uses finished `:ok` runs only (in-flight/failed runs are not markers).
- Migration restamps `inserted_at` on existing mappings so upgrades get one full listing.
- On a full listing, a never-played blank copy cannot unwatch an item whose last agreed state is watched; dated/positioned unwatch still propagates.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/mydia/sync.ex` | `last_successful_run_started_at/3` marker |
| `lib/mydia/watch_sync/engine.ex` | `listing_since`, `mappings_added_since?`, `drop_blank_copies`, full vs incremental |
| `lib/mydia/watch_sync/providers/jellyfin.ex` | Listing `since` behavior (supporting) |
| `priv/repo/migrations/..._refresh_watch_sync_mapping_inserted_at.exs` | Backfill for one full listing |

Tests (separate): `engine_test.exs`, `incremental_test.exs`, `sync_test.exs`, migration test.

## Draft ticket

> After multi-copy watch sync, some movies still do not show the watched badge until they are marked watched again in Jellyfin. Copies that were mapped after their watch was first seen are skipped by later incremental syncs. Import those watches without re-marking them, and do not let a never-played copy clear watched state. Fix it.

## Named acceptance checks

1. **mapped-after-watch-imported** — a copy whose watch predates the cursor is imported on the next run when mappings were added since the last successful run (full listing).
2. **quiet-run-stays-incremental** — when nothing was mapped since the last successful run, the cursor is used (incremental).
3. **finished-ok-marker-only** — failed or in-flight runs are not treated as the cursor marker.
4. **upgrade-one-full-listing** — after the migration, existing mappings look newly added so linked users get one full listing.
5. **blank-copy-no-unwatch** — on a full listing, a never-played copy does not unwatch an item whose agreed state is watched.
6. **dated-unwatch-still-propagates** — a dated/positioned unwatch on a copy still syncs (preservation).

## Incomplete + integrity control

- **Incomplete:** full-listing when mappings change but still use only the last run's timestamp regardless of success (or skip `drop_blank_copies`). Fail **finished-ok-marker-only** or **blank-copy-no-unwatch**.
- **Integrity:** unchanged tree fails **mapped-after-watch-imported**. Reference passes. **dated-unwatch-still-propagates** + **quiet-run-stays-incremental** block over-broad full listings or never-unwatch.

## Preservation

- Quiet incremental performance path retained (known trade-off: repeatedly failing runs always full-list — acceptable and documented).
- Single-copy unwatch with a date still works.
- #1083 multi-copy fold behavior retained.

## Runtime / offline holds

- Same as #1083: SQLite/PostgreSQL, fake providers offline.
- Hold live Jellyfin checks.
- Related task family to `app-candidate-mydia-1083.md` (do not treat as duplicate — different defect).

## Status

**discovered** — follow-up bug with subtle cursor/marker semantics; strong named tests including negative unwatch cases.

## Next action

Order preparation after #1083 candidate is validated (same engine files); run incremental suite at base `a0218e29...`.
