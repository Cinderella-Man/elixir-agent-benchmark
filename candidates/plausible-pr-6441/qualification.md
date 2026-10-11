# Qualification still required

Status: source-verified draft; no application build, tests or model attempt has qualified this case.

The PR adds five real /api/v2/query regressions using ClickHouse fixtures. Its body describes an earlier sentinel-based implementation; use the final merged behavior. Confirm this test module and its fixtures execute in CE. Add unaffected plain-goal and supported special-property controls rather than allowing a repair to disable imported analytics globally.

Before promotion into `cases/`, freeze the historical CE runtime and service images; run protected original tests; demonstrate the intended behavioral failure on the broken state and success after the reference repair; reject plausible incomplete repairs and evaluator bypasses; and establish feasibility under the declared context budget. Record actual visible-test detectability. Compilation failures, missing helpers and setup failures are not bug-detection evidence.
