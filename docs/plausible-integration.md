# Historical Plausible cases in the runner

The unified benchmark includes six actual upstream Plausible repairs. Each case starts at its own original broken commit, with an empty `starter.patch`. The published fork branches remain at those commits. The runtime uses the complete historical application and its locked dependencies; no defect is invented or transplanted onto a common release.

## Executable contract

| Case | Application path | Additional incomplete-repair control |
| --- | --- | --- |
| `plausible-pr-6300` | Date comparison plus a real ClickHouse-backed visitor aggregate | Fix Today but leave Last 24h incorrect |
| `plausible-pr-5939` | LiveView domain editing, PostgreSQL persistence and role boundaries | Let Viewers edit domains too |
| `plausible-pr-6763` | Dashboard CSV/ZIP export and supported legacy page metrics | Suppress the crash by dropping supported legacy metrics |
| `plausible-pr-6449` | LiveView shared-link creation/editing, tokens and site-scoped segments | Remove association casting without preserving valid edits |
| `plausible-pr-6441` | Stats API with native and imported ClickHouse rows | Remove imported counts from ordinary goals too |
| `plausible-pr-5956` | Configuration updates, the running application's tracker cache and HTTP script delivery | Keep the erroneous cache collection behavior after the refactor |

`reference.patch` is the exact upstream production-source change. `reference-tests.patch` supplies a valid coverage submission for controls. `acceptance.patch` contains the grader's test overlay: suitable upstream regression tests plus focused neighboring checks. Reference similarity is never scored. All files, solutions and checks are public; the agent's offline image contains only the original broken source, dependencies, generated tracker assets and a fresh single-commit Git history.

For #5956, the upstream test refactor names a module absent from the broken version. Its evaluator instead uses APIs present on both revisions and the application-started cache. It enables cache access in a serialized test, inserts current generated contents synchronously through the shared adapter, checks repeated configuration changes and another site's script, and restores test state. This covers refresh insertion and delivery, not every distributed-cache behavior or stale-key cleanup path. See the [runtime research](plausible-runtime-research.md).

All six original selected regression suites pass on their broken snapshots: these are coverage-gap cases. No tests were deleted or weakened to obtain that distribution. The historical selection supersedes the earlier proposed ratio of invented visible-test failures.

## Grading

1. Replay the submitted patch in a fresh offline environment. Run the selected original regression suite plus every changed or newly added `test/**/*_test.exs` file.
2. Restore the original test tree, apply the acceptance overlay and run the acceptance suite.
3. Restore the original test tree again and run the protected regression suite. Required test identities and pass/exclusion states must match the reference control.
4. Replay only the submitted test changes onto a separate broken environment. At least one test that passed with the repair must fail in its test body on the original source. Compilation failures, setup failures and incomplete suites do not establish regression coverage.

All four requirements contribute to pass/fail. There is no AI judge, style score or patch-size reward. Test exceptions caused by the application, including linked-process failures, can demonstrate the defect. The trusted formatter records failure types and distinguishes setup stack frames; it does not infer a subjective diagnosis from the output.

The CE helper excludes declared `ee_only`, `e2e`, `slow`, `minio` and `migrations` tags. The grader accepts only declared exclusions, requires actual executed passing tests, rejects skipped tests and protects the reference test states. An excluded enterprise test is never counted as a CE pass. These selected suites provide bounded regression coverage, not the whole upstream suite.

## Environment and commands

Preparation sets `MIX_ENV=ce_test` before installing dependencies, building tracker assets and compiling Elixir. It verifies that the embedded tracker asset is nonempty. Each attempt has private PostgreSQL and ClickHouse containers in a network namespace with no external interface or exposed host ports. The upstream `mix test` alias creates and migrates both databases. Containers run with resource limits and the application runs as an unprivileged user. Cleanup removes only owned containers and their anonymous volumes.

The historical inputs form three groups: #5939/#5956 use Elixir 1.19.4, OTP 27.3.4.6, Node 23.2.0, PG16 and ClickHouse 24.12.2.29; #6300/#6449 use the same language versions with PG18 and ClickHouse 25.11.5.8; #6441/#6763 use Elixir 1.20.4, OTP 28.5.0.5, Node 24.17.0 and the newer databases. Preparation records immutable application IDs, resolved base/Node/service digests, source archive hashes, fixture hashes and the exact Dockerfile. Retain the built images with those records; OS packages and package-registry downloads are not a fully vendored rebuild supply chain.

Run only on the authorized `ratx570` rig. The integration installation is `/srv/elixir-agent-benchmark/plausible-expansion`; the original pilot installation remains separate. The existing recorded GPU power envelope is preserved.

```bash
# Build and run deterministic fixture controls; no model calls.
python3 scripts/qualify_suite.py --prepare

# Requalify already prepared images after grader/ticket changes.
# Changed source, runtime or service inputs require --prepare instead.
python3 scripts/qualify_suite.py --refresh

# Run all admitted cases in one later model campaign.
python3 scripts/run_suite.py --campaign full-comparison --seeds 101
python3 scripts/report.py --campaign full-comparison --document full-comparison.md
```

The default campaign now includes all sixteen cases, including Plausible and Livebook. Use `--cases` only for focused diagnostics. Qualification requires rejection of the empty patch, acceptance of the reference repair with effective regression coverage, rejection of `System.halt(0)` and behavioral rejection of the case's incomplete repair. Controls bind to the fixture, immutable image, controller and formatter; model runs refuse stale or invalid attestations. `refresh` updates grader metadata only after checking that the prepared image inputs are unchanged.

## Qualification evidence and remaining scope

The initial Plausible integration qualified all six fixtures on `ratx570` on 2026-10-11 under the controller and formatter hashes recorded in its artifact. This is historical qualification evidence; current unified controls are recorded in `benchmark-qualification.json`. Counts below are executed tests; the six expected enterprise exclusions in #5939 are listed separately in the artifact.

| Case | Broken acceptance failures | Reference acceptance passes | Protected regression passes | Incomplete-repair failures |
| --- | ---: | ---: | ---: | ---: |
| #6300 | 4 | 38 | 33 | 1 |
| #5939 | 2 | 16 | 10 | 2 |
| #6763 | 1 | 24 | 22 | 1 |
| #6449 | 4 | 19 | 12 | 4 |
| #6441 | 5 | 13 | 8 | 1 |
| #5956 | 1 | 2 | 22 | 1 |

Every reference submission also passed the separate regression-coverage check; every early-exit bypass was rejected. All six images were inspected for one fresh Git commit, no remotes, no injected evaluator or supplemental acceptance file, a nonempty generated tracker asset and application UID 1000. The final rig guard confirmed the unchanged recorded power envelope, and no `eab-*` containers remained.

The shared-grader change also passed the [four original pilot controls](pilot-integration-qualification.json) and [all seven original incomplete-repair probes](pilot-integration-partial-controls.json), using their existing pinned images. This revalidates the fixtures; it does not regrade historical model answers. Seventeen bounded Python controller/report tests passed locally. No application benchmarks or performance measurements ran on the workstation.

During qualification, a linked-process CSV failure exposed an unsupported failure shape in the formatter. The formatter was corrected, setup-versus-test failure metadata was added, and all final controls were rerun under the frozen corrected version. The artifact reports those final controls; the initial formatter failure is not represented as a successful control.

Control results are recorded in [the reviewed qualification artifact](plausible-qualification.json), without raw diagnostic logs or timings. Raw control output stays under the ignored `.local/` directory on the rig. The artifact can be regenerated with `scripts/export_qualification.py --out docs/benchmark-qualification.json` after valid controls. Source provenance is checked independently by `scripts/verify_historical_candidates.py`.

No Plausible model attempts or performance measurements are part of this integration. Correct fixture behavior does not establish that an agent can solve each case within its context window. The runner still keeps the full conversation without compaction. Its default 65,536 completion-token allowance is cumulative generation, not a context cap. A common context policy, prompt accounting, response reserve and unscored feasibility attempts remain prerequisites for a comparative campaign. Immediate publication also means possible prior exposure to these PRs and solutions; offline isolation does not remove that limitation.
