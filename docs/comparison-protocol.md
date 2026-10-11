# One benchmark, distinct model and quantization candidates

The default campaign executes all 16 admitted cases from `config/benchmark.json`. The original pilot, Plausible and Livebook are parts of one inventory. Repository and domain breakdowns help explain strengths and weaknesses; they are not switches required to include those cases. `--cases` remains available for debugging a fixture and creates a diagnostic subset.

## Candidate identity

A candidate is a model checkpoint, quantization and behavior-affecting serving configuration. For example, one model's Q3 and Q4 artifacts require separate IDs, even if they share a model family. Another model's Q3 can outperform either; quantization names do not imply an ordering of scores. Record each artifact's repository, revision, filename and hash, plus reasoning settings. The existing three candidate configurations describe provisioned pilot endpoints, not a final shortlist.

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

## Work required before the comparative model campaign

This integration adds fixtures and scoring infrastructure; it does not launch a model comparison or claim campaign qualification. Fix a common context capacity, response reserve, generation accounting and feasibility policy first. The current runner does **not compact history**. Its 65,536-token default is cumulative server-reported completion, not a context window. Confirm how the chosen backend counts reasoning tokens, validate the actual served artifacts/settings, and perform explicitly unscored feasibility attempts under the intended common profile. Preserve those attempts as diagnostics rather than selecting favorable samples.

Public historical PRs, solutions and tests may have appeared in training data. Offline workspaces exclude the authoring history and evaluator, but this cannot remove prior exposure. Publish that limitation with the results. There are no speed or throughput scores, and no execution is permitted on the shared workstation; use only the separately authorized rig and preserve its GPU power settings.
