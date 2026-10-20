# Redix #351 — Least-busy routing in Redix.Cluster pools

**Status:** discovered  
**Source type:** historical PR  
**Project:** [whatyouhide/redix](https://github.com/whatyouhide/redix)  
**PR:** [#351](https://github.com/whatyouhide/redix/pull/351)  
**Source revisions:** base `7c6cb60b25ec0613d5acabddb34b74db258439a0` → merge `490d0205afa4f8c4f5198789990a8ab4d4c21fe6`  
**Author:** whatyouhide · **Merged:** 2026-09-17  
**Task kind / family:** feature (routing) with preservation  
**Research date:** 2026-10-19

## Authentic work

Redis Cluster connection pools must route commands to an appropriate connection. This PR changes routing toward **least-busy** selection and reworks manager lookup. PR body is empty (maintainer merge) — the substance is the large coordinated diff across cluster + manager + tests.

Related earlier work: #350 “Reduce Redis Cluster pool churn” (base `dd7c5c1…` → `3c931c0…`) already changed `manager.ex` heavily. **Lineage:** do not treat #350 and #351 as two independent cases without a written combined outcome; prefer #351 as the later complete behavior, or a corrected-feature family only if both are needed for one user-visible result.

## Implementation scope (#351)

| File | Role |
| --- | --- |
| `lib/redix/cluster.ex` | Pool-side routing |
| `lib/redix/cluster/manager.ex` | Lookup / slot map / selection |
| `lib/redix/connection.ex` | Connection participation in routing |
| Multiple `test/redix/cluster/*` | Fake-node, manager lookup, telemetry, integration |

**Counts:** 3 substantive implementation files. Large test surface counted separately. Docs page `pages/Cluster.md` is documentation.

## Cross-component behavior to verify

- Commands still land on a connection that owns the right slot (correctness > load heuristic).
- Least-busy choice does not break MOVED/ASK handling or cluster topology updates.
- Fake-node tests can observe which connection was chosen without a real Redis Cluster.
- Ordinary non-cluster Redix behavior unchanged.

## Draft ticket (needs brief because body is empty)

> In a Redis Cluster pool, pick a less-busy connection among the eligible ones instead of a fixed/naive selection, while still obeying slot ownership and cluster redirections. Keep single-Redis Redix unchanged.

**Contract hold:** “least-busy” needs an observable definition (e.g. in-flight command counts on connections managed by the pool) in the brief; otherwise hidden tests can overfit the reference’s private helpers.

## Acceptance design (proposed, unexecuted)

- Fake cluster node helper (already in upstream tests) to pin slot maps.
- Two eligible connections with different in-flight work; assert the freer one is selected.
- Slot-correct routing preserved when only one connection owns the key.
- Redirection/topology path preserved.

## Plausible incomplete (proposed)

Change `cluster.ex` selection but leave `manager.ex` lookup returning a static order; or implement least-busy without respecting slots.

## Integrity control (proposed)

Reject always choosing connection index 0, or a “fix” that disables pooling.

## Runtime / offline

- Historical Mix: Elixir `~> 1.15` at the base (from `mix.exs`).
- Upstream tests use **fake nodes** for much of cluster behavior — that is the offline-friendly path.
- Real Redis is **not** required if acceptance sticks to fake-node/unit surfaces; do not claim full cluster ops against a live Redis without adding that service to the runner.
- License: project is MIT (standard Redix; LICENSE file path may be `LICENSE` or `LICENSE.md` — verify at the chosen SHA).

## Holds / unknowns

- Empty PR body → independent contract review mandatory before checks.
- Large test churn (666-line manager test in #350) suggests concurrency/timing sensitivity; prefer deterministic fake-node counts over sleeps.
- Redis Cluster is a runtime family the runner may not have documented; preparation work is “fake node ExUnit”, not “install Redis Cluster”.

## Coverage added

Pool routing / distributed-system client behavior, distinct from HTTP clients and from OTP PubSub.

## Next action

Prefer **#356 first** (tiny leak fix, same project, same fake-node style) to prove Redix offline prep, then decide whether #351 is the coordinated expansion.
