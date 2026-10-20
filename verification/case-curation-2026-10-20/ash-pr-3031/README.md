# Ash 3031 curation

Status: **in progress**. Branch `codex/curate-researched-multifile-case`, main base `d9684ec85319e3c86be384f534ddd19af4b10562`. Selected from the already researched Ash 3031 dossier; not previously admitted or rejected. The upstream repair changes five substantive implementation files and one test file.

## Prepared fork

The user requested [Cinderella-Man/ash](https://github.com/Cinderella-Man/ash). The pushed baseline branch is `codex/ash-pr-3031-benchmark` at `91d0b01085167e31193e93541623ef48c9f762b8`; the pushed reference branch is `codex/ash-pr-3031-reference` at `ef09550410abc5444c3efc41b4c4b0f7c5a7c12a`. [Draft fork PR #1](https://github.com/Cinderella-Man/ash/pull/1) records this source pair.

The baseline starts at the actual accepted upstream parent `abc634f5a725fadad850dacefc4284dd1d803fad` and prepares only the toolchain declarations and bounded, line-buffered test runtime. Application code, dependencies and existing focused tests are unchanged. The reference replays upstream `190987ec134a6a01b72d3eb8d9dcb26577b15873`, preserving its author and byte-identical implementation/test diffs. Preparation details are in [fork-preparation.json](fork-preparation.json) and [source-review.md](source-review.md). The case needs no environment patch, database, or external service and uses plain focused `mix test` commands.

The immutable fork candidate is `66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b`. Its eight input hashes are in [final-draft-hashes.json](final-draft-hashes.json). The independent requirements-first review and renewed fork-source approval are retained in [contract-review.md](contract-review.md), and the latter has been recorded through `Candidates.review/2` for this version.

## Current execution checkpoint

All 13 original bundles remain parked under `cases_approved/`, with complete hashes in [original-inventory.json](original-inventory.json). The draft is `.local/ash-curation/draft`; the prepared fork clone is `.local/ash-curation/fork`. Controller inventory is empty and its normal observer is installed. No model run has started.

The first fork qualification is active via `/tmp/ash-qualify-fork.exs`. The repeat script is queued on its candidate lock and will retain round 1, then execute rounds 2 and 3 after archiving the preceding cache receipt out of lookup. Logs are `.local/ash-curation/qualification-fork-1.log` and `qualification-fork-repeat.log`. The prior buffered-upstream round completed before this work started; its queued repeat was cancelled before acquiring the lock or launching work.

Next: require all three fresh fork rounds to match complete named outcomes, export with admission, rebuild the singleton controller, install the disabled timing observer, and run the ordinary Pi benchmark twice with fresh Astra contexts. Review both sealed results and patches, then restore all 14 unchanged bundles and the normal controller before committing/pushing the completed branch. Do not import the old `/tmp/ash-draft`: it contains the superseded upstream candidate.

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
