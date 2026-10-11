# Large-codebase expansion: Plausible investigation

Started 2026-10-11. Current direction: actual historical Plausible repairs, with each broken branch pinned to the real pre-fix revision. The user explicitly replaced invented bugs with solved upstream problems after rounds 3–5. The [PR investigation](plausible-pr-candidates.md) and [historical-repair decision](adr/0002-historical-upstream-repairs.md) govern case selection. This supplements the [existing expansion plan](expansion-plan.md), preserving its feature, OTP, multi-repository and evolving-session work.

Source inspection establishes the candidate commit pairs and test evidence; none of these historical cases has passed runtime qualification. The user created the public fork. Local synthetic drafts and an unqualified shared-release runtime draft were archived after the change of direction; the obsolete remote image preparation was stopped. No application tests, model attempts or performance measurements were run during this expansion investigation. The existing runner is unchanged.

The six [historical candidate packages](../candidates/README.md) now contain draft tickets, exact upstream repair/test patches, toolchain declarations and qualification notes. Their six broken branches have been published to the user's fork and checked against the recorded SHAs. The source verifier reconstructed the exact accepted upstream tree for every candidate; this does not establish behavioral red/green results.

## What the project already does

The four pilot cases already seed regressions into complete pinned repositories: NimbleOptions, GenStage and LiveBeats. A case consists of a ticket, source/runtime manifest, starter patch, reference repair and hidden acceptance tests. The expansion changes application depth, scenario realism and evaluation coverage; it does not require inventing a new mutation mechanism.

The runner downloads a whole source archive, applies environment and starter patches, then creates a fresh single-commit Git repository for the agent. The attempt is offline and receives terminal tools, dependency/project sources and deterministic clarification answers. Reference repairs and hidden tests remain outside its workspace. [Source preparation](../scripts/benchmark.py#L110), [attempt contract](pilot-protocol.md#attempt-contract).

The final patch is replayed into a fresh sandbox. The evaluator runs submitted regression checks, restores original tracked tests, introduces hidden checks, and runs the protected regressions. It judges behavior, not similarity to the reference patch. Existing controls accept the reference repair and reject the broken start and an early-exit bypass. [Grading](../scripts/benchmark.py#L230), [controls](../scripts/benchmark.py#L328).

The pilot is still a harness qualification exercise: four scenarios in three repositories, with serving/context differences and incomplete attempts. The [reviewed results](pilot-results.md) do not establish a model ranking. Merely adding many Plausible branches would add cases without adding the same amount of independent repository evidence.

## Authoring branches and agent workspaces

Each case branch points directly to its historical broken upstream commit. No injected source edit or shared healthy parent is needed. Source versions can differ between cases, and each version needs its own pinned environment; identical toolchain/dependency graphs may share prepared layers after qualification.

```text
original pre-fix revision A → codex/bug-pr-6300-weekday-comparison
original pre-fix revision B → codex/bug-pr-5939-editor-domain-change
original pre-fix revision C → codex/bug-pr-6763-filtered-csv-export
```

The full upstream repair, its production changes, its test changes and ancillary changes remain distinguishable. Verify the merged commit's ancestry; the PR API's base SHA is not necessarily the actual mainline pre-fix revision. Use immutable commit and artifact hashes as case identity. Branch names are convenient public views.

An agent must not receive that authoring graph under the existing attempt contract. A reachable healthy parent reveals the repair through a diff or revert. Export only the bugged state into the fresh attempt repository, preserving the current history isolation. Audit all reachable Git objects, refs, remotes, case files and generated artifacts when building an exporter; deleting a branch name alone does not remove its objects.

The current no-network policy also closes direct upstream lookup during an attempt. It cannot prove that a candidate has never seen public Plausible source before. The user chose immediate publication of every authored case and solution in Q14, accepting that reference changes are openly available outside the sandbox. Q19 extends publication to the checks, evaluator and environment recipe. Report the suite as public and potentially previously exposed; do not claim a private, uncontaminated confirmation set. Grader-only describes what is accessible during an attempt, not whether the test source is public. See [the publication decision](adr/0001-public-cases-and-solutions.md).

## Plausible source findings

The inspected upstream `master` revision is `bc2c7b395caddf7bb4eec2548be7958824d07d4a`, dated 2026-10-09. It is an inspection pin, not a baseline selection. It contains Elixir/Phoenix application code, LiveView workflows, PostgreSQL data, ClickHouse analytics, a React dashboard and a JavaScript tracker. [Repository at the inspected revision](https://github.com/plausible/analytics/tree/bc2c7b395caddf7bb4eec2548be7958824d07d4a).

Edition matters. `test` compiles `extra/lib`; `ce_test` compiles the community application and test support and excludes enterprise-only tests. The upstream browser environment also compiles enterprise modules, so it is not automatically a Community Edition browser recipe. The `extra/` and dashboard `extra/` directories carry separate rights notices. The selected first scope is Community Edition; artifact contents and notices need an explicit review when packaging it. [Mix environments](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/mix.exs), [test selection](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/test/test_helper.exs), [backend notice](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/extra/COPYING.txt), [dashboard notice](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/assets/js/dashboard/extra/COPYING.txt).

At that revision, CI runs both PostgreSQL and ClickHouse, builds tracker assets before backend tests, prepares database schemas and updates timezone data. The default test helper excludes `slow`, `minio` and `migrations`, while CI explicitly includes additional groups. The toolchain, services, generated assets, data fixtures and selected test groups must therefore be frozen together; `mix test` alone is not a complete qualification recipe. These are requirements inferred from source, not evidence of a successful local setup. [CI workflow](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.github/workflows/elixir.yml), [toolchain](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.tool-versions).

Q20 originally selected released CE `v3.2.1` for qualification first, pinned to `e4f5a87a5570bd61605217e7ceb376636db8eddb`. All six originally proposed broad areas and LiveView tests exist there. This shared-baseline selection is superseded by using each actual PR's historical broken revision; the comparison below is retained as source-investigation history, not an active runtime selection.

| Baseline candidate | Source facts | Planning consequence |
| --- | --- | --- |
| Released `v3.2.1` | Pins Erlang 27.3.4.6, Elixir 1.19.4-otp-27 and Node 23.2.0; its lockfile includes a Plausible LiveView fork | Preserve the release dependency graph. A release name does not establish correctness in our frozen environment. |
| Inspected `master` | Pins Erlang 28.5.0.5, Elixir 1.20.4-otp-28 and Node 24.17.0; contains newer date-query and attribution code | Appropriate if those newer behaviors are part of the intended work; do not transplant them into release acceptance requirements. |

[Release toolchain](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/.tool-versions), [release dependency lock](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/mix.lock), [recent toolchain](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.tool-versions).

The release builds date windows in [QueryBuilder](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/stats/query_builder.ex), rather than the newer QueryPeriod module. Its [attribution source](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/ingestion/source.ex) supports UTM/referrer cases but lacks newer shared import normalization and domain-suffix behavior. The broad families remain viable; the exact examples must follow the selected version.

The release has [segment filters](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/segments/filters.ex), [invitation acceptance](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/teams/invitations/accept.ex), [session state](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/session/cache_store.ex) and [CSV importing](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/lib/plausible/imported/csv_importer.ex), plus real [LiveView tests](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/test/plausible_web/live/shared_link_settings_test.exs). No chosen area requires newer source merely to exist.

Do not execute an upstream workflow blindly as a baseline recipe. At the release pin, CI and production Makefile targets specify different database versions, default Makefile targets float, and the CI file mentions browser assets/configuration absent from that release tree. Its test environment also uses manual Oban testing and mocked external clients. Choose a consistent CE recipe, prepare required assets offline, and explicitly exercise worker behavior where relevant. [Release CI](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/.github/workflows/elixir.yml), [Makefile](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/Makefile), [test configuration](https://github.com/plausible/analytics/blob/e4f5a87a5570bd61605217e7ceb376636db8eddb/config/test.exs).

## Selected historical candidates

The source-verified draft shortlist is #6300 (weekday comparison), #5939 (editor domain-change permission), #6763 (filtered CSV export), #6449 (shared-link editing), #6441 (imported analytics with goal properties), and #5956 (CE tracker cache). See the [findings](plausible-pr-candidates.md) for exact commit pairs, source links, test scope, alternatives and caveats.

These replace the earlier hypotheses about six deliberately introduced regressions. The user wants real work, so the original category and visible-failure quotas must not force fictional mutations or artificial test failures. Record actual detectability after qualification. Several PRs add coverage for previously untested paths; source evidence alone cannot establish that every existing test passes on their parent.

Use the original issue or PR's problem report as the ticket source. Remove diagnosis and solution instructions, reconcile outdated prose with the final accepted behavior, and state every requirement that the evaluator will enforce. Added upstream tests are useful evidence, not an automatic complete oracle: some call APIs introduced by the fix, so copying them onto the parent can fail for the wrong reason.

Repository size, diagnosis difficulty and repair breadth are different properties. A small correct patch can require substantial investigation; a large repetitive patch can require little. Describe case difficulty using the relevant behaviors, module boundaries, state transitions and edge cases. Do not infer difficulty from changed-line count, source-file count or local execution time.

## Harness changes to plan

| Verified current limit | Implication for expansion |
| --- | --- |
| Preparation records arbitrary service images, but sandbox startup only handles `postgres` ([source](../scripts/benchmark.py#L174)) | Add explicit isolated service lifecycle, readiness and cleanup for ClickHouse alongside PostgreSQL. A manifest entry alone cannot start it. |
| Controls run broken, reference and early-exit states ([source](../scripts/benchmark.py#L328)) | Qualify the exact historical broken and repaired states with an explicit protected regression scope before admission. |
| Regression commands can name only existing files ([web example](../cases/web-playlist-isolation/case.json)) | Define how all relevant agent-added or modified tests are discovered and executed. A ticket demanding regression coverage currently does not guarantee that coverage is assessed. |
| Grading assumes `mix test`, one hidden file and original tests under `test/` ([source](../scripts/benchmark.py#L283)) | Define edition/tag selection and protected-test identity policy. Do not blindly treat expected CE exclusions as failed tests or weaken required-test checks. Frontend grading would need its own adapter. |
| Source retrieval is unauthenticated public GitHub codeload ([source](../scripts/benchmark.py#L118)) | Public upstream plus local patches works today. A direct private authoring-repository source would need an export/authentication path; creating authoring branches does not require changing the runtime representation. |
| All agent history is retained; pilot defaults are 32 calls and 65,536 completion tokens ([source](../scripts/benchmark.py#L358)) | Freeze a common, visible budget and context policy appropriate to the chosen task scope. Do not copy pilot limits into a larger campaign without qualification. |
| Partial-repair probes are hardcoded for current cases ([source](../scripts/check_partial_repairs.py)) | Give new cases declared plausible wrong repairs and admission checks, instead of assuming inverse patches are sufficient verification. |

## Proposed admission contract

Subject to the interview, require each authored case to establish all of the following before scored use:

1. The frozen historical environment starts successfully, and the upstream repaired state passes the declared acceptance and protected regression scope. Name that scope; a selected suite does not prove all application behavior.
2. The original pre-fix state reproduces the ticket's intended failure under the same acceptance contract. Its protected checks pass except for explicitly classified visible failures. Reject missing APIs, fixture startup errors, unrelated broken tests and nondeterministic observations as substitutes.
3. The reference repair satisfies the acceptance contract and protects neighboring behavior. Accept other valid implementations through behavioral checks.
4. Plausible incomplete repairs fail: fixing only display, dropping invalid data silently, ignoring authorization, handling only one boundary or weakening tests must not satisfy a broader ticket.
5. The ticket, accessible project material and scripted clarifications contain all required behavior. Hidden tests may explore undisclosed examples of that contract, not invent requirements.
6. The attempt image contains no reference solution, repair diff, upstream history or grading material. Each independent attempt and grade receives isolated state.
7. Relevant submitted tests execute. For previously uncovered behavior, required new coverage must reproduce the intended assertion failure on the broken state and pass with the repair. A compilation or fixture-startup error is not evidence of detecting the defect; mere file presence is insufficient. Existing adequate coverage need not be duplicated.
8. Record repository/PR and defect-family lineage, visible-test detectability, edition, broken/fixed revisions and suite version. Related branches remain correlated evidence.
9. Exercise at least one real application path per case, with real database behavior where relevant. Isolated helper tests may support this check but cannot replace it.
10. Establish that each repair is achievable within the declared attempt context policy and budgets, including investigation and verification. A short reference patch alone does not establish this. Require an observed successful unscored attempt from the agent-facing ticket and workspace, without access to the mutation or reference repair, and record context use with headroom before admitting the case. This is feasibility evidence, not a guarantee that every candidate or attempt will succeed.

One coherent regression may affect multiple files and workflows. Artificially stacking unrelated mistakes in one branch changes what the task measures and makes partial outcomes harder to interpret. Whether an existing test already catches a defect is useful case metadata, not an automatic reason to reject it. Never remove valid upstream assertions simply to manufacture discovery difficulty.

Concurrency correctness can use controlled event order and watchdogs for hangs. No speed qualification or performance claim is part of this proposal. The shared-workstation prohibition remains in force; prior project authorization for correctness campaigns on the separate rig does not authorize new performance work.

## Round 3 — accepted decisions

The previous interview settled Q1–Q8. The user answered all six new expansion questions below.

| ID | Choice | Accepted answer |
| --- | --- | --- |
| Q9 | What should a large application make difficult: diagnosis, substantial cross-component repair, or both? | Both, with diagnosis central; allow small repairs whose cause requires real navigation. |
| Q10 | Must a seeded regression survive all existing tests? | Include both existing-test failures and coverage gaps, label them, emphasize gaps and preserve upstream assertions. |
| Q11 | Elixir application work or immediate JavaScript/browser work too? | Elixir, APIs, LiveView and database behavior first; consider a separate full-stack track later. |
| Q12 | Which Plausible edition anchors the first cases? | Community Edition; choose and qualify an exact revision after scope is settled. |
| Q13 | One varied Plausible batch first or several large repositories together? | Plausible first, then another large application before broad quality conclusions. |
| Q14 | When are authored defects and solutions published? | Publish every case and solution immediately. This replaces the recommendation for private authoring and staged publication. |

The publication trade-off is captured in an ADR because public disclosure cannot reliably be reversed and affects what future scores can claim. The glossary distinguishes historical repairs from seeded regressions and authoring repositories from attempt workspaces.

## Round 4 — accepted decisions

| ID | Choice | Accepted answer |
| --- | --- | --- |
| Q15 | First Plausible authoring target | Six cases, one in each proposed area; replace candidates that fail realism or correctness qualification. |
| Q16 | Agent-facing ticket evidence | Symptoms, concrete example/reproduction and expected behavior; natural reporter logs where appropriate, without authored location or diagnosis hints. |
| Q17 | Defect unit per branch | One coherent regression, potentially with consequences and repairs across several components. |
| Q18 | Regression coverage in the success contract | Require useful coverage of previously uncovered behavior; do not demand redundant tests when existing coverage already suffices. |
| Q19 | Publication beyond cases and solutions | Publish acceptance checks, evaluator and environment recipe too; keep grading material out of the attempt workspace. |
| Q20 | Exact baseline candidate to qualify first | Released `v3.2.1` at `e4f5a87a5570bd61605217e7ceb376636db8eddb`; recent source if newer behavior is preferred. |

These were the accepted choices at this point in the interview. The subsequent explicit preference for historical PRs supersedes the single-release baseline and invented-defect category quotas. The ticket, publication and behavioral verification requirements remain.

## Round 5 — decisions and correction

| ID | Choice | User's answer |
| --- | --- | --- |
| Q21 | Difficulty and visible-test distribution | Agreed to two localized/navigation cases, two cross-component cases and two state/compatibility cases, targeting four coverage gaps and two visible-test failures. Added the requirement that repairs be feasible within maximum context and asked whether compaction is used. |
| Q22 | Required application depth in verification | Agreed to at least one appropriate real application path per case, including real databases where relevant. |
| Q23 | Code-quality reporting | Challenged the proposed review layer: the purpose is deterministic comparison; vague code quality is not comparable at scale. Clarified direction: executable correctness and integrity checks, no AI judge or subjective code-quality verdict. |

## Deterministic assessment

The proposed subjective patch-review layer is withdrawn. The runner already bases its verdict on executable checks, not an AI assessment. The expanded suite should retain that property while strengthening the declared checks:

- The application compiles and the ticket's behavioral acceptance tests pass through the relevant real application paths.
- Protected regression checks pass with their required test identities intact.
- Required regression coverage detects the intended defect on the broken state and passes after the repair; all relevant submitted tests execute.
- Published integrity rules hold: permitted edits, protected evaluator inputs, completed suites and no early-exit bypass.

Any added static rule must be explicit, executable, frozen before the campaign and satisfied by the qualified baseline. Line count, resemblance to the reference patch, subjective idiom/style preferences and an AI's opinion are not success criteria. People or AI can help construct and inspect fixtures; they do not assign per-attempt quality scores.

Passing these checks establishes conformance to the tested contract, not universal correctness or maintainability. If inspection reveals a missed failure, turn it into a reproducible test and a versioned evaluator correction, applying it consistently to all eligible saved patches and preserving original results. Do not selectively overturn a pass because a reviewer dislikes the code.

## Context feasibility and compaction — Q24 remains open

The repository stays on disk; the initial model input contains the task and system instructions, not the entire application. Source reads and tool results then accumulate in the active history. A large codebase therefore need not fit wholesale into the model window, but the investigation, edits and verification must fit the declared policy. [Initial input](../scripts/benchmark.py#L370).

There are two different limits: the context available to one request, including space for its response, and the cumulative generation allowance across the entire attempt. The current runner's default 65,536 is the latter. It sums server-reported completion tokens and caps an individual response at 8,192; reasoning-token accounting still needs qualification. It neither counts the assembled prompt against a context cap nor reserves response space. [Generation accounting](../scripts/benchmark.py#L377).

Current behavior is no compaction: every assistant message and tool result is appended, and the whole history is resent. Tool output truncation is a per-command byte limit, not context accounting. Endpoint context metadata is recorded but does not control the next request. A context rejection becomes an error; the patch is preserved where possible, but the ordinary final grading path is skipped. Normal action/generation-budget exhaustion instead grades the saved patch. Expansion must specify this distinction explicitly rather than letting endpoint errors define the policy. [History accumulation](../scripts/benchmark.py#L393), [patch preservation](../scripts/benchmark.py#L196), [termination and grading](../scripts/benchmark.py#L427).

**Recommendation for Q24:** use no compaction for the first six-case comparison, with one declared common context cap supported by every included candidate, proper prompt accounting, reserved response space, visible budget information and a separate total generation budget. Author and qualify the six tasks within this envelope. Record context exhaustion explicitly, retain the patch and define its grading/status treatment before scored runs. Do not silently truncate history, extend the budget or retry a failing candidate with extra help.

An alternative is a common compaction policy from the start. It can support longer investigations, but it introduces further decisions: trigger, retained information, summary method/model, summary size, total work accounting and how summaries are recorded. If chosen, use the same rules for every candidate and charge any model-generated summaries against the declared attempt budget; an uncounted stronger model must not assist only some candidates. Files and edits persist while conversation history is reduced. A later compaction-enabled track remains compatible with the accepted evolving-session plan.

Exact context size and total budgets are not selected yet. They depend on the candidate/serving configurations and unscored feasibility evidence. No inference, token-cap qualification or benchmark execution has been performed in this planning session.

## Implementation sequence

1. **Identify actual solved problems.** Inspect original reports, final merged diffs, commit ancestry, edition boundaries and regression tests. Select six varied CE repairs. Preserve full PR provenance and explain rejected or mixed-scope candidates.
2. **Publish reviewable source drafts.** Put each broken branch at the exact upstream pre-fix SHA in the user's fork. Store symptom-focused tickets, source manifests, upstream production/test/ancillary patches and artifact hashes in this repository, outside active `cases/`. No new defect is authored. Source-only drafts must not be auto-discovered by the campaign runner.
3. **Qualify the historical environments.** Pin each source toolchain, lockfiles, generated assets, PostgreSQL/ClickHouse images and test data. Reuse matching runtime layers only after validating compatibility. Add isolated service support and explicit CE test-selection handling to the runner when integrating these cases.
4. **Make upstream evidence into deterministic acceptance.** Preserve suitable upstream regression coverage; adapt checks to stable application interfaces when the repair introduces or renames helpers. Prove an intended assertion failure on the original state and a pass after the reference repair. Add neighboring and plausible incomplete-repair checks where the existing tests leave a material gap. Do not use patch similarity or an AI judge.
5. **Admit validated fixtures.** Execute relevant submitted regression tests, protect original assertions, reject early-exit bypasses and isolate state between grades. Audit answer leakage and establish feasibility under the declared context policy. Only then promote a draft into `cases/` with versioned qualification evidence.
6. **Prepare a subsequent comparison campaign.** Freeze common context/action/generation limits, suite and scaffold version before scored attempts on the authorized rig. Broader conclusions also require the second application and accepted breadth/session work.

A merged PR supplies real work and a reference repair; our remaining work is reproducible packaging and verification. The first milestone remains six qualified application-repair fixtures. The current source drafts do not yet establish that milestone, a model ranking, browser coverage or performance qualification.

## Decisions unlocked by this round

- Q9/Q10 → ticket detail, reproductions/logs, symptom versus implementation hints, difficulty distribution, coherent-regression boundaries and reference/partial-repair review.
- Q11/Q12 → baseline revision, CE packaging, source/test areas, assets, service images, fixtures and precise correctness qualification.
- Q9/Q11/Q13 → first selected cases and count, acceptance surface, remaining breadth targets and the route to feature/session work.
- Q13/Q14 → public development/confirmation methodology, authoring storage, exact published artifacts, attribution and upkeep. There will be no private case/solution holdout under the accepted publication policy.
- Selected cases and acceptance surface → explicit edit permissions, regression-test assessment, context/budget policy and infrastructure/error classification.
- Q21's context requirement → Q24 compaction choice → common context cap and response reserve → workload feasibility qualification and explicit exhaustion handling.
- Frozen suite and scaffold → campaign candidates, repetitions, reporting by family/repository, versioning and later client transfer.

The user has authorized case work and provided the fork. Continue implementation using the historical-PR direction without reopening settled permissions. Context/campaign parameters remain explicit later qualification decisions, not reasons to pause source curation.
