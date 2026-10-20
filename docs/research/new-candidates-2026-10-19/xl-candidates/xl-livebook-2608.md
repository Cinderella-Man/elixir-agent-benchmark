# xl-livebook-2608

**Status:** discovered
**Project:** livebook-dev/livebook
**PR:** [#2608 — Allow Livebook to proxy requests to the runtime](https://github.com/livebook-dev/livebook/pull/2608)
**Issue:** [Closes #2090](https://github.com/livebook-dev/livebook/issues/2090)

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/livebook-dev/livebook/pull/2608 |
| Title | Allow Livebook to proxy requests to the runtime |
| Source type | Historical merged PR (bounded feature; closes #2090) |
| Merge style | **Squash** — one parent |
| Merge commit | `16bd46b54fb1a26662f05d69af6d60004a692580` |
| Parent of merge (= base) | `1150dc288a526896bc651340aaea2d01c34976c5` |
| PR head SHA | `6d3814613dfca8700d69d38fe8f67cd6db4d3c40` (14 commits) |
| Merged at | 2024-05-20T20:04:04Z |
| License | **Apache-2.0** |
| Verification | **Unverified** — PR body + `pull/2608.diff` inspected; suite not executed |

**Note on already-inventoried Livebook cases:** 2219 / 2527 / 2663 / 2800 / 2822 / 3076 / 3169 / 2618 are filed elsewhere. #2608 is a **different** runtime/proxy family and is not a duplicate of #2618 (app-session proxy URLs). Do not merge with #2618 unless a lineage brief explicitly wants generic app-proxy semantics.

## Why it is a LIMIT-TEST

One outcome — *forward HTTP requests from the Liveview endpoint to a handler that lives inside the runtime* — requires a **behaviour implemented consistently across every runtime backend**:

1. **`Livebook.Runtime` contract** gains `fetch_proxy_handler/1`.
2. **Three frontends** implement it: `Runtime.Attached`, `Runtime.Embedded`, `Runtime.ElixirStandalone`.
3. **`ErlDist.RuntimeServer`** actually holds/fetches the handler in the remote/runtime process.
4. **`Session`** is the proxy of record for a session id (lookup + call).
5. **`LivebookWeb.ProxyPlug`** routes `sessions/:id/proxy/*` to that handler; `ErrorJSON`/`Endpoint` wire errors and the plug.
6. **`mix.exs`/`mix.lock`** add the Plug adapter dependency needed for the proxy path (mechanical; count separately).

Miss one runtime and that attach mode silently lacks the feature while others work — the classic incomplete. Miss `Session` and the plug cannot resolve a handler.

## File inventory (honest count)

**Implementation — 10 substantive** (plus 1 mechanical dep line):

| File | Role |
| --- | --- |
| `lib/livebook/runtime.ex` | Behaviour addition `fetch_proxy_handler/1` |
| `lib/livebook/runtime/attached.ex` | Attached-mode implementation |
| `lib/livebook/runtime/embedded.ex` | Embedded-mode implementation |
| `lib/livebook/runtime/elixir_standalone.ex` | Standalone-mode implementation |
| `lib/livebook/runtime/erl_dist/runtime_server.ex` | Handler fetch in the runtime server |
| `lib/livebook/session.ex` | Session-level handler lookup |
| `lib/livebook_web/plugs/proxy_plug.ex` | **New** `sessions/:id/proxy/*` routing |
| `lib/livebook_web/controllers/error_json.ex` | Proxy error responses |
| `lib/livebook_web/endpoint.ex` | Plug pipeline registration |
| `mix.exs` | Dependency declarations for the plug path |

**Mechanical / deps (not product logic):** `mix.lock` (1 line).

**Tests — 2** (separate): `test/livebook_web/plugs/proxy_plug_test.exs` (+117), `test/support/noop_runtime.ex` (+1 behaviour stub).

**Total files in diff:** 13 = 10 impl + 1 lockfile + 2 tests.

## Draft minimum ticket

> I need Livebook to proxy HTTP requests to a handler that runs in the session's runtime, so notebook processes can serve their own endpoints through the Livebook URL. Make `fetch_proxy_handler` work for attached, embedded, and standalone runtimes, route `sessions/:id/proxy/*` to it, and return a clean error when the session or handler is missing.

(Public API name `fetch_proxy_handler` is the requested interface and may appear in the brief.)

## Named deterministic checks

1. **proxy-plug-routes-to-handler** — `GET /sessions/:id/proxy/foo` reaches the runtime handler and returns its body.
2. **attached-implements-fetch** — `Attached.fetch_proxy_handler/1` returns the handler (or nil) per contract.
3. **embedded-implements-fetch** — same for `Embedded`.
4. **standalone-implements-fetch** — same for `ElixirStandalone` (via session/runtime server).
5. **missing-session-404-json** — unknown session id yields the JSON error shape, not a crash.
6. **missing-handler-mapped** — session without a handler is a defined error (not `:ok` / empty body).
7. **noop-runtime-conforms** — test stub satisfies the extended behaviour (keeps other suites compiling).

## Incomplete that compiles (misses one subsystem)

Implement `ProxyPlug` + `Session.fetch_proxy_handler` + `RuntimeServer` **but leave `Attached` / `Embedded` / `ElixirStandalone` returning `nil` stubs**. Compiles; plug tests with a custom runtime pass; **attached/embedded/standalone-implements-fetch** fail.

Alternative incomplete: implement runtimes but forget `ErrorJSON`/endpoint wiring → fail **missing-session-404-json**.

## Integrity shortcuts

- Unchanged tree fails **proxy-plug-routes-to-handler** (no plug).
- Positive checks per runtime block one-backend cheats.
- **missing-session-404-json** + **missing-handler-mapped** block silent `raise`/empty 200s.
- **noop-runtime-conforms** keeps the suite honest about the behaviour shape.

## Preservation

- Existing session/runtime suites unchanged in behavior (new function is additive).
- No change to evaluation, secrets, or app deployment paths (#2618 territory is out of scope here).
- `noop_runtime` updated so other tests still compile.

## Offline holds

| Hold | Notes |
| --- | --- |
| Services | **None required** — standalone runtime uses local node; tests can use `NoopRuntime`. |
| Network | No outbound calls in graded checks. |
| mix.lock | One dependency addition; allow lockfile in env prep but do not grade it as product logic. |
| Apache-2.0 | Preserve license. |
| Teams | This PR is community Livebook, not Teams; do not pull Teams-only test dirs into the graded surface. |

## Cross-component contract

> `Livebook.Runtime` is the interface; every runtime implementation must speak it; `Session` resolves handlers; `ProxyPlug` is the only HTTP front door. A correct solution can use any handler lookup strategy **as long as all four stages agree**.

## Next action

Pin base `1150dc28…`; run `proxy_plug_test` unchanged (fail), reference (pass), incomplete-with-nil-runtime-stubs (fail per-runtime checks). Verify standalone runtime boot is not required for the plug-level tests.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> I need Livebook to proxy HTTP requests to a handler that runs in the session's runtime, so notebook processes can serve their own endpoints through the Livebook URL. Make `fetch_proxy_handler` work for attached, embedded, and standalone runtimes, route `sessions/:id/proxy/*` to it, and return a clean error when the session or handler is missing.

Bounded feature; `fetch_proxy_handler` is the requested public API (fair to name). **Three contract problems block this as written:**

1. **Hidden integration partner.** The reference discovers the handler with `GenServer.whereis(Kino.Proxy)` and serves with `Kino.Proxy.serve/2`. The dependency `kino_proxy` is **added by this PR** (GitHub `livebook-dev/kino_proxy`). At base, no `Kino.Proxy` exists in the tree. A solver cannot invent that module name, that process registry, or `serve/2`'s contract from the ticket. Either name `Kino.Proxy` as the runtime-side integration (like naming `Delivery.send/1` in a refactor brief) **or** grade only "a handler pid obtained from the runtime is forwarded to and returns its response", with the test injecting any pid. As written, hidden API.
2. **Apps path is in the reference but out of the dossier scope.** The PR also routes `apps/:slug/:id/proxy/*`. The dossier says #2618/app-proxy is out of scope. **Ticket/reference contradiction.** Per LINEAGE-MERGE-POLICY the ticket must describe the final behaviour of the frozen reference. Either add "and the same for app session proxy paths under `/apps/...`" to the brief, or strip app routes from the reference (and admit you are no longer freezing this PR as-is).
3. **Error shape is hidden.** Reference raises `LivebookWeb.NotFoundError` and adds `ErrorJSON` returning `%{errors: %{detail: …}}`. The ticket says "clean error". Grade status 404 + JSON body existence, **or** name the shape. Do not require `ErrorJSON`/`NotFoundError` module names.

### 2. Deterministic checks

ExUnit + Phoenix.ConnTest. Upstream `proxy_plug_test.exs` is the right shape. **Fakes:** `NoopRuntime` already stubs the new function. Plug-level tests with a fake session/runtime are enough; the upstream cell-evaluation test (Embedded + `Kino.Proxy.listen`) is heavier but deterministic via `assert_receive`. Prefer both: unit-plug with a fake handler pid **and** one integration via Embedded.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `proxy-routes-to-handler` | fake session + handler pid that answers | `GET /sessions/:id/proxy/foo` | 200 + handler body; method/path forwarded |
| `attached-fetch` | `Attached` runtime | `fetch_proxy_handler` | `{:ok, pid}` or `{:error, :not_found}` per contract |
| `embedded-fetch` | `Embedded` runtime | same | same |
| `standalone-fetch` | `ElixirStandalone` (via session/server; no full boot if possible) | same | same |
| `missing-session-404` | unknown id | `GET` | 404, JSON-ish error, no crash |
| `missing-handler-404` | session without handler | `GET` | defined error (404), not empty 200 |
| `disconnected-runtime-404` | session with disconnected runtime | `GET` | defined error |
| `noop-runtime-conforms` | `NoopRuntime` | compile + call | implements the extended protocol |
| `preservation-session-runtime` | existing session/runtime suites | suite | green |
| `apps-proxy` *(only if in ticket)* | app with session | `GET /apps/:slug/:id/proxy/…` | routed like sessions |

Without `disconnected-runtime-404`, a crash-on-disconnect passes. Without per-runtime checks, one-backend cheats pass. Without `noop-runtime-conforms`, the suite breaks for everyone else and solvers get compile noise.

### 3. Ambiguity / unfairness

- **`Kino.Proxy` is the big one.** Also `Kino.Proxy.serve/2` return shape `{conn, _}` and `Kino.Proxy.listen/1` on the notebook side. Unfair unless named or injectable.
- `Livebook.Runtime` is a **protocol** (`defprotocol`), not a behaviour. The dossier says "behaviour". Solvers adding a protocol function must update **every** `defimpl` (including `NoopRuntime`) or compilation breaks. That is real coordination — but the incomplete "return nil stubs" must still compile the protocol. Fine; just be accurate in the brief ("extend the runtime protocol").
- Error modules: `LivebookWeb.NotFoundError` + `ErrorJSON` shape are hidden (see ticket).
- `prepare_conn` internals (how path_info is rewritten, host/scheme) are hidden. Grade "handler sees the residual path and original method".
- Whether the handler pid can be remote (other node) is unstated. Reference uses `GenServer.whereis` / `GenServer.call` which works remotely if named. Do not grade distribution; local pid is enough.

### 4. Shortcuts

- Plug + Session + RuntimeServer, runtimes return `:not_found` stubs → fails `attached/embedded/standalone-fetch`. Correct incomplete.
- Runtimes implement fetch, plug missing → fails `proxy-routes-to-handler`.
- Implement sessions path only, ignore apps path → fails `apps-proxy` **only if apps are in the ticket**. Currently a silent pass — another reason to resolve scope.
- Missing handler returns 200 empty → fails `missing-handler-404`.
- Raise a bare `RuntimeError` instead of a 404 JSON → fails `missing-session-404` if that check requires the JSON shape.
- Only `Embedded` implemented (the easy one) → fails `attached-fetch` / `standalone-fetch`.
- Forward to the handler but drop the method → fails method-forwarding assertion in `proxy-routes-to-handler`.

### 5. Flakiness

Low–medium. No external services. The upstream integration test evaluates a real cell in Embedded runtime and `assert_receive`s the evaluation response — deterministic but slower; keep `Session.close` in `on_exit`. No network. Do not boot a full standalone Erlang dist unless necessary — prefer protocol-level calls for `ElixirStandalone`. If the standalone check needs a real node, mark it and isolate it; that is the main flake/slow risk.

### 6. Coverage mix

- Positive: route to handler; each runtime fetches; happy path body/method.
- Negative: missing session, missing handler, disconnected runtime.
- Preservation: session/runtime suites; evaluation/secrets paths untouched.
- Mixed: one session with a handler, one without, one disconnected — in one test module so a single global handler cache fails.

### 7. Environment

- Apache-2.0. No outbound network in graded checks.
- **`kino_proxy` is a GitHub dependency added by this PR.** Offline availability at the pinned commit is an **execution-support blocker**. If the offline mirror cannot fetch `livebook-dev/kino_proxy` at a known SHA, **defer the case**. Do not mock `Kino.Proxy` into existence in the fixture as a way to hide the missing dep — that changes the product.
- `mix.lock` line is mechanical; do not grade it as product logic.
- Community Livebook, not Teams — keep Teams-only dirs out.
- **Nothing executed.** No apply, no compile.

### 8. XL-specific

10 impl files is **real coordination** for "every runtime speaks the protocol + HTTP front door agrees": protocol + 3 impls + RuntimeServer + Session + plug + error + endpoint. The classic incomplete (one runtime left as a stub) is exactly the XL value. **But** the PR also carries the apps-proxy route — a second story stapled on the same plug. Per LINEAGE-MERGE-POLICY, either merge it into one honest "proxy for sessions and app sessions" brief or drop it from the reference. Possible split: (a) runtime protocol + 3 impls + server/session (~7 files), (b) HTTP plug + errors (~3 files). **Do not split** — (a) has no observable HTTP outcome and (b) has nothing to call. Outcome is one story **if** apps scope is resolved. If apps stay in, the story is still one ("proxy Livebook URL → runtime handler") but the ticket must say so.

### 9. Verdict

**HOLD** — three independent contract/env blockers: hidden `Kino.Proxy` integration, apps-path ticket/reference contradiction, and a GitHub-only dep that may not be offline. Not REJECT: the work is authentic and the multi-runtime incomplete is excellent once those are fixed.

### 10. Must-fix before qualification

1. Name `Kino.Proxy` (or equivalent) as the requested runtime-side integration, **or** make the handler injectable and grade only forwarding. Do not leave the module name hidden.
2. Resolve apps scope: add app-session proxy to the brief, or strip it from the reference and say the case is sessions-only.
3. Confirm `kino_proxy` is fetchable offline at a pinned SHA. If not, defer.
4. Decide error contract: status 404 + any JSON, or the `%{errors: %{detail: …}}` shape named in the brief. Do not require `ErrorJSON`/`NotFoundError` by name unless named.
5. Incomplete = plug/session/server with nil runtime stubs. Integrity = sessions-only (if apps in scope); empty-200 on missing handler; only Embedded wired.
6. Per-runtime checks + `NoopRuntime` conformance + disconnected-runtime case.

| Verdict | Top risk |
| --- | --- |
| **HOLD** | Hidden Kino.Proxy API; apps-path contradiction; GitHub dep offline risk |
