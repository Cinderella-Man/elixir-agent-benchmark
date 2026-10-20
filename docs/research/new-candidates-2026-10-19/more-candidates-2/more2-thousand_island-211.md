# Thousand Island #211 — `handshake_timeout` server option (bounded TLS handshake)

**Status:** discovered
**Source type:** historical PR
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)
**PR:** [#211](https://github.com/mtrudel/thousand_island/pull/211) — *add a handshake_timeout server option*
**Source revisions:** base = first parent of merge `a2858bbe3d5196c75028fccade983fd8486321ba` (pin at draft) · PR has 7 commits (squash-merged)
**Author:** mpettibone · **Merged:** 2026-08-20
**Task kind / family:** feature / transport handshake lifecycle + public server option
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

A client that connects and then stalls mid-handshake (e.g. opens TCP but never completes TLS negotiation) held its connection process and its `num_connections` slot indefinitely, because `ThousandIsland.Socket.handshake/1` called `transport.handshake/1` with no bound.

The PR adds a `handshake_timeout` server option (default `5_000` ms, matching Ranch; `:infinity` restores the old unbounded behaviour) and an optional `c:ThousandIsland.Transport.handshake/2` callback that accepts a timeout. Stalled handshakes are closed and surfaced to the handler via `c:ThousandIsland.Handler.handle_error/3` with reason `:timeout`. Transports that only implement `handshake/1` keep working (timeout is ignored for them).

## Implementation scope

| File | Role |
| --- | --- |
| `lib/thousand_island.ex` | Document + type `handshake_timeout` in the server-option list |
| `lib/thousand_island/server_config.ex` | New field, default `5_000` |
| `lib/thousand_island/handler_config.ex` | Thread the field through to handlers |
| `lib/thousand_island/socket.ex` | Carry the field; `handshake/1` dispatches to `handshake/2` when exported, else `handshake/1` |
| `lib/thousand_island/transport.ex` | Optional `@callback handshake(socket(), timeout()) :: on_handshake()` + `@optional_callbacks handshake: 2` |
| `lib/thousand_island/transports/ssl.ex` | Implement `handshake/2` via `:ssl.handshake(socket, timeout)`; `handshake/1` delegates with `:infinity` |
| `lib/thousand_island/transports/tcp.ex` | Implement `handshake/2` as pass-through (TCP has no handshake) |
| `test/thousand_island/config_test.exs` | Default `5_000` and `:infinity` acceptance |
| `test/thousand_island/socket_test.exs` | Stalled-handshake timeout, normal handshake, legacy `handshake/1`-only transport fallback |

**Counts:** **7 substantive implementation files**, 2 test files. This is the batch's 5–10-file feature candidate.

## Cross-component behavior to verify

- `ServerConfig` default is `5_000`; `handshake_timeout: :infinity` is accepted and stored.
- `HandlerConfig` and `Socket` carry the value; `Socket.handshake/1` uses it.
- `Transport` behaviour: optional `handshake/2`; transports without it still work.
- SSL: stalled TLS negotiation is closed within the timeout; handler gets `handle_error(..., :timeout, ...)`.
- TCP and custom `handshake/1`-only transports are unaffected (timeout ignored).
- Within the timeout, a normal handshake completes and data flows (preservation).
- Non-handshake connection lifecycle (read_timeout, shutdown) unchanged.

## Draft ticket (clarified implementation brief)

> Add a `handshake_timeout` server option that bounds how long a transport handshake (such as TLS negotiation) may take after a client connects. Default it to 5000 ms; allow `:infinity` to mean unbounded (today's behaviour). When a handshake does not finish in time, close that connection and call the handler's `handle_error/3` with reason `:timeout`, so a stalled client cannot hold a connection slot forever. Transports that implement the existing handshake callback without a timeout argument must keep working — only pass the timeout when the transport supports it. Ordinary connections that complete their handshake in time, and transports without a handshake (TCP), must behave exactly as before.

Public names to freeze if graded: server option `:handshake_timeout`, optional transport callback `handshake/2`, handler error reason `:timeout`.

## Acceptance design (proposed, unexecuted)

- Config: `ServerConfig.new` defaults `handshake_timeout` to `5_000`; `:infinity` accepted.
- Stalled TLS handshake (TCP connect, never start TLS) with `handshake_timeout: 250`: handler receives `{:handle_error, :timeout}`; connection pids empty; client recv returns `{:error, :closed}`.
- Normal handshake within timeout: echo still works (preservation).
- Legacy transport implementing only `handshake/1`: connection works even with `handshake_timeout: 250` set (fallback).
- SSL `handshake/1` (arity 1) still exists and behaves as unbounded (compat).

## Plausible incomplete (proposed)

Wire `handshake_timeout` through `ServerConfig`/`HandlerConfig`/`Socket` and the SSL transport, but forget the `handshake/1`-only fallback (or forget TCP's `handshake/2`). Compiles; the legacy-transport named test fails.

## Integrity control (proposed)

Acceptance must not pass if the timeout is applied to TCP reads (that is `read_timeout`), if `:infinity` is not accepted, if a successful handshake within the bound is rejected, or if removing the optional-callback dispatch breaks `handshake/1`-only transports.

## Runtime / offline

- Elixir `~> 1.13` (from `mix.exs`). In-process TCP/SSL via `:gen_tcp`/`:ssl`; no external services. `capture_log` on the stalled-handshake test.
- Node/browser not required.

## License / provenance

- MIT (Thousand Island). Public GitHub PR. No private edition.

## Holds / unknowns

- Do not merge with [#206+#208+#209 acceptor resilience](more2-thousand_island-206-208-209.md) — different subsystem. Both are valid separate cases.
- Default `5_000` and `:infinity` escape hatch are product decisions visible in the patch; state them in the brief (done above) rather than hiding them in tests.
- `function_exported?/3` dispatch is an implementation choice; an alternative (behaviour with a single timeout-taking callback plus a shim) is acceptable if the observable contract holds.
- Bandit consumes Thousand Island; a Bandit-level handshake-timeout case would be a different (downstream) task. Out of scope here.

## Coverage added

Public server-option + optional transport-behaviour extension across 7 coordinated files. Distinct from the acceptor-resilience lineage and from already-filed TI socket-ownership/telemetry work. This is the batch's 5–10-file feature.

## Next action

If drafting: pin Elixir/OTP from historical CI at merge, freeze the option/callback/error-reason names from the brief, and use "SSL timeout wired but no legacy fallback" as the incomplete control.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

This is the right shape for a feature brief: the product decisions are visible (default `5000`, `:infinity` escape hatch, `handle_error/3` with `:timeout`, legacy `handshake/1`-only transports keep working). Public names are listed for freezing — good.

One soft spot: "Only pass the timeout when the transport supports it" describes the *reference's* dispatch (optional callback + `function_exported?`). A solver who always calls `handshake/2` and ships a shim that delegates to `handshake/1` is implementing the same contract. The dossier already says that is acceptable — keep that freedom in grading and do not name `function_exported?/3` in checks.

"Ordinary connections that complete their handshake in time… must behave exactly as before" is the right preservation clause.

### 2. Named deterministic checks (ExUnit, no sleep)

Proposed, unexecuted. This feature is **inherently wall-clock** — a timeout. That is acceptable: use the timeout as the mechanism and assert on the observable outcome inside a bounded deadline. Do **not** add `Process.sleep`.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `config default-5000` | `ServerConfig.new(...)` | `handshake_timeout` | `5_000` |
| `config infinity-accepted` | `handshake_timeout: :infinity` | stored value | accepted, not coerced |
| `ssl stalled-handshake-closed` | TCP connect, never speak TLS; `handshake_timeout: 250` | handler + client | `handle_error(..., :timeout, ...)`; connection pids empty; client `recv` → `{:error, :closed}` |
| `ssl normal-handshake-works` | complete TLS within the bound | echo | data flows (preservation) |
| `legacy handshake/1-only transport` | custom transport exporting only `handshake/1`; `handshake_timeout: 250` | connection | still works (timeout ignored) |
| `tcp unaffected` | TCP transport | connection lifecycle | unchanged; timeout not applied to reads |
| `ssl handshake/1 still unbounded` | call `handshake/1` on SSL | return | behaves as `:infinity` (compat) |
| `preserve read-timeout` | stall *after* handshake | existing `read_timeout` path | unchanged (do not conflate with `handshake_timeout`) |

Determinism: `handshake_timeout: 250` is the mechanism. Assert with a generous deadline (`assert_receive` / `recv` timeout 2s), not `Process.sleep(250)`. Under CI load, 250ms may race the test harness's own setup — if flaky, raise the option to 500ms and keep the assertion deadline at 2–5s. That is still deterministic (bounded), not sleep roulette.

### 3. Ambiguity / unfairness

- Default `5000` and `:infinity` are stated — good. They were the main hidden-constructor risk and are already fixed.
- `:timeout` as the `handle_error/3` reason is stated. If a solver returns `{:error, :timeout}` instead of routing through `handle_error`, that is a different contract. Ticket is clear enough; grade the handler callback.
- Whether `handshake_timeout` also bounds the window *before* `handshake/2` is called (connection boot) is unspecified. Reference bounds the handshake call only. Do not grade the broader interpretation.
- Do not grade which module dispatches to `handshake/2`.

### 4. Shortcuts + compiling incomplete

- Incomplete A = wire `ServerConfig`/`HandlerConfig`/`Socket`/SSL, forget the `handshake/1`-only fallback. Compiles. Fails `legacy handshake/1-only transport`.
- Incomplete B = forget TCP's `handshake/2` pass-through. Compiles. Fails `tcp unaffected` if the missing callback crashes or drops the timeout into the read path.
- Shortcut: apply the timeout to `read_timeout`. Caught by `preserve read-timeout`.
- Shortcut: treat `:infinity` as a crash / reject. Caught by `config infinity-accepted`.
- Shortcut: close the connection but never call `handle_error/3`. Caught by `ssl stalled-handshake-closed` (handler assertion).

### 5. Flakiness

Medium, and intrinsic to a timeout feature. The stalled-TLS test must not be a `sleep(250)` then assert — use blocking `recv`/`assert_receive` with a 2s bound. Keep `capture_log`. `num_acceptors: 1` if a server is started. No external network.

### 6. Preservation mix

Good: normal handshake within bound, TCP unaffected, `handshake/1` compat, read_timeout distinct. Also keep one test that a successful handshake is **not** rejected by the bound (timeout is not a hard close).

### 7. Environment risk

Good. In-process TCP/SSL via `:gen_tcp`/`:ssl`. Elixir `~> 1.13`. No services. MIT. 7 impl files is above the 2–5 preferred band but coherent (config → handler config → socket → transport behaviour → two transports) and this is the batch's intended large-feature slot.

**Evidence gap:** unexecuted. Diffs in `_work/thousand_island-211.diff` show the full surface.

### 8. Verdict

**READY-WITH-FIX** — well-specified feature with visible product decisions and a real 7-file cross-component contract; needs executed checks and a no-sleep rewrite of the timeout test.

### 9. Must-fix list

1. Execute `config_test` + `socket_test` at base+patch; record outcomes.
2. Stalled-handshake check must use bounded blocking recv/`assert_receive`, never `Process.sleep`. Raise the option to 500ms if 250ms is tight.
3. Incomplete = SSL timeout wired but no `handshake/1`-only fallback; name `legacy handshake/1-only transport`.
4. Do not grade `function_exported?/3` or any particular dispatch mechanism.
5. Keep `preserve read-timeout` so a solver who over-applies the bound is caught.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Time-based test flake + unexecuted acceptance |
