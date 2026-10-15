# Six interrupted Astra cases retried — 2026-10-15

**All six authorized retries passed.** No provider interruption or failed repair occurred in this retry run. All six patches were reviewed, and controller cleanup completed.

Run: `20261015-181757-21047e45`. This is a fresh partial run linked to round 2, `20261015-173713-5825b230`, of the [original two-round evaluation](../astra-validation-2026-10-15/README.md). Only its six evaluation-error cases were attempted. Completed passes and failed repairs were not retried or replaced.

| Case | Original round 1 | Original round 2 | Retry | Reviewed successful attempts |
| --- | --- | --- | --- | ---: |
| plausible-pr-6763 | Failed | Authentication interruption | Passed | 1 |
| plausible-pr-6441 | Failed | Provider overload | Passed | 1 |
| livebook-pr-2219 | Passed | Provider overload | Passed | 2 |
| livebook-pr-2527 | Passed | Provider overload | Passed | 2 |
| livebook-pr-2800 | Passed | Provider overload | Passed | 2 |
| livebook-pr-2822 | Passed | Provider overload | Passed | 2 |

**Nine of eleven cases now meet the two-success gate.** The other five cases already had two reviewed passes before this retry. Plausible 6763 and 6441 each need one additional successful attempt to meet that gate; none was started beyond the six requested retries. Every case now has at least one reviewed successful repair. This is feasibility evidence, not proof of perfect case quality.

## What passed

- **6763:** preserves the CSV schema and supported page metrics while leaving unsupported legacy time-on-page values blank.
- **6441:** excludes inappropriate imported contributions to property-filtered goals while preserving ordinary imported goals and their correct indices.
- **2219:** registers inputs delivered by frame updates and updates their views in notebook and app sessions.
- **2527:** validates the entire unsigned notebook-stamp footer before granting trusted metadata; tampered notebooks lose that trust.
- **2800:** supplies the source snippet expected by exception formatting, preserving error location, caret and code markers.
- **2822:** preserves inherited imports and process-dictionary state after a failed cell, discarding the failed cell's changes.

Every attempt passed acceptance, preservation, submitted-test and regression-coverage checks. Reviews found no weakening of existing tests. The public patches and detailed review notes are included here.

## Execution and provenance

The retry used the benchmark's existing Pi runner and its own signed-in ChatGPT subscription connection: `gpt-6-astra`, reasoning `high`, and the same 262,144-generated-token soft threshold. Pi remained at version 1.2.0. Context and response limits remain provider-enforced; no deterministic model seed or fixed serving revision is claimed. Compaction and automatic Pi retries stayed disabled. One solver attempt ran at a time, with two preparation workers and lookahead 4. Workspaces remained offline except for controller-mediated model access.

The user explicitly authorized one fresh retry of each of the six interrupted cases. Every retry used a fresh workspace and model session. No partial solution, previous conversation or grading feedback was supplied to Astra.

The controller previously supported only full starts and resumptions that preserve evaluation errors. Commit `a31711d` adds `Eab.Runs.retry_errors(source_run_id, key)` to start a fresh, explicitly identified partial run through the same scheduler, Pi agent, grader and cleanup path. It preserves the source run, binds the selection and source-record hash into the new experiment identity, and suppresses a full-benchmark score. Reports and the dashboard label partial retries. The relevant controller, checkpoint, runner, comparison and dashboard tests all passed: **29 tests**.

That controller change produces a new execution release:

- Original frozen release: `9a5256a9d0d791c4384a3859b1bf353843dd5bc858919b4d76da42df84c2378d`.
- Retry execution release: `f69c6218ae7c90bad483071d949565e2af4dbd36b82f89581688a3846d447e4b`.

The release protocol differs only in its implementation hash. `results.json` records the six changed implementation files and their before/after hashes. Case fixtures, prompts, instructions, Pi identity, agent images, runtime identities, qualification identities and normalized control outcomes match the original freeze. Every first model request matches its frozen capture except for its new session key. No case, grader, Pi bridge or model budget was changed. Qualification used the ordinary identity-bound cache.

All 633 artifacts from round 1 and 501 from round 2 remain byte-for-byte unchanged, as does the original public report package. The controller verified every new sealed submission and completion receipt. Request counts, completed-response usage and generated-token totals agree for all six retries. The partial run has no full-benchmark score, even though all its cases passed. No speed or performance comparisons were performed.

## Evidence

- [results.json](results.json): outcomes, named grading states, reviews, input checks, usage, implementation changes and the cumulative two-success gate.
- [release.json](release.json): retry execution release protocol.
- `patches/*.patch`: the six successful model repairs, saved as evidence rather than applied to benchmark fixtures.
- [checksums.json](checksums.json): SHA-256 checksums for the public package.
- [export.py](export.py): offline verification/export; it makes no model or network calls. It requires the private original run copies under `.local/astra-validation-2026-10-15/`, the retry copy and review/receipt records under `.local/astra-retry-2026-10-15/`, and the unchanged frozen package. Run `python3 verification/astra-retry-2026-10-15/export.py` at the recorded implementation revision to reproduce the export.

The public package excludes credentials, account identifiers, raw provider responses and model reasoning. Full original artifacts remain in the local controller's store. The original freeze verifier remains specific to its original implementation; this package records and verifies the controller delta explicitly instead of rewriting that historical freeze.
