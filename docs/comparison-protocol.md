# One benchmark, distinct model and quantization candidates

The default campaign executes all 16 admitted cases from `config/benchmark.json`. The original pilot, Plausible and Livebook are parts of one inventory. Repository and domain breakdowns help explain strengths and weaknesses; they are not switches required to include those cases. `--cases` remains available for debugging a fixture and creates a diagnostic subset.

## Candidate identity

A candidate is a model checkpoint, quantization and behavior-affecting serving configuration. For example, one model's Q3 and Q4 artifacts require separate IDs, even if they share a model family. Another model's Q3 can outperform either; quantization names do not imply an ordering of scores. Record each artifact's repository, revision, filename and hash, plus reasoning settings. The checked-in candidates describe provisioned local endpoints; the configuration is editable and does not prescribe a model shortlist.

Every campaign records the candidate configurations as snapshots. Every attempt also records its configuration and endpoint metadata. Reports retain the candidates that actually participated even if today's configuration file has changed. The scorer rejects attempts whose configuration or budgets differ from the campaign snapshot. Captured server metadata is evidence of the endpoint profile, not a substitute for validating that the intended pinned artifact is served.

## Deterministic scoring

An attempt passes only when every required executable check passes: submitted tests, acceptance, protected regression, and effective regression coverage where required. Source must be valid under the allowed edit contract. There is no AI judge, subjective code-quality number or reference-patch similarity requirement.

For each case, average the binary results over every declared seed. Average those case scores with equal case weight and multiply by 100. All candidates use the same cases and seeds. This is equivalent to passed attempts divided by planned attempts for a complete rectangular matrix. Never choose the best seed or retry only failures and silently replace their outcomes.

Errors, setup failures, missing attempts, identity mismatches and stale controls are reported explicitly. They block a final score; they are neither dropped from the denominator nor silently classified as semantic repair failures. A submitted or budget-ended patch that reaches valid grading gets its executable pass/fail outcome. Report completion/stop reasons alongside it. Resolve operational problems in a newly identified complete campaign rather than rewriting its evidence.

`scripts/score.py` emits counts, per-project breakdowns, candidate identities, all planned attempt states and the frozen protocol fingerprint. `scripts/report.py` includes these scores next to the detailed case matrix. Scores from distinct protocol fingerprints must not be merged into a ranking. Legacy pilot campaigns lack the new frozen receipt and remain evidence matrices rather than retrospective full-benchmark scores.

## Frozen campaign inputs

The receipt records the inventory version and ordered case list, seeds, action/generation budgets, controller/formatter/driver/scoring hashes, every fixture artifact hash, prepared runtime record hashes, and candidate snapshots. The runner checks inputs between attempts and refuses to proceed after a change. Model execution requires successful current controls for every selected case before the first request. Runtime image IDs and environment inputs are bound through the fixture controls and attempt record; rebuilding an image changes the comparison fingerprint even when the case files stay identical.

The per-case and per-project breakdown matters: twelve cases come from only two large applications, and closely related evaluator cases are not independent evidence of twelve different kinds of work. A single aggregate score is a summary of this inventory, not a universal ranking of coding ability.

The agent receives the symptom ticket, allowed edit areas and the selected original test command. That command can narrow the relevant subsystem; these cases do not measure completely unguided repository-wide search. The diagnosis, reference patch and acceptance overlay are withheld from the offline workspace.

## Context and generation policy

Every candidate must serve at least 262,144 tokens. The controller enforces that same working window even if a server allocates more. Before each generation it counts the complete rendered prompt, including tools, through the serving backend's tokenizer. It reserves the requested response allowance (up to 8,192 tokens) and eight safety tokens. If the next request will not fit, generation stops and the saved patch is graded with `stop_reason: context_budget`.

History is not summarized, truncated or compacted by the harness. The server's recorded template determines how previous reasoning is rendered. The cumulative 65,536-token completion allowance includes reasoning, answers and tool syntax; it is separate from the context window. There are at most 32 model calls. These defaults can be changed only as a new protocol, and cannot be merged with scores using different budgets. A 256k capacity is an allowance, not proof that these tasks use or measure the full window.

Campaign preflight checks model aliases, allocated context, expected backend builds, exact prompt accounting, a forced tool call and a tool-result round trip with reasoning. Those small requests are unscored and retained in the campaign receipt. Every scored response must report the pre-counted prompt size and stay within its completion allowance. Endpoint profiles must remain unchanged. Backend differences remain part of the recorded candidate configuration; equal numerical seeds do not promise identical random sampling across different engines or tokenizers.

The reviewed [llama.cpp response serializer](https://github.com/ggml-org/llama.cpp/blob/23b0202a189c44a54625aadcb37a946dd1d6278d/tools/server/server-task.cpp#L359) counts decoded tokens before splitting reasoning and tool fields. The owned Strata launcher disables output clamping, native MCP, reasoning recovery and prompt rewriting; its [completion counter](https://github.com/Niko1221/Strata/blob/61b3fb5dd3f1e8ec09cf7e4e05208bc6d3c46406/serve/server.py#L4020) includes reasoning and tool syntax. Its opt-in overflow counter is supported only with that reviewed launcher. See [the setup details](runbook.md#model-endpoints). No model services are automatically reconfigured by the harness.

Public historical PRs, solutions and tests may have appeared in training data. Offline workspaces exclude the authoring history and evaluator, but this cannot remove prior exposure. Publish that limitation with the results. There are no speed or throughput scores. The maintainer's shared workstation is prohibited from running the benchmark; its separate rig retains an immutable GPU power baseline.
