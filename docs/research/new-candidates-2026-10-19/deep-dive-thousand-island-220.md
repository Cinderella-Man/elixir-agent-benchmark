# Deep-dive dossier — Thousand Island PR #220 (socket ownership-transfer)

**Status:** screened (deep-inspected; not yet provisional/admitted)  
**Research date:** 2026-10-19  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/mtrudel/thousand_island/pull/220 |
| Title | Fix: Handle socket ownership-transfer errors during connection start |
| Author | **mpettibone** (outside contributor; maintainer merged) |
| Created | 2026-08-26T01:15:24Z |
| Merged | 2026-08-31T20:22:25Z |
| **Base SHA (parent of merge)** | `e9a5ae259a103911728f92c15cbcbecf99662570` (PR #219 "Simplify shutdown listener state") |
| **Merge SHA** | `62385e80f43d2197ac55b4092cc8ca44be7491d6` |
| Diff | https://github.com/mtrudel/thousand_island/pull/220.diff |
| Claude-assisted discovery | Yes (PR body note). **Use code and tests as evidence**, not the tool story. |
| Mix version at base | `1.5.0` |
| Elixir req at base | `~> 1.13` |
| License | MIT — Copyright (c) 2018 Mat Trudel |

### Linked issues

**None** in the thousand_island tracker. The PR cites OTP specs as the "rule":

- [`gen_tcp:controlling_process/2`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#controlling_process-2) returns `:ok | {:error, reason}`
- [`ssl:controlling_process/2`](https://www.erlang.org/doc/apps/ssl/ssl.html#controlling_process-2) same, plus caller must be current owner

Authenticity is grounded in transport-spec non-conformance + leak of accepted sockets/handlers, not a product feature request.

---

## 2. Sibling PR #216 relationship (required)

| PR | SHA | Date | Relationship to #220 |
| --- | --- | --- | --- |
| **#216** Refactor: Separate connection start retries from socket handoff | merge `a48bb5e0dfd23c0b99a7b730569b93c06a4292ee` | 2026-08-25 | **Direct structural prerequisite.** Moves `:max_children` retries into `start_child_with_retry/4` and leaves socket handoff in `start/5`. #220 then changes exactly that handoff (`controlling_process` + ready message). |
| #217 Consolidate supervisor lifecycle helpers | `ccaf7a8a…` | 2026-08-25 | Same refactor series; not in #220's patch. |
| #218 Share listener option resolution across transports | `6d6a50ee…` | 2026-08-25 | Touches `transport.ex` types later also edited by #220 (`controlling_process_error/0`). |
| #219 Simplify shutdown listener state | `e9a5ae25…` | 2026-08-25 | **This is #220's base.** |
| #221 Emit connection readiness only after handshake success | `1ff4c232…` | 2026-08-31 (after #220) | Sibling fix on `handler.ex` ready-event timing. Not in #220's patch. |

**Ordering on `connection.ex`:** `8f04692` (pre-series) → `a48bb5e` (#216) → `62385e8` (#220). The #220 patch hunks apply to the post-#216 shape (`start_child_with_retry` already extracted).

**Curation implication:** Pin base at `e9a5ae2` (includes #216–#219). Do **not** pin at pre-#216; the reference patch will not apply and the "incomplete control" design assumes the split retry/handoff structure. Report #216/#220 as one **accept-path lifecycle family**, not as two independent coverage points if both are ever admitted.

---

## 3. Shortest sufficient ticket text

Maintenance report shape (do **not** name `Connection.start/5`, `{:controlling_process, reason}`, or file paths):

> When handing an accepted socket to the connection process fails, cleanup is incomplete: the socket can leak, a handler can be left waiting for messages it will never get, and the failure is hard to observe. Make a failed ownership transfer during connection start close the accepted socket, stop that handler before it is told to start, leave the acceptor healthy and able to accept later connections, and report the failure on the existing connection-setup error telemetry. Keep the normal accept path and ordinary spawn errors working. Fix it.

**Optional clarifiers (state only if scored):**

- Failure must be distinguishable in telemetry as an ownership-transfer problem (not a generic spawn error).
- A handler that never received the ready message must not be treated as a started connection.

**Do not put in the ticket:** the typed error shape `{:controlling_process, reason}`, the `spawn_error` event name (unless treating event names as the already-documented public contract), or "custom transport".

---

## 4. Implementation roles + key code quotes

### Files

| File | Role | Count |
| --- | --- | --- |
| `lib/thousand_island/connection.ex` | Check `controlling_process/2` result; on error close socket, terminate idle child, return typed error | **implementation** |
| `lib/thousand_island/acceptor.ex` | New clause: on `{:error, {:controlling_process, reason}}` emit `:spawn_error` and keep accepting | **implementation** |
| `lib/thousand_island/transport.ex` | Types: `controlling_process_error()`, `on_controlling_process()` | **implementation** (contract/types) |
| `test/thousand_island/connection_test.exs` | **New file.** Deterministic custom transport `OwnershipErrorTransport` + `WaitingHandler` | test |
| `test/thousand_island/acceptor_test.exs` | Extend `FlakyTransport` with injectable `controlling_process` errors; live acceptor regression | test |
| `test/thousand_island/server_test.exs` | Loosen certfile-error test to accept ownership path as well (OTP-dependent race) | test (mechanical/fixture accommodation — count separately) |

**Counts:** 3 substantive implementation files; 2 substantive test files + 1 test accommodation. Custom transports are **test doubles**, not production code.

### Pre-fix behavior (base `e9a5ae2`, post-#216)

```elixir
# connection.ex — result deliberately discarded
_ = handler_config.transport_module.controlling_process(raw_socket, pid)
send(pid, {:thousand_island_ready, raw_socket, handler_config, acceptor_span, start_time})
:ok
```

Comment claimed "if there's an error the connection process will see it, but it's no longer our problem" — **wrong**: the handler is precisely the process that will never see messages, because it did not become owner.

### Post-fix shape (merge `62385e8`)

`connection.ex`:

```elixir
case handler_config.transport_module.controlling_process(raw_socket, pid) do
  :ok ->
    send(pid, {:thousand_island_ready, raw_socket, handler_config, acceptor_span, start_time})
    :ok

  {:error, reason} ->
    _ = handler_config.transport_module.close(raw_socket)
    _ = DynamicSupervisor.terminate_child(sup_pid, pid)
    {:error, {:controlling_process, reason}}
end
```

`acceptor.ex` new clause (before the generic `{:error, reason}`):

```elixir
{:error, {:controlling_process, reason}} ->
  ThousandIsland.Telemetry.span_event(span, :spawn_error, %{error: {:controlling_process, reason}})
  accept(listener_socket, connection_sup_pid, server_config, handler_config, span, count + 1)
```

`transport.ex`:

```elixir
@typedoc "An error returned from a controlling_process/2 call"
@type controlling_process_error() :: :closed | :not_owner | :badarg | :inet.posix()
@type on_controlling_process() :: :ok | {:error, controlling_process_error()}
```

### Cross-component invariant

On ownership-transfer failure: **socket closed** ∧ **idle handler terminated (and never got `:thousand_island_ready`)** ∧ **typed error returned** ∧ **acceptor alive + spawn_error telemetry** ∧ **next connection still served**. On `:ok`: unchanged handoff.

---

## 5. Named acceptance assertions (mapped to visible requirements)

| # | Named assertion | Visible justification |
| --- | --- | --- |
| B1 | **Socket closed on failed transfer** | Ticket: "close the accepted socket" |
| B2 | **Idle handler terminated; never ready** | Ticket: "stop that handler before it is told to start" |
| B3 | **Acceptor stays alive; next client accepted and served** | Ticket: "leave the acceptor healthy and able to accept later connections" |
| B4 | **Typed/observable failure on setup-error telemetry** | Ticket: "report the failure on the existing connection-setup error telemetry" + "failure is hard to observe" |
| B5 | **Successful transfer path unchanged** | Ticket: "Keep the normal accept path" |
| B6 | **Ordinary spawn errors still work** | Ticket: "ordinary spawn errors working" |

If the brief requires a **distinguishable** ownership reason (optional clarifier):

| B7 | Telemetry / error payload identifies ownership-transfer failure vs generic spawn error | Only if stated |

Upstream named tests (for mapping):

- `connection_test.exs` / `"an ownership transfer error closes the socket and terminates the idle handler"` — asserts `{:error, {:controlling_process, :badarg}}`, `:socket_closed`, `:handler_terminated ... :shutdown`, `refute_receive {:handler_ready, _}`, empty DynamicSupervisor.
- `acceptor_test.exs` / `"an ownership transfer failure is reported and the acceptor serves the next connection"` — `:spawn_error` with `error: {:controlling_process, :badarg}`, echo `"NEXT"` on second client, acceptor pids unchanged.

---

## 6. Compiling incomplete control + expected named failure

**Incomplete control (compiling, plausible):**

In `connection.ex`, check `controlling_process` and on error **close the socket and return `{:error, {:controlling_process, reason}}`**, but **do not** `DynamicSupervisor.terminate_child/2` (leave the idle handler up) and **do not** add the acceptor clause for the typed error (or add it without telemetry).

Compiles; returns a typed error; closes the socket.

**Expected named failures:**

- **B2 fails** — `handler_terminated` never arrives; DynamicSupervisor still has a child; `refute Process.alive?(handler_pid)` fails.
- **B3/B4 fail** if the acceptor crashes on the unmatched error or never emits `spawn_error` (depending on which half was omitted).
- Upstream: `assert_receive {:handler_terminated, ^handler_pid, :shutdown}` fails.

**Alternate incomplete (also good):** handle it only in `acceptor.ex` (catch-all and continue) but still send ready / don't close — fails B1/B2.

---

## 7. Integrity / bypass control

Reject solutions that:

| Bypass | Why rejected |
| --- | --- |
| Swallow the error and `send` ready anyway (pretend success) | Leaves non-owning handler active — the original bug. |
| Kill the whole server / acceptor on one failed transfer | Violates B3 ("leave the acceptor healthy"). |
| Close socket but leak the handler (incomplete control) | B2. |
| Emit telemetry but leave socket open / handler waiting | B1/B2. |
| Return `:ok` from `start/5` after a failed transfer | Callers cannot distinguish; violates B4. |
| Match only `{:error, :badarg}` and miss `:closed | :not_owner | :inet.posix()` | Incomplete relative to transport contract; use `{:error, reason}`. |

**Positive preservation:**

- Two sequential clients after a failure: second echoes (upstream `"NEXT"`).
- `:max_children` → `{:error, :too_many_connections}` still closes socket (pre-existing).
- Handler `init` failure → existing `spawn_error` path still works (upstream `"intentional_init_failure"` test).

---

## 8. Preservation

| Behavior | Must remain |
| --- | --- |
| Successful `controlling_process` + ready message | Unchanged |
| `:max_children` retry loop (`start_child_with_retry`) | Unchanged (#216 behavior) |
| Other `spawn_error` reasons | Still emitted |
| `:econnaborted` / `:einval` accept retries | Unchanged |
| Full suite | PR body: connection/acceptor/server tests pass; format/credo/dialyzer clean |

`server_test.exs` certfile-error test was **relaxed** to accept either handler error or ownership error (race: peer close vs ownership transfer). That is a test accommodation, not product behavior — do not grade solvers on which side wins the race.

---

## 9. Runtime / offline / services

| Item | Evidence |
| --- | --- |
| Elixir | `~> 1.13` at base; PR verified on 1.18.4 / OTP 27.3.4 |
| Services | **None** |
| Network | Loopback `:gen_tcp` + custom `ThousandIsland.Transport` doubles |
| Custom transports | **Yes — central.** `OwnershipErrorTransport` (unit) and `FlakyTransport` with injectable `controlling_process` results (integration). Deterministic, offline. |
| Tests run | `mix test test/thousand_island/connection_test.exs test/thousand_island/acceptor_test.exs` then full `mix test`. `test_helper.exs` = `ExUnit.start()`. |
| Machete | Used for measurement assertions (`~> %{...}`); already a test dep. |

---

## 10. Reference challenges

### Later commits touching the same files after merge

**Scan method:** Atom feeds for `connection.ex`, `acceptor.ex`, `transport.ex` (2026-10-19).

| Path | Later commit after `62385e8` (2026-08-31T20:22:24Z)? | Reference bug? |
| --- | --- | --- |
| `lib/thousand_island/connection.ex` | **None** | No |
| `lib/thousand_island/acceptor.ex` | **None** | No |
| `lib/thousand_island/transport.ex` | `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820` — **#225** "Omit the TCP_NODELAY default for Unix domain listeners" (2026-08-31T20:31:11Z) | **No** — different concern (listen options for UDS). Does **not** correct ownership-transfer handling. |

**Conclusion: no follow-up fix / reference bug for the ownership-transfer behavior itself.** #225 is a later edit on `transport.ex` only in the type/option surface; if a case snapshot is taken at `62385e8`, it simply lacks #225 (harmless for this task).

Related same-day siblings (not fixes of #220): #221 readiness-after-handshake, #222 telemetry exception, #223 system_time, #225 TCP_NODELAY.

### Flaky risks

| Risk | Mitigation |
| --- | --- |
| `server_test.exs` certfile race (peer close vs ownership) | Graded checks should use the **deterministic** `connection_test` custom transport, not this race. |
| `assert_receive` 1000ms | Adequate on loopback; bump if CI is slow. |
| `DynamicSupervisor.terminate_child` waits for handler shutdown (`shutdown_timeout: 1_000` in test) | Use the same configured timeout in fixtures; don't assert wall-clock. |

### Contract gaps

| Gap | Note |
| --- | --- |
| Exact error tuple `{:controlling_process, reason}` | Only in reference/types. **If graded, the brief must say** the failure is distinguishable (B7) or name the public error shape. Otherwise accept any typed/observable error that keeps B1–B6. |
| `spawn_error` event name | Already documented upstream (CHANGELOG 0.6.6). Safe to treat as visible if solver image includes docs; still prefer "existing connection-setup error telemetry" in the ticket. |
| Wait for handler shutdown before returning | PR mentions "cleanup waits for the handler's configured supervisor shutdown behavior". Do not require a specific wait unless measured. |
| Custom transports that lie (return `{:error, _}` but transferred anyway) | Reference comment says terminate also closes if a custom transport transferred despite error. Don't grade this exotic case. |

---

## 11. Curator record

```markdown
Source type / project / source revisions / PR or original request:
  historical PR / mtrudel/thousand_island /
  base e9a5ae259a103911728f92c15cbcbecf99662570 → merge 62385e80f43d2197ac55b4092cc8ca44be7491d6 /
  PR #220 "Handle socket ownership-transfer errors during connection start"
  (OTP controlling_process/2 contract; no tracker issue)
  Structural prerequisite: PR #216 (a48bb5e…) split retries vs handoff.

Status: screened

Case version / release inventory / public or withheld exposure:
  v0 / not in inventory / public

Task kind / family / maintenance report or clarified brief:
  bug_fix / accept-path lifecycle (process + socket ownership) / short maintenance report

Full solver-visible ticket and appended instructions:
  See §3. Do not include PR number, Connection.start/5, or the exact error tuple
  unless B7 is explicitly required.

Implementation files and each file's role:
  connection.ex — check transfer result; close + terminate idle handler; typed error
  acceptor.ex   — recoverable spawn_error; keep accepting
  transport.ex  — controlling_process_error type
  (3 implementation files; types-only edits still count as contract surface)

Test / documentation / generated / mechanical files (separate counts):
  connection_test.exs (NEW) — 1 substantive test file
  acceptor_test.exs — 1 substantive test file
  server_test.exs — 1 test accommodation (race-tolerant certfile case)
  No generated/lockfile files.

Cross-component behavior to verify:
  Failed transfer ⇒ socket closed ∧ handler down ∧ never ready ∧ acceptor alive ∧
  setup-error telemetry ∧ next connection works. Success path unchanged.

Visible source for each scored obligation:
  B1–B6 — ticket sentences in §3
  B7 — only if brief names distinguishable ownership failure

Starting-state and reference-test evidence (inspected vs executed):
  Inspected: full PR diff (including new connection_test.exs), PR body, #216 diff,
  commit parent SHAs, later transport.ex commit #225.
  NOT executed locally in this research pass. PR body claims tests fail on unpatched main.

Plausible partial solution and expected named failure:
  Close + typed error but leave idle handler alive → B2 named failure
  (upstream "handler_terminated" / DynamicSupervisor.which_children == []).

Preservation and alternative-solution risks:
  Preserve success path, max_children retries, other spawn_errors, acceptor liveness.
  Alternative: synchronous exit monitoring + demonitor instead of terminate_child is fine
  if B1–B6 hold. Do not require DynamicSupervisor API specifics.

Runtime / offline services / license evidence and unknowns:
  Elixir ~> 1.13, ExUnit, custom transports, loopback, no services, MIT.
  Unknown: historical CI file path (not fetched); IPv6-dependent tests noted in #216 body.

Three-round named control outcomes and frozen-input evidence:
  Not run. Required before admission.

Blind model/settings policy and all attempt IDs (including failures/retries):
  None yet.

Independent contract review / passing-patch reviews / unresolved findings:
  Pending. Flag whether {:controlling_process, reason} is scored (must be in brief if yes).
  Flag: do not require the server_test race to pick a winner.

Coverage added / related or duplicate tasks:
  Transport contract enforcement + process cleanup under failure.
  Family sibling of #216 (refactor of same function) — report as accept-path family.
  Distinct from #228 (metadata cache) and #222 (telemetry).

Admission or exclusion reason / conditions for reconsideration:
  Not admitted yet — needs control execution + blind pair.
  Coherent 3-file work with real cross-component invariant; good second TI case.

Next action:
  Clone at e9a5ae2, implement reference-shaped repair locally or apply merge patch,
  run B1–B6 controls with OwnershipErrorTransport (deterministic), keep certfile race
  out of graded set, then three-round qualification.
```

---

## 12. Next action

1. **Workspace** at `e9a5ae259a103911728f92c15cbcbecf99662570` (post-#216).
2. **Primary graded checks** = deterministic `connection_test` style (custom transport), not the certfile race.
3. **Decide B7** (typed error shape in brief or not) before writing hidden checks.
4. Run unchanged / reference / incomplete / integrity once; then three-round freeze.
5. In corpus reporting, tag with #216 as **accept-path lifecycle family**.

**Not verified in this pass:** local `mix test`, whether `machete` assertions match the runner's expected style, historical CI matrix.
