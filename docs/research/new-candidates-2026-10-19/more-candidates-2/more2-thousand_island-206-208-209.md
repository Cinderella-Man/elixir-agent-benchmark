# Thousand Island #206 + #208 + #209 — acceptor-loop resilience (fd exhaustion, transient accept errors, handler start failure)

**Status:** discovered
**Source type:** historical PR lineage (3 same-day related merges)
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)
**PRs:**
- [#206](https://github.com/mtrudel/thousand_island/pull/206) *Back off on :emfile / :enfile in the accept loop instead of crashing the server* — mpettibone, merged `14de02fc6e86b79b1837e8cc6d66b2944c275301` (2026-08-20)
- [#208](https://github.com/mtrudel/thousand_island/pull/208) *Retry the transient network errors accept(2) documents instead of crashing the acceptor* — mpettibone, merged `0453daf2ec954abe1c5ac59ea4b73eec6af26826` (2026-08-20)
- [#209](https://github.com/mtrudel/thousand_island/pull/209) *Survive handler start failure: close the socket and keep accepting* — mpettibone, merged `8c3199730cbf85faff75bf69996873d50fd1e68b` (2026-08-20)

**Source revisions:** pre-#206 base → apply #206 → #208 → #209 (all same author, same day, same subsystem). Merge SHAs are squash commits.
**Task kind / family:** bug_fix / OTP acceptor lifecycle and telemetry
**Research date:** 2026-10-19
**Exposure:** public historical PRs

## Authentic work

Thousand Island's acceptor loop treated several recoverable accept/spawn conditions as fatal. Because acceptors are `restart: :transient` Tasks under a supervisor with a restart budget, a burst of these errors crashed the acceptor, escalated through the supervision tree, and killed in-flight connections.

Three related fixes (same author, same day) make the accept loop survive each recoverable class:

1. **#206** — `:emfile` / `:enfile` (file-descriptor exhaustion): back off 100ms and keep accepting instead of crashing. Emit `[:thousand_island, :acceptor, :emfile]`.
2. **#208** — transient network errors that `accept(2)` documents as retryable (`:enetdown`, `:enetunreach`, `:ehostdown`, `:ehostunreach`, `:enonet`, `:eproto`, `:enoprotoopt`, `:eopnotsupp`, `:etimedout`): retry immediately and keep accepting. Emit `[:thousand_island, :acceptor, :accept_error]`.
3. **#209** — handler process fails to start (init returns `{:stop, _}` or `:ignore`): `ThousandIsland.Connection` closes the raw socket and returns `{:error, {:spawn_error, reason}}`; the acceptor emits `:spawn_error` and keeps accepting instead of crashing.

Per [LINEAGE-MERGE-POLICY](../large-features/LINEAGE-MERGE-POLICY.md), merge into one case whose ticket describes the final acceptor-resilience outcome. Each intermediate is a natural incomplete control.

## Implementation scope (combined reference)

| File | Role |
| --- | --- |
| `lib/thousand_island/acceptor.ex` | New clauses for `:emfile`/`:enfile` (back off), `@transient_accept_errors` (retry), and `{:spawn_error, reason}` (keep accepting); telemetry span events |
| `lib/thousand_island/connection.ex` | On handler-start failure, close the raw socket and return `{:error, {:spawn_error, reason}}` (also for `:ignore` / nonstandard returns) |
| `lib/thousand_island/telemetry.ex` | Document + type `:emfile`, `:accept_error`, and `:error` measurement on `:spawn_error` |
| `lib/thousand_island/logger.ex` | Attach `:emfile` and `:accept_error` to the error logger |
| `test/thousand_island/acceptor_test.exs` | New file: `FlakyTransport` injects accept errors; `FailInitHandler` fails init; named survival + telemetry tests |
| `test/support/telemetry_helpers.ex` | Attach the new acceptor events |

**Counts:** 4 substantive implementation files, 2 test/support files.

## Cross-component behavior to verify

- Descriptor exhaustion (`:emfile`/`:enfile`): acceptor does not crash; in-flight connections survive; new connections still accepted after the burst; `:emfile` telemetry fires with `error` measurement.
- Transient accept(2) errors: acceptor retries; in-flight connections survive; `:accept_error` telemetry fires with the reason.
- Handler start failure (`init` → `{:stop, _}` or `:ignore`): accepted socket is **closed** (client sees `{:error, :closed}`); acceptor pid unchanged; `:spawn_error` telemetry carries the start reason; server keeps accepting.
- Too-many-connections path is unchanged (`:spawn_error` without `:error` measurement).
- Ordinary accept → handshake → handle_data path is unchanged.

## Draft ticket (short maintenance report)

> The accept loop treats several recoverable conditions as fatal: running out of file descriptors (`emfile`/`enfile`), transient network errors that accept(2) says to retry, and a handler process that fails to start after the socket was accepted. Each of these can crash the acceptor and take down its in-flight connections. Please make the acceptor survive all three: back off briefly on descriptor exhaustion, retry transient accept errors, and on handler-start failure close the accepted socket and keep accepting. Emit telemetry for each recovery so operators can see it.

## Acceptance design (proposed, unexecuted)

- Inject five `:emfile`/`:enfile` accept results (past the restart budget); assert the existing connection still echoes and a new connection works; acceptor pids unchanged.
- Inject the full `@transient_accept_errors` list; same survival assertions; `:accept_error` telemetry carries a reason.
- Handler whose `init` returns `{:stop, :intentional_init_failure}` or `:ignore`: six connections in a row each get `{:error, :closed}` on recv; acceptor pid unchanged; `:spawn_error` telemetry carries the reason.
- Ordinary echo connection still works (preservation).

## Plausible incomplete (proposed)

Handle only `:emfile`/`:enfile` back-off (#206) and still crash on transient accept errors or handler-start failure. Compiles; the corresponding named survival test fails.

## Integrity control (proposed)

Acceptance must not pass if recovery also swallows `:closed` (listener close must still stop the span), if handler-start failure leaves the socket open (client would not see `:closed`), or if too-many-connections stops emitting `:spawn_error`.

## Runtime / offline

- Elixir `~> 1.13` (from `mix.exs`). In-process TCP via `:gen_tcp` and a test `FlakyTransport`; no external services.
- Node/browser not required. Machete used in upstream assertions (dev dependency).

## License / provenance

- MIT (Thousand Island). Public GitHub PRs. No private edition.
- Single author across all three PRs. Attribute all three in provenance; do not score as three cases.

## Holds / unknowns

- This is the **acceptor-loop** family. Do not merge with [#211 handshake_timeout](more2-thousand_island-211.md) (connection handshake bound) — different subsystem (config/transport vs acceptor), even though both are Thousand Island resilience work.
- Already-filed TI identities (228/220/222/216) are socket-ownership, telemetry-exception, and connection-start separation — different families. Keep separate.
- `Process.sleep` in the fd-exhaustion back-off and in tests is part of the reference; grade behavior (survival, telemetry), not sleep duration.

## Coverage added

OTP acceptor/telemetry resilience on a real TCP server stack — complements filed Thousand Island socket-ownership and telemetry-exception work at a different layer (accept loop vs connection lifecycle).

## Next action

If drafting: pin pre-#206 base, apply #206 → #208 → #209, freeze the three survival contracts + telemetry names, and use "#206 only" or "#206+#208 without #209" as incomplete controls.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Product story is right: three recoverable accept/spawn conditions must not kill the acceptor. The draft does not name modules or the fix — good.

**Hidden requirement: telemetry event names.** The ticket says only "Emit telemetry for each recovery so operators can see it." Acceptance asserts `[:thousand_island, :acceptor, :emfile]`, `[:thousand_island, :acceptor, :accept_error]`, and `:spawn_error` with an `error` measurement. Those names are operator-facing public API. Either put them in the ticket or grade "a telemetry event fires with an error measurement" without pinning the event name. Pinning them in hidden checks while the ticket says only "emit telemetry" is unfair.

"Back off briefly" is fine ungraded (reference uses `Process.sleep(100)`). Do not grade duration.

### 2. Named deterministic checks (ExUnit, no sleep)

Upstream `acceptor_test.exs` (in the diffs) is **not** gradeable as-is: it uses `Process.sleep(800)` and `Process.sleep(300)` to wait for injected accept errors to drain. The brief requires **no sleep**. Rewrite around blocking round-trips.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `emfile-survives` | FlakyTransport injects 5× `:emfile`/`:enfile`; 1 live echo connection open; then a new connect | send/recv on both connections; `acceptor_sup_pids` | both echo; acceptor pids unchanged |
| `emfile-telemetry` | inject 1× `:emfile` | telemetry handler | event fires with `error: :emfile` |
| `transient-survives` | inject full `@transient_accept_errors` list | same as above | both echo; pids unchanged |
| `transient-telemetry` | inject 1× `:ehostunreach` | telemetry | event fires with the reason |
| `spawn-error-closes-socket` | handler `init` → `{:stop, _}` or `:ignore`; 6 sequential connects | client `recv` | each returns `{:error, :closed}`; acceptor pids unchanged; `connection_pids` empty |
| `spawn-error-telemetry` | same | telemetry | `:spawn_error` carries `error: :intentional_init_failure` |
| `preserve ordinary-echo` | plain Echo handler | send/recv | echo works |
| `preserve too-many-connections` | exceed `num_connections` | telemetry | `:spawn_error` **without** an `error` measurement (limit path unchanged) |
| `preserve listener-close` | stop the server mid-accept | span | `:closed` still stops the acceptor span (recovery must not swallow `:closed`) |

Determinism trick (replaces sleep): after injecting N errors, issue a new `:gen_tcp.connect` + `send` + `recv` with a **bounded timeout** (2–5s). The recv blocks until the acceptor has drained the injected errors and accepted the connection. That is a deadline, not a sleep-and-hope.

### 3. Ambiguity / unfairness

- Telemetry names (above) — biggest issue.
- `:spawn_error` measurement shape (`error` present on handler-start failure, absent on too-many-connections) is a real contract. If graded, say "handler-start failures report the start reason" in the ticket. Currently silent.
- "Close the accepted socket" is observable (client `recv` → `{:error, :closed}`). Keep that; do not grade *how* the socket is closed.
- Do not grade the 100ms backoff or the exact `@transient_accept_errors` membership beyond "the errors accept(2) documents as retryable" — a defensible superset (e.g. also `:einval`, which the test list includes) is fine.

### 4. Shortcuts + compiling incomplete

- Incomplete A = #206 only (`:emfile` backoff). Compiles. Fails `transient-survives` and/or `spawn-error-closes-socket`.
- Incomplete B = #206+#208, omit #209. Compiles. Fails `spawn-error-closes-socket`.
- Shortcut: recover by swallowing every accept error including `:closed`. Caught by `preserve listener-close`.
- Shortcut: handler-start failure leaves the socket open. Caught by `spawn-error-closes-socket` (client would not see `:closed`).
- Shortcut: reset the too-many-connections path to also emit `error`. Caught by `preserve too-many-connections`.

### 5. Flakiness

**High if upstream tests are reused.** `Process.sleep(800)` after 5×100ms backoff is timing roulette; under load this flakes. Rewrite as in §2. Also: `async: false`, `num_acceptors: 1`, and `:persistent_term` injection of accept results are sound isolation, but the *drain* must be synchronized by a blocking recv, not time. Telemetry `assert_receive` with a 1–5s bound is fine.

### 6. Preservation mix

Good bones (ordinary echo + too-many-connections + listener close). Add explicitly:
- Positive: each of the three recovery classes (survival + telemetry).
- Negative/integrity: `:closed` still ends the span; too-many-connections unchanged.
- Mixed: one recovery class, then ordinary traffic on the same acceptor (proves the loop continued, not that it wedged in a recovery branch).

### 7. Environment risk

Good. In-process `:gen_tcp`, no external services. Elixir `~> 1.13`. Machete is a dev dep (fine). MIT. Single author across all three PRs — one case.

**Evidence gap:** no `mix test` receipt. Diffs exist; tests are written but never executed here.

### 8. Verdict

**READY-WITH-FIX** — coherent acceptor-lifecycle work across 4 impl files, but the graded checks as written sleep, the telemetry names are a hidden requirement, and nothing has been run.

### 9. Must-fix list

1. Put telemetry event names (or "an event carrying the error reason") in the ticket. Do not pin names in hidden checks only.
2. Rewrite acceptance to blocking recv / `assert_receive` deadlines. **Discard** upstream `Process.sleep(800)`/`sleep(300)` as graded checks.
3. Execute the combined tree (#206+#208+#209); record named outcomes.
4. Incomplete = #206 only; name `transient-survives` or `spawn-error-closes-socket` as the failure.
5. State the `spawn_error` measurement rule (reason present on handler-start failure, absent on connection-limit) if it is graded.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Sleep-based upstream tests + hidden telemetry names + unexecuted |
