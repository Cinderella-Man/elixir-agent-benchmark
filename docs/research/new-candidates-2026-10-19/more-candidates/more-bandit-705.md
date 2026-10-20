# Bandit #705 — HTTP/1 error response recovery on keep-alive and pipelining

**Status:** discovered
**Source type:** historical PR
**Project:** [mtrudel/bandit](https://github.com/mtrudel/bandit)
**PR:** [#705](https://github.com/mtrudel/bandit/pull/705)
**Source revisions:** base = first parent of merge (pin at draft) → merge `690b16b30ef513bef434dcf7fc313e5ee16bffe8`
**Author:** jeregrine · **Merged:** 2026-10-12
**Task kind / family:** bug_fix / HTTP/1 connection lifecycle
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

On HTTP/1 keep-alive and pipelined connections, error responses can be corrupted or lost:

1. A completed request's `{:plug_conn, :sent}` notification can still be in the mailbox when the next request is already being handled, so the next response's completion state is wrong (the CHANGELOG: "Preserve independent error responses … by discarding completed requests' sent-response notifications").
2. Empty 4xx/5xx error responses were framed with `connection: close` and **no** `Content-Length`, so their body delimiting depended on a clean EOF. If the connection then fails, the client never sees a complete error response. The fix explicitly frames empty error responses with `Content-Length: 0`.

Both fixes span the handler (when a request finishes / when to discard sent notifications) and the socket (how error responses are framed).

## Implementation scope

| File | Role |
| --- | --- |
| `lib/bandit/http1/handler.ex` | `discard_sent_notifications/0` after completing a request so the next request does not inherit stale `:sent` messages |
| `lib/bandit/http1/socket.ex` | Empty 4xx/5xx error responses get `Content-Length: 0` in addition to `connection: close` |
| `test/bandit/http1/protocol_test.exs` | Pipelined rejection with its own 431; content-length on empty errors; response-write failure paths |
| `test/bandit/http1/logging_test.exs` | Error-path logging expectations updated |
| `test/bandit/http1/plug_test.exs` | Plug-level error recovery cases |

**Counts:** 2 substantive implementation files, 3 test files.

## Cross-component behavior to verify

- Keep-alive: after request N completes, request N+1's response is not completed early by request N's `:sent` message.
- Pipelined header-count rejection: the 431 is its own complete response (not attached to the previous request).
- Empty 4xx/5xx: headers include `content-length: 0` (and still `connection: close`); body is empty; client can read a complete response without relying on EOF.
- Non-empty error bodies are unchanged.
- Telemetry `[:bandit, :request, :start]` still fires; error recovery does not skip request lifecycle events.

## Draft ticket (short maintenance report)

> On HTTP/1 keep-alive and pipelined connections, an error on one request can steal or truncate the next request's response: leftover "sent" notifications from the finished request confuse the next response's completion, and empty error responses are only delimited by closing the connection so a failed close loses the error entirely. Please make each request's completion independent (ignore stale sent notifications from prior requests) and frame empty error responses so the client always sees a complete response (`Content-Length: 0`).

## Acceptance design (proposed, unexecuted)

- Two pipelined GETs where the second is rejected (e.g. too many headers): both responses are independently readable; the second is a complete 431 with `Content-Length: 0`.
- Keep-alive success then error (or error then success): each response completes on its own; no cross-request early completion.
- Empty 400/500 path: `content-length` is `0`, body `""`, `connection: close` still present.
- Non-empty 200 responses unchanged (no forced `Content-Length: 0`).

## Plausible incomplete (proposed)

Fix only the empty-error framing and leave stale `:sent` notifications in the mailbox (or the reverse). Compiles; one of the two named keep-alive/pipeline assertions fails.

## Integrity control (proposed)

Acceptance must not pass if `Content-Length: 0` is added to **all** responses including non-empty bodies, if sent-notification discarding drops a **current** request's notification, or if error responses stop sending `connection: close`.

## Runtime / offline

- Elixir `~> 1.13` (from `mix.exs`). No external services; in-process TCP via the project's `SimpleHTTP1Client` test helper.
- Thousand Island is the transport (Bandit 1.x); tests bind a local port only.
- Node/browser not required.

## License / provenance

- MIT (Bandit). Public GitHub PR. No private edition.

## Holds / unknowns

- Related Bandit identities already noted elsewhere: #707 chunked compression (3 impl, focused reserve), #713 control bytes in request targets (1 impl file — too thin alone), #668 stale-conn guard **later reverted** in #719 — do not build a case on #668.
- This PR's tests tightened timing (`Process.sleep(20)` removed in favor of waiting for request-start telemetry). Grade behavior, not the test helper style.
- HTTP/2 error paths are out of scope unless the brief says so.

## Coverage added

HTTP/1 connection lifecycle and error framing on a real server stack (pairs with already-filed Thousand Island socket-ownership work as a different layer).

## Next action

If drafting: pin Elixir/OTP from historical CI at merge, write the ticket with both behaviors (stale sent + empty error framing), and add a one-of-two-omitted incomplete control.

---

## Grilling (2026-10-19)

### Minimum ticket
Good maintenance report; both behaviors are stated (stale sent-notification discard + empty error framing with `Content-Length: 0`). That is the right level — both are product-visible and the second one even names the header because it **is** the requested outcome. Keep "empty error responses" wording so solvers do not add `Content-Length: 0` to non-empty bodies. One trim: the parenthetical about mailbox internals is a small hint; acceptable because the symptom (one request stealing the next response) is already user-visible.

### Named deterministic checks
Unexecuted. Required named set (these can live in `protocol_test` / `plug_test` style):
1. two pipelined requests, second rejected (431): both responses independently readable; second has `Content-Length: 0`
2. keep-alive success then error (and error then success): each response completes independently
3. empty 400/500: `content-length: 0`, empty body, `connection: close` still present
4. non-empty 200: unchanged (no forced `Content-Length: 0`)
5. telemetry `[:bandit, :request, :start]` still fires on error recovery

Without (2) the "framing-only" incomplete passes. Without (4) the "always Content-Length: 0" cheat passes.

### Ambiguity / unfairness
- `Content-Length: 0` on empty errors is explicitly requested in the ticket — fair to grade the header value.
- Do not grade exact 431/400/500 **reason phrases** or header order.
- "Ignore stale sent notifications from prior requests" is close to an implementation instruction. It is arguably necessary to distinguish the two bugs. Acceptable, but a solver who solves the symptom another way (e.g. tag notifications per request) must still pass — grade behavior (independent completion), not `discard_sent_notifications/0`.
- HTTP/2 out of scope — keep it that way.

### Shortcuts + compiling incomplete
Framing-only and notification-only incompletes both compile. Under-weighted shortcuts: discard **all** sent notifications including the current request's (integrity must reject — dossier has this); add `Content-Length: 0` to every response including non-empty (check 4); drop `connection: close` on empty errors (check 3 must require it still present); fix pipelined 431 but break normal keep-alive (check 2 both directions).

### Flakiness
In-process TCP via `SimpleHTTP1Client` is the right harness. The PR removed `Process.sleep(20)` in favor of telemetry waits — good direction. Flake risk is port bind and any residual timing in the test helper. Grade behavior, not helper style. Keep checks synchronous with bounded waits.

### Preservation
Non-empty 200 path, telemetry start events, and ordinary keep-alive success are the preservation set. Add a named "two sequential successful keep-alive responses both complete" so a solver who over-discards cannot pass.

### Env
Elixir `~> 1.13` from mix.exs; **historical CI at merge `690b16b3` not pinned**. No external services; local port only. Thousand Island transport (Bandit 1.x). **Nothing executed** — no apply, no compile, no test. MIT.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. Do **not** build on #668 (stale-conn guard, later reverted in #719). #707 / #713 stay separate reserves.

### Verdict
**HOLD** — nice coherent two-bug fix, but zero execution and the named check set does not exist yet.

### Must-fix before qualification
1. Pin base (first parent of `690b16b3`) and toolchain; run the HTTP/1 tests at base and base+patch. Unchanged tree must fail the new named checks; reference must pass.
2. Name checks 1–5 above as protected tests (especially independent completion and non-empty-body preservation).
3. Grade independent completion behaviorally — do not require the specific discard helper name.
4. Integrity: reject always-`Content-Length: 0`, dropped `connection: close`, over-discard of current request.
5. MIT in provenance.
