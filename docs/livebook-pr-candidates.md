# Livebook historical repair candidates

Source review on 2026-10-11. Recommended first authoring batch: **six coherent historical repairs**, including the previously identified #2822 and #3076. This document records source evidence and proposed acceptance checks; no candidate here has been built, executed, or runtime-qualified by this investigation. Proposed tests and incomplete-repair probes remain hypotheses until broken/fixed controls establish their behavior.

The upstream merge commits below each have a single parent. Those actual parent relationships were checked through GitHub's commit API; a PR's `base.sha` is not assumed to be its final broken baseline. Fixed-revision source and test diffs were inspected. Each pair preserves the real historical code and dependencies rather than transplanting defects into a shared modern baseline.

| PR | Candidate behavior | Broken parent | Fixed commit |
| --- | --- | --- | --- |
| [#2219](https://github.com/livebook-dev/livebook/pull/2219) | Inputs introduced through frame updates render correctly | `64dad900d7890389f6f59edf4d6dbbdb725bcb26` | `2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66` |
| [#2527](https://github.com/livebook-dev/livebook/pull/2527) | Notebook stamps do not authorize added unsigned content | `57ddb291598b4ac5683fd71bd7a1454b621091e4` | `94a0aedfda5d518997359a976f135dd0c12724e9` |
| [#2663](https://github.com/livebook-dev/livebook/pull/2663) | Markdown round trips preserve nested long numbered lists | `6f7a8e3e79db9a002b5c2508d817402b7c11ccb5` | `12ccf3c6834170326b5c4c964672e77244f13f42` |
| [#2800](https://github.com/livebook-dev/livebook/pull/2800) | Erlang cell syntax errors show usable diagnostics | `c374ac6a4b50d65b60d6112c5dd95bd79f7453dd` | `3470f2de4878efe15de76193134ad9dbbef5dc43` |
| [#2822](https://github.com/livebook-dev/livebook/pull/2822) | Failed evaluation preserves earlier imports and process dictionary | `5ee9a502af29daa8b499a5e0aba7c36f169968e6` | `8dfe52258f3e383fe74a8fc1f2d0be38f0c9bbb6` |
| [#3076](https://github.com/livebook-dev/livebook/pull/3076) | Adding S3 storage through the real LiveView form succeeds | `bdb2b95a1d7fe837cd71e17688791d4785bb37e9` | `02f00794c202e6a0a83f2c3cc94ee617a9d2f80c` |

## #2219 — frame inputs and their default values

The report describes input controls inside a dynamically replaced frame appearing blank until unrelated interaction forces a rerender. Ticket facts can describe that visible behavior, give a frame containing a labeled input with a default value, and require the default value to appear after the update in both notebook and app sessions. Do not describe indexing, the changed helper, or the diagnosis in the ticket. [Original Kino issue #345](https://github.com/livebook-dev/kino/issues/345).

The repair coordinates `Livebook.Notebook`, `Notebook.Cell`, `SessionLive` and `AppSessionLive`: frame-update children are indexed, input/asset traversal recognizes the update, and targeted component updates receive input views. One coherent input-rendering defect crosses four production modules. A new `frame output update with input` LiveView test uses existing session APIs, injects `:runtime_evaluation_output`, synchronizes with the session and asserts the label and input value. It uses no browser or live external service. [Repair](https://github.com/livebook-dev/livebook/commit/2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66), [LiveView test](https://github.com/livebook-dev/livebook/blob/2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66/test/livebook_web/live/session_live_test.exs).

Qualification concern: upstream changes `Notebook.find_frame_outputs/2` from frame outputs to `{frame_output, cell}` pairs and updates two original notebook tests accordingly. Blindly restoring the original notebook-test expectations after applying the reference repair would reject the upstream solution. Preserve independent original coverage, while explicitly accounting for those implementation-facing contract changes; do not turn the new helper shape into an agent requirement. The new LiveView regression uses existing APIs and avoids that problem. The session helper waits through a synchronous `Session.get_data/1`, not a sleep or measured duration. [Notebook test diff](https://github.com/livebook-dev/livebook/pull/2219/files), [synchronization helper](https://github.com/livebook-dev/livebook/blob/2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66/test/support/session_helpers.ex).

Proposed supplement: exercise append and replace, nested inputs, and an app-session rendering path if the ticket promises it. Proposed incomplete-repair probe: retain the coordinated patch except the `Cell.find_inputs_in_output/1` frame-update clause; this should still compile but fail to initialize/render the introduced input. A second useful probe omits the app-session input-view update, requiring a matching app-session acceptance check.

## #2527 — notebook stamp boundaries

The upstream regression appends an extra executable cell after the signed prefix, before the stamp comment. The notebook must not retain the stamp's secret authorization for that altered content. An unchanged signed notebook should still verify. Those are sufficient ticket-level expectations without disclosing the parser location. [Repair and regression](https://github.com/livebook-dev/livebook/commit/94a0aedfda5d518997359a976f135dd0c12724e9).

The production change is confined to `lib/livebook/live_markdown/import.ex`. The new test in `test/livebook/live_markdown/import_test.exs` uses the existing `Import.notebook_from_livemd/1` API, asserts `stamp_verified?: false`, empty `hub_secret_names`, and a warning. Existing tests in the same file cover valid stamps and offline-hub restoration. No new production API is required by the regression. [Import tests](https://github.com/livebook-dev/livebook/blob/94a0aedfda5d518997359a976f135dd0c12724e9/test/livebook/live_markdown/import_test.exs).

Proposed acceptance: preserve the upstream altered-content case, valid unchanged stamps, whitespace surrounding a valid final stamp, and malformed/out-of-range offsets where the existing API defines their behavior. Proposed incomplete-repair probe: reject every stamp to block the new attack while breaking legitimate signed notebooks; the valid-stamp controls must reject that workaround. Keep fixture signing keys and tokens limited to the existing public test fixtures.

## #2663 — nested list round trips

The report supplies an actual generated table of contents: children under a numbered item with two digits become siblings after opening/saving/reloading the notebook. Ticket expectations should require preserved nesting for numbered lists of varying length, including nested code blocks and unchanged ordinary unordered/single-digit cases. [Issue #2659](https://github.com/livebook-dev/livebook/issues/2659).

The change is confined to the Markdown renderer and its tests. The added `properly indents nested lists when the parent list has double digit items` test checks a formatting round trip with nested bullet items under item 10 and a fenced block under item 11. It calls existing formatting behavior and requires no runtime evaluation, browser or external service. [Repair and test](https://github.com/livebook-dev/livebook/commit/12ccf3c6834170326b5c4c964672e77244f13f42).

Proposed supplement: a three-digit parent item with nested content, plus round-trip stability. Proposed incomplete-repair probe: use four indentation spaces for all numbered items from 10 onward. That repairs the demonstrated two-digit example but still corrupts item 100; the supplemental case distinguishes it deterministically.

## #2800 — Erlang error diagnostics

The PR reports that an Erlang syntax error causes another `ArgumentError` while constructing the error message. Ticket examples can include incomplete `X =`, invalid `X ==/== a.`, and a multiline example, with expected readable Erlang diagnostics identifying the offending source line rather than a diagnostic-rendering exception. [PR description](https://github.com/livebook-dev/livebook/pull/2800).

The production change only touches `runtime/evaluator.ex`. Existing evaluator tests previously asserted just the leading exception class; the repair strengthens them to verify diagnostic text and snippets for tokenizer/parser errors, incomplete input and an ordinary Erlang exception. Tests call the existing `Evaluator.evaluate_code/5` API and use message synchronization. [Repair and tests](https://github.com/livebook-dev/livebook/commit/3470f2de4878efe15de76193134ad9dbbef5dc43).

Qualification concern: upstream expects exact formatted exception strings, including an `erl_eval.erl` line number. Pin the historical Elixir/OTP pair and do not classify a version-format mismatch as a semantic defect. Supplemental acceptance should focus on exception type, offending source line, location and absence of formatting failure, without introducing new APIs. Proposed incomplete-repair probe: always select the first source line as the snippet; single-line examples pass, while a syntax error later in a multiline cell has an incorrect snippet.

## Previously identified candidates

#2822's original report demonstrates an imported `ExUnit.Assertions` macro becoming unavailable after a failed assertion. Its new evaluator regression verifies failure-context and merged-context behavior, including unchanged prior imports and process dictionary values without leaking failed bindings, aliases or requires. A plausible incomplete repair preserves imports but loses process dictionary entries; another preserves the entire failed context and leaks bindings. Both should be rejected by explicit context assertions. [Issue #2821](https://github.com/livebook-dev/livebook/issues/2821), [repair](https://github.com/livebook-dev/livebook/commit/8dfe52258f3e383fe74a8fc1f2d0be38f0c9bbb6).

#3076's personal-workspace LiveView test submits only real form fields and uses Bypass for S3 listing. The original tests accidentally supplied ownership metadata the browser would not submit. Retain the existing ordinary user workflow and exercise distinct hubs/ownership boundaries where supported offline. A plausible incomplete repair hardcodes the personal hub instead of respecting the selected hub; that probe requires an independently runnable non-personal/offline hub test before it is useful. Do not claim Teams integration coverage based on the personal test alone. [Repair and corrected tests](https://github.com/livebook-dev/livebook/commit/02f00794c202e6a0a83f2c3cc94ee617a9d2f80c).

## Historical environments and admission

| Candidate | Upstream `versions` Elixir / OTP | Source |
| --- | --- | --- |
| #2219 | 1.15.2 / 26.0.2 | [versions](https://github.com/livebook-dev/livebook/blob/2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66/versions) |
| #2527 | 1.16.2 / 26.2.1 | [versions](https://github.com/livebook-dev/livebook/blob/94a0aedfda5d518997359a976f135dd0c12724e9/versions) |
| #2663 | 1.17.0 / 27.0 | [versions](https://github.com/livebook-dev/livebook/blob/12ccf3c6834170326b5c4c964672e77244f13f42/versions) |
| #2800 | 1.17.2 / 27.0 | [versions](https://github.com/livebook-dev/livebook/blob/3470f2de4878efe15de76193134ad9dbbef5dc43/versions) |
| #3076 | 1.18.3 / 27.3.3 | [versions](https://github.com/livebook-dev/livebook/blob/02f00794c202e6a0a83f2c3cc94ee617a9d2f80c/versions) |

Historical CI compiles and runs `mix test` before its separate Node/npm steps; therefore these Elixir tests appear suitable without a browser build. #2800 CI sets `ELIXIR_ERL_OPTIONS="-epmd_module Elixir.Livebook.EPMD"`; environment qualification should preserve the relevant distribution setup. A container needs loopback for Bypass and any local BEAM communication, even when external networking is disabled. [#2219 CI](https://github.com/livebook-dev/livebook/blob/2a71e49d76fb24b386bb067a9e5d1bd1d6e44e66/.github/workflows/test.yml), [#2800 CI](https://github.com/livebook-dev/livebook/blob/3470f2de4878efe15de76193134ad9dbbef5dc43/.github/workflows/test.yml).

Admission still requires actual broken-fails/fixed-passes, executed acceptance identities, regression coverage that fails behaviorally on broken source, protected existing behavior, incomplete-repair rejection and early-exit rejection. No model context-feasibility or performance claim follows from this review. All application execution belongs on the separately authorized rig, not this shared workstation.

## Other inspected leads

- [#2709](https://github.com/livebook-dev/livebook/pull/2709): real cross-component file identity problem, but its new test directly calls a newly introduced `equal?/2`; an unchanged test overlay would fail broken by undefined API, not behavior. Broader user-facing tests would be necessary before selection.
- [#2783](https://github.com/livebook-dev/livebook/pull/2783): file-URL opening validation; useful reserve, but added evidence is doctests for a newly introduced optional argument, so add a LiveView behavior regression on an existing entry point.
- [#2611](https://github.com/livebook-dev/livebook/pull/2611): distributed asset resolution; upstream test changes exercise new node-aware routes but do not establish the actual two-node transfer behavior. Requires additional isolated multi-node acceptance, so defer from the first batch.
- [#3161](https://github.com/livebook-dev/livebook/pull/3161): smart-cell identity and consecutive-cell diffing fixed together. Do not bundle those distinct failures merely to increase difficulty.
- [#2017](https://github.com/livebook-dev/livebook/pull/2017): smart-cell initialization accompanied by a separate secret-button ID change, with tests for the latter. Reject as a ready-made coherent case.
