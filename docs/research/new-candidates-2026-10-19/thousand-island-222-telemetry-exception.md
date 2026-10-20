# Thousand Island #222 — Emit telemetry exception events for handler callback exceptions

**Status:** discovered  
**Source type:** historical PR  
**Project:** [mtrudel/thousand_island](https://github.com/mtrudel/thousand_island)  
**PR:** [#222](https://github.com/mtrudel/thousand_island/pull/222)  
**Source revisions:** base `e9a5ae259a103911728f92c15cbcbecf99662570` → merge `7caea621e0afeeb2e92874796a7b8d3caf0e2a7b`  
**Author:** mpettibone · **Merged:** 2026-08-31  
**Task kind / family:** bug_fix / telemetry contract  
**Research date:** 2026-10-19

## Authentic work

Handler `handle_connection/2` / `handle_data/3` raises, throws, or exits → connection span did not end with the conventional `[:thousand_island, :connection, :exception]` event. Ordinary `{:error, reason, state}` returns must still emit `:stop`. The exception must be re-raised unchanged so handler process semantics do not change.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/thousand_island/handler.ex` | Wrap callbacks; re-raise original class/reason/stacktrace |
| `lib/thousand_island/telemetry.ex` | Exception span end measurements/metadata |
| `test/support/telemetry_helpers.ex` | Helpers |
| `test/thousand_island/handler_test.exs` | Regressions |

**Counts:** 2 substantive implementation files, 1 support + 1 test file.

## Cross-component behavior to verify

- Exception path: `[:thousand_island, :connection, :exception]` with `duration`, `monotonic_time`, `kind`, `reason`, `stacktrace`.
- Normal error-return path: still `:stop` only.
- Handler process still crashes with the **original** exception (not a wrapper).
- Successful handlers unchanged.

## Draft ticket (short maintenance report)

> When a connection or data handler raises, throws, or exits, the connection telemetry span does not end with the documented exception event. Emit the exception span for those failures and re-raise the original exception so handler crash behavior is unchanged. Keep the ordinary stop event for normal error returns.

## Acceptance design (proposed, unexecuted)

- Attach a telemetry handler; trigger raise/throw/exit in handler callbacks; assert exception event payload and that the process exits with the original reason.
- Assert `{:error, reason, state}` still produces `:stop` and not `:exception`.

## Plausible incomplete (proposed)

Emit exception telemetry but wrap/rebrand the exception; or emit exception events on ordinary error returns.

## Integrity control (proposed)

Reject a solution that rescues and continues the handler, or that only logs without the telemetry event.

## Runtime / offline

Same as other Thousand Island tasks: Elixir `~> 1.13`, ExUnit, no services.

## License / provenance

MIT. Same contributor series as #220.

## Holds / unknowns

- Exact telemetry event names/metadata keys are the public contract — must be in the brief if scored (they are conventional Telemetry names already documented in the project).
- Sibling of #220 on the same base; treat as focused reserve unless a telemetry-family case is wanted.

## Coverage added

Telemetry / observability contract under failure.

## Next action

Keep as focused reserve. Prefer #228/#220 first if only one Thousand Island case is prepared initially.
