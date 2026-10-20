# Ash 3031 curation

Status: **in progress**. Branch `codex/curate-researched-multifile-case`, main base `d9684ec85319e3c86be384f534ddd19af4b10562`. Selected from the already researched Ash 3031 dossier; not previously admitted or rejected. The upstream repair changes five substantive implementation files and one test file.

## Prepared fork

The user requested [Cinderella-Man/ash](https://github.com/Cinderella-Man/ash). The pushed baseline branch is `codex/ash-pr-3031-benchmark` at `91d0b01085167e31193e93541623ef48c9f762b8`; the pushed reference branch is `codex/ash-pr-3031-reference` at `ef09550410abc5444c3efc41b4c4b0f7c5a7c12a`. [Draft fork PR #1](https://github.com/Cinderella-Man/ash/pull/1) records this source pair.

The baseline starts at the actual accepted upstream parent `abc634f5a725fadad850dacefc4284dd1d803fad` and prepares only the toolchain declarations and bounded, line-buffered test runtime. Application code, dependencies and existing focused tests are unchanged. The reference replays upstream `190987ec134a6a01b72d3eb8d9dcb26577b15873`, preserving its author and byte-identical implementation/test diffs. Preparation details are in [fork-preparation.json](fork-preparation.json) and [source-review.md](source-review.md). The case needs no environment patch, database, or external service and uses plain focused `mix test` commands.

The current immutable candidate is **`09528c895206c98feddc652314bef1da31dd72ee7e870218b187bb1ec704f394`**. Its eight input hashes are in [final-draft-hashes.json](final-draft-hashes.json). It makes typed-comparison and nil-tuple/default preservation explicit in the ticket and corresponding requirement descriptions. All 15 acceptance groups, source, reference, runtime and controls are unchanged from the stronger-check version. See [explicit-preservation-review.md](explicit-preservation-review.md) for independent requirements-first approval. The earlier [preservation-amendment-review.md](preservation-amendment-review.md) records why the two added checks are fair public behavior.

## Current execution checkpoint

All 13 original bundles remain parked unchanged under `cases_approved/`, with complete hashes in [original-inventory.json](original-inventory.json). The superseded admitted Ash bundle is preserved at `.local/ash-curation/superseded-admitted-66b3546` and in commit `ae0aaabd`; it is not an approved addition. The stronger-check admitted bundle is preserved at `.local/ash-curation/superseded-admitted-923f2ac` and in commit `9983edec`. Both checkout and rebuilt controller have empty active inventories for the clarified draft. The controller uses the normal observer during qualification. No model is active.

Fresh ordinary Astra run **`20261020-145143-810635d8`** completed under candidate `66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b`, passed its original official grader, and used 40 calls / 13,823 generated tokens. Sealed completion/submission verification and all named outcomes are retained in [astra-1.json](astra-1.json), with the sealed [patch](astra-1.patch). This was the first model attempt; no model attempt occurred on earlier drafts.

**That official pass is rejected as an accepted validation success after review.** The patch loses nil-tuple/default behavior and permits normalized literals to be recast in typed comparisons. Independent fresh diagnostic workspaces confirmed both: the reference passes both added checks, pristine source preserves nil/default behavior and fails the normalized comparison, and Astra's patch fails both with test-body assertion failures. See [first-submission-review.md](first-submission-review.md), [probe source](first-submission-probes.exs), and [complete named probe outcomes](first-submission-probes.json). No test weakening or grading shortcut was found. No second run was launched against that superseded version.

The superseded version's three valid, matching qualification rounds remain under [superseded-66b3546](superseded-66b3546/), with its exact original input hashes. Those rounds are not credited to the strengthened version.

The stronger-check version `923f2acf250e8b9e79afbda9cd56fce6e383aed747224b1081a4806f4617d88b` passed three fresh matching qualification rounds, now retained under [superseded-923f2ac](superseded-923f2ac/). Its ordinary run **`20261020-160506-224bb2fa`** completed and cleaned up, with **13/15 hidden, 117 preservation and 125 submitted tests passing**. The two failed hidden checks are exactly the typed-comparison and nil-tuple/default checks. It used 35 calls / 11,998 generated tokens. [The failed result](astra-amended-1.json) retains sealed receipts, complete named outcomes and qualification binding; [the patch](astra-amended-1.patch) is preserved. Both independent reviewers found the same two defects and no weakened tests or grader shortcuts. The pair driver stopped after this failure; no second attempt was launched on that version.

The next version clarifies only those two observable obligations. It does not remove or weaken checks, change the reference, or give new solver contexts a previous patch or failure trace. Both prior attempts remain attached to their original versions and do not count as new successes. The current prepared image still matches the fork tree.

The clarified draft is imported and independently reviewed; three fresh full rounds are running through `import-explicit-preservation.exs`. Progress is `.local/ash-curation/qualification-explicit.log`. A guarded continuation process, `continue-explicit-preservation.py`, waits for all three verified rounds, exports the admitted singleton, reinstalls disabled timing, and launches two new ordinary blind runs under matching frozen inputs. Its log is `.local/ash-curation/explicit-continuation.log`; inspect it and the private current-version run list before starting duplicate work. Next: finish these gates. Review their sealed patches, restore all 14 bundles and the normal controller, freeze the restored release, commit/push Ash completion, then perform the fork migration. Inspect current controller/private receipts and logs before starting duplicate work. The prior pair process has stopped; its retained log is `.local/ash-curation/fresh-pair-amended.log`.

## Authorized follow-on work

After finishing and committing this Ash case, audit every active case one by one on this branch. The user has supplied `Cinderella-Man/operately`, `Cinderella-Man/live_beats`, `Cinderella-Man/accent`, `Cinderella-Man/livebook`, and `Cinderella-Man/plausible-analytics`. Verify each case uses a prepared branch in the corresponding fork; create and push missing preparation/reference branches, migrate the case with renewed source/runtime validation, and retain prior evidence honestly. Update the operational READMEs and case-addition guidance to require prepared fork branches. The user requested unattended completion; this follow-on work does not replace the remaining Ash gates. The user specifically notes that the Plausible fork already has many branches: inspect every supplied fork and compare existing branch commits/preparation before creating or changing any branch. Reuse matching prepared branches; an upstream URL in a case manifest does not establish that a prepared fork branch is missing.

The read-only pre-migration audit is saved at `.local/fork-migration/initial-source-audit.json`; fresh no-checkout fork clones are under `.local/fork-migration/forks/`. All 13 existing source pairs are present with matching commit/tree identities. Nine cases already have exact-revision branches: six Livebook and three active Plausible cases. Accent, Livebeats and both Operately cases have four environment overlays, none overlapping their reference implementation or exact upstream test paths. No other fork branch or case has been changed. Recheck remote refs immediately before any mutation and preserve excluded-case branches.

Independent Standards review found no documented blanket exemption allowing historical-patch replay to replace fresh model validation after a source-version migration. Follow the current qualification/model gates for the migrated versions; historical successes and any replay remain explicitly historical, not newly claimed blind runs.

## Retained earlier evidence

No model attempt occurred in the three pre-fork candidate versions below. The later superseded fork version has the explicitly retained review-rejected attempt above. No assertion was weakened or removed.

| Candidate | Outcome | Evidence |
| --- | --- | --- |
| `a25d3e7…c13d` exploratory upstream | All four controls executed; invalid only because provisional starting-failure list named four instead of the ten observed failures. | [exploratory-controls.json](exploratory-controls.json) |
| `8a1b088…2d38` unbuffered upstream | Two valid control rounds, but complete named-outcome comparison rejected a missing failure-phase record caused by interleaved CLI progress output. | [reporter-interleaving.json](reporter-interleaving.json), [unbuffered-draft-hashes.json](unbuffered-draft-hashes.json) |
| `bf25352…a691` buffered upstream | One fresh valid round; superseded solely by the user's fork preference. The queued repeat was cancelled before starting another round. | [buffered-upstream-qualification.json](buffered-upstream-qualification.json), [buffered-upstream-draft-hashes.json](buffered-upstream-draft-hashes.json) |

The reporting issue and neutral per-writer line-buffer correction are documented in [reporter-diagnosis.md](reporter-diagnosis.md). [adapter-validation.json](adapter-validation.json) retains five focused adapter checks and the actual dual-formatter diagnostic (40 completed tests, 20 intentional assertion failures, all phase/type records). The fork uses the same tested adapter body plus SPDX attribution. This is test-output preparation, not an application repair. Earlier rounds do not count as final fork qualification.

## Verification utilities

Copy the relevant `.exs` scripts together into the controller and run with `bin/eab rpc 'Code.eval_file("/tmp/<directory>/<script>.exs")'`. `repeat-qualification.exs`, `export-qualification.exs`, and `validation-preflight.exs` require the sibling `qualification-outcomes.exs`. Preflight and model export also require `evidence-binding.exs`. Utilities use the retained current-candidate pointer and refuse invalid gate transitions.

- `qualification-outcomes.exs` compares all controls, completed named tests, failure phases/types and both model-test probes.
- `repeat-qualification.exs` archives cache receipts before fresh rounds; `export-qualification.exs` exports their sanitized evidence.
- `install-validation-observer.exs` installs the sibling `validation-measurement.ex` only in the idle singleton controller. `validation-preflight.exs` verifies admission, candidate identity, three receipts and disabled timing.
- `evidence-binding.exs` binds all three fresh receipts, the verified image source tree, and each saved solver qualification/runtime to one stable preflight.
- `run-fresh-pair.exs` starts exactly two new ordinary runs sequentially, waits for full grading/cleanup, preserves every run ID, and stops for review on any failure. It verifies frozen inputs before each launch and exports passing results for independent patch review.
- `start-astra.exs` launches the actual ordinary Pi runner with `gpt-6-astra`, high reasoning, 262144 generated-token response-boundary soft threshold, no compaction and no automatic retries. It records each run ID immediately and permits only the requested two launches.
- `export-astra.exs` verifies sealed completion/submission receipts, all grading dimensions, behavioral pristine probes, matching frozen inputs, distinct fresh contexts, usage ledgers, and disabled observer records; it exports both model patches.
- `verify-restoration.exs` checks unchanged original/new bundle hashes, the full restored controller inventory, admissions, normal observer source/beam, and a frozen full release without another model run.

All execution is functional correctness/task-success validation with bounded resources. No speed measurements or performance claims are part of this evidence. The repository harness and normal measurement implementation remain unchanged.

**Prepared-source policy, 2026-10-20:** runnable additions and source migrations must follow [prepared fork sources](../../../docs/prepared-fork-sources.md). This record retains its original source versions and outcomes; [the later fork audit](../../prepared-forks-2026-10-20/README.md) records branch reuse and any new migration evidence separately.
