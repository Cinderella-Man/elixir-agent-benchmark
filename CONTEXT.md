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

**Attempt**:
One independent agent run on a scenario, including its investigation, edits, tool calls and self-corrections.
_Avoid_: Test when referring to an entire agent run.

**Candidate**:
The particular model and serving configuration being evaluated. A changed quantization or behavior-changing runtime configuration is a different candidate.

**Agent scaffold**:
The interaction rules and tools through which a candidate performs a scenario.

**Verifier**:
The independent checks that determine whether a submitted project state satisfies a scenario's acceptance criteria.

**Quality evidence**:
Recorded outcomes that show how reliably a candidate completes defined work, with the scenario, agent setup and assessment method identified.
