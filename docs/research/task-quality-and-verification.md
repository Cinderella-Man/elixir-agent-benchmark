# Task quality and verification for the Elixir Agent Benchmark

Historical audit of the original twelve-case revision. The audited inputs are preserved in [the original fixture archive](../../verification/task-quality/original/README.md); the [subsequent promotion](../verification/task-quality-promotion-2026-10-14.md) applies the findings to the eleven-case v3 inventory.

Research date: **2026-10-14**. Scope: task selection, specification, grading validity, and a practical verification standard for the twelve existing historical PR cases. This report supplements [the earlier SWE-bench research](swe-bench.md), which covers the preparation and release architecture in more detail.

The subsequent [execution report and per-case decisions](../verification/task-quality-audit-2026-10-14.md) apply this research to all twelve cases. The proposed checks below are the research-stage plan; the execution report records what actually passed and failed.

**Recommendation:** keep real upstream tasks, but admit a *specified, reconstructed, executable case*, not a PR merely because it was merged. For every case, demonstrate that its checks accept the reference, reject unchanged code and meaningful incomplete implementations, preserve relevant existing behavior, and do not demand unstated implementation choices. Custom tests and small hand-written control patches are appropriate for this inventory. A generic mutation framework is unnecessary.

The externally grounded findings below cite primary papers, authors' repositories, official documentation, or original annotation material. The admission rules, proposed controls, and portfolio recommendations are this report's synthesis for this repository; they are not claims that an external benchmark requires exactly this process. No model attempts, builds, fixture controls, or speed measurements were run in producing this research report. The per-case table is an audit plan, **not an assertion that those controls have passed**.

## What the primary evidence establishes

### Historical PRs provide useful evidence, not a complete specification

Original SWE-bench collected issue-linked merged PRs that changed tests, then retained tasks with at least one test failing before the implementation and passing after it. It excluded installation/runtime failures. Its evaluation permits implementations different from the reference. These are useful foundations: authentic context, executable change evidence, and implementation freedom. Requiring an upstream test patch, however, is a sampling choice rather than proof of task quality. [SWE-bench paper, §§2.1–2.3 and appendix A](https://arxiv.org/html/2310.06770v3)

SWE-Lancer instead commissioned tests for real freelance work. Its coding tasks use hidden Playwright flows, with three engineering verification rounds plus automated broken/fixed checks. This supplies a concrete precedent for writing task-specific tests when upstream tests do not exercise the actual user workflow. Its task mix is still concentrated in one product and mostly bug fixes; using full-stack tests does not itself establish broad representativeness. [SWE-Lancer paper, §§1–2 and appendix A.12](https://arxiv.org/html/2502.12115v4)

**Implication for us:** lack of upstream tests should increase the verification work, not automatically disqualify a useful PR. Conversely, a large upstream test patch should not waive any admission check. Include the complete requirement expressed by the task, but do not silently turn incidental cleanup bundled into a PR into mandatory work.

### Human verification must check both directions of the contract

The original SWE-bench Verified campaign reviewed 1,699 tasks with three independent annotations each and retained 500. It screened issue specificity, test fairness, and other major issues. Its conservative aggregation intentionally risked rejecting some usable tasks. This supports independent review and recording disagreement, rather than treating the original maintainer's merge as benchmark review. [Verified announcement](https://openai.com/index/introducing-swe-bench-verified/)

The annotation instructions ask reviewers to reason from the information the solver receives. They warn especially about new function names, variable names, and exact error messages that tests require but the description does not provide. A correct solution should not have to guess the reference author's private choices. [Original annotation rubric, pp. 1–3](https://cdn.openai.com/introducing-swe-bench-verified/swe-b-annotation-instructions.pdf)

**Implication for us:** review the ticket and starting repository before reading the reference and grader. Then trace assertions back to that contract. Independently trace every material requirement forward to at least one check. These are separate tasks: assertion mapping catches unfair rejection, whereas requirement coverage catches undeserved success.

### “Verified” and “Pro” are not permanent guarantees

OpenAI's February 2026 audit found material defects in 59.4% of **138 selected difficult Verified tasks**, not 59.4% of a random sample of all 500. It documented overly specific tests, unstated additional requirements, and contamination examples. The audit therefore shows credible failure mechanisms; its selected sample does not establish the prevalence in this Elixir inventory. [February audit](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)

The July 2026 audit of original Pro flagged 286 of 731 tasks for deeper review. Its agent-assisted process classified 200 tasks as broken and its human campaign 249. Categories included misleading prompts, underspecification, overly strict tests, and inadequate coverage. The authors withdrew their earlier recommendation to use Pro. Those findings describe the audited original public split, not every subsequent Pro release. [July audit](https://openai.com/index/separating-signal-from-noise-coding-evaluations/)

Scale's Pro V2, released September 22, 2026, retained 642 cases after removing 89. Its pinned card reports rewriting 529 statements with assertion-to-sentence mapping, blind implementation of revised instructions by a second engineer, test/parser repairs, sanitized images, reference-success and empty-patch-failure gates, and pristine regrading. These are the release authors' controls, not independent certification. [Pro V2 card, revision `2d52cb3`](https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro/blob/2d52cb3df914a3fcf80c7f66738b3a88ae37fc50/README.md)

**Implication for us:** qualification must bind an exact case version, not a familiar benchmark label. Review both passes and failures. A model's failure can reveal an unfair test; its success can reveal missing coverage. Correcting either changes the evaluation contract and requires a new immutable release identity.

### Passing selected tests is weaker than solving the task

Wang, Pradel, and Liu studied passing patches from three systems. Broader developer tests rejected 7.8%, while differential testing found behavioral divergence in 29.6%. Their manual sample classified only part of the divergent patches as certainly incorrect; divergence from the reference alone was not a sound rejection rule. The evidence motivates relevant regression coverage and semantic review, not exact matching to the gold patch. [Authors' ICSE 2026 paper](https://software-lab.org/publications/icse2026_SWE-bench-correctness.pdf)

UTBoost independently found both weak tests and test-result parser defects, identifying 345 previously accepted erroneous patches in its studied submissions. The parser finding matters because correct assertions are insufficient if their identities or outcomes are read incorrectly. The reported count concerns that study's data, not an estimated rate for arbitrary coding benchmarks. [UTBoost, ACL 2025](https://aclanthology.org/2025.acl-long.189/)

**Implication for us:** verify observable results and relevant side effects, not just successful HTTP responses or the absence of exceptions. Protect test execution and test identities. Inspect why a negative control failed: a syntax error or failed database startup does not demonstrate sensitivity to the missing requirement.

### Targeted mutations are useful; a mutation score is not a proof

Google's mutation-testing work selects changed code and suppresses unproductive, equivalent, uncompilable, and redundant mutations. Its cache example is particularly relevant here: removing a cache lookup can preserve functional output, so functional tests are not expected to reject that change. [Practical Mutation Testing at Scale, §§III–IV](https://arxiv.org/html/2102.11378v1)

Stryker distinguishes killed and surviving mutants from compile/runtime errors; invalid mutants are excluded from its score. It counts timeouts as detected, which is a tool convention rather than the policy this benchmark must adopt. [Stryker's mutant states and metrics](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/)

**Implication for us:** hand-write a few plausible mistakes tied to each case's requirements. Require a named behavioral failure for ordinary incomplete-repair controls. Do not count a noncompiling patch as useful coverage evidence. Do not require a particular cache representation, optimization, or source layout unless the public task explicitly requires it. No speed-based mutation experiment belongs on this machine.

### Reproducible execution and fresh tasks solve different problems

SWE-bench-Live's original release contained 1,319 tasks from 93 repositories with dedicated Docker images. Its validation compares tests before and after the patch and repeats runs, retaining consistent transitions. It also uses recent issues to reduce exposure risk. Repeatability supports stable execution; recent dates support a different claim about likely exposure. Neither proves prompt/test alignment. [SWE-bench-Live, §§3.3–3.5](https://arxiv.org/html/2505.23419v1)

Original Pro used expert-built environments, repeated gold-test runs, and human relevance checks. It augmented descriptions with behavior requirements and interfaces because original discussions were insufficiently self-contained. This is evidence that editorial clarification and per-project preparation are normal curation work. [Original Pro paper, §§4.2–4.3 and appendix A](https://arxiv.org/html/2509.16941v1)

**Implication for us:** use pinned historical environments and clean service state, and save stability evidence separately from semantic review. An offline workspace prevents live answer retrieval through that workspace; it does not remove information already learned during model training.

## Which tasks to include

The target should be meaningful work in the two selected applications, assessed at the boundary where a user or caller experiences it. The [current domain model](../../CONTEXT.md) already distinguishes bugs, features, and refactors. Recommended selection:

| Task kind | Good candidate | Evidence required | Candidate to defer or rewrite |
|---|---|---|---|
| Bug fix | Clear trigger, wrong result, and expected result in a genuine application workflow | Reproduction fails on the starting revision; meaningful behavior passes after repair; neighboring valid behavior remains intact | “Fix crash” with no defined output; failure actually caused by an unavailable service |
| Feature | A bounded new capability, with stated input/output and necessary public interfaces | Capability absent before and present afterward; old behavior preserved | Broad product request whose “done” criteria depend on unpublished discussion or taste |
| Refactor | Explicit interface or structural objective with preserved behavior | Objective acceptance check rejects unchanged code; behavioral preservation checks pass before and after | “Improve architecture” scored through arbitrary gold-patch similarity |
| Data/query change | Observable inclusion, exclusion, aggregation, or data-lifecycle rule | Positive and negative fixtures that distinguish plausible query mistakes | One trivial fixture on which several wrong queries have the same answer |
| State/concurrency change | An incorrect transition, ownership, or isolation property | Controlled sequence/interleaving, observable state, bounded watchdog for hangs | A speed improvement or wall-clock threshold presented as functional correctness |
| UI/workflow change | Actual rendered output or user-submitted form behavior | Real render/event/controller path; persisted effects; relevant failure path | Testing a helper while bypassing the broken UI boundary |
| Security/permission change | Precisely stated authorized and unauthorized behavior | Both allowed and forbidden cases plus side-effect checks | Deny-all accepted because the tests only exercise attackers |

These are eligibility categories, not quotas. A one-line change can require substantial diagnosis and be a useful task. A large patch can be mechanical or poorly specified. Prefer variety in reasoning and integration over variety in line count. Include modest tasks to diagnose baseline competence and larger coherent tasks to expose cross-module work. Avoid making the main set exclusively difficult for the currently favored model.

Keep unrelated changes out of a task's required outcome. If a PR contains two independent features, either specify and test both as one consciously larger task or construct separately versioned cases with accurate provenance. Do not split one fix into many near-duplicate cases and then interpret equal case weighting as equal coverage of independent skills.

A feature that requires live credentials, an uncontrolled third-party service, an unsupported platform, or a subjective visual judgment is not ready for this offline executable benchmark. It can become suitable through a faithful local service, explicit platform contract, or objective interaction requirement. Omitting the essential behavior merely to make it testable is not an acceptable adaptation.

## Ten admission gates

The gates below are recommended hard requirements for a new release. They apply equally to legacy cases even if their stored manifests predate newer admission fields.

| Gate | Evidence to retain | Failure means |
|---|---|---|
| 1. Authentic reconstruction | Exact repository, broken/fixed commits and tree identities; upstream patch partitions; documented environment-only changes | Provenance is unconfirmed; do not admit |
| 2. Sufficient solver contract | Ticket plus accessible starting-tree context; explicit required names/interfaces; editorial changes with rationale | Rewrite the ticket or defer |
| 3. Fair assertions | Every required assertion mapped to a stated or demonstrably established behavior | Rewrite/remove the assertion or clarify the contract before testing models |
| 4. Material requirement coverage | Every material requirement mapped to a meaningful check | Add coverage; a passing reference cannot compensate |
| 5. Positive and unchanged controls | Reference passes every scored stage; unchanged code completes and fails the declared behavioral check | Diagnose the fixture or oracle |
| 6. Incomplete-repair discrimination | Plausible partial patches rejected for the intended missing behavior | Strengthen the check or justify why the candidate is actually valid |
| 7. Preservation | Relevant original behavior passes before and after; known exclusions named and justified | Narrow/fix the fixture or reject the reference/case |
| 8. Execution integrity | Missing/skipped/duplicate/incomplete tests and early exits rejected; protected checks restored | Fix the harness before trusting case outcomes |
| 9. Isolation and stability | Fresh source and service state; no reference/history/test leakage; targeted repeat/order evidence | Repair the environment; do not call it a model failure |
| 10. Review and frozen evidence | Independent review, exact artifact identities, control logs, limitations, decision | Keep as a candidate until evidence is complete |

“Could run” is not gate 5. Source inspection is not a runtime result. One successful run is evidence for that execution, not proof of freedom from flakiness. A cached receipt is valid only for the executable inputs it binds. Do not manufacture review attestations: agent review is useful and should be labeled as such; it does not become a second human engineer's blind implementation.

## A practical per-PR verification procedure

### 1. Write a small requirement ledger

Before examining the grader, summarize the behavior in plain language. Assign IDs to independent obligations, including preserved behavior that rules out obvious shortcuts. Record whether each obligation comes directly from the ticket or from a concrete existing interface/convention in the starting tree. “The gold patch does this” is not enough.

Then map both directions:

| Requirement | Observable example | Grader identity | Why unchanged code fails | Plausible wrong repair | Preservation obligation |
|---|---|---|---|---|---|
| Editors may change the domain | Guest and team Editor submit a new domain; saved current/previous domains are correct | Named tests for each role path | Existing permission logic rejects Editor | Permit only team Editor; permit everybody | Owner/Admin succeed; Viewer/outsider cannot mutate |

Use as many rows as the task needs. Do not force every edge case into a new test file or build an elaborate schema merely for this audit. A checked-in Markdown table plus named tests and patch files can be sufficient.

### 2. Test the boundary the ticket describes

For a query/API case, assert the response and returned data, supported metadata, and persisted effects when relevant. For a LiveView workflow, submit the fields the real form supplies. For formatting, compare document structure and round-trip stability when whitespace is not the requirement. For signed imports, assert both verification and actual authorization behavior. For evaluator state, use successive evaluator requests and inspect what later code can observe.

Use unit checks to isolate corner cases, but include a path through the broken integration boundary. A helper can be correct while its caller omits a required field. Conversely, a full browser is unnecessary if a LiveView render/event test exercises the exact server-owned behavior. Add browser coverage when the requirement depends on client code, actual browser events, or browser rendering.

Avoid reproducing the implementation inside the expected-value calculation. A test that computes the expected query result with the same faulty helper can agree with the bug. Prefer small manually understandable data and independently derived expected outputs. Check negative space: unauthorized records did not change, unrelated sites remain available, failed-cell additions did not leak, and unsupported imported data did not enter totals.

### 3. Run the control matrix, not just the reference patch

| Variant | Expected outcome | What it establishes |
|---|---|---|
| Starting source + acceptance checks | Named behavioral failure, complete execution | The task is present and checks can distinguish unchanged code |
| Starting source + preservation checks | Pass, except explicit qualified exclusions | Regression controls are valid at baseline |
| Reference implementation + reference tests + acceptance + preservation | Pass all required stages | At least one known implementation is accepted under the actual grading pipeline |
| Plausible incomplete implementations | Named requirement failures | The suite distinguishes the important partial solutions from a complete repair |
| Reference plus a deliberate neighboring regression | Named preservation failure when warranted by risk | The chosen regression checks detect the shortcut they are meant to prevent |
| Reference plus integrity bypass | Rejected for incomplete/invalid execution | The runner cannot convert “did not test” into success |
| Alternative valid implementation, where narrowness is a concern | Pass | The oracle accepts at least one materially different valid design |
| Fresh repeat or changed test order for state-sensitive cases | Same functional verdicts | Additional stability/isolation evidence under those conditions |

A complete Cartesian product of every branch is unnecessary. Select fixtures that separate realistic hypotheses. For two unrelated obligations, a patch implementing only the first and a patch implementing only the second often provide more useful evidence than dozens of syntax-level mutants. Retain the full patch, expected missing behavior, actual failing test identity, phase, and explanatory assertion output for each control.

An alternative implementation is especially valuable when grading touches internal structs, helper names, list order, error strings, or cache representation. It is not necessary to invent a second design for every simple one-line correction. For a security fix, overbroad refusal is a particularly useful partial implementation to reject.

### 4. Keep submitted-test quality separate from hidden acceptance

This repository requires model-authored regression evidence in addition to implementation correctness; that is explicit in the [evaluation contract](../evaluation.md). Report the dimensions separately even when the final pass requires all of them: acceptance behavior, preservation, and submitted-test evidence. A functionally correct patch without a qualifying regression test is a failure of this benchmark's complete task, not evidence that the functional repair itself is wrong.

SWT-Bench defines a successful generated regression test through failing-before/passing-after behavior, with no tests failing after the fix, and reports change coverage as an additional measure. This provides a useful precedent for separating patch applicability, issue reproduction, and coverage rather than conflating them. [SWT-Bench, §3.3](https://arxiv.org/html/2406.12952v3)

For our bug cases, the submitted test must fail because it exposes the described behavior. A missing new helper that prevents compilation is not equivalent evidence. Reject source-text assertions, checks of reference-specific implementation choices, or an unconditional failure on the starting revision. For refactors, preservation tests can legitimately pass both before and after; the separate objective refactor check provides discrimination.

### 5. Diagnose environmental failure separately

Retain phase distinctions: source reconstruction, dependency/build preparation, service startup, patch application, test discovery/setup, test body, teardown, and result parsing. A reference failure is not automatically a bad upstream fix; it may be a broken adaptation. An unchanged-source setup failure is not proof of the intended bug. A missing required test is not a pass.

ExUnit's documentation says asynchronous cases should not change global state; tests within an ordinary module are sequential. Ecto's SQL sandbox documentation distinguishes ownership, explicit process allowances, and shared mode, and warns that shared mode prevents concurrent database tests. Those mechanics explain why application configuration, named ETS tables, processes, and database ownership need deliberate isolation. Use the APIs available in each case's pinned historical versions, not whichever features appear in current documentation. [ExUnit.Case](https://ex-unit.hexdocs.pm/ExUnit.Case.html), [Ecto SQL Sandbox](https://ecto-sql.hexdocs.pm/Ecto.Adapters.SQL.Sandbox.html)

Our recommendation is to freeze clocks where dates matter, seed random inputs, use unique resources, restore application configuration, and synchronize on actual messages/state. Use bounded watchdogs to detect hangs; do not infer latency or throughput from any execution duration. Repeating a flaky assertion until it passes does not qualify the fixture. Investigate the source of variation and keep the failing evidence.

## Audit obligations for the twelve existing tickets

The rows below derive from the [current inventory](../../verification/task-quality/original/config/benchmark.json) and its solver-visible tickets. They identify the decisive boundaries and useful partial repairs for the case audit. They do not replace reading the source, running controls, or recording actual results. Exact numbers or examples can vary when the ticket permits them; the semantic distinction must remain.

| Case | Decisive behavior to verify | Useful incomplete or overbroad control | Fairness/preservation trap |
|---|---|---|---|
| [Plausible 5939](../../verification/task-quality/original/cases/plausible-pr-5939/ticket.md) | Guest Editor and team Editor can change current/previous domain through the real route; Owner/Admin retain access; Viewer/outsider cannot mutate | Permit only one Editor membership path; grant every role access | Success status alone does not prove persistence; checking only authorized users misses privilege expansion |
| [Plausible 5956](../../verification/task-quality/original/cases/plausible-pr-5956/ticket.md) | CE configuration creation and repeated updates serve the correct current script; a second site's script remains correct | Repair initial creation but leave repeated updates stale/duplicated; globally clear or mix site state | Assert script semantics and site isolation, not a particular ETS table type or response time |
| [Plausible 6300](../../verification/task-quality/original/cases/plausible-pr-6300/ticket.md) | Both Today and Last 24h honor year-over-year weekday matching; opt-out, time range, site timezone, and previous-period semantics hold | Fix only Today; always shift regardless of option; compute in UTC instead of site time | Use independent expected dates and at least a boundary that distinguishes the timezone choice |
| [Plausible 6441](../../verification/task-quality/original/cases/plausible-pr-6441/ticket.md) | Restricted event/page goals exclude unsupported imports in filters and mixed breakdowns; ordinary goals retain imports; supported special-event filtering remains valid | Disable all imports; fix filters only; fix only event goals; accidentally include restricted aggregate rows | HTTP 200 is insufficient; assert totals and import metadata with both eligible and ineligible rows |
| [Plausible 6449](../../verification/task-quality/original/cases/plausible-pr-6449/ticket.md) | Slug is immutable on edit; same-site segments attach; foreign/missing/invalid selections yield no segment; empty clears; the stated formerly site-wide segment remains usable | Fix slug only; trust any segment ID; reject all segments; reject now-personal same-site segment | Create and edit are distinct paths; invalid selection must satisfy the specified save semantics, not merely reject the request |
| [Plausible 6763](../../verification/task-quality/original/cases/plausible-pr-6763/ticket.md) | Page-filtered export without legacy cutoff returns parseable CSV, full schema, correct per-day counts, and empty unavailable time-on-page | Avoid crash by omitting the metric/column, forcing zero, or dropping filtered rows | Header/status assertions alone accept data loss; preserve configured-cutoff and ordinary export modes |
| [Livebook 2219](../../verification/task-quality/original/cases/livebook-pr-2219/ticket.md) | Frame update immediately produces rendered input label and default via notebook session output | Update backing state without the rendered assigns; show label but lose default | Do not trigger an unrelated rerender in the test and thereby hide the original defect |
| [Livebook 2527](../../verification/task-quality/original/cases/livebook-pr-2527/ticket.md) | Added executable content before the final stamp invalidates verification and secret authorization; unchanged valid content still verifies | Reject every stamp; keep authorization after failed verification; verify only an earlier prefix | Checking an error message alone misses retained authorization; test the actual signed bytes and imported privileges |
| [Livebook 2663](../../verification/task-quality/original/cases/livebook-pr-2663/ticket.md) | Nested bullets and fenced code retain structure across digit-width boundaries; single-digit/unordered behavior and repeated round trips stay valid | Hard-code two-digit width; preserve bullets but not fences; repair one pass but corrupt the next | Prefer semantic nesting plus stability; do not reject reasonable formatting solely for gold-specific whitespace |
| [Livebook 2800](../../verification/task-quality/original/cases/livebook-pr-2800/ticket.md) | Parser and scanner errors yield readable source/location diagnostics through evaluation; runtime exceptions still work | Handle one error tuple shape; swallow all errors into a generic message; remove line information | Diagnose meaning and location; exact incidental wording may differ across legitimate formatter implementations |
| [Livebook 2822](../../verification/task-quality/original/cases/livebook-pr-2822/ticket.md) | Earlier successful imports/macros/dictionary survive failed evaluation; failed changes, bindings, aliases, requires, and modules do not leak; combined contexts hold | Restore imports only; retain failed-cell mutations; restore state only in the simple single-parent path | Positive preservation and negative rollback are both necessary; use later evaluations to observe state |
| [Livebook 3076](../../verification/task-quality/original/cases/livebook-pr-3076/ticket.md) | Submit exactly the visible S3 form fields with a local successful connection; storage persists and appears; editing and invalid input behave correctly | Make the low-level constructor pass while leaving form construction broken; return success without saving | A helper-only test or manually injected hidden field bypasses the defect |

Where the audit discovers a new edge case not reasonably included in the ticket or established behavior, first decide whether it is truly part of this task. Do not quietly expand hidden requirements. Either document a justified clarification before the release or leave the extra case as non-scoring diagnostic evidence.

## Leakage, contamination, and answer access

Keep three concerns separate:

1. **Training exposure:** the model may already have seen public issues, code, fixes, or this benchmark. The [public-cases ADR](../adr/0001-public-cases-and-solutions.md) accepts this limitation. Renaming a case or hiding a PR number does not erase training exposure.
2. **Execution-time leakage:** the current workspace may accidentally contain reference patches, future commits, Git objects, stashes, nested repositories, setup scripts, grading files, logs, or derived artifacts revealing the fix. Inspect the actual solver-visible filesystem, image contents, mounts, and network policy.
3. **Evaluation adaptation:** repeatedly changing prompts, cases, seeds, budgets, or grader tests after looking at target-model outcomes can optimize the benchmark around those outcomes. Preserve a development inventory and a frozen comparison release; document corrections and do not silently carry old scores onto new graders.

These are recommended controls for different threat models. Public transparency is compatible with withholding grader artifacts during an attempt, but it is incompatible with claiming this is a secret holdout. Newer historical PRs can reduce some exposure opportunities; without trustworthy training-data information they cannot establish absence of exposure. A private future set would be a separate project and policy choice, not a relabeling of these twelve cases.

Keep all starting workspaces and grading workspaces independent. Replaying a submission diff on pristine prepared state helps distinguish a submitted code repair from an accidental interactive environment modification. Preserve exact setup exceptions where historical dependencies need adaptation. Do not let a preparation patch itself solve the target bug.

## Portfolio quality and what twelve cases can support

The inventory contains six Plausible and six Livebook repair cases. Its tickets cover useful permissions, query/data handling, cache lifecycle, rendering, formatting, signed imports, evaluator diagnostics/state, and forms. That is a useful functional pilot with application-level variety. It does **not** yet sample feature implementation, objective refactoring, general Elixir ecosystem work, or software engineering in general. This follows from the local inventory and tickets, not from an external estimate.

For expansion, record project, subsystem, task kind, languages, public boundary, reasoning shape, service needs, patch scope, age, and related-task family. Review the candidate pool and exclusions, not only the admitted rows. Sample from qualified candidates according to a declared portfolio rather than taking whichever tests are easiest to extract. Keep related PR families together when forming development/held-out partitions. A large count from two projects still measures those projects more directly than the wider ecosystem.

With twelve equally weighted cases, one case changes the score by **8.33 percentage points**; within a six-case project, one changes it by **16.67 points**. These are arithmetic consequences of the denominator. Prefer `8/12` with case outcomes over an apparently precise `66.67%` ranking.

NIST describes Wilson and exact binomial intervals and cautions against simple normal approximations for small samples. As an illustration, the Wilson 95% interval for 6 successes in 12 independent identically distributed Bernoulli trials is about 25%–75%. Our hand-picked, correlated application tasks do not justify treating that interval as a confidence interval for “all Elixir work.” [NIST confidence-interval guidance](https://www.itl.nist.gov/div898/handbook/prc/section2/prc241.htm)

Recommended reporting separates a descriptive score on the fixed set from uncertainty about repeat model attempts and uncertainty about task selection. Use paired per-case outcomes when comparing configurations on the same release. Record all attempts and declared seeds; do not replace failures with successful retries. More seeds help characterize repeatability on these cases, while more independently selected task families address portfolio coverage. Neither operation alone fixes a flawed oracle.

The official SWE-bench submissions retain predictions, execution logs, trajectories, and results as inspectable artifacts. That is a useful reproducibility standard independent of any leaderboard score. [Official submission repository](https://github.com/SWE-bench/experiments)

## Recommended decision record

Give each case an explicit verdict: **admit**, **admit after the recorded corrections**, **defer pending named evidence**, or **reject for a stated reason**. Record separately the task's value, specification quality, oracle coverage/fairness, runtime qualification, and unresolved limitations. A useful authentic task can still be deferred because its environment has not completed qualification.

The minimum reviewable packet is the exact ticket and source identities, requirement/check ledger, reference and upstream partitions, custom controls, actual phase-aware results, relevant preservation results, isolation/stability checks, independent review notes, and the frozen artifact hashes. Keep unsupported claims out of the verdict. The strongest honest conclusion available from finite tests is that the case meets this documented admission standard under its pinned environment—not that every possible correct or incorrect program has been proven classifiable.
