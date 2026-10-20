# app-candidate-mydia-1083

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1083 |
| Title | fix(watch-sync): sync watched state across every Jellyfin copy of a movie |
| Project | getmydia/mydia |
| Source type | Historical merged PR (bug fix + data-model change; fixes #1079) |
| PR head SHA | `8cd2059733f4b2cb4e3c569ac844b46efcc4fa6a` (last of 6 commits) |
| First commit | `5fb348e3eced05a1c998bc9f54a67c110c8fe0e0` |
| Parent of first commit (likely base) | `5b53be4fb9e5aa3242fed0d5d91e9010d7cee718` |
| Merged at | 2026-10-08T04:01:03Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body/diff inspected; tests not executed |

## Why it is a case

A movie in two Jellyfin libraries (1080p + 4K) is two remote items with separate played flags. Mydia kept one mapping per movie, so the crawl kept whichever copy it listed last and dropped watches on the other. Most 4K movies never showed watched.

What must stay consistent:

- Mapping uniqueness moves to `(item, remote_id)` — one row per server copy (reversible migration).
- Sync folds all copies: watched if **any** copy is watched; position/time from the most recently played copy.
- Incremental runs must not unwatch a multi-copy item from an unseen copy; only a full listing can unwatch.
- Local watch/unwatch pushes to **every** copy; if any copy's write fails, no snapshot is recorded (retry later).
- Forced mapping crawl prunes copies the server no longer lists; empty crawl prunes nothing.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/mydia/watch_sync/mapping.ex` | Unique copy constraints (`unique_copy_constraints`) |
| `lib/mydia/watch_sync/engine.ex` | Map every copy; fold remote state; prune; push to all copies |
| `lib/mydia/watch_sync/reconciler.ex` | `merge_remotes/1` recency/position policy |
| `priv/repo/migrations/..._allow_many_remote_copies_per_item.exs` | Uniqueness move; rollback keeps most recently seen copy |

Tests (separate): `engine_test.exs`, `reconciler_test.exs`, `schemas_test.exs` with fake provider modules.

## Draft ticket

> Movies that exist in more than one Jellyfin library (for example a 1080p and a 4K copy) never show as watched. Watched state must consider every remote copy of an item, and local watch actions must update all copies. Fix it.

## Named acceptance checks

1. **every-copy-mapped** — after a mapping crawl, each remote copy has its own mapping row.
2. **any-copy-watched** — item is watched if any copy is watched; position/time from most recently played copy.
3. **partial-listing-no-unwatch** — an incremental listing that does not include a watched copy does not unwatch the item.
4. **push-all-copies** — marking watched in Mydia writes to every mapped copy.
5. **failed-push-no-snapshot** — if one copy's write fails, no success snapshot is recorded (next run retries).
6. **prune-forced-crawl** — forced crawl prunes unmapped copies; empty crawl prunes nothing.
7. **reconcile-single-item** — reconciler merges multi-copy sides once per item (not once per copy).

## Incomplete + integrity control

- **Incomplete:** change mapping uniqueness and map all copies, but fold state from only the last-listed copy (or push to only one copy). Fail **any-copy-watched** or **push-all-copies**.
- **Integrity:** unchanged tree fails **every-copy-mapped** / **any-copy-watched**. Reference passes. Single-copy pass-through (**a single copy passes through**) is preservation.

## Preservation

- Single-copy items behave as before.
- Dated/positioned unwatch still propagates.
- Rollback of the migration keeps a usable mapping (most recently seen copy).

## Runtime / offline holds

- SQLite local + PostgreSQL CI — offline.
- Upstream tests use **fake provider modules** (not a live Jellyfin) — fixtures feasible.
- Hold any end-to-end check that requires a real Jellyfin server.
- Author note: local Postgres test DB was not created in one environment — dual-DB migration risk **unverified**.

## Status

**discovered** — strong domain model + engine + reconciler coordination; issue #1079 supplies authentic symptom; excellent named tests.

## Next action

Run engine/reconciler/schemas tests at base `5b53be4f...` on SQLite and PostgreSQL; confirm migration up/down on both.
