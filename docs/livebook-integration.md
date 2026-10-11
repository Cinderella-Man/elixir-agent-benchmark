# Historical Livebook cases

Six authentic upstream repairs are wired into the same benchmark as Plausible and the original pilot. `scripts/run_suite.py` executes all sixteen cases by default. The source packages preserve exact broken/fixed commits and complete upstream changes; the fork branches point directly at the historical broken commits. No defect was planted or transplanted onto a modern baseline.

| Case | Observable behavior | Broken branch | Incomplete repair rejected by the intended checks |
| --- | --- | --- | --- |
| [#2219](https://github.com/livebook-dev/livebook/pull/2219) | An input introduced through a notebook frame update shows its label and default value | [frame inputs](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2219-frame-inputs) | Fix frame bookkeeping but omit input initialization/rendering |
| [#2527](https://github.com/livebook-dev/livebook/pull/2527) | Inserting content before a notebook stamp invalidates secret authorization | [notebook stamps](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2527-notebook-stamps) | Reject valid signed notebooks as well as altered ones |
| [#2663](https://github.com/livebook-dev/livebook/pull/2663) | Long numbered lists retain nested bullets and code when formatted | [numbered lists](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2663-nested-numbered-lists) | Repair two-digit parents but still misindent three-digit parents |
| [#2800](https://github.com/livebook-dev/livebook/pull/2800) | Erlang syntax errors produce readable diagnostics with source snippets | [Erlang diagnostics](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2800-erlang-diagnostics) | Suppress formatting errors by dropping source snippets |
| [#2822](https://github.com/livebook-dev/livebook/pull/2822) | A failed evaluation preserves earlier imports and process dictionary state | [evaluation context](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2822-failed-evaluation-context) | Retain imports while discarding the process dictionary |
| [#3076](https://github.com/livebook-dev/livebook/pull/3076) | The S3 form saves storage using only fields actually submitted by the user | [S3 storage](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-3076-s3-storage-form) | Remove the invalid owner value without assigning the workspace |

## Acceptance scope

Every reference production patch is the upstream source diff. Acceptance uses upstream behavior tests on existing APIs. #2663 additionally exercises nested content under three-digit list items and repeated round trips. The tickets state the behavior being graded; they do not identify the changed function or prescribe the upstream implementation.

#2219 runs the notebook session LiveView file. The upstream repair also changes an internal helper's return shape and updates two notebook-helper tests. Those implementation-facing assertions are preserved in provenance but excluded from the selected grading scope, so the grader does not demand the upstream tuple representation. The ticket and executable scope cover notebook sessions, not a separately qualified app-session workflow.

#3076 runs the personal-workspace LiveView file, whose S3 path uses a local Bypass server. Three upstream Git-storage tests require external SSH credentials and remain explicitly excluded. Teams tests are retained in the full upstream patch but are not claimed as executed coverage. The case checks the real form fields rather than tests that inject ownership metadata unavailable in the UI.

The selected evaluator files for #2800 and #2822 exercise real evaluator processes. #2800 retains exact historical diagnostic assertions, including OTP-specific formatting. #2527 preserves neighboring valid-stamp coverage. These are bounded regression scopes, not claims that the entire historical application test suite passes.

All six cases require submitted regression coverage. A changed or new test must pass after repair and fail in a completed test body on broken source. Setup errors, missing APIs, compile failures and early exits do not establish coverage. The same protected-test restoration and identity checks apply across the whole benchmark.

## Runtime and isolation

The [runtime investigation](livebook-runtime-research.md) records each historical Elixir/OTP pair and verified base-image digest. Preparation preserves `mix.lock`, committed static assets and native dependency artifacts. It installs build tools including CMake, uses noninteractive OS package installation, and reuses Ubuntu Noble's existing UID 1000 as the unprivileged agent account. There is no Node/browser build or database sidecar for these cases.

Older Livebook revisions use ordinary epmd with a loopback node identity. #2800/#2822/#3076 use the custom EPMD flag supported by their historical source. External networking is disabled during attempts and grading; loopback remains available to local processes and HTTP test stubs. No real storage credentials or Teams service are needed.

Only broken source enters the image. Its Git history is replaced with one initial commit and no remote. Reference patches, provenance and the acceptance overlay stay outside the agent workspace. Images and runtime records bind the source archive, environment recipe and fixture hashes. Preserve those image IDs for reproduction: downloaded OS packages/native artifacts are frozen in the image but are not a fully vendored build supply chain.

## Qualification and campaign boundary

Application controls run only on the authorized `ratx570` rig, in `/srv/elixir-agent-benchmark/plausible-expansion`. The existing path is retained for the unified integration. GPU power services and limits remain unchanged. Controls must reject the broken snapshot, accept the reference repair and its effective regression tests, reject the early-exit bypass, and behaviorally reject the incomplete repair listed above.

All six cases passed qualification on 2026-10-11. Counts below include executed checks only; #3076's three credential-dependent Git tests remain excluded and are listed separately in the artifact.

| Case | Broken acceptance failures | Reference acceptance passes | Protected regression passes | Incomplete-repair failures |
| --- | ---: | ---: | ---: | ---: |
| #2219 | 1 | 84 | 83 | 2 |
| #2527 | 1 | 44 | 43 | 4 |
| #2663 | 2 | 46 | 44 | 1 |
| #2800 | 1 | 53 | 53 | 1 |
| #2822 | 1 | 54 | 53 | 1 |
| #3076 | 1 | 8 | 8 | 1 |

Every reference repair also passed the separate regression-coverage probe, and every early-exit bypass was rejected. The original selected tests pass on each broken snapshot: these are demonstrated coverage gaps, including #2800's previously incomplete diagnostic assertions and #3076's unrealistic form parameters. The [image audit](livebook-image-audit.json) confirms UID 1000, a single fresh Git commit, no remotes, absent evaluator/supplement files and unchanged historical source/test files at the inspected paths.

The [reviewed unified artifact](benchmark-qualification.json) records successful controls for all sixteen cases under one controller and formatter, including exact image/fixture/evaluator pins. The [seven original incomplete-repair probes](benchmark-partial-controls.json) were also rerun and rejected under this evaluator. Twenty-seven local bounded Python checks passed. The final rig guard confirmed unchanged GPU power settings and no remaining benchmark containers. Raw control logs remain under `.local/`. Source-only provenance can be checked independently:

```bash
python3 scripts/verify_historical_candidates.py --project livebook --repository /path/to/livebook
```

On the rig, `python3 scripts/qualify_suite.py --prepare` builds and qualifies every case; `--refresh` reuses unchanged prepared images for grader-only updates. `python3 scripts/export_qualification.py --out docs/benchmark-qualification.json` exports the reviewed facts without raw logs or measurements.

No Livebook model attempts or speed measurements are part of this integration. The subsequent [comparison protocol](comparison-protocol.md) enforces a shared 262,144-token window with exact prompt accounting, reserved response space and no compaction. Fixture controls alone do not establish model success within those budgets. Public upstream fixes may have appeared in model training data; offline isolation does not remove that limitation. See the [comparison protocol](comparison-protocol.md) before interpreting aggregate scores.
