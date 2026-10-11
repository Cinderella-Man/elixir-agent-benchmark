# Elixir agent benchmark

Language for comparing coding models through realistic work in Elixir projects.

## Language

**Source task**:
A published task from the source collection that may inform a benchmark scenario. Its suitability as independent evaluation evidence is not assumed.

**Task family**:
Related source tasks or scenarios that share an underlying problem, template or solution structure. Variants from one family are not automatically independent evidence.

**Benchmark scenario**:
A defined piece of agent work with an initial project state, a user request and acceptance criteria.
_Avoid_: Prompt, unit test when referring to the whole scenario.

**Repository baseline**:
The particular project state from which a set of scenarios is constructed. Calling it a healthy baseline means its declared correctness checks have passed.

**Historical repair**:
A scenario drawn from an actual upstream defect and its accepted repair, preserving the original broken project state and the repair's provenance.
_Avoid_: Seeded regression when no defect was introduced by the benchmark author.

**Reference repair**:
A known solution used to qualify a scenario's acceptance checks. Other implementations can satisfy the same behavioral contract.

**Seeded regression**:
A behavior-breaking change intentionally introduced into a previously correct project state for a repair scenario. It is authored evaluation material, not evidence of a historical upstream defect.
_Avoid_: Upstream bug when referring to a defect introduced by the benchmark author.

**Authoring repository**:
The project history used to construct and maintain scenario starting states and reference repairs.

**Attempt workspace**:
The project state made available to an agent for one attempt. Its accessible material is part of the scenario contract and can differ from the authoring repository.

**Attempt**:
One independent agent run on a scenario, including its investigation, edits, tool calls and self-corrections.
_Avoid_: Test when referring to an entire agent run.

**Attempt context budget**:
The limit on the combined input and response space available to a candidate in one interaction during an attempt. It is distinct from the allowance for generation across the whole attempt.

**Attempt generation budget**:
The cumulative allowance for tokens generated across an attempt's interactions, under the declared accounting rules.

**Candidate**:
The particular model, quantization and serving configuration being evaluated. A changed quantization or behavior-changing runtime configuration is a different candidate. Candidate identity includes pinned model artifacts; endpoint aliases alone do not identify a model.

**Benchmark inventory**:
The versioned list of admitted scenarios executed by default in one benchmark. Repository and domain breakdowns describe parts of this inventory, not separately selected benchmarks.

**Campaign**:
A frozen matrix of candidates, scenarios and seeds under one declared agent and grading protocol. A focused subset is a diagnostic campaign and does not receive a full-benchmark score.

**Case score**:
The mean of binary executable outcomes across the declared seeds for one scenario. A complete benchmark score gives each scenario equal weight. Missing, unqualified and errored attempts block a final score rather than disappearing from the denominator.

**Agent scaffold**:
The interaction rules and tools through which a candidate performs a scenario.

**Verifier**:
The independent checks that determine whether a submitted project state satisfies a scenario's acceptance criteria.

**Fixture qualification**:
Recorded controls establishing that a particular environment and evaluator reject the broken state and plausible incomplete repairs, accept the reference repair, and reject integrity bypasses. It establishes executable case behavior, not model ability.

**Campaign qualification**:
The additional validation of the chosen candidates, shared agent contract, context and generation limits, and task feasibility needed before a comparative model campaign.

**Grader-only check**:
An acceptance check withheld from the agent during an attempt and made available to the verifier. Its source may still be publicly available outside the attempt.
_Avoid_: Private test when its source is published.

**Quality evidence**:
Recorded outcomes that show how reliably a candidate completes defined work, with the scenario, agent setup and assessment method identified.
