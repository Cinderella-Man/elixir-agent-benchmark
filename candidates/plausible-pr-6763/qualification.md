# Qualification still required

Status: source-verified draft; no application build, tests or model attempt has qualified this case.

The upstream overlay adds an HTTP export regression using existing fixtures and helpers. Run it in ce_test against PostgreSQL and ClickHouse. The PR author reported a red/green result in ordinary MIX_ENV=test; that is upstream testimony, not our CE qualification. Preserve the CSV schema, rows and unavailable-value semantics as well as status 200.

Before promotion into `cases/`, freeze the historical CE runtime and service images; run protected original tests; demonstrate the intended behavioral failure on the broken state and success after the reference repair; reject plausible incomplete repairs and evaluator bypasses; and establish feasibility under the declared context budget. Record actual visible-test detectability. Compilation failures, missing helpers and setup failures are not bug-detection evidence.
