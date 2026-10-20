# Repository instructions

## Case curation

When adding a benchmark case, resuming an unfinished candidate, changing an existing case's source or preparation, or finishing a curation batch, follow [the case curation workflow](docs/case-curation-loop.md). Every runnable case must use a prepared branch in the user's fork; the workflow links the source-preparation procedure. It also defines isolation, qualification, two fresh Astra solver runs, evidence review and restoration before merging.

## Shared machine constraint

This machine is used concurrently for other work. Functional benchmarks, model accuracy/task-success evaluations, fixture qualification, builds and correctness/concurrency tests are allowed here when speed is not the subject. Run those locally when needed; do not ask for another host merely because the project calls them benchmarks.

Never run speed-based benchmarks, throughput/latency measurements, or performance comparisons on this machine. Do not run combined evidence scripts that include such measurements. Disable automatic elapsed-time measurement before local solver validation as described in the curation workflow.

Use bounded resource concurrency for local functional work. Watchdog timeouts may detect hangs; do not interpret their elapsed times or routine test/build durations as performance evidence. Historical timings from this machine are unsuitable indicators for performance decisions. Speed/performance qualification requires a separate suitable environment and explicit authorization to use it.

On 2026-10-08 the user ordered all Bream speed-test evidence removed and redone. Do not restore historical timing results or derived performance claims. Keep correctness evidence and source; new speed qualification requires another suitable environment and explicit authorization.
