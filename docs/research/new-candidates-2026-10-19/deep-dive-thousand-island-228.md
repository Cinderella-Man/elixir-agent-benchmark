# Deep-dive dossier — Thousand Island PR #228 (peername cache)

**Status:** screened (deep-inspected; not yet provisional/admitted)  
**Research date:** 2026-10-19  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/mtrudel/thousand_island/pull/228 |
| Title | Cache the peername on the socket so it survives the client going away |
| Author | **mtrudel** (maintainer; not an outside contributor) |
| Created | 2026-10-15T16:59:15Z |
| Merged | 2026-10-15T17:12:32Z |
| **Base SHA (parent of merge)** | `e3eb2a7a05f98d79436abcefd8c954da2f8b05c0` |
| **Merge SHA** | `9ef920e33a1ac8853bf92736c35759f5bc6c0680` |
| Head SHA | `7a839432815131f15dfc85dd3d646286e480c1a0` (branch `cache-peername`) |
| Diff | https://github.com/mtrudel/thousand_island/pull/228.diff |
| Claude-generated body | Yes (`🤖 Generated with Claude Code`); treat **code + tests** as evidence, not the tool story |
| Mix version at base | `1.5.0` |
| Elixir req at base | `~> 1.13` |
| License | MIT — Copyright (c) 2018 Mat Trudel |

### Linked issues / downstream evidence

| Ref | Relationship |
| --- | --- |
| [mtrudel/bandit#647](https://github.com/mtrudel/bandit/issues/647) | Upstream symptom: `log_client_closures: false` does not suppress client disconnects during HTTP/2 connection init ("Unable to obtain conn_data", non-`:closed` reason). PR body cites this as the production crash (`Bandit.SocketHelpers.conn_data/1`). |
| [mtrudel/bandit#717](https://github.com/mtrudel/bandit/pull/717) | Downstream Bandit PR "Don't crash the HTTP/1 handler when the client aborts during init" — a defensive rescue on the Bandit side for older Thousand Island. PR #228 notes it "is still worth having for users on older Thousand Island versions" and can be removed once Bandit's minimum TI includes this. |
| PR body claim | "The reporter sees it a few times a day per node behind a cloud load balancer." — authentic, recurring production defect, not synthetic. |

No GitHub issue **inside** thousand_island is linked. The problem statement is self-contained in the PR body.

---

## 2. Shortest sufficient ticket text

Maintenance report shape (do **not** name `Socket.new/4`, the `peername` field, or the file split):

> After a client connects and then goes away, reading the connection's peer address can crash the handler because the address is looked up again on a dead socket. Make the peer address stable for the life of the connection once it has been obtained, and keep the existing early-close behavior when it cannot be obtained at start. Fix it.

**Optional clarifiers (only if a hidden check would otherwise be unfair):**

- Peer address must remain the **real** client address from connection start (not a placeholder).
- `ThousandIsland.Socket.peername/1` is a public API used by handlers; it must keep returning `{:ok, address}` after the peer is gone.
- Early-close path `{:shutdown, {:premature_conn_closing, reason}}` when the **initial** lookup fails must remain.

**Do not put in the ticket:** the new field name, `Socket.new/4` arity change, "cache", or "struct". Those are reference shape, not user-visible outcomes — except if the curator deliberately scores the **API arity** as a stated outcome (see §11 contract gaps). Prefer scoring behavior over arity.

---

## 3. Implementation roles + key code quotes

### Files

| File | Role | Count |
| --- | --- | --- |
| `lib/thousand_island/handler.ex` | Capture peername at accept time and pass it into the socket struct; docs update for manual `Socket.new` users | **implementation** |
| `lib/thousand_island/socket.ex` | Store peername on the struct; `peername/1` returns the cached value | **implementation** |
| `test/thousand_island/socket_test.exs` | Regression: RST then read peername; unit: `Socket.new` stores what `peername/1` returns | test |

**Counts:** 2 substantive implementation files, 1 test file. Docs change is inside `handler.ex` (moduledoc step 3) — count once with the file.

### Pre-fix behavior (base `e3eb2a7`)

`handler.ex` already looks up peername at connection start and throws away the result after using it for process label + telemetry:

```elixir
{ip, port} =
  case handler_config.transport_module.peername(raw_socket) do
    {:ok, remote_info} ->
      remote_info
    {:error, reason} ->
      # ... client has already gone away ...
      _ = handler_config.transport_module.close(raw_socket)
      throw({:stop, {:shutdown, {:premature_conn_closing, reason}}, {raw_socket, state}})
  end

ThousandIsland.ProcessLabel.set(:connection, handler_config, {ip, port})
# ... telemetry span_meta with remote_address/remote_port ...
socket = ThousandIsland.Socket.new(raw_socket, handler_config, connection_span)
```

`socket.ex` re-queries the live transport every call:

```elixir
@spec peername(t()) :: ThousandIsland.Transport.on_peername()
def peername(%__MODULE__{} = socket) do
  socket.transport_module.peername(socket.socket)
end
```

### Post-fix shape (merge `9ef920e`)

1. `handler.ex` passes the already-known `{ip, port}` into `Socket.new/4`:
   ```elixir
   socket = ThousandIsland.Socket.new(raw_socket, {ip, port}, handler_config, connection_span)
   ```
2. `socket.ex` gains enforced `:peername` key; `Socket.new/3` becomes `Socket.new(raw_socket, peername, handler_config, span)`; `peername/1` becomes:
   ```elixir
   def peername(%__MODULE__{peername: peername}), do: {:ok, peername}
   ```
3. Handler moduledoc step 3 rewritten: manual implementors must call `transport.peername(raw_socket)` first and abandon if it fails, then `Socket.new/4`.

### Cross-component invariant to keep consistent

- The address used for **process label**, **telemetry metadata** (`remote_address`/`remote_port`), and **`Socket.peername/1`** must be the same value, taken once at accept time.
- Initial lookup failure still closes and stops with `{:premature_conn_closing, reason}` — caching must not invent a dummy peer.
- Successful connected clients still see their real peer.

---

## 4. Named acceptance assertions (mapped to visible requirements)

| # | Named assertion | Visible justification |
| --- | --- | --- |
| A1 | **Peername stable after client RST**: after client abort, `:inet.peername(socket.socket)` fails **and** `ThousandIsland.Socket.peername(socket)` returns `{:ok, {_ip, client_port}}` matching the client's port. | Ticket: "peer address stable for the life of the connection once it has been obtained" after "client connects and then goes away". |
| A2 | **Cached value is the real peer**: while connected, peername equals the actual remote address/port (not `nil`, not hardcoded loopback/zero). | Ticket: "peer address"; positive requirement that address is real. Integrity control also covers this. |
| A3 | **Early close preserved**: when the **initial** transport peername lookup fails, connection still stops with `{:shutdown, {:premature_conn_closing, reason}}` and the socket is closed. | Ticket: "keep the existing early-close behavior when it cannot be obtained at start". |
| A4 | **Handler crash gone for abort race**: a handler that calls `Socket.peername/1` in `handle_connection/2` after the peer is gone does **not** crash (no exception from peername). | Ticket: "can crash the handler... Fix it." |

**Optional A5 (API shape — only if brief states it):** `Socket.new` accepts the peer address and `peername/1` always returns `{:ok, _}`. This is a **breaking change** for external socket builders (PR body documents `lucacorti/bgp`, `MdSadiqMd/firemig`). Prefer not to require a specific arity; accept any implementation that satisfies A1–A4.

### Upstream regression tests (reference, for curator mapping)

From `test/thousand_island/socket_test.exs` (merge side):

- `PeernameAfterAbort` handler: wait until live `:inet.peername/1` fails (RST via `linger: {true, 0}`), then compare live vs `Socket.peername/1`.
- Unit: `Socket.new(:unused, {{1,2,3,4},5}, handler_config, nil)` → `peername/1 == {:ok, {{1,2,3,4},5}}`.

---

## 5. Compiling incomplete control + expected named failure

**Incomplete control (compiling, plausible partial fix):**

Capture peername in `handler.ex` for process label / telemetry only (as today), and add a `peername` field that is **stored but unused** by `Socket.peername/1` — leave `Socket.peername/1` as a live `transport_module.peername(socket.socket)` lookup.

This compiles (`Socket.new/4` can take the extra arg and ignore it, or `new/3` can remain). It even keeps A2 (connected case still works) and A3 (early close).

**Expected named failure:**

- **A1 / A4 fail** — after RST, `Socket.peername/1` returns `{:error, :enotconn | :einval}` or raises depending on transport, and a handler that pattern-matches `{:ok, ...}` crashes.
- Specifically the upstream regression `is still available once the client has aborted the connection` fails on `assert {:ok, {_ip, ^client_port}} = cached`.

---

## 6. Integrity / bypass control

Reject solutions that:

| Bypass | Why rejected |
| --- | --- |
| Return `nil` / `:error` / hardcoded `{{127,0,0,1}, 0}` for **every** peername | Breaks A2 (real peer). |
| Cache only in telemetry/process-label and leave `Socket.peername/1` live | That is the incomplete control — A1 fails. |
| Return a successful dummy peername when the **initial** lookup failed | Breaks A3 / papers over premature close. |
| Rescue and swallow handler crashes without providing a real peer address | Does not satisfy "peer address stable"; just hides the crash. |
| Keep live lookup but wrap it in `try/rescue` returning `{:error, reason}` after abort | Behavior still not "stable"/`{:ok, ...}`; handlers that expect ok-tuple still break. |

**Positive preservation examples** (must pass on the repair):

- Fresh connected client: peername is real IP+ephemeral port.
- `{:ok, {ip, port}} = Socket.peername(socket)` used for Registry registration (docs example in `handler.ex`) still works while connected.
- Premature-close path still fires when transport peername fails at start.

---

## 7. Preservation

| Behavior | Must remain |
| --- | --- |
| Process label | Still set from peer `{ip, port}` |
| Telemetry `remote_address` / `remote_port` | Same peer as `Socket.peername/1` |
| Handshake / normal close / `handle_connection` continuation | Unchanged |
| `sockname` / `peercert` / other Socket metadata | Unchanged (PR is **only** peername; do not expand scope to sockname) |
| Existing suite | Full suite green (PR body: 129 passed) |

---

## 8. Runtime / offline / services

| Item | Evidence |
| --- | --- |
| Elixir | `~> 1.13` at base (`mix.exs`) |
| OTP | ExUnit + `:gen_tcp` loopback; PR body verified on Elixir 1.18.4 / OTP 27.3.4 |
| Deps | `telemetry` (~> 0.4 or ~> 1.0); dev/test: machete, ex_doc, dialyxir, credo |
| Services | **None.** No PostgreSQL/ClickHouse/Node. |
| Network | Loopback TCP only (`:gen_tcp.connect(~c"localhost", port, ...)`). Offline-safe. |
| Custom transports | Not required for this PR's tests. Upstream suite has custom transports elsewhere; this regression uses real `:gen_tcp` + `linger: {true, 0}` RST. |
| Tests run | `mix test` (plain ExUnit; `test_helper.exs` is just `ExUnit.start()`). `elixirc_paths(:test)` includes `test/support`. |
| Platform note | `:enotconn` (Linux) vs `:einval` (macOS) — assertions should use `{:error, _}` not a specific atom. |

**Flaky risk (moderate):** the RST race uses `wait_for_failure` polling up to 200×5ms for the live lookup to fail. Usually deterministic with `linger: {true, 0}`; on a loaded CI host the poll can exhaust and `live` stays `{:ok, _}`, failing the test's `assert {:error, _} = live`. Prefer a custom transport that deterministically returns `{:error, :enotconn}` from `peername/1` after a close signal for the graded check; keep the RST test as a secondary.

---

## 9. Reference challenges

### Later commits touching the same files after merge

**Scan method:** GitHub commits Atom feeds for `lib/thousand_island/socket.ex`, `lib/thousand_island/handler.ex` (checked 2026-10-19).

| Path | Later commits after `9ef920e` (2026-10-15T17:12:32Z)? |
| --- | --- |
| `lib/thousand_island/socket.ex` | **None.** Merge commit is the tip of that file's history. |
| `lib/thousand_island/handler.ex` | **None.** |
| Whole repo | Only `3528889b688742ee533c7bdfe355405874481b72` "Version bump to 1.6.0" (2026-10-15T18:07:35Z) — version metadata, not a fix. |

**Conclusion: no follow-up fix / reference bug candidate for #228 as of 2026-10-19.** Re-check before freeze if research drifts more than a few weeks.

### Flaky risks

- RST / `linger` race (see §8). Use deterministic custom transport for graded assertions if needed.
- `assert_receive ... 2000` timeouts in upstream tests are tight for slow hosts — bump or use explicit sync.

### Contract gaps / overconstraint risks

| Gap | Note |
| --- | --- |
| **API break** | `Socket.new/3` → `new/4` and new enforced `:peername` key. Scoring exact arity invents a product decision. Prefer behavior (A1–A4). If arity is scored, **state it in the brief** as a compatibility rule. |
| **Always `{:ok, _}`** | Post-change `peername/1` can never return `{:error, _}`. Handlers that still match `{:error, _}` keep compiling. Do not require solvers to change that contract unless the ticket says so. |
| sockname / other metadata | Out of scope. Do not require. |
| Bandit integration | Out of scope; Bandit is a separate repo. |

### Sibling / family relationship

- Distinct from #220 (ownership-transfer cleanup) and #222 (telemetry exception): different defect family (socket metadata lifetime vs process cleanup vs observability).
- Same project, small Mix, loopback — good first Thousand Island case.
- Do **not** merge with siblings into one task.

---

## 10. Curator record (from `docs/pr-selection-guidelines.md`)

```markdown
Source type / project / source revisions / PR or original request:
  historical PR / mtrudel/thousand_island /
  base e3eb2a7a05f98d79436abcefd8c954da2f8b05c0 → merge 9ef920e33a1ac8853bf92736c35759f5bc6c0680 /
  PR #228 "Cache the peername on the socket so it survives the client going away"
  (linked: bandit#647, bandit#717)

Status: screened

Case version / release inventory / public or withheld exposure:
  v0 / not in inventory / public (upstream PR is public; training exposure possible)

Task kind / family / maintenance report or clarified brief:
  bug_fix / socket metadata lifetime / short maintenance report

Full solver-visible ticket and appended instructions:
  See §2. Do not include PR number, file names, or "cache".

Implementation files and each file's role:
  handler.ex — capture peername at accept; pass into Socket
  socket.ex  — store peername; peername/1 returns cached ok-tuple
  (2 implementation files)

Test / documentation / generated / mechanical files (separate counts):
  socket_test.exs — 1 test file (2 tests). Docs live inside handler.ex (no separate count).
  No generated/lockfile/mechanical-only files.

Cross-component behavior to verify:
  process label, telemetry remote_address/remote_port, and Socket.peername/1
  all agree on one accept-time peer value; premature close still works.

Visible source for each scored obligation:
  A1/A2/A4 — ticket sentences "stable for the life of the connection" + "can crash the handler"
  A3 — ticket sentence "keep the existing early-close behavior"
  (arity change — only if brief states a compatibility rule)

Starting-state and reference-test evidence (inspected vs executed):
  Inspected: full PR diff, base handler.ex/socket.ex, PR body, bandit issues.
  NOT executed locally in this research pass (no clone/run). PR body claims 129 passed,
  mix format/credo/dialyzer clean on Elixir 1.18.4 / OTP 27.3.4.

Plausible partial solution and expected named failure:
  Store peername on struct but leave Socket.peername/1 as live lookup →
  fails A1/A4 (RST case returns error/raises).

Preservation and alternative-solution risks:
  Preserve early close, real peer when connected, process label, telemetry.
  Alternative: keep new/3 and stash peername in process dictionary / handler state —
  acceptable if A1–A4 hold; do not require struct field.

Runtime / offline services / license evidence and unknowns:
  Elixir ~> 1.13, Mix/ExUnit, loopback TCP, no services, MIT.
  Unknown: exact OTP matrix in historical CI (ci.yml not at expected path; unverified).

Three-round named control outcomes and frozen-input evidence:
  Not run. Required before admission.

Blind model/settings policy and all attempt IDs (including failures/retries):
  None yet.

Independent contract review / passing-patch reviews / unresolved findings:
  Pending. Flag API-arity overconstraint (see §9).

Coverage added / related or duplicate tasks:
  Socket metadata lifetime. Complements HTTP-client research; not a duplicate of #220/#222.

Admission or exclusion reason / conditions for reconsideration:
  Not yet admitted — needs local execution of controls + blind pair.
  Strong candidate: coherent 2-file behavior, clear visible contract, offline.

Next action:
  Clone at e3eb2a7, run reference/unchanged/incomplete/integrity controls once,
  then decide whether ticket stays behavioral (recommended) or names the API rule.
```

---

## 11. Next action

1. **Prepare workspace** at `e3eb2a7a05f98d79436abcefd8c954da2f8b05c0` (Elixir ~> 1.13; CI-style 1.18/OTP 27 is fine).
2. **Run controls once** (not three-round freeze yet): unchanged (expect A1 fail), reference (A1–A4 pass), incomplete (A1 fail only), integrity (A2 bypass fails).
3. **Decide contract surface:** keep ticket behavioral (recommended) vs state `Socket.new` arity/`{:ok, _}` contract explicitly.
4. **Harden flaky RST** if the graded check uses the upstream test — consider a deterministic custom transport wrapper.
5. If green: mark **provisional**, then three qualification rounds + two blind successes.

**Not verified in this pass:** local `mix test` execution, historical CI matrix file, absence of unpublished private forks depending on `Socket.new/3`.
