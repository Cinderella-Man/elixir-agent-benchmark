# Resume completed-case checkpoints

With a target of approximately 500 cases per model, an interrupted run may explicitly resume from durable completed-case checkpoints when its model, benchmark, agent, evaluator and settings identities still match. Preserve completed pass/fail outcomes and prior interruption evidence; unfinished Pi work starts in a fresh workspace rather than restoring a partial conversation. This replaces fresh-run-only recovery without silently retrying completed failures or combining outcomes from different model configurations.
