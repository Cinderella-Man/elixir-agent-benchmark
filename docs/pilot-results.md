# Initial pilot summary

Reviewed snapshot of the 2026-10-11 pilot on the authorized `ratx570` rig. This document is maintained source documentation; generated reports and raw evidence are optional artifacts under the ignored `results/` directory.

The pilot exercised four curated repairs across three real projects. Twelve model attempts ran: ten reached grading and two stopped with context or tool-protocol errors. Eight earlier zero-call setup failures are recorded separately in the evidence. This is a harness qualification exercise, not a controlled model ranking.

## Observed outcomes

One attempt per cell, seed 101. Coder390 and Swift use `pilot-v2`; Flash-Next uses `pilot-v1`. Pass means the saved patch passes the submitted-workspace checks, hidden acceptance tests and protected regression tests. All ten graded attempts ended at the call budget rather than explicitly submitting.

| Scenario | Coder390 | Swift 1.5 | Flash-Next |
| --- | --- | --- | --- |
| Elixir data normalization | Pass | Fail: added tests | Pass |
| OTP demand and cancellation | Incomplete: context limit | Fail: test execution | Fail: behavior and tests |
| Settings validation and LiveView feedback | Fail: validation feedback | Fail: validation feedback | Fail: added tests |
| Playlist ownership and authorization | Pass | Incomplete: tool-call parsing | Pass |

The endpoints had different context settings: 65,536 tokens for Coder390 and 262,144 for Swift and Flash-Next. Coder390's OTP attempt reached its context limit after 30 successful responses. Swift's playlist attempt ended after 19 successful responses when the serving stack rejected malformed tool-call JSON; the pilot does not isolate its underlying cause.

The initial generic `high` reasoning value was rejected by the 27B templates before inference. Corrected requests used `xhigh`. Flash-Next's first case accepted `high`; its later cases used `xhigh`. These configuration differences and the small sample preclude a quality ranking.

## Verifier validation

All four fixtures reject the broken starting state and an early-exit bypass, and accept the reference repair. The fixtures contain 18 hidden tests and 397 original regression test executions across the four cases; those are not independent benchmark scenarios. Seven deliberately incomplete repairs were also rejected after executing the checks.

The final evaluator permits harmless new diagnostic files, checks the agent's submitted regression tests before restoring original tests, and synchronizes a demonstrated race in an upstream GenStage test without changing its assertion. Completed frozen patches were reassessed uniformly; original verdicts and earlier regrades remain in the evidence. No model answer was regenerated to repair a grading issue.

The final environment check found unchanged GPU power controls, no active benchmark containers and no endpoint-key matches in the exported evidence.

## Evidence and reproduction

Source checkouts include the harness, case fixtures and this summary. The following generated artifacts are kept locally or distributed as a separately reviewed evidence archive:

- `results/reports/pilot-results.md`: detailed matrices and links to individual artifacts.
- `results/pilot-v1/` and `results/pilot-v2/`: requests, responses, transcripts, saved patches and verdicts, including errors.
- `results/controls/`, `results/controls-history/` and `results/partial-repair-controls.json`: verifier controls and preserved diagnostic failures.
- `results/runtime-inventory.json`, `results/final-environment-check.json` and `results/artifact-integrity.json`: runtime identities, final environment check and artifact hashes.

See the [runbook](runbook.md) for running and exporting a campaign, the [protocol](pilot-protocol.md) for assessment rules, and the [expansion plan](expansion-plan.md) for broader scenarios and repeated comparisons. The report exporter writes only under `results/`; it does not overwrite this reviewed summary.
