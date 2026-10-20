# Broadway #369 — Telemetry span around `handle_failed/2`

**Status:** discovered
**Source type:** historical PR
**Project:** [elixir-broadway/broadway](https://github.com/elixir-broadway/broadway)
**PR:** [#369](https://github.com/elixir-broadway/broadway/pull/369)
**Source revisions:** base = first parent of merge (pin at draft) → merge `966c59ad95ddb6aa75c91e71848cfc617bef3a8e`
**Author:** yordis · **Merged:** 2026-04-02
**Task kind / family:** feature / telemetry contract
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

Broadway already emits telemetry around processors and batchers, but the failure path (`Broadway.Acknowledger` invoking the user's `handle_failed/2`) is a black box: no start/stop/exception events. Operators cannot measure failure-handling duration or see raises from user code as telemetry exceptions.

The PR wraps `handle_failed/2` in `:telemetry.span/3` under `[:broadway, :handle_failed]`, documenting the three events (`:start`, `:stop`, `:exception`) and the `telemetry_span_context` metadata. The actual callback invocation is split into `do_handle_failed_messages/3` so the span measures the user callback, while existing arity/return-shape validation errors stay outside or are raised in a way the span can observe.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/broadway.ex` | Document the three `[:broadway, :handle_failed, *]` events and metadata in the telemetry section |
| `lib/broadway/acknowledger.ex` | `:telemetry.span/3` around `module.handle_failed/2`; split `do_handle_failed_messages/3`; keep return-value checks |
| `test/broadway_test.exs` | Named tests: span start/stop from a processor path; exception event when the callback raises |

**Counts:** 2 substantive implementation files, 1 test file.

## Cross-component behavior to verify

- `[:broadway, :handle_failed, :start]` and `[:stop]` fire around a successful `handle_failed/2`.
- `[:broadway, :handle_failed, :exception]` fires when `handle_failed/2` raises (and the existing log/raise behavior is preserved).
- Span metadata includes `telemetry_span_context` (and whatever upstream documented — freeze names in the brief).
- Existing contract still holds: `handle_failed/2` must return the same number of messages; non-list returns still error.
- Other telemetry (`[:broadway, :processor, *]`, batcher events) is unchanged.

## Draft ticket (short maintenance report)

> I cannot observe how long failure handling takes, or whether user `handle_failed/2` code raised, because that callback has no telemetry. Please emit a telemetry span around `handle_failed/2` with the usual start/stop/exception events, documented alongside the existing Broadway telemetry, without changing the callback's return contract or the existing processor/batcher events.

Public names to freeze if graded: event prefix `[:broadway, :handle_failed]` and the `:start`/`:stop`/`:exception` suffixes (PR treats them as the product API).

## Acceptance design (proposed, unexecuted)

- Attach handlers for `:start` and `:stop`; run a topology whose messages fail; assert both events fire once per `handle_failed/2` invocation with a shared span context.
- Callback raises: assert `:exception` event (and that the failure is still logged/handled as today).
- Callback returns wrong arity list: still a named contract error (not silently swallowed by the span).
- Processor/batcher telemetry events still fire and do not include `:handle_failed` in their span names.

## Plausible incomplete (proposed)

Emit only `:start` and `:stop` but no `:exception`, or wrap the return-shape checks inside the span so a contract error is misreported as a user-callback exception. Compiles; a named exception-event or contract assertion fails.

## Integrity control (proposed)

Acceptance must not pass if the span is missing `telemetry_span_context`, if `:exception` fires for validation errors that are not user raises (or the reverse, per frozen brief), or if wrapping changes the arity/return error behavior.

## Runtime / offline

- Elixir `~> 1.7` (from `mix.exs`). OTP `:telemetry` only; no external services.
- Broadway tests use `async: false` in places where app env is mutated (same isolation note as filed Broadway #344). Keep grading isolation honest.
- Node/browser not required.

## License / provenance

- Apache-2.0 (`LICENSE.md`). Public GitHub PR. No private edition.

## Holds / unknowns

- #370 (`feat: include producer metadata in per-message events`, same author, 2 impl files) is a **different** telemetry feature on a nearby path; do not bundle. Keep as sibling reserve if a second Broadway telemetry slot exists.
- Filed Broadway #344 (pluggable config storage) is unrelated; #363 (process labels) was already noted as a thin reserve.
- Exact metadata keys beyond `telemetry_span_context` should be frozen from the PR docs at draft time.

## Coverage added

Telemetry/observability contract on the **failure** path (complements start/stop on happy paths). Small, offline, ordinary ExUnit.

## Next action

If drafting: freeze event names and metadata keys from the PR body, add a "exception event when callback raises" case, and keep the arity/return contract as an integrity control.

---

## Grilling (2026-10-19)

### Minimum ticket
Good short report. "Emit a telemetry span around `handle_failed/2` with the usual start/stop/exception events, documented alongside the existing Broadway telemetry, without changing the callback's return contract or the existing processor/batcher events." That is nearly ideal. Keep event prefix `[:broadway, :handle_failed]` and the three suffixes in the ticket as the product API — the dossier is right to freeze them. Add one clause for `telemetry_span_context` if that metadata is graded ("span metadata must include a span context so start/stop/exception can be correlated").

### Named deterministic checks
Unexecuted. Required named set:
1. `:start` and `:stop` fire once per `handle_failed/2` invocation with a shared span context
2. `:exception` fires when `handle_failed/2` raises (and existing log/raise behavior preserved)
3. wrong-arity / wrong-return `handle_failed/2` still raises the existing contract error (not silently swallowed)
4. processor/batcher telemetry unchanged (no `:handle_failed` mixed into their spans)
5. span metadata includes `telemetry_span_context`

Without (2) the "start/stop only" incomplete passes. Without (3) a solver who wraps validation inside the span and misreports contract errors as user exceptions can pass (4) while breaking the callback contract.

### Ambiguity / unfairness
- "Usual start/stop/exception events" is fine given Broadway already documents spans elsewhere — but freeze the three suffix names explicitly (the draft says to; do it).
- Whether a **validation/arity error** (not a user raise) should emit `:exception` is the unfairness hot spot. The dossier lists it as integrity control "per frozen brief". Decide now: recommendation — `:exception` only for failures **inside** the user callback; arity/return contract errors keep their current error path and are **not** `:handle_failed` exceptions. State that in the brief. If you grade the opposite, state that instead. Do not leave it to hidden checks.
- `telemetry_span_context` presence is gradeable if named in the brief; add it or drop it.
- Do not require exact metadata key list beyond what the brief states.

### Shortcuts + compiling incomplete
Named incompletes: start/stop without `:exception`; validation inside the span misreported. Both compile. Under-weighted shortcuts: fire the span around the whole acknowledger including other users' callbacks (must wrap only `handle_failed/2`); emit start but never stop on success (check 1 counts pairs); change the callback's return contract while refactoring `do_handle_failed_messages/3` (check 3).

### Flakiness
OTP `:telemetry` only; pure ExUnit. Broadway tests use `async: false` where app env is mutated — keep grading isolation honest (this is the Broadway #344 lesson). Telemetry handler attach/detach must be cleaned up per test or later tests flake. Use `:telemetry.attach` + `on_exit` detach; no sleeps.

### Preservation
Processor and batcher telemetry unchanged (check 4). Return-contract errors unchanged (check 3). Add a named "normal successful handle_failed still returns the same messages" so a refactor that drops messages cannot pass by only firing events.

### Env
Elixir `~> 1.7` from mix.exs; historical CI at merge `966c59ad` not pinned. No services. **Nothing executed** — no apply, no compile, no test. Apache-2.0.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. Do **not** bundle #370 (producer metadata in per-message events) — different feature. #344 / #363 stay separate.

### Verdict
**HOLD** — small and coherent, but the exception-vs-validation policy is undecided and nothing has been executed.

### Must-fix before qualification
1. Pin base (first parent of `966c59ad`) and toolchain; run `mix test` at base and base+patch.
2. Decide and state in the brief: `:exception` for user-callback raises only (recommended) **or** for all failures inside the span — no third unstated option.
3. Name checks 1–5 as protected tests; add success-path message-preservation check.
4. Freeze `telemetry_span_context` in the brief or drop it from graded metadata.
5. Keep telemetry handler cleanup in fixtures so tests do not flake; Apache-2.0 in provenance.
