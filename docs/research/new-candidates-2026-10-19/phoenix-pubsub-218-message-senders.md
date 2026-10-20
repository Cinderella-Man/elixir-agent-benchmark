# Phoenix.PubSub #218 — Message senders

**Status:** discovered  
**Source type:** historical PR (feature + immediate follow-ups)  
**Project:** [phoenixframework/phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub)  
**PRs:** [#218](https://github.com/phoenixframework/phoenix_pubsub/pull/218) (core), [#219](https://github.com/phoenixframework/phoenix_pubsub/pull/219) (followups), [#220](https://github.com/phoenixframework/phoenix_pubsub/pull/220) (finalize callback)  
**Source revisions:** base `01cf8ed2d71f9f7798314fe79a766214131238ad` → merge `391d814f55ce09e5ab1f43e1e447c552a3e65908`  
**Author:** SteffenDE (core), follow-ups same thread with josevalim  
**Merged:** 2026-10-06 / 2026-10-07 / 2026-10-08  
**Task kind / family:** feature / PubSub sender behaviour  
**Research date:** 2026-10-19

## Authentic work

Introduces a **message sender** abstraction so custom send-side behavior (not just dispatch) can be plugged into PubSub. This is a coherent new capability across the public API, a new behaviour module, and supervisor wiring, with distributed tests. Immediate follow-ups (#219, #220) adjust the API surface (`finalize`) — a feature-then-correction lineage in a three-day window.

PR #218 body is empty; meaning must be taken from the diff and follow-ups. #220 discusses versioning (optional callback vs 2.4.1 vs 2.5.0).

## Implementation scope (core #218)

| File | Role |
| --- | --- |
| `lib/phoenix/pubsub.ex` | Public API for senders on broadcast paths |
| `lib/phoenix/pubsub/sender.ex` | **New** sender behaviour |
| `lib/phoenix/pubsub/supervisor.ex` | Wire sender configuration |
| `test/phoenix/pubsub_test.exs` | Single-node sender tests |
| `test/phoenix/distributed_pubsub_test.exs` | Distributed sender coverage |
| `test/support/remote_dispatcher.ex`, `test/support/node_case.ex` | Test support |

**Counts:** 3 substantive implementation files. Tests and support counted separately.

## Cross-component behavior to verify

- Sender module is invoked on the send path without changing ordinary default delivery.
- Supervisor option ↔ public API ↔ behaviour callbacks stay aligned (including `finalize` if the case includes #220).
- Local and distributed broadcast both honor the sender.
- Missing/optional callbacks do not break default senders (see #220 discussion).

## Draft ticket (feature brief — needs curator settle)

> Let me plug a custom message sender into a PubSub the same way I can plug a dispatcher, so sends go through my module. Ordinary PubSub behavior with no sender configured must stay unchanged. [If including follow-ups: the sender lifecycle must include an explicit finalize step when the library exposes one.]

**Contract hold:** the exact callback set and whether `finalize` is required are product/API decisions from #219/#220. Freeze one lineage before scoring. Do not mix an optional-callback design with a required-callback hidden check.

## Acceptance design (proposed, unexecuted)

- Configure a recording sender; assert it observes/handles sends for local broadcast.
- Unconfigured PubSub: byte-for-byte ordinary delivery.
- If #220 is included: assert `finalize` runs exactly once at the documented boundary.
- Distributed test only if the brief claims cluster behavior; otherwise keep single-node and preserve existing distributed suite.

## Plausible incomplete (proposed)

Implement `sender.ex` and wire `broadcast/3` but leave `direct_broadcast` (or distributed path) on the old code path.

## Integrity control (proposed)

Reject a “sender” that is ignored (always fall back to default module) or that changes default message payload/shape.

## Runtime / offline

- Elixir `~> 1.13` family at the base revision; confirm from `mix.exs` + historical CI.
- No DB. Distributed tests use `:peer` / node cases in-repo — **multi-node OTP is a runner question**. Prefer a single-node acceptance surface unless `Fixtures`/`Sandbox` already support peer nodes.

## License / provenance

- MIT (same Phoenix.PubSub license).
- Author is a Phoenix team member (SteffenDE); follow-up discussion includes José Valim — authentic upstream, not a synthetic request.

## Holds / unknowns

- Empty PR body → draft ticket must be reconstructed from diffs; needs independent contract review before any hidden checks.
- Lineage: decide **core only** vs **core+finalize** as one task. Do not count #218 and #219/#220 as three cases.
- Multi-node support in the existing runner is unverified.

## Coverage added

OTP messaging extension points / behaviour callbacks. Distinct from Phoenix web cases.

## Next action

Read the three diffs together, freeze one API surface, then draft a brief that states only that surface. Treat multi-node as optional preservation unless the runner already isolates peer nodes offline.
