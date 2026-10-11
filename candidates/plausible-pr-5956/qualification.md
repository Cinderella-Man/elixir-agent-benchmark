# Qualification still required

Status: source-verified draft; no application build, tests or model attempt has qualified this case.

The upstream repair renames the cache module and splits CE/EE behavior. Its new tests cannot be overlaid verbatim on the parent: missing-module errors would not prove the bug. Build the oracle around stable Tracker/configuration APIs and the script HTTP endpoint, with the production cache configuration. Ensure tracker assets are built before compiling; do not accept an empty script fixture. Synchronize updates explicitly instead of grading elapsed time. The full upstream patch retains EE source and tests for provenance; CE acceptance must exclude EE-only behavior and preserve upstream notices.

Before promotion into `cases/`, freeze the historical CE runtime and service images; run protected original tests; demonstrate the intended behavioral failure on the broken state and success after the reference repair; reject plausible incomplete repairs and evaluator bypasses; and establish feasibility under the declared context budget. Record actual visible-test detectability. Compilation failures, missing helpers and setup failures are not bug-detection evidence.
