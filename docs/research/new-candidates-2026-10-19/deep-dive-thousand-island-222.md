# Deep-dive dossier — Thousand Island PR #222 (telemetry exception events)

**Status:** screened (deep-inspected; not yet provisional/admitted)  
**Research date:** 2026-10-19  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/mtrudel/thousand_island/pull/222 |
| Title | Fix: Emit telemetry exception events for handler callback exceptions |
| Author | **mpettibone** (outside contributor; maintainer merged) |
| Created | 2026-08-26T01:33:30Z |
| Merged | 2026-08-31T20:24:09Z |
| **Base SHA (parent of merge)** | `1ff4c2321399ceed777e6f76fc918028b9c9f20b` (**PR #221** "Emit connection readiness only after handshake success") |
| **Merge SHA** | `7caea621e0afeeb2e92874796a7b8d3caf0e2a7b` |
| Diff | https://github.com/mtrudel/thousand_island/pull/222.diff |
| Claude-assisted discovery | Yes (PR body note). Use **code and tests** as evidence. |
| Mix version at base | `1.5.0` |
| Elixir req at base | `~> 1.13` |
| License | MIT — Copyright (c) 2018 Mat Trudel |

> **Correction vs short note `thousand-island-222-telemetry-exception.md`:** that note lists base `e9a5ae2…`. That is the base of **#220**, not of #222. The merge commit `7caea62`'s parent is `1ff4c232` (#221). Both #221 and #222 show `handler.ex` `index 7800f58..…` in their PR diffs (same pre-#221 blob), but #222 was merged **on top of** #221. **Pin case base at `1ff4c232`** so the reference patch applies cleanly. Patching #222 onto `e9a5ae2` may context-conflict with #221's ready-event move in `handle_continue`.

### Linked issues

**None** in thousand_island. Normative sources cited in the PR body:

- [`telemetry.span/3`](https://hexdocs.pm/telemetry/telemetry.html#span/3) — exception event pair with `kind => throw | error | exit`, `reason => term()`, `stacktrace => list()`.
- Thousand Island's own event docs already "explicitly adopt" that span convention for listener/acceptor/connection pairs.

No Bandit ticket (unlike #228). Authenticity is spec non-conformance + lost exception class/stacktrace for error trackers.

---

## 2. Sibling PR #216 relationship

**Indirect, same contributor series — not a structural prerequisite.**

| PR | What it changes | Relation to #222 |
| --- | --- | --- |
| **#216** `a48bb5e` (2026-08-25) | `connection.ex` — split `:max_children` retry from socket handoff | Same `mpettibone` series; **no shared files** with #222 (`handler.ex` / `telemetry.ex`). Do not treat #216 as required to apply #222. |
| #217 / #218 / #219 | supervisor helpers, listener options, shutdown state | Same series; not in #222's patch. |
| **#220** `62385e8` (2026-08-31) | ownership-transfer cleanup | Same day; different files. Independent task. |
| **#221** `1ff4c232` (2026-08-31) | `handler.ex` — move `:ready` telemetry to **after** handshake success | **Immediate parent.** Same file region (the `handle_continue(:handle_connection, …)` clause that #222 wraps). |
| **#223** `3f262b10` (2026-08-31) | `telemetry.ex` — add `system_time` to **start** span measurements | **Immediate child / follow-on on the same file.** See §10. |

**Series timeline (2026-08-25 → 2026-08-31):** #216 → #217 → #218 → #219 → #220 → #221 → **#222** → #223 → #225.

**Curation implication:** #222 is a **focused observability** task. It does not depend on #216. It does sit on a tree that already contains #220+#221. If a report later groups "socket lifecycle" cases, keep #222 separate from #220/#216 (different obligation: event contract vs cleanup).

---

## 3. Shortest sufficient ticket text

Maintenance report shape (event names may appear if treated as the documented public contract; do **not** name `invoke_callback`, `exception_span`, or the process-dictionary marker):

> When a connection or data handler raises, throws, or exits, the connection telemetry span does not end with the documented exception event. End those spans with the conventional exception event carrying duration, kind, reason, and stacktrace, and re-raise the original exception so handler crash behavior is unchanged. Ordinary error returns from handlers must keep ending the span with the normal stop event and must not emit the exception event. Fix it.

**Optional clarifiers (state only if scored):**

- Exactly one terminal event per span (exception **or** stop, not both).
- `kind` is `:error | :throw | :exit`; `reason` for `:error` is the exception struct.
- Event name `[:thousand_island, :connection, :exception]` if the grader matches the exact atom list (this is already documented in `telemetry.ex` moduledoc at base for stop/start — **exception event is new**; see §9).

**Do not put in the ticket:** the wrapper function name, `:erlang.raise/3`, or the "process-local marker" implementation.

---

## 4. Implementation roles + key code quotes

### Files

| File | Role | Count |
| --- | --- | --- |
| `lib/thousand_island/handler.ex` | Wrap `handle_connection/2` and `handle_data/3` dispatch; on raise/throw/exit emit exception span then re-raise | **implementation** |
| `lib/thousand_island/telemetry.ex` | New `exception_span/4`; `stop_span/3` skips when exception already emitted; docs for `[:thousand_island, :connection, :exception]` | **implementation** |
| `test/support/telemetry_helpers.ex` | Register the new event in `attach_all_events` | test support |
| `test/thousand_island/handler_test.exs` | Regressions for `:error`/`:throw`/`:exit`, `handle_data` raise, and "error return ≠ exception" | test |

**Counts:** 2 substantive implementation files; 1 test-support file + 1 test file (count tests separately).

### Pre-fix behavior (base `1ff4c232`)

No `:exception` event exists. Callback crashes propagate into generated `terminate/2`, whose catch-all reports via `ThousandIsland.Telemetry.stop_span/3` — a `:stop` event with GenServer-normalized exit reason in `error` metadata. Crash vs `{:error, reason, state}` are indistinguishable; class and stacktrace are lost.

Relevant dispatch (after #221):

```elixir
# handle_data for :tcp/:ssl
__MODULE__.handle_data(data, socket, state)
|> ThousandIsland.Handler.handle_continuation(socket)

# handle_continue(:handle_connection, ...)
__MODULE__.handle_connection(socket, state)
|> ThousandIsland.Handler.handle_continuation(socket)
```

### Post-fix shape (merge `7caea62`)

`handler.ex` adds:

```elixir
@doc false
@spec invoke_callback(ThousandIsland.Socket.t(), (-> result)) :: result when result: term()
def invoke_callback(socket, callback) do
  callback.()
catch
  kind, reason ->
    stacktrace = __STACKTRACE__
    ThousandIsland.Telemetry.exception_span(socket.span, kind, reason, stacktrace)
    :erlang.raise(kind, reason, stacktrace)
end
```

Both dispatch sites become `ThousandIsland.Handler.invoke_callback(socket, fn -> ... end) |> handle_continuation(socket)`.

`telemetry.ex`:

```elixir
def exception_span(span, kind, reason, stacktrace) do
  case Process.put(exception_marker(span), true) do
    true -> :ok   # already emitted
    _ ->
      monotonic_time = monotonic_time()
      measurements = %{monotonic_time: monotonic_time, duration: monotonic_time - span.start_time}
      metadata = Map.merge(span.start_metadata, %{kind: kind, reason: reason, stacktrace: stacktrace})
      untimed_span_event(span, :exception, measurements, metadata)
  end
end

def stop_span(span, measurements \\ %{}, metadata \\ %{}) do
  case Process.delete(exception_marker(span)) do
    true -> :ok   # suppress duplicate stop
    _ -> # ... existing stop emission ...
  end
end

defp exception_marker(span), do: {__MODULE__, :exception_emitted, span.telemetry_span_context}
```

### Cross-component invariant

- Callback failure ⇒ **exactly one** `[:thousand_island, :connection, :exception]` with conventional fields, **then** original `kind/reason/stacktrace` re-raised (process exit identical to unpatched).
- `{:error, reason, state}` and normal closes ⇒ **only** `[:thousand_island, :connection, :stop]`, never `:exception`.
- Marker is process-local and keyed by span context — relies on callbacks and `terminate/2` running in the same handler process (stated in PR risks).

---

## 5. Named acceptance assertions (mapped to visible requirements)

| # | Named assertion | Visible justification |
| --- | --- | --- |
| C1 | **Exception span on raise** | Ticket: "raises … does not end with the documented exception event" → must emit it |
| C2 | **Exception span on throw** | Ticket: "throws" |
| C3 | **Exception span on exit** | Ticket: "exits" |
| C4 | **Payload: duration + monotonic_time, kind, reason, stacktrace** | Ticket: "carrying duration, kind, reason, and stacktrace" |
| C5 | **`handle_data/3` covered as well as `handle_connection/2`** | Ticket: "connection or data handler" |
| C6 | **Original exception re-raised / process still crashes the same way** | Ticket: "re-raise the original exception so handler crash behavior is unchanged" |
| C7 | **Error returns keep `stop`, never `exception`** | Ticket: "Ordinary error returns … must keep ending the span with the normal stop event and must not emit the exception event" |
| C8 | **Exactly one terminal event** (no `stop` after `exception`) | Ticket: "does not end with the documented exception event" + "keep ending … with the normal stop" (mutually exclusive ends). Also PR "a process-local marker prevents the later terminate/2 cleanup from also emitting stop". |

Upstream named tests (merge side of `handler_test.exs`):

- `"it should end the span with an exception event when a callback error/throw/exits"` (for over `[:error, :throw, :exit]`)
- `"it should end the span with an exception when handle_data raises"`
- existing `"it should send stop telemetry event with payload on error"` extended with `refute_receive {:telemetry, [:thousand_island, :connection, :exception], _, _}`

---

## 6. Compiling incomplete control + expected named failure

**Incomplete control (compiling, plausible):**

Emit `exception_span` from `invoke_callback`, but **re-raise with a wrapper** (e.g. `raise "callback failed: #{inspect(reason)}"` or `:erlang.raise(:error, {kind, reason}, stacktrace)`), **or** emit exception events **and still** let `stop_span` fire (no marker).

Both compile and produce the exception event.

**Expected named failures:**

- Wrapper case: **C6 fails** — supervisor/crash reason is no longer the original `RuntimeError`/`"nope"`/`:whatever`; upstream `assert_exception_reason/2` and process-exit checks fail.
- Double-event case: **C8 fails** — `refute_receive ... :stop` after exception fails; or stop-only path emits both.

**Alternate incomplete:** only wrap `handle_connection/2` but not `handle_data/3` → **C5** named failure (`Telemetry.DataException` / "handle_data raises").

---

## 7. Integrity / bypass control

Reject solutions that:

| Bypass | Why rejected |
| --- | --- |
| Rescue and continue the handler (swallow) | Violates C6 ("crash behavior unchanged") and process semantics. |
| Only log / Logger.error, no telemetry event | C1–C3 fail. |
| Emit `exception` on ordinary `{:error, reason, state}` | C7 fails. |
| Emit **both** `stop` and `exception` for one crash | C8 fails. |
| Emit `exception` but drop stacktrace or kind | C4 fails. |
| Change GenServer terminate reason to a wrapper | C6 fails. |
| Attach telemetry only in tests (no production path) | C1–C3 fail in real handler runs. |

**Positive preservation:**

- Successful handlers unchanged (still `:stop` on normal close / `{:close, state}`).
- `{:error, reason, state}` still `:stop` with `error` metadata (existing test).
- Handshake failure path (post-#221) unchanged.
- Process death reason for `raise "data nope"` remains `%RuntimeError{message: "data nope"}`.

---

## 8. Preservation

| Behavior | Must remain |
| --- | --- |
| Normal `:stop` telemetry | Unchanged payload shape |
| Handler crash reports / exit reasons | Byte-for-byte the original class/reason/stacktrace |
| #221 ready-after-handshake | Unchanged (already on base) |
| #220 ownership-transfer path | Unchanged (already on base if pinned at `1ff4c232`) |
| Full suite | PR body: `handler_test.exs` passes; format/credo/dialyzer clean |

---

## 9. Runtime / offline / services

| Item | Evidence |
| --- | --- |
| Elixir | `~> 1.13` at base; PR verified on 1.18.4 / OTP 27.3.4 |
| Deps | `telemetry` (~> 0.4 or ~> 1.0) — already required |
| Services | **None** |
| Network | Loopback `:gen_tcp` only |
| Custom transports | **Not required** for #222 tests (unlike #220). |
| Tests run | `mix test test/thousand_island/handler_test.exs`, then full `mix test`. `test_helper.exs` = `ExUnit.start()`. |
| Capture log | Exception tests use `@tag capture_log: true` — keep that to avoid noisy crash reports failing log-based setups. |

---

## 10. Reference challenges

### Later commits touching the same files after merge

**Scan method:** Atom feeds for `telemetry.ex`, `handler.ex` (2026-10-19).

| Path | Later commit after `7caea62` (2026-08-31T20:24:08Z)? | What it changed | Reference bug? |
| --- | --- | --- | --- |
| `lib/thousand_island/telemetry.ex` | **Yes** — `3f262b1030bc4354e0a48de83e05d1480523b71a` **#223** "Add system time to telemetry span start measurements" (2026-08-31T20:27:52Z, parent `7caea62`) | Adds `system_time` measurement to **`start_span/3` only**; updates several tests to expect `system_time`; new `telemetry_test.exs`. Does **not** touch `exception_span/4` or `stop_span/3`. | **Not a fix of #222's bug.** Additive on a different measurement. Treat as **adjacent follow-up**, not a reference-bug signal. |
| `lib/thousand_island/handler.ex` | Yes later — `9ef920e` (#228 peername, 2026-10-15) | Peername cache + `Socket.new/4`. Different concern. | No |
| `lib/thousand_island/handler.ex` | `1ff4c232` (#221) is **before** #222 | ready-after-handshake | Parent, not follow-up |

**Contract asymmetry after #222+#223 (worth noting for grading):**

- Start events: `monotonic_time` **and** `system_time` (after #223).
- Exception events (from #222): documented as `monotonic_time` + `duration` only — **no `system_time`**.
- Stop events: `monotonic_time` + `duration` (+ caller extras).

If a hidden check requires `system_time` on exception events, that is **unfair** relative to #222's visible contract — #223 did not add it. Do not require it.

**No commit undoes or corrects** the exception-span / suppress-stop-marker logic through 2026-10-19.

### Flaky risks

| Risk | Mitigation |
| --- | --- |
| `refute_receive ... 100` for the *absent* terminal event | Slightly tight under load; 100ms is usually fine for local events; bump to 200–300 if CI flakes. |
| Crash reports in logs | `@tag capture_log: true` required. |
| `assert_receive ... 500` for exception event | Adequate; raise is synchronous in the handler before terminate. |

### Contract gaps

| Gap | Note |
| --- | --- |
| **Exact event name** `[:thousand_island, :connection, :exception]` | New event; not present in base docs. Scoring the exact list requires the brief (or visible docs) to name it. **Recommendation:** put the conventional event name in the brief (it is the requested outcome — analogous to a public API name in a refactor ticket), or grade "an exception terminal event with conventional fields" more loosely. |
| Measurement keys `duration` / `monotonic_time` | Ticket already lists them — safe to score. |
| Metadata keys `kind` / `reason` / `stacktrace` | Ticket lists them — safe to score. |
| Whether `stop` metadata still includes `error` for `{:error, _, _}` | Existing behavior; preserve via existing tests. |
| Marker key shape / `Process` dictionary | Implementation detail — do not score. |
| Listener/acceptor exception spans | Out of scope; PR only does connection callbacks. |

---

## 11. Curator record

```markdown
Source type / project / source revisions / PR or original request:
  historical PR / mtrudel/thousand_island /
  base 1ff4c2321399ceed777e6f76fc918028b9c9f20b (= PR #221 merge) →
  merge 7caea621e0afeeb2e92874796a7b8d3caf0e2a7b /
  PR #222 "Emit telemetry exception events for handler callback exceptions"
  (telemetry.span/3 convention; no tracker issue)

Status: screened

Case version / release inventory / public or withheld exposure:
  v0 / not in inventory / public

Task kind / family / maintenance report or clarified brief:
  bug_fix / telemetry & observability contract under failure /
  short maintenance report (may name the public event name as requested outcome)

Full solver-visible ticket and appended instructions:
  See §3. Optionally name [:thousand_island, :connection, :exception] explicitly.
  Do not name invoke_callback / exception_span / Process marker.

Implementation files and each file's role:
  handler.ex     — wrap handle_connection/handle_data; re-raise original
  telemetry.ex   — exception_span/4 + stop suppression + docs
  (2 implementation files)

Test / documentation / generated / mechanical files (separate counts):
  test/support/telemetry_helpers.ex — test support (1)
  test/thousand_island/handler_test.exs — test (1)
  Docs changes are inside telemetry.ex (count with implementation).
  No generated/lockfile files.

Cross-component behavior to verify:
  Exception path and error-return path must stay disjoint;
  process exit reason unchanged while telemetry payload gains class/stacktrace.

Visible source for each scored obligation:
  C1–C7 — ticket sentences in §3
  C8 — ticket "end with the documented exception event" + "keep ending … stop"
  Event atom name — only if brief states it

Starting-state and reference-test evidence (inspected vs executed):
  Inspected: full PR diff, PR body, #221 diff (parent), #223 diff (follow-on),
  atom history for telemetry.ex/handler.ex.
  NOT executed locally in this research pass. PR body claims handler_test passes
  and new assertions fail on unpatched main.

Plausible partial solution and expected named failure:
  Emit exception event but wrap/rebrand the exception on re-raise → C6 fails
  (upstream assert_exception_reason / process reason checks).

Preservation and alternative-solution risks:
  Preserve stop-on-error-return, normal closes, #221 ready timing, crash reasons.
  Alternative: try/catch at a different layer is fine if C1–C8 hold.
  Do not require Process dictionary specifically.

Runtime / offline services / license evidence and unknowns:
  Elixir ~> 1.13, ExUnit, telemetry dep, loopback, no services, MIT.
  Unknown: historical CI file; whether runner treats capture_log tags specially.

Three-round named control outcomes and frozen-input evidence:
  Not run. Required before admission.

Blind model/settings policy and all attempt IDs (including failures/retries):
  None yet.

Independent contract review / passing-patch reviews / unresolved findings:
  Pending. Flag: exact event name in brief or not; do NOT require system_time on
  exception events (that is #223 start-only). Flag C8 as a named check.

Coverage added / related or duplicate tasks:
  Telemetry/observability under failure. Distinct from #220 cleanup and #228 cache.
  Family note: #223 is a later same-file additive change — do not fold into this task.

Admission or exclusion reason / conditions for reconsideration:
  Not admitted yet — needs control execution + blind pair.
  Focused 2-file task with a crisp contract; good reserve if corpus already has
  enough accept-path work from #220.

Next action:
  Clone at 1ff4c232, apply/verify reference patch, run C1–C8 controls
  (raise/throw/exit + error-return + handle_data), then three-round qualification.
  Decide event-name visibility before freezing hidden checks.
```

---

## 12. Next action

1. **Workspace** at `1ff4c2321399ceed777e6f76fc918028b9c9f20b` (post-#221). Do not use `e9a5ae2` as base.
2. **Decide** whether the ticket names `[:thousand_island, :connection, :exception]` (recommended — requested outcome) before hidden checks.
3. Grade C1–C8 with a telemetry handler attached; keep `capture_log: true`.
4. Do **not** require `system_time` on exception events (post-#223 start-only).
5. Run controls once; then three-round freeze + blind pair.

**Not verified in this pass:** local `mix test`, whether `telemetry` 0.4 vs 1.0 changes span helpers (code uses `:telemetry.execute/3` directly), historical CI matrix.
