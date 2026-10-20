# Ash 3031 curation

Status: **in progress**. Branch `codex/curate-researched-multifile-case`, main base `d9684ec85319e3c86be384f534ddd19af4b10562`. Selected from the already researched Ash 3031 dossier; not previously admitted or rejected. The upstream repair changes five substantive implementation files and one test file.

## Prepared fork

The user requested [Cinderella-Man/ash](https://github.com/Cinderella-Man/ash). The pushed baseline branch is `codex/ash-pr-3031-benchmark` at `91d0b01085167e31193e93541623ef48c9f762b8`; the pushed reference branch is `codex/ash-pr-3031-reference` at `ef09550410abc5444c3efc41b4c4b0f7c5a7c12a`. [Draft fork PR #1](https://github.com/Cinderella-Man/ash/pull/1) records this source pair.

The baseline starts at the actual accepted upstream parent `abc634f5a725fadad850dacefc4284dd1d803fad` and prepares only the toolchain declarations and bounded, line-buffered test runtime. Application code, dependencies and existing focused tests are unchanged. The reference replays upstream `190987ec134a6a01b72d3eb8d9dcb26577b15873`, preserving its author and byte-identical implementation/test diffs. Preparation details are in [fork-preparation.json](fork-preparation.json) and [source-review.md](source-review.md). The case needs no environment patch, database, or external service and uses plain focused `mix test` commands.

The immutable fork candidate is `66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b`. Its eight input hashes are in [final-draft-hashes.json](final-draft-hashes.json). The independent requirements-first review and renewed fork-source approval are retained in [contract-review.md](contract-review.md), and the latter has been recorded through `Candidates.review/2` for this version.

## Current execution checkpoint

All 13 original bundles remain parked under `cases_approved/`, with complete hashes in [original-inventory.json](original-inventory.json). They were rechecked unchanged before export. The admitted Ash bundle is now the only directory under `cases/` containing `case.json`; its eight reviewed input hashes match exactly, and `admission.json` binds the fork candidate.

**Three fresh qualification rounds passed with identical complete named outcomes.** Reference: 13 acceptance, 117 preservation and 170 submitted tests passed. Unchanged source: ten acceptance failures; incomplete repair: one acceptance failure; early exit: no completed tests and rejected. The comparison includes both pristine probes and failure phases/types. Sanitized receipts are `qualification-round-1.json`, `qualification-round-2.json`, and `qualification-round-3.json`; original receipts/cache archives remain under `/data/curation/ash-pr-3031/66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b/`.

The controller was rebuilt with singleton inventory `ash-pr-3031`. Admission, three receipts, source/runtime identities, controller idleness and the disabled observer passed preflight. The temporary observer is installed only inside this validation controller; repository harness source is unchanged.

Fresh ordinary Astra run **`20261020-145143-810635d8`** has started using `gpt-6-astra`, high reasoning and the 262144 generated-token response-boundary soft threshold. It is the first model attempt for this case; there were no model attempts on prior candidate versions. The run ID is also retained under the candidate's `astra-runs.json`. No second run has started.

Next: wait for first-run grading and cleanup, start the second ordinary fresh run with the same inputs/settings, review both sealed results and patches, then restore all 14 unchanged bundles and the normal controller. Freeze the restored full release without starting a model run, commit/push the completed Ash checkpoint, and proceed with the authorized fork audit below.

## Authorized follow-on work

After finishing and committing this Ash case, audit every active case one by one on this branch. The user has supplied `Cinderella-Man/operately`, `Cinderella-Man/live_beats`, `Cinderella-Man/accent`, `Cinderella-Man/livebook`, and `Cinderella-Man/plausible-analytics`. Verify each case uses a prepared branch in the corresponding fork; create and push missing preparation/reference branches, migrate the case with renewed source/runtime validation, and retain prior evidence honestly. Update the operational READMEs and case-addition guidance to require prepared fork branches. The user requested unattended completion; this follow-on work does not replace the remaining Ash gates. The user specifically notes that the Plausible fork already has many branches: inspect every supplied fork and compare existing branch commits/preparation before creating or changing any branch. Reuse matching prepared branches; an upstream URL in a case manifest does not establish that a prepared fork branch is missing.

## Retained earlier evidence

No model attempt occurred in any earlier candidate version. No assertion was weakened or removed.

| Candidate | Outcome | Evidence |
| --- | --- | --- |
| `a25d3e7…c13d` exploratory upstream | All four controls executed; invalid only because provisional starting-failure list named four instead of the ten observed failures. | [exploratory-controls.json](exploratory-controls.json) |
| `8a1b088…2d38` unbuffered upstream | Two valid control rounds, but complete named-outcome comparison rejected a missing failure-phase record caused by interleaved CLI progress output. | [reporter-interleaving.json](reporter-interleaving.json), [unbuffered-draft-hashes.json](unbuffered-draft-hashes.json) |
| `bf25352…a691` buffered upstream | One fresh valid round; superseded solely by the user's fork preference. The queued repeat was cancelled before starting another round. | [buffered-upstream-qualification.json](buffered-upstream-qualification.json), [buffered-upstream-draft-hashes.json](buffered-upstream-draft-hashes.json) |

The reporting issue and neutral per-writer line-buffer correction are documented in [reporter-diagnosis.md](reporter-diagnosis.md). [adapter-validation.json](adapter-validation.json) retains five focused adapter checks and the actual dual-formatter diagnostic (40 completed tests, 20 intentional assertion failures, all phase/type records). The fork uses the same tested adapter body plus SPDX attribution. This is test-output preparation, not an application repair. Earlier rounds do not count as final fork qualification.

## Verification utilities

Copy the relevant `.exs` scripts together into the controller and run with `bin/eab rpc 'Code.eval_file("/tmp/<directory>/<script>.exs")'`. `repeat-qualification.exs`, `export-qualification.exs`, and `validation-preflight.exs` require the sibling `qualification-outcomes.exs`. Utilities use the retained current-candidate pointer and refuse invalid gate transitions.

- `qualification-outcomes.exs` compares all controls, completed named tests, failure phases/types and both model-test probes.
- `repeat-qualification.exs` archives cache receipts before fresh rounds; `export-qualification.exs` exports their sanitized evidence.
- `install-validation-observer.exs` installs the sibling `validation-measurement.ex` only in the idle singleton controller. `validation-preflight.exs` verifies admission, candidate identity, three receipts and disabled timing.
- `start-astra.exs` launches the actual ordinary Pi runner with `gpt-6-astra`, high reasoning, 262144 generated-token response-boundary soft threshold, no compaction and no automatic retries. It records each run ID immediately and permits only the requested two launches.
- `export-astra.exs` verifies sealed completion/submission receipts, all grading dimensions, behavioral pristine probes, matching frozen inputs, distinct fresh contexts, usage ledgers, and disabled observer records; it exports both model patches.
- `verify-restoration.exs` checks unchanged original/new bundle hashes, the full restored controller inventory, admissions, normal observer source/beam, and a frozen full release without another model run.

All execution is functional correctness/task-success validation with bounded resources. No speed measurements or performance claims are part of this evidence. The repository harness and normal measurement implementation remain unchanged.
