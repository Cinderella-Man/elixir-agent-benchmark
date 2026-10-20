# Thousand Island #220 — Handle socket ownership-transfer errors during connection start

**Status:** discovered  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)  
**PR:** [#220](https://github.com/mtrudel/thousand_island/pull/220)  
**Source revisions:** base `e9a5ae259a103911728f92c15cbcbecf99662570` → merge `62385e80f43d2197ac55b4092cc8ca44be7491d6`  
**Author:** mpettibone · **Merged:** 2026-08-31  
**Task kind / family:** bug_fix / accept-path lifecycle  
**Research date:** 2026-10-19

## Authentic work

When `transport.controlling_process/2` fails during connection setup, the accept path did not consistently clean up: socket close, idle handler termination, typed error, and telemetry. The PR makes that failure mode first-class and observable. PR body notes Claude-assisted discovery of transport-spec non-conformance — treat the **code and tests** as evidence, not the tool story.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/thousand_island/acceptor.ex` | Keep acceptor alive on per-connection setup failure; emit spawn_error |
| `lib/thousand_island/connection.ex` | Check controlling_process result; cleanup path |
| `lib/thousand_island/transport.ex` | Contract/typed error `{:controlling_process, reason}` |
| `test/thousand_island/acceptor_test.exs`, `connection_test.exs`, `server_test.exs` | Deterministic custom-transport regressions |

**Counts:** 3 substantive implementation files, 3 test files.

## Cross-component behavior to verify

- Failed ownership transfer: accepted socket closed, idle handler child terminated, handler never receives `handle_connection`.
- Acceptor remains alive and can accept later connections.
- Existing `:spawn_error` telemetry still fires, now with the error attached.
- Successful transfer path unchanged (positive preservation).

## Draft ticket (short maintenance report)

> If handing an accepted socket to the connection process fails, cleanup is incomplete: sockets and handlers can leak and the failure is hard to observe. Make ownership-transfer failure during connection start close the socket, stop the idle handler, leave the acceptor healthy, and report a typed error. Keep the normal accept path working. Fix it.

## Acceptance design (proposed, unexecuted)

- Custom test transport that fails `controlling_process/2` on demand (pattern already in upstream tests).
- Assert socket close + handler down + acceptor alive + spawn_error telemetry + typed reason.
- Preserve successful connections and ordinary spawn errors.

## Plausible incomplete (proposed)

Handle the error in `connection.ex` but forget to keep the acceptor from dying; or emit telemetry without closing the socket.

## Integrity control (proposed)

Reject “fixes” that swallow the error and pretend the connection started, or that kill the whole server on one failed transfer.

## Runtime / offline

- Elixir `~> 1.13`, Thousand Island ~1.5 line at base.
- No external services. Custom transport keeps it deterministic and offline.

## License / provenance

- MIT (Mat Trudel). Contributor PR with maintainer merge.

## Holds / unknowns

- Same base family as #222 (both base `e9a5ae2…`) — they may share ancestry; do not double-count as unrelated coverage if later combined as a socket-lifecycle family in reporting.
- “Typed error” shape must be in the visible brief if scored.

## Coverage added

Transport contract enforcement and process cleanup under failure — different from #228’s metadata cache.

## Next action

Good second Thousand Island candidate after (or before) #228. Pair only in reporting as “socket lifecycle family”, not as one merged task unless a single coherent outcome is written.
