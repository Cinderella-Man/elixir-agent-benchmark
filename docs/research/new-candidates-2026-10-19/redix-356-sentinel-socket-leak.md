# Redix #356 — Fix leaking socket in sentinel path

**Status:** discovered  
**Source type:** historical PR  
**Project:** [whatyouhide/redix](https://github.com/whatyouhide/redix)  
**PR:** [#356](https://github.com/whatyouhide/redix/pull/356)  
**Source revisions:** base `6e95bbd533f7d2c8d6fde5f30269a8fe52628794` → merge `933edc09fe6428c8f90e368115b85a057935a385`  
**Author:** Linuus · **Merged:** 2026-10-14  
**Task kind / family:** bug_fix / connection resource leak  
**Research date:** 2026-10-19

## Authentic work

In the Redis Sentinel path, when a sentinel reports a server with the **wrong role**, or the ROLE check fails, the connector never closed the server socket before trying the next sentinel. If a later sentinel worked, the leaked socket stayed open for the life of the connection.

Clear user/caller problem: connection setup leaves fds/sockets open. Small but real, with an upstream fake-node regression.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/redix/connector.ex` | Close server socket on role/ROLE failure before next sentinel |
| `test/redix/connector_test.exs` | Fake-node regression |

**Counts:** 1 substantive implementation file, 1 test file. **Focused one-file task** (allowed as a smaller corpus slice).

## Cross-component behavior to verify

- Wrong-role server: socket closed, next sentinel tried.
- ROLE check failure: same.
- Successful sentinel path: exactly one live server socket (no close of the good one).
- Ordinary (non-sentinel) connect path unchanged.

## Draft ticket (short maintenance report)

> When Sentinel hands us a server with the wrong role, or the role check fails, the already-opened server socket is left open while we try the next Sentinel. If a later Sentinel works, that socket stays leaked. Close those sockets and keep the successful path working. Fix it.

## Acceptance design (proposed, unexecuted)

- Fake sentinel/node fixture: fail ROLE once, succeed later; assert the failed attempt’s socket is closed (count opens/closes or observe transport).
- Happy path: still one connection, no extra close of the working socket.
- Non-sentinel connect preserved.

## Plausible incomplete (proposed)

Close on wrong-role only, forget ROLE-check failure; or close after selecting the next server (race/order).

## Integrity control (proposed)

Reject always closing every socket including the one that will be used, or skipping sentinel fallback entirely.

## Runtime / offline

- Elixir `~> 1.15` at base (from `mix.exs`).
- Fake-node test style already in the project → offline ExUnit, no real Redis/Sentinel service required for this bug.

## License / provenance

- Redix is MIT (verify exact LICENSE filename at SHA).
- Clear PR body with failure mode stated.

## Holds / unknowns

- One-file implementation: keep it as a focused reserve; do not pad with unrelated cluster work to hit 2–5 files.
- Confirm the fake fixture can observe socket lifetime deterministically (upstream added a test — adapt rather than invent a timing sleep).

## Coverage added

Resource-lifetime bug in a connection library; complements #351 cluster routing as a same-project family without merging them.

## Next action

Best **first Redix preparation candidate** — small, described, tested. Then expand to #351 if more Redix coverage is wanted.
