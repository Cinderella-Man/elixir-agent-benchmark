# Design tree and requirements interview

Started 2026-10-11. The user explicitly stopped the general benchmark proposal and requested a separate planning project based on their Elixir task repository. This document records settled intent, open decisions and dependencies; recommendations are not accepted decisions.

## Settled intent

- Compare the strongest practical models by coding and tool-use quality.
- Focus on realistic agent work, involving multiple actions and tests rather than isolated answer generation.
- Investigate [the supplied Elixir tasks](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/main/tasks) as source material.
- Keep this project in its own self-contained directory.
- After rounds 1 and 2, the user explicitly authorized a working end-to-end pilot and expansion through practical use. Implementation choices may proceed without another interview round.
- Preserve the existing rig power controls. Never benchmark on the shared workstation.
- Do not carry over a general-purpose task split, task count, agent choice or scoring rule as an implicit decision for this project.

## Round 1 — accepted decisions

| ID | Decision | Accepted answer | Why it matters |
| --- | --- | --- | --- |
| Q1 | What work dominates? | Changes to existing applications, with some new features | Determines initial repository states, task horizons and whether investigation is necessary |
| Q2 | Which Elixir domains represent actual use? | A balanced mix of OTP/backend and Phoenix/Ecto application work | Determines scenario families, dependencies and acceptance checks |
| Q3 | Compare models under one agent, or complete model-agent systems? | One pinned scaffold for all models, then actual-client validation | Determines what a score can legitimately attribute to the model |
| Q4 | Reuse public tasks unchanged, adapt them, or create fresh cases? | Adapt task families into new scenarios with independently written hidden checks | Determines contamination risk, authoring work and family-aware dataset splits |

The source audit runs independently of these choices. Source facts are research work, not questions for the user.

## Round 2 — accepted decisions

| ID | Decision | Accepted answer | Consequence |
| --- | --- | --- | --- |
| Q5 | Source of starting applications | Pinned real open-source applications with curated scenarios | Improves realism; requires compatibility, licensing, history and reference-state review |
| Q6 | Ticket/session structure | Independent tickets plus a separate three-ticket evolving-session track | Separates fresh-task ability from remembering and preserving earlier work |
| Q7 | Development tools and external access | Terminal/files/tests plus pinned local dependency documentation, no external web | Preserves investigation freedom while avoiding changing web content and solution lookup |
| Q8 | Clarification behavior | Scripted answers for intentional ambiguities, otherwise autonomous | Makes useful clarification testable without different human assistance across models |

## Source observations affecting the design

Read-only review pins the source at `328195bb34782b61fdad8df8188dffa86bc5defe`. A non-truncated tree contains 14,895 prompt/solution units plus five loose files; the source describes 83 underlying task families. Directory count is not independent scenario count. Its README reports approximately 92% of completions appear verbatim in sibling prompts and recommends splitting by the leading family number. Its exported-training-example count is a different quantity from raw units. [Pinned source README](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb34782b61fdad8df8188dffa86bc5defe/README.md)

This favors family-aware provenance and new evaluation scenarios, consistent with Q4. It does not establish that any particular candidate was trained on the source. Independent hidden checks must also validate concurrency and lifecycle behavior, not merely duplicate visible unit tests. The detailed audit records what was inspected and which claims are publisher-reported.

## Design branches and their dependencies

1. **Representative work** — Q1/Q2 → work categories → realistic project fixtures → task lengths → single-ticket versus evolving multi-ticket sessions.
2. **Reuse and independence** — source audit/Q4 → source lineage → train/evaluation overlap → family separation → public development versus reserved evaluation scenarios.
3. **Agent behavior** — Q3 → actual tool interface → permitted commands and documentation → feedback and clarification policy → recovery behavior → repeatable attempt boundaries.
4. **Acceptance** — work categories → executable outcomes → regression protection → concurrency/OTP behavior → deterministic integrity checks → aggregation and failure classification. Q23 excludes subjective patch-quality review from benchmark results.
5. **Fair comparison** — scaffold/acceptance → reasoning and action budgets → model-specific templates → repeat count → uncertainty → rules for ties and improvements.
6. **Context** — realistic fixtures/task horizons → context length distribution → cross-file dependencies → long history and contradictory evidence → useful long-context assessment without artificial filler.
7. **Execution** — dependency audit/tool policy → isolated environments → pinned Elixir/OTP and dependencies → reference controls → flaky-test detection → resource and power checks.
8. **Release and upkeep** — source license/overlap policy → publication boundary → reproducibility artifacts → versioning → adding new scenarios without silently changing an existing ranking.

## Implementation authorization and first increment

After accepting Q5–Q8, the user clarified: “the wider we can go, the better, Phoenix, Liveview, OTP, normal Elixir code on some data, everything that we can test — let's get SOME end-to-end benchmark ready and then expand to more cases.” This explicitly authorizes the first runnable increment and routine design decisions; no further design-confirmation round is required before it.

The first increment uses four repair scenarios in pinned NimbleOptions, GenStage and LiveBeats sources. It proves the agent/terminal/patch/fresh-grader path across ordinary Elixir, OTP and Phoenix/LiveView/Ecto. These small controls are not a sufficiently broad or independent sample for a model leaderboard. Three-ticket sessions, larger feature tasks, useful long context and actual-client transfer remain expansion work, not silently abandoned requirements.

## Large-codebase expansion interview

On 2026-10-11 the user requested deeper project investigation and planning for realistically seeded bugs in large applications, proposing Plausible and independent branches from one working baseline. The [Plausible investigation](large-codebase-expansion.md) records verified source facts, candidate scenario families, harness gaps and the interview. This planning round preserves the accepted Q1–Q8 decisions and the broader expansion requirements.

Round 3 accepted Q9–Q14: diagnosis-led work with both local and cross-component repairs; a mix of existing-test failures and mostly coverage gaps; Elixir first with full-stack work later; Community Edition; Plausible first followed by another large application; and immediate public release of every case and solution. Q14 explicitly overrides the recommendation for private authoring and a reserved private set; see [ADR 0001](adr/0001-public-cases-and-solutions.md). Remaining task selection, baseline, verification and campaign decisions are still open.

Round 4 accepted Q15–Q20: six initial cases across report dates, attribution, filters, invitations, session state and CSV compatibility; concrete bug reports with the cause undisclosed; one coherent regression per branch; useful new coverage where existing tests are insufficient; public checks/evaluator/environment recipes; and qualification of CE release `v3.2.1` at `e4f5a87a5570bd61605217e7ceb376636db8eddb` first. Source inspection has not yet qualified that baseline or any new fixture. Round 5 addresses difficulty distribution, application-level verification and code-quality reporting.

Round 5: Q21 and Q22 are accepted, with an added requirement that repairs be feasible within the attempt's context policy. Q23 is corrected toward deterministic executable assessment: no AI judge and no vague, subjective code-quality verdict. Q24 remains open: no compaction with a common context cap for the first six cases (recommended), or a common explicit compaction policy. The current runner has neither compaction nor context-window enforcement; its generation allowance is a different limit. The [detailed plan](large-codebase-expansion.md#context-feasibility-and-compaction--q24-remains-open) records source evidence and the implications.

## Historical PRs replace invented defects

The user provided the public [Plausible fork](https://github.com/Cinderella-Man/plausible-analytics) and authorized separate broken branches, then explicitly changed the source of cases to actual problems that occurred and were solved in upstream PRs. This supersedes introducing new defects on one `v3.2.1` baseline. Preserve each historical broken revision and accepted repair; do not transplant or invent mistakes merely to preserve the original six categories. Independent branch names remain useful, but the branches can start at different upstream revisions.

The next increment is a source-verified six-PR shortlist and public draft broken branches, followed by historical environment qualification. Reuse authentic problem reports and upstream regression coverage where suitable. Keep the cause and solution out of the attempt ticket, verify final merged behavior when a PR description is stale, and prove acceptance tests fail for the intended behavior before the repair and pass afterward. Source inspection and a small diff do not establish runtime correctness or context feasibility. See the [PR findings](plausible-pr-candidates.md) and [decision](adr/0002-historical-upstream-repairs.md).
