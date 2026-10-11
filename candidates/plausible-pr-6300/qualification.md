# Qualification still required

Status: source-verified draft; no application build, tests or model attempt has qualified this case.

The upstream test overlay uses existing QueryBuilder and Comparisons interfaces. Add a report/API boundary check using actual stored events; helper-level date assertions alone do not meet the accepted application-path requirement. Freeze the clock and timezone data. Preserve exact-date mode, previous-period behavior and non-UTC coverage.

Before promotion into `cases/`, freeze the historical CE runtime and service images; run protected original tests; demonstrate the intended behavioral failure on the broken state and success after the reference repair; reject plausible incomplete repairs and evaluator bypasses; and establish feasibility under the declared context budget. Record actual visible-test detectability. Compilation failures, missing helpers and setup failures are not bug-detection evidence.
