# Sequential case curation

Use this workflow when asked to add cases or finish a candidate. Work on one candidate at a time, validate it, park it, then continue only within the requested scope. Finish a batch with all approved cases restored so the merge contains the additions and their evidence.

**“Run against Astra” means run the actual benchmark with `gpt-6-astra` as the LLM solver through the ordinary Pi runner.** Fixture qualification without a model, a curator-written solution, and an Astra subagent are not those solver runs.

## Folder roles

| Location | Purpose |
| --- | --- |
| `cases/` | Active inventory. During a solver run, contains exactly the candidate being validated. At batch completion, contains the full approved inventory. |
| `cases_approved/` | Temporary holding folder for validated cases, excluded from runs. Move complete case directories here unchanged, including admission receipts. |
| Draft directory outside both folders | Unqualified or deferred candidate bundles; not part of the validated inventory. |
| `verification/case-curation-<date>/<case-id>/` | Qualification outcomes, model attempts, patches, reviews and continuation notes. |

Folder membership determines the active set. `config/benchmark.json` supplies defaults and preferred ordering; new case folders are discovered automatically. No case ID, manifest or configuration edit is needed merely to park or restore a case. Leave folder-level files such as `cases/README.md` and `.gitkeep` in place.

## 1. Establish the branch and recover existing work

Read the worktree status, current case folders and any candidate's verification record before changing them. For a new curation branch, fetch main and branch from the current `origin/main` using the `codex/` prefix. When continuing an existing curation branch, use its recorded state rather than restarting completed work.

For an unfinished case from an older branch, inspect its diff first. Import only that candidate's bundle, contract review and case-specific evidence onto the new branch. Main may have moved substantially: keep current harness/configuration code and existing cases. Verify imported admission and qualification evidence against current source, artifact hashes, grader and runtime identities.

Record the original approved case IDs and file hashes before moving them. These establish that restoration preserves every original bundle.

**Ready:** the branch/base and candidate are identified, existing work is preserved, and any reused evidence has been checked rather than assumed valid.

## 2. Park approved cases and isolate the candidate

Check the running controller's `Eab.Runs.snapshot()`: `active` must be `nil`, `cleaning` must be `false`, and `cleanup_error` must be `nil`. Also finish any standalone qualification/preparation using its data volume. Wait for active work; do not interrupt another run to change folders.

Create `cases_approved/` if needed. Move every already-approved directory containing `case.json` from `cases/` into it. Check destination names first and stop on a collision instead of merging or overwriting directories. On a resumed branch, keep the single unfinished candidate separate from approved cases and investigate any other active folders.

Docker copies case files into the controller image; host moves alone do not change its inventory. After membership changes, rebuild/recreate the idle controller with `docker compose up --build -d`. Inspect `Eab.Inventory.all()` inside that controller before launching a model. It must equal `[candidate_id]`; a host directory listing is insufficient.

**Ready for model validation:** only the qualified candidate is active in both the checkout and controller; all other approved cases are parked.

## 3. Prepare and qualify the fixture

Follow the [selection guidelines](pr-selection-guidelines.md) and [admission APIs](case-admission.md) for source provenance, the minimal solver contract, independent requirements-first review, acceptance/preservation checks, and plausible incomplete/integrity controls.

Develop drafts outside `cases/`. Import and review the immutable version through `Eab.Candidates`, then complete **three fresh qualification rounds with matching named outcomes**, including completion and failure phases/types. Each round executes reference, unchanged, incomplete and integrity controls in fresh workspaces/service state. A cached qualification lookup is not another fresh round; preserve the previous receipt outside the cache lookup before repeating controls. Prepared images may be reused.

For an unchanged resumed candidate, existing three-round evidence can remain valid after verifying the exact artifacts, receipts, grader, runtime and qualification identity. Record that verification as evidence reuse, not three new executions. Changed inputs require the applicable renewed review and fresh qualification.

Export the qualified bundle with `Eab.Candidates.export/2` to `cases/<case-id>/`, including `admission.json`, then rebuild the controller and verify isolation. Preserve the qualified upstream reference throughout model validation.

**Ready:** independent review is recorded, all three rounds match, source reconstruction verifies, and `Eab.Candidates.verify_admission!(candidate_id)` succeeds on the active bundle.

## 4. Run the benchmark with Astra twice

Use the existing benchmark connection and ordinary **Run benchmark** flow. The established validation settings are `gpt-6-astra`, high reasoning effort, a 262,144 generated-token response-boundary soft threshold, compaction disabled, and no automatic retries. Reuse these unless the user requests another policy; record effective settings and verify the model is available through the benchmark's own connection.

The same flow can be launched through the controller's existing APIs: select the signed-in, plan-enabled account from `Eab.ChatGPTAuth.accounts/0`, find `gpt-6-astra` in `Eab.OpenAI.catalog/1`, build its endpoint with `Eab.OpenAI.endpoint/2`, then call `Eab.Runs.start(endpoint, "", %{"max_tokens" => 262144, "reasoning_effort" => "high"})`. Use the intended saved account if more than one is available. Keep credentials and account identifiers out of committed evidence.

Before each launch, verify the singleton active inventory, admission, controller idleness and disabled timing observer described below. Record the returned run ID immediately. Wait for grading and cleanup before the next launch. Start the second run through the ordinary fresh-run path with the same frozen inputs/settings; **Resume is not a second independent attempt**.

Each solver starts with a fresh context and workspace containing only its ordinary visible task/source. Give it no previous repair, reference solution, hidden check or failure feedback. Keep case files, prompts, settings and effective controller implementation fixed across the pair.

Retain every attempt. Diagnose graded failures against the visible contract and exact assertion; distinguish them from established infrastructure interruptions. A justified retry starts fresh and preserves the failed/interrupted record. If a case or environment correction changes frozen inputs, qualify the corrected version and collect a new matching pair. Missing historical run artifacts mean an unknown outcome, not a pass or a discarded failure.

**Ready for approval:** two fresh runs completed and passed every required grading dimension under matching frozen inputs/settings, with no unresolved case/grader concern.

### Local timing observer

Apply the [shared-machine constraint](../AGENTS.md#shared-machine-constraint): local correctness and model task-success runs are allowed with bounded resources; speed measurement is not.

Inspect the current `Eab.Measurement` implementation before launch. It currently records `attempt_ms` automatically, so leaving the default observer active is incompatible with this machine's rule. The [Operately 1205 completion](../verification/case-curation-2026-10-18/operately-pr-1205/README.md#completion-on-current-main--2026-10-20) records the working approach and retains the [disabled observer source](../verification/case-curation-2026-10-18/operately-pr-1205/validation-measurement.ex).

For that implementation, install the disabled source and its compiled module only in the idle validation controller, before freezing either run. Preserve the effective source and its hash in evidence so the frozen implementation identity describes the actual controller. Verify `Eab.Measurement.start()` returns `:disabled` and saved attempt/progress records contain the explicit disabled marker, with no `attempt_ms`. A controller recreation restores its image's observer; recheck after every rebuild. If this interface changes, inspect and adapt only the observer, preserving solver and grading behavior. Keep temporary observer changes out of a case-only merge and restore the normal repository controller build after validation.

## 5. Review evidence and park the accepted case

For each pass, verify the sealed submission/completion receipts, final cleanup, patch hashes, usage ledger, completed named acceptance/preservation/submitted results and applicable model-test policy. For bug fixes/features, confirm submitted tests fail in test bodies on pristine source and pass on the repair.

Compare the two releases/experiments, model/settings, agent and runtime identities, frozen prompts/instructions/configuration/qualification, and initial requests excluding distinct session keys. Record unavailable provider revision/seed information honestly.

Read both submitted patches for correctness, weakened tests and grader shortcuts. A valid implementation may differ from the reference or touch fewer files. Preserve both patches, reviews and sanitized result summaries in the case's verification directory, including all earlier unsuccessful attempts and amendments.

Once those gates pass, move the **unchanged complete bundle** from `cases/<case-id>/` to `cases_approved/<case-id>/` while the controller is idle. Record bundle hashes and approved status. For a multi-case batch, commit/push the checkpoint on its curation branch, rebuild the controller before the next run, and continue with the next requested candidate. Stop at the requested scope; finishing one candidate does not authorize an open-ended queue.

## 6. Restore the inventory and finish the branch

At batch completion, move every approved case directory from `cases_approved/` back to `cases/`, including newly accepted cases. Check for destination collisions before moving and remove the holding folder only if empty. Unqualified/deferred drafts stay outside the validated inventory.

Verify the original case IDs and complete file hashes against the pre-move record. Rebuild/recreate the idle controller from repository source, verify the restored `Eab.Inventory.all()`, check schema-v2 admissions and freeze the restored release without starting another model run.

Review the diff against the branch's main base. A case-only batch should contain new case bundles and their relevant review/verification evidence; temporary moves, deletions of existing cases, observer changes and unrelated old-branch harness changes must be absent. Commit and push the completed curation branch. Report its name/commit, which cases passed twice, and that the full inventory has been restored. Single-case validations are not a full-inventory model score.

**Done:** the requested candidates are accounted for, accepted bundles are in `cases/`, original bundles are unchanged, controller inventory matches the checkout, and the branch is ready to merge.

## Handoff before an interruption

Update the candidate's tracked verification README before ending an unfinished session. Record the branch/main base, case ID and immutable version, current folder placement, controller inventory/observer state, completed review/qualification gates, every run ID and outcome, any active process/container, retained evidence locations and the exact next action. Commit the checkpoint when possible. Keep raw credentials private and make the next action understandable without ignored `.local` scripts.

An interrupted checkpoint may deliberately leave approved cases parked. Label it unfinished and have the next session inspect active work before moving anything. On completion, always perform the restoration step above.
