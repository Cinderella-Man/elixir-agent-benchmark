# Qualification still required

Status: source-verified draft; no application build, tests or model attempt has qualified this case.

The upstream test patch expands an existing owner case into a role matrix and adds a test-support helper. Preserve the original owner assertion while porting the added roles. Include guest/team viewers and unrelated users as negative controls, using real LiveView submission and persisted Ecto records. The changelog change is ancillary.

Before promotion into `cases/`, freeze the historical CE runtime and service images; run protected original tests; demonstrate the intended behavioral failure on the broken state and success after the reference repair; reject plausible incomplete repairs and evaluator bypasses; and establish feasibility under the declared context budget. Record actual visible-test detectability. Compilation failures, missing helpers and setup failures are not bug-detection evidence.
