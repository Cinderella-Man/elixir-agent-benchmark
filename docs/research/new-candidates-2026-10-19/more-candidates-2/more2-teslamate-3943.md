# TeslaMate #3943 — honor Retry-After on HTTP 429

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#3943](https://github.com/teslamate-org/teslamate/pull/3943) — *Respect Retry-After header on 429 response code*  
**Author:** (upstream) · **Merged:** 2024-06-07  
**Task kind / family:** bug_fix / Tesla API client error surface → Vehicle fetch scheduling  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `b900a98d08c227c0ffe780cae807a0f239284965` | Title `…(#3943)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `f34c0876e80171cc4f41b78ad26d6f0652339491` | Sole parent on commit page — **task base** (PR API `base` was `31cdaac…`; master moved before merge) |

PR metadata: same-week open/merge. Reconstruct at **`f34c0876…`** and apply `pull/3943.diff`. Drop `.gitignore` (mechanical).

## Why it is a good case

Tesla’s Fleet/owner API returns **429 Too Many Requests** with a `Retry-After` header. TeslaMate currently treats that as a generic error and keeps polling on the default schedule, so rate-limited cars thrash the API. The fix must thread a new error shape from `TeslaApi.Vehicle` (parse header) through `TeslaMate.Api` (typed 3-tuple) into `TeslaMate.Vehicles.Vehicle` (reschedule fetch after `retry_after` seconds). Three coordinated implementation files plus a test; the ticket can describe rate-limit backoff without naming modules or the `Retry-After` key.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/tesla_api/vehicle.ex` | On 429, parse `retry-after` (default `"300"`) and return `%Error{reason: :too_many_request, message: seconds}` |
| `lib/teslamate/api.ex` | Match the new error reason and return `{:error, :too_many_request, retry_after}` |
| `lib/teslamate/vehicles/vehicle.ex` | On that tuple, keep state and `schedule_fetch(retry_after, data)` instead of the usual error path |
| `test/teslamate/api_test.exs` | Mocked API test for the 429 path |
| `.gitignore` | Mechanical — exclude from graded diff |

**Counts:** 3 substantive implementation files + 1 test. Coordinated error-policy work, not a one-liner.

## Cross-component behavior to verify

- HTTP 429 with `Retry-After: 60` must delay the next vehicle fetch by ~60s (not the usual 30s error backoff).
- Missing `Retry-After` uses a conservative default (upstream: 300s).
- Other error reasons (`:vehicle_unavailable`, `:timeout`, generic) keep their existing schedules.
- Summary/fetch broadcasts still fire so the UI does not show a stuck “fetching” state.

## Draft ticket (shortest sufficient)

> When the Tesla API rate-limits us (HTTP 429), we keep polling too aggressively and make the limit worse. Honor the API’s retry delay when it is provided and wait that long before the next vehicle fetch; if the response does not say how long to wait, use a conservative default. Other API errors must keep behaving as they do today. Fix it.

Maintenance report. Does not name files, `Retry-After`, or the GenServer.

## Proposed named acceptance checks

1. `api 429-parses-retry-after` — mocked 429 with `retry-after: 60` yields a typed rate-limit error carrying `60`.
2. `api 429-defaults-when-header-missing` — 429 without header yields the conservative default delay.
3. `vehicle reschedules-after-retry-after` — given that error, next fetch is scheduled at the provided delay, state preserved.
4. `vehicle keeps-other-error-schedules` — `:vehicle_unavailable` / timeout still use their existing intervals (preservation).
5. `api other-errors-unchanged` — non-429 errors still return the previous 2-tuple shape (preservation).

**Upstream test caveat:** `api_test.exs` names `:too_many_requests` (plural) while implementation uses `:too_many_request` (singular); the mock may fall through the generic handler. Curator must align reason atoms and assert the **3-tuple** path plus Vehicle reschedule, not only `Api.get_vehicle`.

## Plausible incomplete + integrity control

- **Incomplete:** parse 429 in `TeslaApi.Vehicle` only; `api.ex` / `vehicle.ex` unchanged (compiling). Fails check 3.
- **Integrity:** reject patches that always sleep 300s, that drop the delay for other errors, or that parse `Retry-After` as milliseconds without converting.

## Preservation

- 408 / 504 / offline / signed-out paths keep current schedules.
- Streaming vs non-streaming fetch cadence unchanged for non-429 cases.

## Runtime / offline holds

- AGPL-3.0. PostgreSQL + MQTT optional; tests use Mox for `TeslaApi`. No live Tesla account.
- Verify `test/teslamate/api_test.exs` runs offline at `f34c0876…`.
- Atom mismatch above is a **grading fix**, not a product decision.

## Experiments (quick)

- `pull/3943.diff` well-formed; 5 paths as listed. Diff parses.
- Squash parent `f34c0876…` from commit page (`parents:[…]`, “1 parent”). Prefer this over PR API `base` `31cdaac…`.

## Optional git apply

```
git checkout f34c0876e80171cc4f41b78ad26d6f0652339491
git apply --exclude=.gitignore pull/3943.diff
```

## Status: discovered

Strong 3+1 coordinated bug with a real cross-process contract. Named checks need a small curator fix (reason atom / 3-tuple).

## Next action

Pin `f34c0876…` → apply diff minus `.gitignore` → rewrite checks 1–5 with matching reason atoms → incomplete = vehicle.ex-only parse → three qualification rounds.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> When the Tesla API rate-limits us (HTTP 429), we keep polling too aggressively. Wait as long as the API says before the next vehicle fetch; if the response does not say, wait five minutes. Other API errors must keep their current schedules. Fix it.

Maintenance report, 3 sentences. States the two product decisions the repo cannot settle: honor the server-supplied delay, and the no-header default is **five minutes**. Does not name `Retry-After`, modules, or the GenServer.

**Hidden requirement flagged:** the draft ticket said "use a conservative default" without a number. The reference hardcodes `"300"` in `lib/tesla_api/vehicle.ex`. A solver who picks 60s or 600s is defensible and would fail a hidden "exactly 300" check. State the default in the ticket or accept a band.

### 2. Deterministic checks

All offline; Mox already mocks `TeslaApi`. No sleep — assert the **scheduled delay** value, not wall-clock.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `api rate-limit-carries-delay` | Mock `get/2` returns 429 with header `retry-after: 60` | `Api.get_vehicle/2` return | `{:error, :too_many_request, 60}` (typed 3-tuple; atom name free but consistent) |
| `api rate-limit-default-delay` | Mock 429 **without** header | same | 3-tuple carrying `300` (or the ticket's stated default) |
| `vehicle reschedules-on-rate-limit` | Feed that 3-tuple into the Vehicle fetch error path (or drive via mocked Api) | next `schedule_fetch` delay + state | delay equals the carried seconds; state kept; `broadcast_fetch(false)` and `broadcast_summary()` still emitted |
| `vehicle other-errors-unchanged` | `:vehicle_unavailable`, `:timeout`, generic reason | schedule delay | still the pre-change intervals (preservation) |
| `api non-429-shape-unchanged` | Mock generic `TeslaApi.Error` | `Api.get_vehicle/2` | still the old 2-tuple `{:error, reason}` (preservation) |

Needs a fake provider: yes — existing Mox `TeslaApi.Vehicle` mock. No fake HTTP server.

**Do not reuse upstream `api_test.exs` as the graded check.** Diff evidence: the new test mocks `reason: :too_many_requests` (plural) and asserts `{:error, :too_many_requests}` (2-tuple), while `api.ex` matches `:too_many_request` (singular) and returns a 3-tuple. The mock falls through the generic handler; the assertion passes for the wrong reason. That test is a false green.

### 3. Ambiguity / unfairness

- Default delay is the main contest (above). Fix the ticket.
- Atom spelling (`:too_many_request` vs `:too_many_requests`) is implementation — checks must not pin the atom name, only the shape and the carried integer.
- Whether `Retry-After` may be HTTP-date (spec allows it) is unsettled. Reference only does `String.to_integer/1` and will crash on a date. Either say "delay is given in seconds" or accept date parsing. Prefer stating seconds-only in the ticket.
- Header name casing: Tesla.Env headers are downcased in practice; a solver matching `"Retry-After"` only is plausible. Grade case-insensitively or state lowercase.

### 4. Shortcuts

- Parse the header and return a 3-tuple from `TeslaApi.Vehicle` only; never thread it through `Api`/`Vehicle`. Compiles; Vehicle keeps the old schedule. Caught by `vehicle reschedules-on-rate-limit`.
- Always sleep 300s on any error (over-backoff). Caught by `vehicle other-errors-unchanged`.
- Return the delay but `schedule_fetch` the usual 30s "error" path while logging the delay. Caught by the schedule assertion.
- Parse `Retry-After` as milliseconds → 60_000s schedule. Integrity check: assert the unit is seconds.

### 5. Flakiness / nondeterminism

Low. Pure mocked-Api path. Risk: `schedule_fetch` is a state-machine timeout — assert the timeout value in the returned action list (or via `:sys.get_state` / telemetry), never `Process.sleep`. Do not boot the full Vehicles supervisor tree with MQTT if avoidable; the three modules can be tested at their boundaries.

### 6. Coverage mix

Need both directions:
- Positive: 429 with header, 429 without header (new behaviour).
- Preservation: `:vehicle_unavailable`, `:timeout`, generic error schedules, and the non-429 `Api` return shape.
- Mixed population in one Vehicle test: one 429 then one generic error — second fetch must use the generic schedule, not stick at 300s.

### 7. Environment risk

- **AGPL-3.0** — record in provenance; fine for research, not for some distributions.
- PostgreSQL for the suite; MQTT optional. Focused `api_test` + a Vehicle error-path test should run with PG only.
- No live Tesla account (Mox). Historical Elixir/OTP at `f34c0876…` must be pinned; repo is not young.
- `.gitignore` hunk is mechanical — drop from graded diff.

### 8. Verdict

**READY-WITH-FIX** — real 3-file cross-process contract, but the default-delay policy is unstated and the upstream test is a false green.

### 9. Must-fix list

1. Put the no-header default (five minutes / 300s) in the ticket, or accept any documented conservative default in checks.
2. Author curator checks 1–5; **discard** the upstream `:too_many_requests` test as graded evidence (atom + arity mismatch).
3. Decide Retry-After format: state "seconds only" in the ticket or accept HTTP-date.
4. Incomplete control = parse in `TeslaApi.Vehicle` only (compiling); it must fail the Vehicle reschedule check.
5. Preservation witness for `:vehicle_unavailable` / `:timeout` / generic schedules.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Unstated default delay + upstream test false-green |
