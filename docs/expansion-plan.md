# Expand after the end-to-end pilot

The accepted scope includes Phoenix, LiveView, Ecto, OTP and ordinary Elixir/data work. The first four repair cases validate the pipeline. Expand breadth and realism before interpreting small score differences.

The [large-codebase expansion interview](large-codebase-expansion.md) selects Plausible Community Edition as the first large application, with Elixir-first, diagnosis-led repairs. The user subsequently chose actual solved upstream defects instead of invented bugs: select merged PRs, preserve each original broken revision, and reuse the real repair and suitable regression tests. The [historical PR investigation](plausible-pr-candidates.md) records the first shortlist. This replaces the single-release seeded-case design; earlier family and difficulty counts are breadth goals, not reasons to manufacture defects. A second large application follows. The user requires immediate publication of every case and solution; [ADR 0001](adr/0001-public-cases-and-solutions.md) records the resulting exposure limits.

## First breadth target

The six historical Plausible cases and six [Livebook cases](livebook-integration.md) join the original four in one 16-case benchmark, executed in full by default. [The comparison protocol](comparison-protocol.md) treats each model/quantization combination as a distinct candidate. Fixture qualification and model/context qualification are distinct. These repairs do not replace the feature, OTP or evolving-session targets below.

Keep the four pilot cases as development checks. The eight additions below would create a 12-scenario development set; these are authoring targets, not implemented or validated fixtures. Select and pin suitable real repositories before writing patches. At least two additions must use applications outside LiveBeats.

| Addition | Agent's realistic ticket | Observable acceptance contract |
| --- | --- | --- |
| Phoenix JSON API | Add a paginated filtered listing to an existing endpoint | Stable ordering, page boundaries, combined filters, empty results and ownership isolation through router requests |
| Ecto schema evolution | Add a per-account preference with migration and an existing-record default | Fresh and upgraded databases work; existing records remain valid; invalid changes preserve data; context and UI agree |
| LiveView reconnect | Preserve an in-progress edit when a background update or reconnect occurs | Unsaved values survive intended transitions, valid external updates appear, stale subscriptions are cleaned up |
| LiveView asynchronous search | Prevent an older search response replacing newer results | Controlled out-of-order responses, empty queries, service errors and cancellation preserve the current query's result |
| OTP supervision recovery | Recover a worker without dropping or duplicating accepted jobs | Explicit process termination, restart, in-flight ownership and eventual results verified using message barriers |
| OTP request coalescing | Share one outstanding fetch among concurrent callers | Same-key calls coalesce, different keys proceed independently, leader/caller failure releases waiters and state |
| Streaming data import | Add an import path for chunked records in an existing application | Unicode and record boundaries across chunks, malformed input diagnostics, duplicate handling and persisted outcomes |
| Elixir report calculation | Fix a grouped report over real application records | Empty groups, ordering, missing values, decimal arithmetic and date boundaries follow the ticket's explicit policy |

Concurrency checks should control event order with barriers or injected collaborators, not assume a machine completes work within a speed target. A useful fixture must reject plausible incomplete fixes as well as the original broken state.

## After breadth

Before a comparative campaign, review the agent-facing contract as well as the cases. The runner now states permitted edit paths, the project test command, initial action/completion allowances and the no-compaction policy. It does not yet expose a remaining-budget counter or enforce a common context window. Freeze the common contract before running a scored campaign. Qualify reasoning-token accounting, context handling, seed support and native tool parsing on each serving stack before claiming equal budgets.

The large-codebase interview adds two requirements: tasks must be achievable under the declared context policy, and results must come from deterministic executable checks rather than subjective code-quality review or an AI judge. The existing total generation allowance does not enforce a context window. Compaction versus a common cap without compaction remains open in Q24; qualify task feasibility before scored use.

1. **Establish a development set of about 12 independent scenarios.** Add a cross-file feature with an Ecto migration, a LiveView reconnect/state transition, a supervision recovery case, a streaming/parser boundary case, and an authorization change. Use several repositories; avoid filling the set with derivatives of one function. Review real user-facing tickets and executable contracts before writing the gold solution.
2. **Add the accepted three-ticket session track.** Keep workspace and agent history across an evolving feature, a changed requirement and an incident. Grade every checkpoint independently without giving hidden-test feedback between tickets. Report the sequence as a correlated family; preserve earlier failures rather than secretly resetting to the reference solution.
3. **Separate development from confirmation by lineage and use.** Select confirmation families that were not used to tune the scaffold or candidate settings, rather than treating sibling directories as independent evidence. All cases and solutions are public immediately under the accepted publication policy, so this is a methodological separation, not a secrecy or uncontaminated-training guarantee. New grader-only checks do not alone remove public-solution exposure. Record source provenance and known possible exposure; no model is assumed uncontaminated.
4. **Freeze an initial quality campaign.** Select the serious candidate artifacts, common agent version, task and reasoning budgets, sampling settings and repetitions before running the confirmation set. Include plain Qwen controls and the relevant current contenders; do not add small models merely for replica efficiency. Use multiple independent attempts, retain every outcome, and report uncertainty at the scenario-family level.
5. **Increase realistic context.** Add multi-module applications and longer change histories only when the task requires using that information. Include stale documentation, earlier design decisions and cross-file dependencies. Reserve response space and test actual correctness near the desired context limit; repeated filler is not a coding-context benchmark.
6. **Check transfer to the user's client.** Repeat a fixed subset through pinned Pi after the common-agent comparison. Keep scaffold effects separate. Investigate Cursor compatibility where a reproducible client path is available.

These are implementation priorities, not a promise that every item is already present. Case counts are working targets and may change if source review finds weak or correlated tasks. Version the unified inventory as scenarios evolve so that an old score never silently changes meaning.
