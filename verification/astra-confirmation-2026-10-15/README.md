# Eleven-case Astra validation: short report

**Nine cases meet the two-reviewed-success rule. Two remain pending. All eleven have been solved at least once.**

The requested additional attempts on **Plausible 6763 and 6441 both failed grading**, with no provider interruption. Their earlier successful repairs are preserved. These results do not justify claiming that Astra always passes or that every case is unambiguous.

| Case | Task | Successful / graded attempts | Infrastructure interruptions | Readiness |
| --- | --- | ---: | ---: | --- |
| Plausible 5939 | Editor domain-change permission | 2 / 2 | 0 | Validated |
| Plausible 6763 | Page-filtered CSV export | 1 / 3 | 1 | Hold: clarify CSV schema |
| Plausible 6449 | Shared-link URL and segment validation | 2 / 2 | 0 | Validated |
| Plausible 6441 | Imported analytics and property-filtered goals | 1 / 3 | 1 | Pending: needs second success |
| Plausible 5956 | Dedicated tracker cache updates | 2 / 2 | 0 | Validated |
| Livebook 2219 | Inputs in frame updates | 2 / 2 | 1 | Validated |
| Livebook 2527 | Signed-notebook trust after inserted code | 2 / 2 | 1 | Validated |
| Livebook 2663 | Nested content in numbered lists | 2 / 2 | 0 | Validated |
| Livebook 2800 | Erlang syntax-error rendering | 2 / 2 | 1 | Validated |
| Livebook 2822 | State inherited after failed cells | 2 / 2 | 1 | Validated |
| Livebook 3076 | Personal-workspace S3 configuration | 2 / 2 | 0 | Validated |

“Validated” means the recorded feasibility criterion is met, supported by fixture qualification and patch review. It does not certify exhaustive coverage, absence of ambiguity or reliable success on every attempt. Infrastructure interruptions are separate from failed repairs. Across all recorded attempts there are 20 passes, 4 failed repairs and 6 interruptions; this adaptively selected history is not a full-benchmark accuracy score.

## What the two failures mean

**6763 needs a clearer requirement.** The repair fixes the crash but omits the unavailable `time_on_page` column. One hidden test requires the column to remain with blank values. All existing preservation tests, submitted tests and regression coverage pass. Inspection found that the visible code already supports dropping unavailable metrics, and its existing header test covers a different site configuration. The short ticket does not resolve this output-policy choice. This qualifies the earlier claim that the failure was simply a model mistake. See the [case-quality note](case-quality-note.md).

Recommended clarification: **“Keep the CSV columns unchanged; leave unavailable values blank.”** That would be a new case version needing fresh blind validation. The current prompt and tests were left intact.

**6441 received an overly broad repair again.** The patch avoids incorrect property-goal imports by disabling all imports for mixed goal queries. Valid ordinary event and page goals consequently disappear: the hidden witnesses lose a Signup row with 3 visitors / 5 events and an ordinary page-goal row with 3 visitors. Two acceptance checks fail; existing and submitted tests pass. Unlike the unavailable-column choice above, this removes supported data from unrelated goals. The earlier successful repair demonstrates solvability, but only one reviewed success has been obtained.

**Recommendation:** use the nine validated cases as the current pilot set, clarify 6763 before promotion, and retain 6441 as a candidate pending the second-success criterion. No case was removed from the configured eleven-case inventory during this task. The set is still eleven public bug-fix tasks from two Elixir applications, so it should not be treated as broad coverage of day-to-day development.

## Recorded execution

- Additional run: `20261015-190138-357b9a90`; exactly one fresh attempt per requested case. Status `completed`, both grades failed, cleanup finished, and no further attempts started.
- Same `gpt-6-astra` identifier, signed-in benchmark account, `high` reasoning, Pi 1.2.0, and 262,144-generated-token soft threshold. Automatic retries and compaction remained disabled. Workspaces were fresh and offline except for the model gateway; no previous solution or grading feedback was supplied.
- Both attempts match all nine frozen-input checks: prompt, instructions, Pi, agent image, settings, initial request except its fresh session key, runtime, qualification identity and control outcomes. Their session keys differ from all three prior attempts on those cases.
- Commit `508020c` extends the existing partial-run path with `Eab.Runs.repeat_cases(source_run_id, cases, key)`. It retains previous artifacts, records the selected cases and their source, uses the ordinary scheduler/agent/grader, and gives no full-inventory score. All 30 relevant controller/checkpoint/runner/comparison/dashboard tests passed.
- The controller change produced execution release `c9ab5f1e8b4f8a439f437cb4804b471fc25a93f557dea45419a5a4c1946c801d`. Case fixtures and agent protocol remain identical to the original frozen release; implementation deltas are recorded explicitly. Neither grader nor model-visible inputs changed.
- All 1,505 artifacts from the two original rounds and six-case retry remain byte-for-byte unchanged. The prior public packages remain unchanged. Both new sealed completion receipts and usage ledgers verified. Functional evidence only; no speed or performance comparison was performed.

[Results and all eleven case histories](results.json) · [Execution release](release.json) · [Artifact checksums](checksums.json) · [Offline exporter](export.py)

The `patches/` directory contains the two failed submissions as evidence; neither was applied to benchmark fixtures. The public export omits account identifiers, credentials, raw provider responses and model reasoning. Run `python3 verification/astra-confirmation-2026-10-15/export.py` at the recorded implementation revision with the private local run copies, review records and receipt audit under `.local/astra-confirmation-2026-10-15/` to reproduce it.
