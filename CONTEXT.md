# Elixir Agent Benchmark

## Language

**Case**: A defined coding task with an exact starting project revision, a task description and executable acceptance criteria. Every case comes from an actual upstream PR and identifies whether it concerns a bug fix, feature or refactor.

**Candidate case**: A proposed coding task being inspected and qualified before admission to a benchmark release. Discovery of a merged PR alone does not make it an admitted case.

**Benchmark release**: A frozen, versioned selection of qualified case definitions used for comparable model evaluations.

**Reference solution**: An accepted upstream implementation used to qualify a case's checks. Submissions may use another implementation that satisfies the stated contract.

**Reference repair**: A reference solution for a bug-fix case; also the historical name used by the original repair-only inventory.

**Model profile**: The served model, quantization, context capacity and serving configuration reported by an endpoint. Missing metadata remains unknown; aliases do not establish exact artifact identity.

**Run**: An evaluation of one model profile across a frozen selection of cases, using fixed inputs, budgets and one declared seed.

**Attempt**: One agent's investigation, edits, tool calls and submission for a case. A run records one scored attempt per case and retains interrupted work separately.

**Workspace**: A fresh offline Docker environment containing a case's starting project source and prepared dependencies. It excludes reference solutions, grader-only checks, upstream Git history and controller credentials.

**Prepared case**: A case whose starting environment is available and whose fixture qualification is valid for that environment.

**Case baseline**: The reusable pristine starting state of a case, including prepared source, dependencies and initial service data. It excludes changes and observations produced by attempts or grading checks.

**Build seed**: A pristine preparation build whose compatible artifacts can be reused when preparing another case. It contains no agent investigation, reference repair or grading state.

**Database seed**: Pristine initialized database state whose compatible migration history can be reused when preparing another case. It contains no changes made by an attempt or grading check.

**Waiting workspace**: A pristine workspace held ready for the next ordered attempt, before the agent's investigation begins.

**Submission**: The saved patch produced by an attempt and handed to the grader.

**Context budget**: The maximum combined input and response space for one model interaction, including a small safety allowance.

**Generation budget**: The cumulative tokens generated during an attempt, including reasoning and tool syntax.

**Agent**: The pinned Pi coding agent running inside a case workspace. Pi owns the model conversation and built-in tools; Elixir launches it and grades its changes.

**Model transport**: The restricted connection between an agent and the configured model, enforcing budgets and accounting while keeping endpoint credentials outside the workspace.

**Grader**: The independent executable checks applied to a submission in fresh workspaces.

**Grader-only check**: An acceptance check withheld from the attempt workspace. Its source is public in this repository.

**Fixture qualification**: Controls proving that the current environment and grader reject unchanged starting code, plausible incomplete solutions and integrity bypasses, while accepting the reference solution.

**Case outcome**: A completed pass or fail from the grader. Infrastructure and accounting errors remain errors.

**Score**: The percentage of selected cases passed, with equal case weight. A final score requires a valid outcome for every selected case; missing, errored, cancelled and interrupted attempts prevent a final score.
