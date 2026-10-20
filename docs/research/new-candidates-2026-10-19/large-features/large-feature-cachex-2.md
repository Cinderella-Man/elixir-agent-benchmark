# Large feature — Cachex #306 scheduled LRW eviction policy

**Status:** discovered
**Source type:** historical merged PR (closes #303 and #300)
**Project:** [whitfin/cachex](https://github.com/whitfin/cachex)
**PR:** [#306](https://github.com/whitfin/cachex/pull/306) — Add a scheduled LRW policy for low memory use
**Author:** whitfin · **Merged:** 2023-01-09
**Source revisions:** base `fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e` → head `65a10ca487dfe8f2c826748573a72cfa047edf3a` → merge `7b4062bd8d139114ac865535a151165bc0c7d28d`
**Size:** +417 / −202, **9 changed files**
**Task kind / family:** bounded feature / cache limit policy (eviction)
**Research date:** 2026-10-19
**License:** MIT (`package().licenses: ["MIT"]`)

---

## Why it is a LIMIT-TESTING case

LRW eviction already exists as an evented hook policy. This PR adds a **scheduled** implementation that enforces cache bounds on a timer (lower memory, possible delay) while keeping the shared LRW algorithm. Coordination spans:

1. **`Cachex.Policy` behaviour** — drop unused `child_spec/1` / `strategy/0`; keep `hooks/1`.
2. **`Cachex.Policy.LRW`** — become shared utilities + default delegation; document both policies.
3. **`Cachex.Policy.LRW.Evented`** — existing hook-based policy moved here (default preserved).
4. **`Cachex.Policy.LRW.Scheduled`** — new timer-driven policy with `:batch_size` and `:frequency` options.
5. **`Cachex.Services`** — start/stop policy servers with the cache.

Five implementation files, clear user choice (`limit` policy options), tests that actually insert and observe eviction. Not a pure refactor: a new public policy module with its own options.

## File inventory with roles

From `pull/306.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/cachex/policy.ex` | Behaviour cleanup; still the policy entry. |
| `lib/cachex/policy/lrw.ex` | Shared LRW prune logic + docs pointing at Evented/Scheduled. |
| `lib/cachex/policy/lrw/evented.ex` | **New home** of the previous LRW hook policy (default). |
| `lib/cachex/policy/lrw/scheduled.ex` | **New** timer policy: `:batch_size`, `:frequency`, bound enforcement. |
| `lib/cachex/services.ex` | Supervise policy servers alongside other cache services. |

**Counts:** 5 substantive implementation files. Tests separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/cachex/policy/lrw/scheduled_test.exs` | **New**: no-limit non-eviction, cross-limit eviction, expired-key reclaim (`"evicting with no upper bound"`, `"evicting when a cache crosses a limit"`, `"evicting by removing expired keys"`). |
| `test/cachex/policy/lrw_test.exs` | Shared/evented LRW behavior stays green. |
| `test/cachex/policy_test.exs` | Policy behaviour surface. |
| `test/cachex/services_test.exs` | Service wiring. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| (moduledoc updates in policy modules) | Documentation embedded in impl files — not extra count. |

## Draft clarified feature brief

> Add a least-recently-written eviction policy that enforces cache limits on a schedule instead of on every write hook, for lower memory use. It must still evict oldest-writer entries when the cache crosses its limit, support a batch size for how many keys to drop at a time, and leave the existing evented LRW behavior available. Caches without an upper bound must not evict. Keep today’s default LRW behavior unless the policy is explicitly selected.

Keep “scheduled LRW policy”, batch size, and frequency as requested outcomes if graded. Do **not** require the author’s later rename of `enforce_bounds` (PR body says the public name was still open).

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **No bound:** 5000 keys stay when no max size (`"evicting with no upper bound"`). |
| A2 | **Cross limit:** cache trims to bounds; oldest entries evicted first (`"evicting when a cache crosses a limit"`). |
| A3 | **Expired keys:** schedule also reclaims expired entries (`"evicting by removing expired keys"`). |
| A4 | **Scheduled module selectable:** `limit: Cachex.Policy.LRW.Scheduled` (with options) runs without hook-message flooding. |
| A5 | **Evented preserved:** existing LRW/evented tests still pass. |
| A6 | **Batch/frequency options:** custom `:batch_size` / `:frequency` are honored (moduledoc contract). |

## Incomplete control

**Compiling partial that misses one area:** implement `Cachex.Policy.LRW.Scheduled` and shared prune helpers, but leave `Cachex.Services` not starting the policy server.

- Module loads; **A2/A3** fail (no timer → no eviction).
- Second partial: copy evented hook policy under the Scheduled name → **A4** semantics wrong; A2 may pass by accident — require a memory/hook-message-free construction note in curator checks, not in the ticket.

## Integrity / shortcut rejection

Reject patches that:

- Evict when no limit is set (A1).
- Drop newest entries instead of least-recently-written.
- Remove the evented policy or break its default (A5).
- Use unbounded `Enum` scans that defeat the “low memory” purpose as a hidden perf-only claim — score functional eviction, not latency.

## Preservation of existing behavior

- Default limit policy remains evented LRW (PR author considered changing the default and did not require it in the brief).
- `Cachex.Policy.LRW` stays importable for existing users.
- Policy behaviour still provides `hooks/1`; removing `child_spec/1`/`strategy/0` must not break third-party policies that only implement `hooks/1` (overridable defaults already covered).

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.5` at base | Cachex `3.4.0`. |
| Services | None. ETS + ExUnit. |
| Timing | Scheduled tests use cache limits and may need short waits; pin a generous but bounded assert style (upstream already does this). |
| MIT | Provenance notice. |
| Public name `enforce_bounds` | Author unsure; **do not grade that symbol** unless the brief freezes a name. |

Not verified here: compile/test/boot.

## Status: discovered

Five-file policy feature with real eviction assertions and an explicit evented-vs-scheduled product choice. Second Cachex family (limits) next to warmer naming (#341).

## Next action

1. Pin base `fc4f2a0d9ce30842ce2eb0d51d9c3f743fc5867e`.
2. Freeze whether the brief names `Cachex.Policy.LRW.Scheduled` (recommended: yes — public module) and leave `enforce_bounds` ungraded.
3. Incomplete = policy module without service start.
4. Acceptance: `test/cachex/policy/lrw/scheduled_test.exs` + existing `lrw_test.exs` preservation.
