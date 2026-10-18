# Case selection: evidence and practical refinements

Research date: **2026-10-18**. This report distinguishes the repository's established curation rules from proposed refinements. It changes no policy, cases, inventory, runner or scores. Work was limited to reading local evidence and primary public sources; no model attempts, fixture qualification, builds or performance measurements were run. Published studies below were not independently reproduced.

The existing guidance is substantially aligned with the evidence. The useful next step is to make its reviews more discriminating and its selection history more visible: record why candidates disappear from the funnel, test coordinated behavior with plausible wrong solutions, distinguish fixed-order repeatability from order robustness, and describe the corpus as conditional on its validation gate.

## 1. What is already policy

[PR selection guidance](../pr-selection-guidelines.md) is the current operational source. The October 15 [design recommendation](benchmark-design-recommendation-2026-10-15.md) and [landscape](benchmark-landscape-2026-10-15.md) remain research documents; their proposals should not silently supersede the current guidance.

| Established rule | Consequence for this discovery round |
| --- | --- |
| Prefer coherent work across 2–5 substantive implementation files; retain useful focused tasks | Count responsibilities and their interactions, with tests/generated files separately. File count is a discovery signal, not a difficulty score or a restriction on valid solutions. |
| Use the shortest sufficient visible contract | A bug report may be brief; settled feature decisions may need a clarified brief. Inspect appended requirements and other solver-visible material as well as `ticket.md`. |
| Qualify unchanged, reference, plausible-incomplete and integrity controls | A candidate needs meaningful assertion failures, preservation evidence and a reference that actually works. Compilation failure from mutilating a patch is not an adequate incomplete control. |
| Three fresh qualification rounds and two reviewed blind strong-model successes | These are distinct gates. Neither proves exhaustive correctness or that every subsequent failure measures model capability. |
| Keep failure histories, exposure and related task families | Rejected/deferred work must not reappear under a new name without its history and a reason for reconsideration. |
| Public historical repairs are the default source | Reconstructions and original requests are eligible small pilots, subject to provenance/runtime support. A proposed private pack is not the current public corpus. |

The [Astra review](../../verification/astra-confirmation-2026-10-15/README.md) reports nine cases meeting the two-success rule, four graded failures and six infrastructure interruptions across the examined history. That adaptively selected history is not a benchmark accuracy estimate. The [rejection register](../../cases_rejected/README.md) distinguishes Plausible 6763's unresolved CSV contract from Plausible 6441's missing second reviewed success. Neither case should be presented as newly discovered, unsolvable, or automatically eligible for readmission.

## 2. Selection quality is a corpus property as well as a case property

**Primary evidence.** SWE-bench Verified's authors explicitly report that filtering changed its difficulty distribution, while noting improvements within difficulty groups too. Quality filtering and a change in the sampled workload can occur together. The original release was August 13, 2024; the inspected page records an update on February 24, 2025. [Verified methodology and limitations](https://openai.com/index/introducing-swe-bench-verified/).

The March 10, 2025 SetUpAgent paper constructs separate application-focused and broader-repository datasets and finds meaningful distributional differences from SWE-bench. It supports examining repository/application concentration; it does not supply a representative sampling frame for Elixir work, prove that more repositories automatically improve validity, or establish an optimal file-count quota. [Original paper, sections 4–5](https://arxiv.org/html/2503.07701v1).

**Proposed refinement: publish a small selection funnel before looking at comparison-model results.** The existing candidate record already has statuses and reasons. Aggregate those records by project, task family and rejection/defer reason, including the search scope and date. This makes it possible to tell whether “mostly Livebook” reflects actual coverage choices, search effort, cheap preparation, or systematic failures elsewhere.

For each release, inspect these dimensions together:

| Dimension | Useful categories | Selection mistake it exposes |
| --- | --- | --- |
| Work and prompt | Repair, bounded feature, objective refactor; maintenance report versus clarified brief | Calling a bug-fix collection representative of all implementation work |
| Integration boundary | UI/server, query/results, persistence/process, serialization/consumer, authorization/state | Counting unrelated file edits as coordinated work |
| State and configuration | Fresh/existing state, supported editions/modes, restart/reconnect, success/error paths | Overrepresenting fresh-object happy paths |
| Source and family | Historical/reconstructed/authored; issue/PR lineage and neighboring fixes | Counting backports, reverts or repeated manifestations as independent coverage |
| Preparation friction | Supported now, support work required, unavailable dependency/service | Silently selecting only the easiest environments |

This is an operational proposal, not a numerical quota or a statistical claim of representativeness. Prefer candidates that fill identified gaps **after** they meet contract and execution gates. A coverage benefit cannot compensate for an ambiguous requirement. Keep “adds little coverage” separate from “invalid task,” since a good case may be unnecessary in a particular release.

## 3. Make contract review configuration-specific

**Primary evidence.** OpenAI's July 8, 2026 audit of the original 731-task SWE-Bench Pro public release distinguishes misleading instructions, unstated requirements, overly specific tests and insufficient checks. Its deeper review starts from a flagged subset and includes engineer review; its counts are not a census of Pro V2 or an estimate for this repository. The practical lesson is that upstream discussion, code and tests do not automatically form a self-contained evaluation contract. [Original audit](https://openai.com/index/separating-signal-from-noise-coding-evaluations/).

The local [6763 diagnosis](../../verification/astra-confirmation-2026-10-15/case-quality-note.md) is a concrete example: a visible CSV-header assertion covered a different metric-availability configuration from the hidden assertion. The failed repair could follow the visible convention of dropping unavailable metrics. Another successful repair did not remove that ambiguity.

**Proposed refinement: add the triggering configuration and competing interpretation to each disputed requirement's review record.** The existing two-way requirement/assertion mapping is necessary; write down the reasoning where it is non-obvious:

```text
Observable obligation:
Exact mode/input/prior state in which it applies:
Solver-visible justification at the starting revision:
Reasonable competing behavior, if any:
Why the contract excludes it, accepts it, or needs clarification:
Named acceptance witness and neighboring preservation witness:
```

A maintainer's later explanation may establish the desired product policy, but if that policy is absent from the starting workspace it belongs in the clarified ticket. Conversely, repository conventions should remain available for investigation; not every relevant code path must be summarized in the prompt. The review question is whether an outcome is reasonably inferable in the actual scenario, not whether a reviewer who has seen the gold patch can invent a rationale for it.

Treat private helper names, exact internal data layouts and incidental error formatting as suspect unless the visible task or a real compatibility boundary requires them. When two behaviors are defensible, clarify the smallest necessary outcome or accept both. Do not convert the entire reference architecture into requirements.

## 4. Test obligations with wrong solutions and valid alternatives

**Primary evidence.** UTBoost, published at ACL in July 2025, reports patches accepted by original SWE-bench checks that fail added task-relevant tests. That supports reviewing passing submissions and test adequacy separately from fail-before/pass-after construction. Its rates describe its evaluated tasks and submissions, not this corpus. [UTBoost](https://aclanthology.org/2025.acl-long.189/).

A useful newer source is **PROBE**, arXiv v2 dated August 6, 2026 and identified with ASE 2026. It uses plausible program variants to locate untested behavior and admits generated checks only after reference success, rejection of a surviving variant and checks against behavior-preserving transformations. Its example catches a repair that changes an encoder without updating its downstream consumer. The authors discuss equivalent variants and reference-specific tests as validity risks, and evaluate Python rather than Elixir. Search results may still show the v1 title, *Are Benchmark Tests Strong Enough?*; this report uses v2. [PROBE methodology and limitations](https://arxiv.org/html/2604.01518v2).

**Proposed refinement: plan a small set of wrong behaviors by obligation, rather than treating one incomplete patch as coverage of every obligation.** This does not require adopting a mutation framework or producing a second full reference for every case.

| Candidate shape | Plausible incomplete solution to challenge | Preservation witness | Valid-alternative risk to review |
| --- | --- | --- | --- |
| Authorization after a state change | Refreshes the page display but keeps an old permission path | Authorized access still works; unrelated records are unchanged | Demanding one internal permission cache design |
| Filtering a mixed population | Removes the offending category by suppressing all results | Legitimate entries remain beside the invalid ones | Requiring exact intermediate query structure |
| Configuration propagated to a process | Changes persisted configuration but leaves running state stale | Existing instances and unrelated settings continue working | Requiring a particular message or helper name |
| Encoder/decoder or query/consumer change | Fixes one entry point only | Existing supported inputs and downstream consumption | Equating a reference representation with the public contract |
| Bounded feature with error cases | Implements the happy path but ignores invalid transitions | Existing operations and retry/idempotence behavior | Hidden policy for a state the brief never specifies |

These are proposed review patterns, not new cases or claims that every example belongs in every test suite. Select a few witnesses that separate materially different wrong behaviors. If a variant survives, first decide whether it violates the visible obligation: a valid alternative is evidence against an overconstrained grader, not a target to eliminate. Branch coverage and mutation counts are diagnostics, not admission scores.

The local [6441 review](../../verification/astra-confirmation-2026-10-15/README.md) already demonstrates the value of a mixed-population witness: rejecting invalid imports alone could reward a solution that also discards valid ordinary goals. The next corpus should carry that lesson into other state/data boundaries.

## 5. Separate fixed-input repeatability from robustness to test order

**Local finding.** The [frozen-case procedure](../../verification/frozen-cases-2026-10-15/README.md) ran all three qualification rounds with ExUnit seed `0`. ExUnit documents that seed `0` disables within-file randomization and uses definition order; this is present in both the historical v1.15.2 source and current v1.20.4 documentation. Consequently, this evidence cannot test dependence on different within-file orders. This is a limitation of the evidence, not a newly established flaky case. [ExUnit v1.15.2 source](https://github.com/elixir-lang/elixir/blob/v1.15.2/lib/ex_unit/lib/ex_unit.ex), [current configuration documentation](https://ex-unit.hexdocs.pm/ExUnit.html#configure/1).

**Proposed refinement:** keep the three identical fresh rounds as the official gate, and perform a separate, bounded robustness diagnostic while curating new cases. Choose a small declared set of nonzero seeds; keep resource concurrency bounded and recorded. For process/state cases, inspect explicit synchronization and cleanup, and use a small controlled set of message/state orders where the behavior requires it. A seed is not a deterministic BEAM schedule. Do not run until a favorable sequence appears, discard inconvenient failures, or change the official comparison settings silently.

Also exercise the actual submission path: apply a patch with ordinary added tests into fresh grading state, restore protected checks, and confirm all expected test identities ran. Inspect contamination from local services, environment variables, clock-sensitive fixtures, process names and cached files. Project onboarding should distinguish an inability to install the historical environment from a product assertion failure.

No universal number of seeds or repetitions is established by the sources. The appropriate scope depends on the task's statefulness and the risks found during inspection. This is functional qualification; watchdogs detect hangs, and elapsed time is not performance evidence.

## 6. Keep the two-success gate, but explain what it selects

The [existing ADR](../adr/0009-validate-minimal-tasks-with-blind-model-attempts.md) deliberately requires two fresh blind strong-model passes. Keep it. Separately preserve whether the candidate was clear and behaviorally qualified, and whether it satisfied that model gate. A fair task that does not satisfy the gate belongs in a deferred pool; the evidence does not establish that its grader is broken.

**Primary evidence.** *On Randomness in Agentic Evals*, first submitted February 6, 2026 and revised March 25, studies repeated SWE-bench Verified attempts across three models and two scaffolds and reports meaningful variation even at temperature zero. Its recommendations concern repeated-run estimation and statistical power. Those particular variance estimates cannot be transferred to Astra/Pi or Elixir tasks. [Paper v3](https://arxiv.org/abs/2602.07150v3).

**Inference and proposed reporting refinement:** admission is conditional on the validating model, scaffold and resource policy. Under an idealized fixed first-two-attempt gate with independent per-attempt success probability `p`, a task's admission probability would be `p²`; the actual repository allows separately justified diagnostic attempts, so this is an illustration rather than its exact sampling law. It explains why two successes supply feasibility evidence while changing the mix of retained tasks.

Record the attempted candidate population and all outcomes, not just the accepted pair. Freeze the comparison set before inspecting cheaper-model results. Any further diagnostic runs need the already-required bounded rationale. Do not treat the 20 historical passes divided by 24 graded attempts as a corpus score, and do not infer a task's difficulty from the number of retries it happened to receive.

The stronger follow-up for a disputed contract is an independent interpretation or implementation, not many retries of the same model. Model agreement can repeat a shared assumption or prior exposure. This strengthens review without replacing the existing admission criterion.

## 7. Separate public exposure, run leakage and developer usefulness

**Primary evidence.** OpenAI's February 23, 2026 Verified audit provides examples of models recalling public task details and repairs. Its problem-quality analysis used 138 deliberately difficult tasks; neither that defect rate nor its contamination examples establish an exposure rate for this benchmark. [Verified audit](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/).

SWE-bench-Live provides a useful process distinction: its August 2025 update keeps comparison subsets frozen while collection continues, and its August 2026 update requires trajectories to inspect withheld-field leakage. Fresh sourcing, fixed comparison inputs and evaluation access controls serve different purposes. [Official project updates](https://swe-bench-live.github.io/).

**Proposed refinement:** add explicit exposure dates and related-family identities to the existing candidate records. A new case ID, paraphrased ticket, removed feature or newer release date is not evidence of an unseen solution. If future development/confirmation subsets are created, place related fixes/backports in the same partition; if the claim is transfer to unfamiliar repositories, partition by repository too. Keep public-case comparisons labeled honestly. A private original-task pilot remains a separate policy decision and must not be simulated by calling public PRs private.

Finally, functional success is a narrower claim than a merge-ready contribution. METR's March 10, 2026 research note had four maintainers from three Verified repositories review 296 agent PRs across 95 tasks and found a substantial gap between test passage and acceptance. Human judgments were noisy too: only 68% of original merged reference patches were accepted in the re-review. The study used older agents, limited repositories and review without ordinary CI/iteration, and is explicitly a less-reviewed research note. [METR's original study and limitations](https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/).

The implication here is to keep patch review for missed functional obligations and preservation, while avoiding an unstated subjective “would a maintainer like this?” scoring rule. If an objective structural constraint is part of a refactor, expose it and grade it explicitly. If code quality is only reviewed qualitatively, report that separately from task success.

## 8. Recommended order of work

1. **Use the existing gates for screening now.** Preserve active, rejected and deferred identities and name a concrete coverage contribution for each new candidate. Unknown environment feasibility stays unknown until qualified.
2. **Improve the review artifact before expanding volume.** Record the exact triggering configuration, alternative interpretation and requirement-level wrong-solution witnesses. This directly addresses both local rejection lessons.
3. **Track the selection funnel across projects and task families.** Make preparation bias and strong-model conditioning visible before drawing broad conclusions from 100–200 cases.
4. **Pilot bounded varied-seed and patch-replay diagnostics on new candidates.** Preserve the official frozen-input qualification procedure and keep all functional work resource-bounded.
5. **Revisit corpus exposure only when the intended claim requires it.** Public, reproducible evaluation is useful; unseen-task claims require separate evidence and handling.

None of these steps admits a candidate by documentation alone. Source inspection, a promising upstream test and a plausible reference are discovery evidence; local qualification, independent review and the recorded blind attempts remain outstanding until actually completed.
