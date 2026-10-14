# Prepared-baseline validation — 2026-10-14

**Later evidence:** the [task-quality audit](verification/task-quality-audit-2026-10-14.md) validated matching original qualification receipts for all twelve cases and replayed every reference acceptance suite in a fresh workspace. It also found coverage gaps and a reference-contract mismatch in Plausible 6300. The interrupted-job record below remains historical evidence, not the current task-quality verdict.

The updated controller is deployed. The user stopped the model-free, twelve-case qualification job before completion. No Pi attempts, model generations or speed benchmarks ran, and no new PR cases were added. The website is idle with cleanup complete. Completed caches and evidence remain on disk.

## Completed checks

- All twelve existing cases reconstruct their exact recorded upstream fixed trees.
- Repository formatting and tests pass: **115 passed, 5 Docker tests excluded** from that invocation. Separate Docker checks passed for synthetic feature/refactor grading and offline pinned Chromium.
- Desktop and mobile checks passed for comparison and storage views using isolated synthetic records. Those preview records and their volume were removed.
- Two real cases passed all four controls under the deployed evaluator: the original source fails the acceptance checks, the reference repair passes, an early-exit bypass is rejected, and an incomplete repair fails. The early-exit control executed but did not complete its test suite, as intended.

| Existing case | Current pristine baseline saved | Current controls qualified |
| --- | --- | --- |
| plausible-pr-6300 | Yes | Yes |
| plausible-pr-5939 | Yes | Yes |
| plausible-pr-6763 | No; build interrupted | No |
| plausible-pr-6449 | No; build interrupted | No |
| plausible-pr-6441 | Yes | No |
| plausible-pr-5956 | Yes | No |
| livebook-pr-2219 | No | No |
| livebook-pr-2527 | No | No |
| livebook-pr-2663 | No | No |
| livebook-pr-2800 | No | No |
| livebook-pr-2822 | No | No |
| livebook-pr-3076 | No | No |

“Current” means matching the deployed preparation/evaluator identities. Older artifacts may still exist without meeting that contract. The availability check verified current component records and physical Docker images; it did not start workspaces.

## Retained evidence and limits

The interrupted job is recorded at `/data/jobs/qualification-existing12-checked-20261013/job.json`. Per-case activity lives under `/data/runs/qualification-existing12-checked-20261013/`; matching control receipts live in `/data/qualifications/`. The deployed evaluator identity is `91079ba054696abb2ad60ee6aec92033770832cf953b23fbdc4fb11bc7a8c545`. Earlier interrupted qualification jobs retain their own evidence.

Real logs show exact application/database reuse for 6300 and 5939, scanner-only metadata refresh without rebuilding 5939, and compatible application-seed selection for 6763 and 6449. Changed compilation inputs still required compilation during their initial preparation. Their unfinished images were not published as complete baselines.

The planned complete-inventory repeat check **did not run**. Do not claim all twelve cases are qualified or that whole-inventory warm reuse is proven. No startup or performance result was measured. Clicking Run can automatically prepare missing baselines and qualify remaining cases; completed matching artifacts and controls remain reusable.
