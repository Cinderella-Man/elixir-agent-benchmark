# TeslaMate #5823 — Skip geofence re-assignment when location/radius unchanged

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#5823](https://github.com/teslamate-org/teslamate/pull/5823)  
**Source revisions:** base `3249b36da65d295bede807c7fa48865867aa35ab` → merge `ff347f572c87d9fe460378825509d11f564cb548`  
**Author:** JakobLichterfeld (member; Claude-assisted PR body — treat code/tests as evidence) · **Merged:** 2026-10-03  
**Task kind / family:** bug_fix / geofence assignment vs form updates  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later (`package: [licenses: ["AGPL-3.0-or-later"]]` in `elixir/mix.exs`; LICENSE is AGPL-3.0 text)

## Why it is a good case

Cross-component behavior in one coherent user problem: the geofence edit form always submits **all** fields as strings, including unchanged lat/lon/radius. `update_geofence/2` must distinguish “billing/name only” from “location/radius changed”, because assignment of drives and charging sessions depends only on those three fields. The PR also documents a real product consequence (timeout on large DBs when changing only price) and preserves the still-needed re-assignment path when location *does* change. Investigation is about ownership of assignment (`apply_geofence/2`) and when it must run — the ticket should not name `location_changed?` or the three fields.

Note: PR body states Claude-assisted generation. Upstream tests and merge are still real; do not expose the tool story in the ticket.

## Implementation file roles

| File | Role |
| --- | --- |
| `elixir/lib/teslamate/locations.ex` | `update_geofence/2` branches: full re-assign transaction only when assignment-relevant fields change; otherwise plain `Repo.update/1`. Private `location_changed?/1` checks `:latitude`, `:longitude`, `:radius` via `Ecto.Changeset.changed?/2`. |
| `elixir/test/teslamate/locations/geofences_test.exs` | Two new tests: (1) name/cost update with form-like string attrs leaves detached drives/charges detached; (2) invalid data with unchanged location still returns error changeset and does not mutate the geofence. |

**Counts:** 1 substantive implementation file, 1 test file (plus CHANGELOG). Focused one-file repair; guidelines allow this as a minority of the corpus.

Key snippet (post-fix):

```elixir
def update_geofence(%GeoFence{id: id} = geofence, attrs) do
  changeset = GeoFence.changeset(geofence, attrs)

  if location_changed?(changeset) do
    Repo.transaction(fn ->
      with :ok <- apply_geofence(geofence, except: id),
           {:ok, geofence} <- Repo.update(changeset),
           :ok <- apply_geofence(geofence) do
        geofence
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  else
    Repo.update(changeset)
  end
end
```

## Cross-component behavior to verify

- Editing only name / billing type / costs must not re-assign drives or charging processes (form submits all fields as strings).
- Moving or resizing a geofence **must** still re-assign (existing tests cover this — positive preservation).
- Invalid changesets still return `{:error, changeset}` and leave DB rows unchanged.
- Retroactive cost application still finds sessions by stored `geofence_id` when location is unchanged (PR body claims; **unverified in this pass**).

## Draft ticket (shortest sufficient)

> Editing a geofence’s name or costs re-walks and re-assigns every nearby drive and charging session, even though those assignments do not depend on the fields I changed. On bigger histories this save can time out. Keep assignment correct when I move or resize a geofence, but do not redo it when only the non-location fields change. Fix it.

## Proposed named acceptance checks

1. `update_geofence name-and-costs-keeps-assignments-unchanged` — create drive/charge near a fence, detach them, update only name/costs with string attrs as the form sends; assert both stay unassigned.
2. `update_geofence move-still-reassigns` — update latitude/radius; assert drives/charges inside new geometry get the fence id.
3. `update_geofence invalid-data-without-location-change` — `session_fee: -0.01` returns error changeset and geofence row is unchanged.

## Plausible incomplete + integrity control

- **Incomplete:** skip re-assignment on *every* update (breaks move/resize re-assign).
- **Integrity:** reject patches that also stop assigning on create, or that treat string-coerced equal coordinates as “changed” and still re-walk.

## Preservation

Existing geofence create/update/delete assignment tests in `geofences_test.exs` must still pass. Do not require re-assignment to “heal” historical wrong links when location is unchanged (PR body explicitly gives that up; do not score it).

## Runtime / offline holds

- **PostgreSQL** with `earthdistance` / `cube` (geofence SQL). Runner supports PostgreSQL service handling — verify extension bootstrap.
- No live Tesla API for these tests (local fixtures: `car_fixture`, `create_drive`, `create_charging_process`).
- Elixir `~> 1.19` at merge-time `elixir/mix.exs` — toolchain pin is a real hold if the runner image is older.

## Status: discovered

Not rejected. Strong focused repair; only one implementation file.

## Next action

Confirm PostgreSQL earthdistance works in the existing Sandbox/Fixtures path, then draft case with the three named checks. Pair in reporting with #5820 as a geofence-assignment family; do not merge into one task.
