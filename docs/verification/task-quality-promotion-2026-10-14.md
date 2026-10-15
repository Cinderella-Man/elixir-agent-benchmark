# Eleven-case task-quality promotion — 2026-10-14

Status: complete. All eleven final fixtures passed fresh qualification, all sixteen challenge replays produced the expected outcome, and all eleven seed-101 reference repeats matched. On 2026-10-15, the running application was also confirmed to use this exact qualified release with valid qualification records for every case.

The user approved applying the [twelve-PR audit](task-quality-audit-2026-10-14.md). Protocol `elixir-agent-benchmark-v3` removes Plausible 6300 and retains five Plausible and six Livebook repairs. All eleven now include the reviewed custom checks in their scored acceptance overlays. The source snapshots and reference implementation patches are unchanged. Controller/grader source is unchanged from commit `6a86c8eb890cbbdb0d099cf627be90744188cd08`; the inventory and fixture checks define the new release.

## Changes by case

| Case | Promoted verification | Full-grader challenge |
|---|---|---|
| Plausible 5939 | Editor permissions remain scoped to the correct site/team | Rejected global Editor permission |
| Plausible 5956 | Create and repeatedly update a configuration, then fetch its actual script without cache repair; preserve a second site | Rejected omitted write-to-cache updates |
| Plausible 6441 | Preserve supported imported special-event data and unrestricted page goals alongside restricted goals | Rejected two overbroad import exclusions |
| Plausible 6449 | Malformed edits clear existing segment associations; parent settings enforce permissions and foreign-link boundaries | Rejected retaining the old association after malformed input |
| Plausible 6763 | Preserve a supported page-filtered aggregate's legacy time-on-page value | Rejected a repair that preserves only page breakdowns |
| Livebook 2219 | Text-input editing, append/replacement, nested frames and sibling output | Rejected numeric-only initialization |
| Livebook 2527 | Inserted Elixir/Erlang cells lose authorization; legitimate Unicode and harmless whitespace remain valid | Rejected Elixir-only checks and character/byte offset confusion |
| Livebook 2663 | Compare parsed list structure at decimal boundaries and repeat formatting | Accepted harmless extra continuation space at item 9/99; existing two-digit-only control was rejected |
| Livebook 2800 | Check error meaning, offending source and location across single/multiline diagnostics, without exact decorative snapshots | Rejected first-line-only source selection; accepted readable indented diagnostics |
| Livebook 2822 | Exact imports and later execution, failed-state rollback and combined contexts | Rejected widened imports and retention of the failed process dictionary |
| Livebook 3076 | Visible form fields, persistence, missing credentials and S3 forbidden responses | Rejected ignored connectivity failure and skipped field validation |

Each manifest selects the added test files and requires all 34 additional passing test identities from the retained audit cases, alongside the previously required checks and the revised diagnostic test identity. Reference regression-test patches contain the same curated checks. Four cases previously used their reference-test patch directly for provenance; they now retain the exact upstream test patch separately. All eleven continue to reconstruct the exact upstream fixed tree. Tickets state the behavioral boundaries being tested and permit equivalent diagnostic presentation.

Plausible 6300 is removed from both `cases/` and the scored inventory. Its reference starts a weekday-matched comparison on Tuesday instead of Monday across unequal daylight-saving transition dates. The assertion remains unchanged in the audit archive; the flawed reference was not silently repaired. Readmission requires a separately reviewed task/reference and fresh qualification.

## Evidence and reproducibility

All twelve archived qualification-input objects were compared with their original receipts through the archive-aware Elixir inventory loader and matched exactly. The exact original twelve-case fixtures, inventory and frozen release are retained under [the archive](../../verification/task-quality/original/README.md), with checksums verified against the original audit records. Historical audit scripts now explicitly select that archive. Old scores retain their original inventory and checks; v2 and v3 scores are not directly interchangeable.

Current qualification uses a separate data directory and installation identity. Prepared source archives and immutable runtime images are reused, while final-fixture control receipts start empty. The [reproduction instructions](../../verification/task-quality/README.md#reproduce-the-eleven-case-promotion) cover qualification, case-specific challenge replay and evidence export. Workspaces are offline, qualification has at most two preparation workers, and replay uses at most two independent case workers with disjoint case lists. Each replay worker uses one workspace at a time. Each bad repair must fail a named assertion that the original audit identified for that exact defect and that passes on the reference. An unrelated failure does not count as detection. No model generations or speed measurements are requested by these scripts.

The controller test suite passed: **128 passed, 5 optional Docker tests excluded**. This includes the eleven-case inventory/setup view and a saved-run test proving that retired case 6300 still displays its logs. Real Docker qualification below exercises the actual historical fixtures; the five unrelated optional controller integration tests were not rerun for this fixture-only change.

The production image built successfully with compiler warnings treated as errors. Its own release freezer reproduced the qualification release hash and confirmed that retired case 6300 is absent. Formatting checks passed. Fresh qualification completed successfully for all eleven cases: **44 expected control outcomes**, with every reference accepted and every unchanged, early-exit and incomplete repair rejected. Every reference also passed submitted-test validation, original preservation, and the fail-before/pass-after regression-test requirement.

Full-grader replay rejected **all 14 deliberately wrong repairs** for their intended behavioral failures and accepted **both valid alternative implementations**. Thirteen rejected submissions have exactly the same source and submitted-test hashes as submissions the original grader accepted, demonstrating that the promoted checks close those observed gaps. The failed-process-dictionary variant was already rejected by the original grader and is not counted as a newly closed gap. All eleven reference repeats at seed 101 passed with exactly the same test identities and states as seed 0.

The [portable evidence](task-quality-promotion-evidence-2026-10-14.json) records qualification controls, provenance, complete challenge grades, submission hashes, and repeat results. On 2026-10-15, all eleven fixture sets, the inventory, and executed script hashes were rechecked against that export and still matched. These checks reused completed functional evidence; no model evaluations or speed tests were launched.

Qualified release: `8b7ec63e7506dfbb9debef902a8ed4a288186ac5c196f6b646f9ae16ecaa9925`. Candidate production image: `sha256:c1b6f5ff5dd33f188c28b1fbf0eecdbcdf779c0367d3bd3d8da9349dbc317cad`.

The running controller was inspected on 2026-10-15. Its image is `sha256:f01ceb33396de80ee3a6219651b60a89b14ee761e0b9e02914c0771e4cc12e3d`; its inventory and implementation resolve to the exact qualified release above. All eleven installed qualifications match their current runtime identities, their active control records match, and their prepared fixture hashes match the promoted fixtures. The application was idle with no cleanup in progress or active leases. The earlier deployment stop at an unexpected local image tag therefore required no further replacement or restart.

Prepared application/service image identities are recorded in the evidence. Some cold-build inputs still use image tags; preserve the qualified runtime artifacts or qualify a newly built environment separately. The time-on-page assertion uses fixed synthetic analytics timestamps, not execution-time measurements.

These checks establish a bounded, reproducible pilot for the stated Elixir repair tasks. They do not prove exhaustive correctness, estimate model success or flakiness, or constitute independent human review. Published upstream repairs may also be present in model training data; this inventory is not a contamination-free measure of general coding ability.
