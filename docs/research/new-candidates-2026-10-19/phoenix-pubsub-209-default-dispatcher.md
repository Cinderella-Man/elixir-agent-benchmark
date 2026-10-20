# Phoenix.PubSub #209 — Add configurable default dispatcher

**Status:** discovered  
**Source type:** historical PR  
**Project:** [phoenixframework/phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub)  
**PR:** [#209](https://github.com/phoenixframework/phoenix_pubsub/pull/209)  
**Source revisions:** base `0b63dce1765de0cb3f57f6c7e5cc6b4fc9ef0d98` → merge `228b82ec2cd1eae6f933e9a723fea82228476fd4`  
**Author:** twinn · **Merged:** 2026-04-17  
**Task kind / family:** feature / OTP PubSub configuration  
**Research date:** 2026-10-19  
**Exposure:** public historical PR

## Authentic work

An application that wants a custom broadcast dispatcher currently must pass it on every `broadcast` call or wrap `Phoenix.PubSub`. That is easy to miss at call sites. The PR adds a per-PubSub default `:dispatcher` so one supervision-tree option applies to all ordinary broadcasts, while still allowing a per-call override.

Motivation in the PR body is explicitly about test isolation / filtering broadcasts without a fragile wrapper.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/phoenix/pubsub/supervisor.ex` | Accept and store `:dispatcher` in the PubSub meta tuple |
| `lib/phoenix/pubsub.ex` | Broadcast helpers read configured default when no explicit dispatcher is passed |
| `test/phoenix/pubsub_test.exs` | Default dispatcher, per-call override, all broadcast variants |

**Counts:** 2 substantive implementation files, 1 test file. Mechanical/docs not present.

## Cross-component behavior to verify

- `child_spec`/`start_link` option → stored meta → every public broadcast entry point uses it.
- Default remains `Phoenix.PubSub` when the option is omitted (preservation).
- Explicit dispatcher argument still wins over the configured default.
- Applies to the broadcast family (`broadcast`, `broadcast!`, `direct_broadcast`, etc. — confirm exact names at the starting revision).

## Draft ticket (short maintenance report)

> Custom dispatching works only if every call site remembers to pass a dispatcher. Let me configure one default dispatcher for a PubSub at startup so ordinary broadcasts use it, while an explicit dispatcher on a call still overrides. Keep today’s behavior when nothing is configured.

Do **not** put the option name `:dispatcher` or the meta-tuple shape in the solver ticket unless it is declared as the requested public interface (the PR body treats `:dispatcher` as the product API — if graded, the brief must name it).

## Acceptance design (proposed, unexecuted)

- Start a PubSub with a test dispatcher that records/transforms messages; assert broadcasts arrive via that dispatcher.
- Same PubSub without the option: assert default delivery is unchanged.
- Per-call dispatcher overrides the default on the same PubSub.
- Cover each public broadcast variant used by the library.

## Plausible incomplete (proposed)

Wire the option in the supervisor but forget one broadcast entry point (e.g. `direct_broadcast`). Compile succeeds; a named assertion for that variant fails.

## Integrity control (proposed)

Acceptance must not pass if the solver makes the default always win over an explicit argument, or if they only change one helper and leave another on the hardcoded module.

## Runtime / offline

- Historical Mix: Elixir `~> 1.13` at base `0b63dce…` (from `mix.exs`).
- No database, no network service. Pure OTP + ExUnit.
- Node/browser not required.
- Cluster tests exist in the project; acceptance can stay single-node if the ticket does not claim distributed delivery.

## License / provenance

- MIT (`LICENSE.md` at merge): Copyright (c) 2014 Chris McCord.
- Public GitHub PR. No private edition.

## Holds / unknowns

- PR body is complete enough to settle the API; confirm at the starting revision whether all broadcast names that must honor the default are listed.
- Distributed dispatch behavior with a custom default is unspecified in the body — do not score cluster custom dispatch without a brief clause.
- Follow-up #210 (`:group_by`) is a **different** feature on the same meta path; do not bundle it.

## Coverage added

OTP / PubSub configuration and consistent multi-entry-point defaults. Not another Phoenix/LiveView web task.

## Next action

If drafting: pin Elixir/OTP from historical CI, write the ticket with `:dispatcher` as the requested public option (product decision already in upstream), and add a one-variant-missed incomplete control.
