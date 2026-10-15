# Rejected cases

These case bundles are preserved unchanged for inspection, but are excluded from
[the active inventory](../config/benchmark.json). Historical releases, attempts
and scores retain their original inputs and inventory.

| Case | Rejected on | Reason |
| --- | --- | --- |
| [Plausible 6763](plausible-pr-6763/ticket.md) | 2026-10-15 | The short ticket leaves the CSV column policy ambiguous, while a hidden check requires retaining an unavailable column with blank values. Only one of three graded Astra attempts passed. Clarify the requirement and validate a new case version before reconsidering it. |

See the [eleven-case Astra review](../verification/astra-confirmation-2026-10-15/README.md)
for the recorded attempts and diagnosis. Rejection does not establish that a
case is unsolvable; every case in that review was solved at least once.

The earlier eleven-case freeze remains a historical record. Its strict verifier
targets that original inventory and implementation, rather than the current
active set.
