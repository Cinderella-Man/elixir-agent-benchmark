# Task sourcing, feature removal, and prompt contracts

Research date: 2026-10-15. This note informs the proposed curation policy; it does not admit tasks, alter existing cases, or change the runner. Sources below are first-party papers, benchmark documentation, and repositories. Recommendations are our design judgments, not universal benchmark standards.

## Advice for this benchmark

Keep authentic repository maintenance as the main population, and add a clearly labeled feature-development population. Source candidates through both historical changes and carefully authored feature requests. Pilot feature removal as a third sourcing method, rather than replacing all PR-derived tasks with reconstruction exercises. Keep creating an entire application separate from modifying a maintained application: those tasks ask different questions about a model.

Replace the proposed universal one-sentence policy with **the shortest sufficient behavioral contract**. A short symptom report is appropriate when the starting repository establishes the intended behavior. A feature needs the product decisions that a developer would otherwise obtain through clarification. A frozen summary of a requirements interview is a useful input: it measures implementation after clarification. It cannot measure the ability to ask good questions or negotiate requirements.

Prefer coordinated changes across 2–5 implementation files because that reflects the user's target workload. Treat that as a sampling preference, not a correctness condition or a scientific definition of complexity. The important question is which components must agree and how the tests observe that agreement. A valid solution may change fewer files than the reference.

## What the primary sources establish

**Historical PRs are useful evidence, but are not automatically fair tasks.** SWE-bench Multilingual's documented selection process rejects insufficient issue descriptions, issue/PR misalignment, PRs combining multiple issues, and tests that reject valid solutions. This supports reviewing the issue, implementation, and verifier together rather than equating “merged upstream” with “ready for evaluation.” [SWE-bench Multilingual construction](https://www.swebench.com/multilingual)

**Detailed requirements and interfaces can be legitimate inputs.** SWE-bench Pro's original paper supplies human-augmented descriptions, requirements, and relevant interfaces. It explicitly distinguishes implementing a well-specified change from resolving ambiguity, and acknowledges that augmentation can become excessively prescriptive. Its interface information addresses false negatives when tests expect particular callable names. The lesson is to disclose genuine integration contracts, while questioning tests that insist on arbitrary private structure. [SWE-bench Pro, §§3.2, 4.2, 6 and Appendix A](https://arxiv.org/html/2509.16941v1)

**Removing a feature is an established construction method.** FeatureBench traces tests into a dependency graph to isolate feature code, retains code needed by preservation tests, and validates the resulting incomplete repository and restored reference. It supplies behavior descriptions and callable interfaces. It also addresses answer retrieval through installed packages. These are feature-reconstruction tasks, not untouched historical development states. Its current repository reports an August 2026 V1.1 update correcting inconsistencies and omissions in problem statements; automatic construction still requires contract review. [FeatureBench paper, §§3.1–3.2 and Appendix B](https://arxiv.org/html/2602.10975v1), [official repository](https://github.com/LiberCoders/FeatureBench)

**Whole-application generation is a different evaluation.** The 2024 DevBench implementation task asks for an entire repository using a product requirements document, diagrams, and architecture. Its authors curated existing repositories and prepared documents and tests; “generate from scratch” describes the solver's starting position, not necessarily newly invented source tasks. Open-ended design uses a model judge, whereas implementation uses execution. Therefore a from-scratch task is not inherently a private, novel task, nor is all of its quality deterministically scorable. [DevBench, §§3–4](https://arxiv.org/html/2403.08604v2)

**Prompt length does not establish realism.** A recent preprint, ReqClarifyBench, distinguishes vague intent, a human-validated requirements document, and interactive clarification. Its evaluation studies elicitation separately from subsequent implementation. This is directly relevant to the proposed interview-summary prompt, although an October 9, 2026 preprint is emerging evidence, not settled consensus. [ReqClarifyBench, §§3–4](https://arxiv.org/html/2610.13022v1)

**Versions matter.** OpenAI's July 2026 audit found substantial prompt/test defects in the original SWE-bench Pro public set. Scale's current repository describes a September V2 with 642 validated tasks, an offline agent phase, and fresh-sandbox regrading. Do not apply the older audit's numerical findings to V2 without a new audit. Both the existence of revisions and the original failures support freezing exact benchmark versions and retaining qualification evidence. [OpenAI audit](https://openai.com/index/separating-signal-from-noise-coding-evaluations/), [SWE-bench Pro repository](https://github.com/scaleapi/SWE-bench_Pro-os), [V2 protocol](https://github.com/scaleapi/SWE-bench_Pro-os/blob/main/v2/README.md)

## Compare the sourcing methods

The following tradeoffs are recommendations inferred from those construction methods, rather than measured costs for this repository.

| Method | What it measures well | Main curation cost or bias | Recommended role |
| --- | --- | --- | --- |
| Historical bug/feature PR | Understanding an existing system and changing an authentic workflow | Recovering intended scope, historical dependencies, incomplete issues, extra PR changes, public answers | Main source; select coherent outcomes rather than arbitrary PR size |
| Feature removal from a working tree | Implementing a bounded capability while preserving surrounding code | Unnatural remnants, accidental breakage, reference-derived specs, installed/history copies of the answer | Small labeled pilot after a removal audit |
| Newly authored feature in an existing repo | Work that has a real stakeholder and no published exact solution | Authoring a credible request, independent acceptance checks, working reference, domain review | Valuable source for fresh held-out tasks |
| Entire application from a specification | Architecture, integration, bootstrapping, and broad implementation | Large option space; subjective design and UI quality; longer qualification cycle | Separate future population, not a substitute for everyday maintenance |

Do not require every candidate to originate in a single PR. A genuine feature may cross several changes. However, manually combining unrelated fixes to manufacture a bigger task produces a different workload. Record the user-visible outcome and the role of each affected component before counting files.

A diverse corpus should vary behavior families, project types, and integration boundaries. SWE-PolyBench is a useful example of explicitly sampling bug fixes, features, and refactoring and reporting structural categories; its particular mixture is not a prescription for an Elixir benchmark. [Official SWE-PolyBench repository](https://github.com/amazon-science/SWE-PolyBench)

## Write the contract before writing the answer

For a newly authored task, conduct the requirements interview during curation. Freeze its result before the solver attempt. Include the actor and objective, observable behavior, material edge policies, compatibility obligations, and any required public entry point. Specify non-goals when they prevent reasonable but incompatible interpretations. Neutral environment instructions belong alongside the task.

For example, “Let me cancel a queued export” is incomplete if the hidden tests decide what happens to running exports, who is authorized, and whether cancellation survives restarting the worker. An implementation-ready request could state that the requesting owner may cancel while queued, a canceled job never starts and remains canceled after worker restart, and already-running jobs remain unchanged. Those are product decisions, not repair instructions. Only add them if they are truly intended and independently justified.

Avoid naming the faulty helper, listing required edit locations, prescribing control flow, or converting the reference patch into prose. Public route names, callback signatures, serialized shapes, and exact messages belong in the input when they are required compatibility boundaries. Internal helper names generally do not. If a test imports a new private helper solely because the reference uses it, improve the test boundary instead of forcing the same decomposition on every solution.

Use a curator-side obligation table: visible requirement or existing contract → acceptance assertion → plausible violation rejected. Inspect the entire solver input, including appended grading requirements, visible tests, comments, and environment notes. A minimal ticket with a second detailed solution hidden in metadata is still a detailed solution prompt.

Have a reviewer who did not author the reference read only the solver-visible package and describe the acceptable outcomes. Reconcile disagreements before evaluation. AI can draft specifications, traces, and checks, but a shared model-generated assumption must not silently become both the task and its proof. Keep authorship and review provenance. Two blind strong-model passes add feasibility evidence; they cannot prove the contract complete or all passing patches correct.

## A safe feature-removal pilot

This proposed protocol adapts the idea to the repository's existing fixture controls; it does not require a second agent engine.

1. **Select a coherent capability.** Identify a user/caller outcome with a meaningful boundary and preservation obligations. Reject removal that leaves only trivial stubs or an unrelated collection of missing functions.
2. **Freeze a working reference.** Pin repository revision, dependencies, local services, licenses, and deterministic fixture data. Establish that the feature and relevant neighboring behavior work before removing anything.
3. **Write an independent request.** Describe the desired behavior from stakeholder requirements, external API contracts, and observed use. Use the reference to check completeness, not to prescribe its private decomposition. Record that the case is derived by removal.
4. **Create a coherent starting state.** Remove the capability and adjust registrations, imports, UI entry points, documentation, and migrations as needed to represent a plausible pre-feature product. Preserve legitimate conventions. Do not leave missing imports that prevent the whole application from starting unless repairing that failure is the actual task.
5. **Audit answer remnants.** Exclude reference patches and feature tests from the solver workspace; inspect history, alternate worktrees, build outputs, source maps, packaged dependencies, caches, fixtures, docs, and examples for copies or direct reconstruction instructions. Keep legitimate consumer contracts visible. Apply the existing offline boundary; a prompt asking an agent not to retrieve the answer is insufficient isolation.
6. **Qualify behavior, not just compilation.** The starting state must demonstrate the absent capability at its relevant boundary while preservation checks remain meaningful. Missing API tests may fail on an absent symbol, but that alone must not stand in for testing the finished workflow. The restored reference must satisfy all required behavior.
7. **Challenge the verifier.** Try compiling partial implementations, lost persistence, incorrect authorization, ignored error cases, and shortcuts appropriate to the task. Ensure each fails a named assertion. Where a legitimate design differs from the reference, exercise it or adjust the check so the design is accepted.
8. **Review and freeze before model trials.** Record the exact source/removal/reference patches, full solver prompt, grader, environment, and case version. Run the ordinary independent qualification attempts. Any contract or grading repair creates a revised version and requires renewed evidence.

The resulting label should be “feature implementation in a curated starting state,” not “authentic historical issue.” Creating a new removal today does not make the removed public implementation unknown to trained models. Fresh private requirements can reduce exposure of an exact answer; they do not by themselves establish task quality. Use provenance and exposure labels alongside the behavioral checks.

## Proposed next decision

Before sourcing more cases, agree on two prompt regimes under the same Pi execution flow: **maintenance from an observed problem** and **implementation from clarified requirements**. Select a small pilot covering historical maintenance, an authored feature, and one feature-removal task. Compare curator effort, ambiguity findings, preservation coverage, and partial-solution rejection—not speed or an artificially low model pass rate. Freeze the policy after reviewing those concrete examples, then expand toward the intended 100–200 cases.
