# Recommendation: realistic, defensible repository tasks

Research date: 2026-10-15. **Proposal for discussion, not an adopted policy.** Existing cases, inventory, runner and ADRs are unchanged. This investigation used primary papers, benchmark repositories, release notes, original audits and local source inspection; it did not execute or independently reproduce the published benchmark audits.

## Recommended direction

Build a benchmark of **making a coherent change in an existing Elixir project**, using two explicitly labeled prompt regimes:

| Regime | Solver input | Capability measured |
| --- | --- | --- |
| Maintenance | A short, sufficient report of an observed problem, plus the existing repository | Investigating and correcting behavior whose intended contract is discoverable |
| Clarified implementation | A concise requirements brief with the material product decisions already settled | Implementing a feature or objective refactor while preserving existing behavior |

Use historical PRs, carefully reconstructed pre-feature states, and newly authored requests as candidate sources. Apply the same quality gates to all three. Prefer coordinated work across 2–5 implementation files, without requiring a particular file count from a solution. Keep the existing Pi execution flow.

Use public cases for development and transparent comparisons. If future claims about unfamiliar tasks matter, add a separately controlled, private evaluation set of original tasks. Both sets should use the same runner and grading rules. Secrecy is an exposure policy, not another agent workflow.

The defensible claim is: **these versioned tasks have reviewed contracts, repeatable checks and demonstrated solutions under a recorded execution policy.** It is not that every future failure proves model weakness or that passing proves the absence of all bugs. Model behavior, its interaction with Pi, resource limits, fixture reliability and grader completeness can all affect results.

## What the benchmark research changes

The likely match for the newly authored benchmark in the question is **DeepSWE**. Its current repository publishes instructions, verifiers and reference patches. Original tasks with solutions never merged upstream are different from permanently secret tasks. The identification is an inference; the public artifacts are directly inspectable. [DeepSWE announcement](https://deepswe.datacurve.ai/blog/deepswe), [pinned public task](https://github.com/datacurve-ai/deep-swe/tree/0b9fabbb63b9104d678fe965e1632f2dd9eaa2ea/tasks/abs-module-cache-flags).

SWE-bench Lite deliberately filters out multi-file changes, so it is a poor selection template for the workload wanted here. Verified's annotation instructions instead offer a useful principle: the task must establish what is wanted, and tests must allow reasonable implementations rather than demand undisclosed reference-specific details. [Lite selection](https://www.swebench.com/lite.html), [Verified reviewer instructions](https://cdn.openai.com/introducing-swe-bench-verified/swe-b-annotation-instructions.pdf).

Neither a famous benchmark nor human review settles quality permanently. OpenAI's February 2026 Verified audit examined a selected difficult subset, not a representative sample of all tasks. Its July Pro audit concerns the original public release; Pro V2, released September 22, revises statements, tests and reference patches and removes tasks. Those audits support stronger review, but their defect rates must not be assigned to the revised release or this repository. [Verified audit](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/), [Pro audit](https://openai.com/index/separating-signal-from-noise-coding-evaluations/), [Pro V2 dataset card](https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro).

Detailed comparisons and source/version caveats are in [benchmark landscape](benchmark-landscape-2026-10-15.md). The separate [sourcing and prompt study](task-sourcing-and-prompts-2026-10-15.md) examines FeatureBench, DevBench, SWE-bench Pro and clarification research.

## 1. Select outcomes before selecting diffs

A good candidate has one recognizable stakeholder outcome and a credible reason for the surrounding code to change together. Examples include keeping authorization correct after ownership changes, carrying configuration from an API through a process to persistence, or adding an operation whose UI and background worker must agree.

Use this screening table before preparing an environment:

| Question | Acceptable evidence | Defer or reject when |
| --- | --- | --- |
| Is it real work? | An actual reported workflow, an upstream design need, or an independently reviewed product request | It is make-work, mechanical churn, or unrelated fixes combined to increase size |
| Is its meaning recoverable? | Every scored obligation comes from the prompt or specified, solver-visible repository contracts | A hidden test chooses an unstated policy |
| Is it meaningfully coordinated? | State, data or an interface crosses responsibilities that must remain consistent | Several files contain only repetitive edits |
| Can success be observed? | Behavioral checks plus relevant preservation checks distinguish complete and partial solutions | Passing depends on matching private helper names, exact patch shape or subjective taste |
| Can it run reliably? | Pinned source, dependencies, services and data work in an offline functional environment | It depends on unavailable cloud state or uncontrollable external behavior |
| Does it add coverage? | It adds a project, workflow, failure mode or integration boundary | It repeats a backport or nearly identical task family |
| Can its origin be explained? | Source revisions, task authorship, reference/test origins and license notices are recorded | Provenance or redistribution requirements are unresolved |

Record implementation, test, documentation and generated changes separately. Prefer 2–5 substantive implementation files in the expanding corpus, retain some focused tasks, and permit larger coherent tasks. Record the integration boundaries and material states/error paths as well as reference size. Do not impose minimum lines changed, require the reference architecture, or manufacture extra edits. There is no source-backed universal file-count threshold for difficulty.

Sample application workflows as well as libraries: Phoenix/LiveView, Ecto/data constraints, OTP ownership and lifecycle, background jobs, serialization, authorization and offline UI interactions. Track project and task-family concentration at each release. Discover candidates without inspecting the cheaper models' results; otherwise their weaknesses become an undocumented selection criterion.

Pure speed improvements are outside this functional benchmark's proposed scope. Correctness and bounded concurrency checks are eligible; this machine must not be used for speed, latency or throughput qualification.

## 2. Give the shortest sufficient contract

Replace a universal one-sentence rule with: **leave investigation and implementation to the solver; disclose decisions it cannot fairly infer.** Prompt length follows the contract. A bug may need one sentence and an input example. A feature may need several paragraphs or a short requirements list. Do not pad either to reach a target length.

For maintenance, include the observed result, essential trigger and intended result when the latter is not evident. For example: “After I transfer an item, its previous owner can still edit it from an already-open page; fix it.” Whether other users should retain access must follow the visible authorization model or be stated.

For a feature, an illustrative clarified brief could be:

> Let the owner cancel a queued export from its status page. A successful cancellation must survive a worker restart and prevent the export from starting. Repeated cancellation should leave the same canceled state. A running or completed export cannot be canceled and must remain unchanged. Users who do not own the export must not change its state. Preserve existing export creation and download behavior. Use the project's existing presentation and error conventions.

This supplies product decisions; it does not reveal modules to edit, storage representation or control flow. If a specific HTTP endpoint, callback signature, serialized shape or error code is required for compatibility, state it. If the tests require an arbitrary private helper, change the tests instead of turning that helper into a fake product requirement.

The proposed “grill-with-docs without back-and-forth” is a **requirements interview performed during curation**, followed by its frozen outcome brief. It measures implementation after clarification. A separate interactive benchmark would be needed to measure asking questions and resolving ambiguity. Pro's original methodology makes a similar distinction; the recent ReqClarifyBench preprint explicitly separates vague intent, clarified documents and interaction. Treat the latter as emerging evidence, not established consensus. [Pro paper](https://arxiv.org/html/2509.16941v1), [ReqClarifyBench](https://arxiv.org/html/2610.13022v1).

Review the whole solver input, including visible tests, comments and environment instructions. In this repository, [`TaskContract.instructions/1`](../../lib/eab/task_contract.ex) also appends `grading.requirements[].text`. The frozen prompt must include that material; grading metadata must not silently disclose a repair or impose extra requirements.

## 3. Use three sources, with honest provenance

| Source | Recommended use | Required caution |
| --- | --- | --- |
| Historical issue/PR | Authentic maintenance and already agreed feature requests | Read linked discussions and later corrections; separate incidental changes; public fixes may have been seen during training |
| Feature reconstruction | A bounded implementation task in a curated starting state | Removing working code can leave broken scaffolding, answer remnants or unnatural integration boundaries |
| Original request in an existing repo | Fresh product work, especially for a private evaluation set | Independently review the request, reference and checks; author agreement is not external validation |

Do not replace repository work with whole-application generation for this benchmark. That introduces architecture and open-ended design choices needing a different evaluation contract. DevBench illustrates that broader task class; a solver starting from an empty directory also does not mean the source task itself is novel. [DevBench paper](https://arxiv.org/html/2403.08604v2).

Feature removal is a supported research direction, not merely an improvised trick. FeatureBench constructs such tasks using dependency analysis, preservation checks and explicit interfaces; its later statement corrections also show that construction does not eliminate specification problems. [FeatureBench paper](https://arxiv.org/html/2602.10975v1), [release repository](https://github.com/LiberCoders/FeatureBench).

For a reconstruction candidate: pin and test the complete version; define the user-facing capability; create a plausible pre-feature state; keep unrelated behavior working; remove answer copies from history, artifacts, caches and installed packages; qualify the restored reference and compiling partial implementations. Preserve legitimate consumer contracts. Reject a removal that merely breaks imports globally or leaves the missing implementation written in comments. Record the removal patch explicitly. The [supporting note](task-sourcing-and-prompts-2026-10-15.md#a-safe-feature-removal-pilot) contains the full protocol.

For original tasks, write and review the behavior brief before the reference implementation. A separate reviewer should derive acceptable outcomes from the solver-visible package before seeing the reference. Generate tests from those obligations, then use the reference to check executability. AI assistance is useful for drafting and finding gaps, but having the same model invent the requirement, solution and judge creates correlated assumptions.

## 4. Make grading repeatable and challenge its meaning

There are two different requirements: **the same submitted patch should receive the same result**, and **that result should represent the requested behavior**. Deterministic tests address the first; carefully chosen assertions and review address the second. Finite tests cannot certify that arbitrary software is bug-free.

UTBoost found both insufficient task tests and result-parser problems in SWE-bench evaluations. An ICSE 2026 study found regressions in patches accepted by benchmark tests and used differential testing to find further suspicious behavior. Difference from the reference was a signal for investigation, not proof of incorrectness. [UTBoost](https://aclanthology.org/2025.acl-long.189/), [correctness study](https://software-lab.org/publications/icse2026_SWE-bench-correctness.pdf).

Proposed admission gates:

| Gate | Evidence required |
| --- | --- |
| Contract alignment | Each material obligation maps to named assertions; each assertion has visible justification. A reviewer resolves plausible alternative interpretations. |
| Starting and reference states | The starting state fails for the intended missing behavior; the reference passes acceptance and relevant preservation checks. Setup failure is not the target failure. |
| Plausible wrong solutions | Compiling partial fixes or targeted mutations leave material obligations unmet and fail the corresponding assertions. Use more than one when the workflow has distinct failure modes. |
| Valid alternatives | Review likely alternative designs. Execute a different valid implementation where a check appears coupled to the reference. Do not require two full handwritten solutions for every case. |
| Preservation | Exercise neighboring behavior, error handling and state transitions. Use the broader stable suite when feasible; document scoped omissions. |
| Reproducibility | Pin dependencies, services, data, locale/timezone and random seeds. Control clocks and synchronize processes explicitly. Require three clean repetitions of qualification checks with identical outcomes as an initial policy, not a proof against flakiness. |
| Grader integrity | Reapply the submission in a clean environment. Keep authoritative checks outside the agent's control, confirm expected tests actually ran, reject missing/duplicate/skipped required results, and exercise an early-exit/bypass control. |
| Blind solvability | Two fresh attempts using the same recorded strong-model configuration, frozen task and ordinary Pi flow pass the qualified grader. Retain all attempts and review the passing patches. |

For the cancellation example, reject partial fixes that only hide a button, cancel another user's job, change an in-memory flag lost on restart, or suppress all export execution. Also accept legitimate alternative persistence/process designs. That is more informative than checking that the gold patch passes and an empty patch fails.

Use property, metamorphic or differential checks where the contract supports them: round-trip invariants, idempotence, equivalent input transformations, or consistency across old and new entry points. Freeze generated inputs or controlled seeds for grading. Review any differential discrepancy against the contract; the reference can itself be incomplete. An LLM may help propose checks or investigate disagreements, but should not be the final pass/fail judge for this functional benchmark.

Test injection also needs review. A September audit reports false negatives in DeepSWE v1.1 when hidden tests collided with agent-written tests or replacement removed their helpers. This is attributed evidence, not reproduced here. Keep grader-owned and agent-owned test artifacts distinct, and exercise collection/replay with representative added tests. A fresh container alone does not prevent these conflicts. [DeepSWE audit](https://samaritan-research.org/benchmarks/deepswe/review).

Treat a timeout as an operational event to classify, not automatic proof of a bad case or slow model. Distinguish candidate-caused failures from independently established infrastructure failures. Never convert an unknown grading outcome into a silent pass, and do not drop failing tasks selectively from a published denominator.

## 5. Keep two strong-model passes, with a narrower interpretation

Keep the requested two-pass gate as feasibility evidence. Use separate clean contexts and workspaces, with no previous solution, reference or hidden checks. A resumed attempt is not a second fresh attempt. Review the produced patches for untested shortcuts and record unsuccessful trials; do not repeatedly retry and retain only the best two.

Two successes do not establish statistical independence, comprehensive correctness, freedom from memorization, or that another model's failure is deserved. The same model can make the same assumption twice. A second model family or human implementation is useful additional evidence for disputed cases, but need not become a mandatory second full reference for every task.

This gate also selects a corpus conditional on what the validating model and budget can solve. Label it accordingly. If a well-reviewed task defeats that model, keep it in a deferred/research pool; do not call it broken merely for failing the gate. Conversely, retain valid easy tasks when they represent useful work. Do not optimize the corpus to produce a desired failure rate.

For later comparisons, freeze the entire solver prompt, Pi version, tools, environment and effective resource policy. Generous admission runs and stricter evaluation runs answer different questions. Use a fixed attempt policy, report per-task outcomes and slices by regime/project/source, and distinguish pass-on-one-attempt from success after several attempts. With 100–200 correlated tasks, a few percentage points should not automatically be treated as a reliable model ranking.

## 6. Care about secrecy according to the claim

| Risk | What happens | Useful response |
| --- | --- | --- |
| Prior exposure | Training or retrieval includes a public task or its solution | Fresh original withheld tasks, exposure records and honest limits on contamination claims |
| During-run leakage | The agent finds a reference, hidden test, future commit or answer artifact | Offline workspace boundaries and an audit of images, dependencies, history and mounted files |
| Repeated tuning | Model/prompt/scaffold choices adapt to the same evaluation results | Public development tasks plus a locked confirmation set and scheduled replacement of exposed tasks |

Withholding a public PR's identifier does not hide the underlying fix. Removing a public feature today does not make its implementation novel. Private tests alone do not stop a model remembering a public reference. Original tasks on public code can still be useful private tasks when the new requirements, exact answer and verifier have not been published.

Recommend a **public engine and development corpus, plus a private pack of prospective original tasks** if unseen-task comparison is important. Keep it private from task authoring through validation and scoring, including prompts, model responses, patches, reports, container layers and CI artifacts. Public records can disclose aggregate categories, version commitments and the evaluation protocol; an independent reviewer can inspect private artifacts. This trades immediate public reproducibility for reduced exposure. Periodically retire and publish a version only after replacement tasks are ready, and mark it public thereafter.

Split near-duplicate tasks and common source changes together. Include some held-out projects if transfer to unfamiliar repositories matters, while distinguishing that from unseen work in familiar repositories. Do not repeatedly tune Pi on the private set. Adaptive holdout reuse can overfit evaluation data even without deliberate benchmark training. [Foundational holdout-reuse research](https://arxiv.org/abs/1506.02629).

Privacy from the public is also separate from provider data handling. OpenAI's API documentation says API inputs/outputs are not used for training by default unless opted in, while retention and application state have separate rules. `store: false` alone is not a zero-retention or universal no-training guarantee. [API data controls](https://developers.openai.com/api/docs/guides/your-data).

The [subscription inference documentation](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference) specifies `store: false`; the pages examined do not establish a complete training/retention policy for this account's subscription-authenticated flow. Do not silently apply an API organization's policy to it. Before sending genuinely private tasks through that path, establish the applicable account/provider policy. The local implementation already sets `store: false` in [`OpenAI.payload`](../../lib/eab/openai.ex), but that setting does not resolve this research limitation. No credentials or account settings were inspected or changed.

For a personal comparison of local models, public cases remain useful. Report them as public-case performance, and avoid claiming their exact tasks were unseen. We cannot make already published cases private retroactively.

## 7. What adoption would change here

These are future work items, not changes made by this report:

- Revise [ADR 0002](../adr/0002-historical-upstream-repairs.md) and the provenance schema to represent historical, reconstructed and authored tasks truthfully. [`Provenance`](../../lib/eab/provenance.ex) currently requires a GitHub PR and exact broken/fixed upstream trees. Do not invent PRs or disguise feature removal as a task-neutral environment patch.
- Revise the prompt guidance in [PR selection](../pr-selection-guidelines.md) and the interpretation of [ADR 0009](../adr/0009-validate-minimal-tasks-with-blind-model-attempts.md) to allow clarified feature briefs while retaining blind solvability checks.
- If a private pack is chosen, revise [ADR 0001](../adr/0001-public-cases-and-solutions.md) and add explicit private input/export handling. Current inventory/release code assumes repository case bundles; privacy is not achieved merely by adding an exposure label. The agent execution engine can remain Pi.
- Extend curation evidence for targeted negative controls, alternative-solution review and repeatability. The current [`Grader`](../../lib/eab/grader.ex) already has unchanged/reference/early-exit/incomplete controls; one incomplete patch is not comprehensive coverage. Automatic two-model-run admission is not currently enforced.
- Verify adapters at project onboarding. Current [`TestAdapter`](../../lib/eab/test_adapter.ex) supports ExUnit and specified Node tests; an upstream browser/Jest suite does not become supported just because a PR includes it.

No security certification of the runner follows from this source inspection. No new task metadata fields, private exports or admission automation were implemented during research.

## 8. Pilot before expanding to 100–200 cases

After agreeing the policy, prepare **six pilot candidates: two historical changes, two feature reconstructions and two original requests**, across at least three projects. This number is a practical proposal, not a literature-derived optimum. Prefer coordinated 2–5-file work, include both prompt regimes, and keep any intended private tasks out of public artifacts from the start.

Complete one candidate at a time, with a separate commit per finished public case as previously requested. Evaluate contract clarity, environment feasibility, partial-fix rejection, alternative-solution acceptance and curation effort. Do not use elapsed execution time as performance evidence or select candidates to force a particular model ranking. Resolve policy and runner gaps before admitting a new source kind.

For each candidate, retain a compact record:

```text
Identity/version; project/source revision; source kind; exposure history
Task kind and prompt regime; intended user outcome
Full solver-visible contract and environment notes
Implementation responsibilities and integration boundaries; separate file counts
Requirement -> visible justification -> acceptance/preservation checks
Reference provenance; targeted wrong controls; alternative-solution review
Environment and grader hashes; repeatability/integrity results
Reviewer findings; both blind-run records and all unsuccessful attempts
Admission/defer reason; related-task family; unresolved limitations
```

Freeze the contract, environment and verifier together. A substantive correction creates a new case version and invalidates the relevant old qualification and comparison evidence. Preserve old release results with their original meaning. Once the pilot demonstrates a sustainable process, expand by coverage gaps, keeping development and confirmation results distinguishable.
