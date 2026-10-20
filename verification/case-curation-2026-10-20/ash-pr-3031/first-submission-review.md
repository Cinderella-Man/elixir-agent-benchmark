# First Ash submission review

Run `20261020-145143-810635d8`, candidate `66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b`. The sealed patch SHA-256 is `35b2492506b3968004f4f8872a03fbc886d492bff2c5df881c76631165b0b964`. The original official grader passed. Its result remains in `astra-1.json`; the patch is `astra-1.patch`.

## Standards

Independent reviewer `/root/standards_review` found no additional actionable issue or grading shortcut. The submission adds a substantive regression suite, changes no existing tests, and does not alter test helpers/reporters, protected fixtures, admission metadata or runner behavior. Its wider type-helper changes address shared input/error paths. The correctness findings below remain blockers despite the official pass. This review was read-only and ran no tests.

## Specification

Independent reviewer `/root/contract_review` identified two concrete public-contract regressions:

1. The filter tuple path removes `args || %{}` and rejects nil before default assignment. Previously, a nil tuple argument container omitted arguments and applied defaults. The ticket requires preservation of ordinary/default semantics.
2. Query argument validation inserts normalized literals as bare values. Typed comparison hydration can subsequently cast them again using the attribute type. A permitted custom type that casts `n` to `n + 1` and constrains it to twice the value maps input 2 to 6. An attribute holding 6 should compare greater than or equal to that normalized 6; recasting the operand changes it to 7 and makes the result false. The ticket explicitly requires normalized values to survive beside expression arguments.

Neither finding requires a particular wrapper or reference-like implementation. The review found no test weakening. It was source-traced, with functional confirmation recorded separately.

## Functional diagnostic

`first-submission-probes.exs` exercises both behaviors in fresh bounded offline workspaces through the trusted test reporter. `run-first-submission-probes.exs` uses the exact prepared runtime and verified sealed submission. Pristine source passes nil/default behavior and fails the normalized-comparison test in its body. The reference repair passes both. The sealed submission fails both probes with `ExUnit.AssertionError` in test bodies. Complete named outcomes are retained in `first-submission-probes.json`. Therefore the original official passing grade is retained but rejected as an accepted validation success. These previously uncovered requirements justify a new immutable case version and a new blind pair; no failure feedback is given to later solvers.

An initial diagnostic staging operation could not write a new directory as container root under dropped capabilities; it executed no test. The retained runner stages the probe using the ordinary patch application path. This was a probe setup correction, not a solver attempt or application behavior result.
