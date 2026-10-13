# Elixir Agent Benchmark

## Language

**Case**: A defined repair task with an exact broken project revision, a symptom-focused ticket and executable acceptance criteria. Every case comes from an actual upstream PR.

**Reference repair**: An accepted solution used to qualify a case's checks. Submissions may use another implementation that satisfies the same behavior.

**Model profile**: The served model, quantization, context capacity and serving configuration reported by an endpoint. Missing metadata remains unknown; aliases do not establish exact artifact identity.

**Run**: An evaluation of one model profile across the entire twelve-case inventory, using frozen inputs, budgets and one declared seed.

**Attempt**: One agent's investigation, edits, tool calls and submission for a case. Each run contains one attempt per case.

**Workspace**: A fresh offline Docker environment containing broken project source and prepared dependencies. It excludes reference repairs, grader-only checks, upstream Git history and controller credentials.

**Context budget**: The maximum combined input and response space for one model interaction, including a small safety allowance.

**Generation budget**: The cumulative tokens generated during an attempt, including reasoning and tool syntax.

**Agent**: The pinned Pi coding agent running inside a case workspace. Pi owns the model conversation and built-in tools; Elixir launches it and grades its changes.

**Model transport**: The restricted connection between an agent and the configured model, enforcing budgets and accounting while keeping endpoint credentials outside the workspace.

**Grader**: The independent executable checks applied to a submission in fresh workspaces.

**Grader-only check**: An acceptance check withheld from the attempt workspace. Its source is public in this repository.

**Fixture qualification**: Controls proving that the current environment and grader reject the broken state, plausible incomplete repairs and integrity bypasses, while accepting the reference repair.

**Case outcome**: A completed pass or fail from the grader. Infrastructure and accounting errors remain errors.

**Score**: The percentage of cases passed, with equal case weight. A final score requires a valid outcome for all twelve cases; missing, errored, cancelled and interrupted attempts prevent a final score.
