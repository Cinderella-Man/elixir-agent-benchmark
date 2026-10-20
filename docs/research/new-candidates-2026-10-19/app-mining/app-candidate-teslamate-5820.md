# TeslaMate #5820 — Geofence re-assignment distance used the wrong latitude

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#5820](https://github.com/teslamate-org/teslamate/pull/5820)  
**Source revisions:** base `1ddb3e46f53b3b261b127c7743314108d51faf4c` → merge `3249b36da65d295bede807c7fa48865867aa35ab`  
**Author:** JakobLichterfeld · **Merged:** 2026-10-02  
**Task kind / family:** bug_fix / SQL geofence assignment correctness  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Why it is a good case

`apply_geofence/2` rebuilds drive/charge geofence links with PostGIS-style `earth_box` / `earth_distance` SQL. The distance subquery used an **unqualified** `latitude` paired with `p.longitude`, so the radius filter could disagree with the bounding-box filter and with true geodesic distance. Users see wrong or missing geofence labels after create/update/delete of a fence. The ticket can describe mis-assignment without naming the column qualifier fix. Two new tests use concrete Berlin-area coordinates to pin bbox-vs-radius and nearest-center behavior — good named, deterministic checks.

## Implementation file roles

| File | Role |
| --- | --- |
| `elixir/lib/teslamate/locations.ex` | SQL string in `apply_geofence`: `ll_to_earth(latitude, p.longitude)` → `ll_to_earth(p.latitude, p.longitude)` in both the subquery distance/order and the outer filter (three sites). |
| `elixir/test/teslamate/locations/geofences_test.exs` | Tests: (1) ignore fences whose bbox but not radius contains the position; (2) assign the fence whose center is closest when two fences both contain the point. |

**Counts:** 1 substantive implementation file, 1 test file. Focused repair.

## Cross-component behavior to verify

- Bounding-box candidate set and radius filter must use the **same** position point (the drive/charge position row).
- When several fences contain a point, the nearest center wins (order-by distance).
- Deleting an inner fence that was wrongly chosen must leave the session unassigned if the outer fence’s radius does not actually contain the point.

## Draft ticket (shortest sufficient)

> After I create, update, or delete a geofence, some drives and charging sessions end up with the wrong geofence or none at all, even though the position looks clearly inside or outside a fence. The re-assignment query is picking the wrong place. Fix it.

## Proposed named acceptance checks

1. `apply_geofence ignores-bbox-only-outer-fence` — position ~113 m from outer center with outer radius 100 m and outer bbox containing the point; after deleting a covering inner fence, charge/drive `geofence_id` is nil.
2. `apply_geofence prefers-nearest-center` — two fences both covering the position; assert the closer center’s id is stored on both drive and charging process.

## Plausible incomplete + integrity control

- **Incomplete:** fix only one of the three `latitude` occurrences (order-by vs filter still wrong).
- **Integrity:** reject patches that widen radius matching to “any bbox hit”, or that always pick the largest fence.

## Preservation

Existing geofence create/delete assignment tests must pass. Keep `earth_box` index-friendly prefilter; do not replace with a pure sequential scan rewrite unless results match.

## Runtime / offline holds

- PostgreSQL + `earthdistance`/`cube` required (same as #5823).
- No Tesla API. Fixtures construct positions/charges/drives locally.
- Sibling of #5823 (same `apply_geofence` family). **Do not** treat as independent coverage if both enter the corpus without noting shared subsystem.

## Status: discovered

Focused SQL correctness repair; high investigation value for a one-file task.

## Next action

If a second TeslaMate geofence case is wanted after #5823, take this next. Otherwise park as focused reserve. Verify earthdistance tests run offline before drafting a case bundle.
