# Per-PR task-quality verification

These are custom correctness checks from the original twelve-case audit. They supplement the source reviews in [research](../../docs/research/task-quality-and-verification.md). The final decisions and recorded outcomes are in the [audit report](../../docs/verification/task-quality-audit-2026-10-14.md).

The files in this directory preserve the audit inputs. Following explicit approval, eleven cases now include these checks in the scored `cases/` fixtures under protocol v3. Plausible 6300 is retired. The exact original twelve-case fixtures and inventory are retained in [original/](original/README.md), and the historical audit scripts explicitly select that archive. In particular, a reference failing a legitimate additional requirement is evidence against admission; it is not a reason to weaken that assertion until it passes.

Each case contains:

- `acceptance.patch`: additional tests applied after the original acceptance overlay.
- `audit.json`: selected test files and exact, hand-written source changes applied after the reference implementation. Each change explains the missing behavior it tests. Occurrence counts reject stale mutations.
- Where needed, `replacement-acceptance.patch`: a fairer replacement for the original overlay, applied instead of it. Livebook 2800 retains source, location and error meaning while dropping decorative diagnostic snapshots.

The 6300 overlay includes a daylight-saving challenge to the reference itself. The 2663 and 2800 plans include positive formatting alternatives. A differing implementation is not automatically a defect. A positive alternative must pass both the semantic checks and original preservation tests; the original acceptance result is retained to expose overly strict assertions.

## Reproduce without a model

Use the repository's `eab-tooling:dev` Docker image and Docker socket access, as described in the [runbook](../../docs/runbook.md). Run these scripts with `mix run --no-start`; they start the command registry and HTTP dependencies, **not** the website, model transport or run manager.

Set `EAB_DATA_DIR` to a separate persistent audit directory. Do not point it at an active controller's writable data directory. Preparation metadata, source archives and immutable Docker images may be reused by copying `cache/`, `sources/`, `build-seeds/`, `runtimes/`, `controls/` and `qualifications/` into the audit directory. Do not copy `installation.json`, credentials, run-manager state or leases. The scripts validate content identities and physical image availability. Alternatively, prepare from an empty audit directory; preparation needs network access to fetch sources and build dependencies. Test workspaces themselves remain offline.

Example, from the repository root, with existing preparation records in `.local/task-audit`:

```sh
docker run --rm --cpus=2 --memory=4g \
  --user "$(id -u):$(id -g)" --group-add "$(stat -c %g /var/run/docker.sock)" \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -e EAB_DATA_DIR=/app/.local/task-audit \
  -e EAB_AUDIT_PLANS=/app/verification/task-quality/cases \
  -v "$PWD:/app" -v /var/run/docker.sock:/var/run/docker.sock -w /app \
  eab-tooling:dev mix run --no-start scripts/qualify_case_audit.exs
```

Using the same mounts and environment, run in order:

```sh
mix run --no-start scripts/repeat_case_references.exs
mix run --no-start scripts/audit_cases.exs
mix run --no-start scripts/replay_audit_submissions.exs
```

The archived `audit_cases.exs` run intentionally reports an unmet positive expectation for Plausible 6300 and exits nonzero: reproducing its DST defect is the evidence for retirement. The eleven-case promotion scripts must complete successfully. Use controller code matching the recorded grader identity when reproducing a historical experiment.

The one-off audit and promotion exporters were retired on 2026-10-18; their source remains in Git history. The checked-in evidence remains unchanged. The audit export required a negative control to fail a behavioral check that passed on the custom reference, so the independent DST defect did not count as mutant detection. Positive alternatives also had to pass original preservation. The evidence records the runner's actual combined command; standalone `command` hints in some plans are not used by the runner.

The exact runner used for the recorded probes is retained in [executed-audit-runner.exs](executed-audit-runner.exs). The current copy in `scripts/` also selects the original fixture archive explicitly. The exact executed snapshot preserves the historical identity; subsequent script changes do not retroactively alter old execution records.

An additional [2663 formatting challenge](supplemental-probes/list-formatting-challenge.exs) is retained as the exact executed script. To rerun it against the original fixture, load `scripts/original_case_audit.exs` and require the challenge inside `OriginalCaseAudit.map(["livebook-pr-2663"], fn _ -> ... end)`. It is an exploratory probe outside the main matrix. Adding a continuation space to every multi-digit parent passed original preservation but changed fenced-code contents under the pinned parser; both original acceptance and the semantic check rejected it. It must not be counted as a valid alternative or a fairness defect. Its exact script and raw-result hashes are retained separately in the evidence export.

The four historical audit scripts accept case IDs after their filenames to select a subset. Run sequentially, or at most two independent case workers if the host permits. The fresh workspaces retain the existing CPU, memory and process limits. Watchdog timeouts detect hangs; elapsed times are not performance evidence. No speed measurements, model calls or model scores are produced.

## What the stages establish

1. `qualify_case_audit.exs` reconstructs upstream provenance, prepares/reuses the exact baseline, and runs or validates identity-matching unchanged/reference/early-exit/incomplete controls. Reused controls are explicitly distinguishable from fresh executions.
2. `repeat_case_references.exs` executes each original reference acceptance suite in a fresh workspace with ExUnit seed 101 instead of 0 and checks every original test identity/state. Two orders are a bounded stability check, not a flake-rate estimate.
3. `audit_cases.exs` executes unchanged source, reference, targeted incomplete implementations and stated positive alternatives. Ordinary negative controls must complete and fail in a test body. Build/setup failures are recorded as errors, not successful bug detection. Each result binds the original fixtures, audit files, runner and prepared runtime. Saved successful probes are reused only with matching identities.
4. `replay_audit_submissions.exs` selects incomplete implementations for which every original acceptance identity passed but a supplemental assertion failed. It submits their source plus the existing reference regression-test patch to the **complete original grader**, including submitted tests, hidden acceptance, preservation and fail-before/pass-after test coverage. This distinguishes an acceptance-only gap from an actual scoring false positive.

Raw results and generated implementation patches remain under `EAB_DATA_DIR/audit-results/` and `audit-patches/`. The checked-in evidence summary retains named failures, stage outcomes and artifact hashes; raw logs contain routine tool/test output, not speed conclusions. Review the failure cause and requirement mapping before interpreting any mutation result. A surviving mutation may be a correct alternative, and a reference failure may reveal either a bad test or a real contract mismatch.

The [promotion record](../../docs/verification/task-quality-promotion-2026-10-14.md) tracks the new commands, required identities, unchanged upstream source reconstruction and final-fixture qualification. Prior scores are not retroactively altered, and no independent human review is claimed.

## Reproduce the eleven-case promotion

Use a separate `EAB_DATA_DIR`, for example `.local/task-promotion`, with the same tooling image and socket mounts. For fresh qualification, copy only prepared `cache/`, `sources/`, `build-seeds/` and `runtimes/` records; leave out `controls/` and `qualifications/`. Runtime reuse is identity checked, and all four functional controls execute against the final fixtures.

```sh
mix run --no-start scripts/qualify_promoted_cases.exs
mix run --no-start scripts/replay_promoted_cases.exs
```

Finish qualification before starting replay. Qualification permits at most two preparation workers. Each replay process uses one workspace at a time; optional case IDs may partition the replay into at most two independent workers with disjoint case lists. The replay script accepts optional case IDs, reconstructs each named variant from the unchanged reference and reviewed replacement plan, and requires a current successful qualification. Bad repairs submit the original reference tests, so the hidden checks must independently detect one of that variant’s specific named behavioral failures from the original audit. Valid alternatives submit the revised reference tests and must pass the complete grader. Each final reference suite also runs in a fresh workspace at seed 101 and must match every seed-0 test identity/state.

The recorded export validated the frozen inventory and fixture checksums, original archive, runner/plan/submission identities, full grades, required checks and reference repeat outcomes. Raw promotion records and submitted patches stay under `promotion-results/` and `promotion-patches/` in the data directory. No model scores or speed measurements are produced.
