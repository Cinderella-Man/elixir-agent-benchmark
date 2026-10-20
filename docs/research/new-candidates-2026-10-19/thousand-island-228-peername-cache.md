# Thousand Island #228 — Cache the peername on the socket

**Status:** discovered  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)  
**PR:** [#228](https://github.com/mtrudel/thousand_island/pull/228)  
**Source revisions:** base `e3eb2a7a05f98d79436abcefd8c954da2f8b05c0` → merge `9ef920e33a1ac8853bf92736c35759f5bc6c0680`  
**Author:** mtrudel · **Merged:** 2026-10-15  
**Task kind / family:** bug_fix / socket metadata lifetime  
**Research date:** 2026-10-19

## Authentic work

`ThousandIsland.Handler` looks up the peername at connection start (for process label and telemetry), then **discards** the value. Later `ThousandIsland.Socket.peername/1` does a fresh lookup on the live socket. If the client disconnects between those moments, the second lookup fails (`:enotconn` / `:einval`) and a handler that expects peername to work can crash.

The PR body describes this as a real race: client sends a few bytes then resets. That is ordinary connection-lifecycle work, not performance tuning.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/thousand_island/handler.ex` | Captures peername at start and stores it on the socket |
| `lib/thousand_island/socket.ex` | `peername/1` returns the cached value instead of a live lookup |
| `test/thousand_island/socket_test.exs` | Regression coverage |

**Counts:** 2 substantive implementation files, 1 test file.

## Cross-component behavior to verify

- Handler-start peername and later `Socket.peername/1` agree **after** the client is gone.
- Ordinary connected peername still returns the real address (positive preservation).
- Failure of the **initial** lookup still closes cleanly (`{:shutdown, {:premature_conn_closing, reason}}`) — do not paper over that path by inventing a dummy peername when none was obtained.
- Telemetry/process label still see the same peer address as handlers.

## Draft ticket (short maintenance report)

> After a client connects and then goes away, reading the connection’s peer address can crash the handler because the address is looked up again on a dead socket. Make the peer address stable for the life of the connection once it has been obtained, and keep the existing early-close behavior when it cannot be obtained at start. Fix it.

## Acceptance design (proposed, unexecuted)

- Custom/loopback connection: read peername, close/reset the client, read peername again → same value, no raise.
- Fresh connection while open: peername is the real peer (not a placeholder).
- Handler that only reads peername in `handle_connection` after the peer is gone does not crash.

## Plausible incomplete (proposed)

Cache in `handler.ex` for the process label/telemetry only, but leave `Socket.peername/1` as a live lookup. Compiles; the post-disconnect assertion fails.

## Integrity control (proposed)

Reject a repair that returns `nil`/`:error` for every peername, or that hardcodes `{{127,0,0,1}, 0}` regardless of the real peer.

## Runtime / offline

- Historical Mix: Elixir `~> 1.13`, version `1.5.0` at the base.
- Loopback TCP is enough; no external network. Prefer Unix-domain/TCP local fixtures already used by the suite.
- No PostgreSQL/ClickHouse/Node.

## License / provenance

- MIT: Copyright (c) 2018 Mat Trudel.
- Author is the maintainer. Problem statement is complete in the PR body.

## Holds / unknowns

- Confirm whether any other live socket metadata (sockname) is in scope — the PR is specifically peername; do not expand the ticket.
- Custom transport tests from sibling PRs (#220) are a different task; do not require them here.

## Coverage added

Connection lifecycle / socket metadata ownership. Complements HTTP client work already researched (Mint/Finch/Req/Tesla) without being another HTTP client task.

## Next action

Draft the short report above; map checks to “stable after disconnect” + “real peer when connected” + “unchanged premature close”. Good first preparation candidate (small Mix, ExUnit, loopback).
