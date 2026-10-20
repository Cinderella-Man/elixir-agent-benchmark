# Operately 1069 curation

Status: approved after three fresh matching fixture qualification rounds and two reviewed fresh Astra successes. The unchanged case bundle is parked in `cases_approved/operately-pr-1069/`.

The case repairs duplicate project-check-in subscriptions at the real authenticated API boundary. Its source pair is `4a223d0077e0027219546d184115b9fe1dc9d1a9` → `eda760952eeacc927ed4107420cf474d840c4a26`; exact upstream reconstruction passed. [Source and lineage research](../../../docs/research/music-work-management-candidates-2026-10-18.md) and [independent contract review](../../../docs/research/operately-1069-contract-review-2026-10-18.md) record the scope, license, assertions and review limitations.

The current candidate version is `0075bbde3730e9c5198019498463f09c1c40d9998ef1431c49c141d4ee0b6907`. It pins upstream Elixir 1.14.2/OTP 25.2 on Ubuntu Jammy, PostgreSQL 14.5, UTC and test seed 0. API fixtures disable only unused browser startup and custom formatters; the actual endpoint, session authentication, transactional operation, database and existing authorization checks execute offline. Certificate settings follow the upstream local-development configuration, with automatic renewal disabled. Model speed measurements are disabled.

## Preparation history

| Version | Outcome |
| --- | --- |
| `31aef147dd4f5b6faeee1639f34bc597bdb24040383ed4b76010490f6b9911f5` | Original Debian base failed preparation because security package URLs returned 404. No tests or model ran. A draft status assertion was also corrected from atom to the existing string representation before any test execution. |
| `c34e2696bb9959fb0edeb08faf331ed63a8cfc36162ce4d4422d5be62d5b89f5` | Ubuntu toolchain and database prepared, but API startup lacked required local certificate environment settings. No test bodies ran; no model ran. Failed control evidence retained under this version. |
| `0075bbde3730e9c5198019498463f09c1c40d9998ef1431c49c141d4ee0b6907` | Local certificate setup added and independently re-reviewed. Three fresh complete fixture qualification rounds passed with matching named outcomes. |

The first valid round produced these named outcomes: the reference passed all four acceptance tests, 17 original preservation tests and its 18-test submission suite; its changed regression tests exposed the starting defect. Unchanged and plausible-incomplete code each failed precisely the two duplicate-recipient assertions while passing the two positive preservation assertions and the original suite. The early-exit bypass did not complete the tests and was rejected.

Each additional round retained the previous qualification cache outside lookup and executed all four controls in fresh isolated workspaces/services. Named test outcomes, phases and failure types matched, not just totals. Prepared images may be reused. These are functional checks only; routine build/test durations are not performance evidence.

All nine existing validated cases remain parked in `cases_approved/` and have not been rerun by Astra. Only this candidate was in `cases/` for its two fresh ordinary Pi runs. It was moved out after validation; `cases/` is empty again. A catalog connection failure occurred before launch; it did not create a model attempt.

## Two fresh Astra runs

| Run | Acceptance | Original preservation | Submitted suite | Added regression exposes starting defect | Generated tokens |
| --- | --- | --- | --- | --- | --- |
| `20261018-104437-c356857f` | 4 passed | 17 passed | 21 passed | Yes | 2,981 |
| `20261018-104720-1aa9de63` | 4 passed | 17 passed | 19 passed | Yes | 2,641 |

Both runs used `gpt-6-astra`, high reasoning effort and a 262,144-token response-boundary soft threshold through the ordinary Pi runner. Compaction and automatic retries were disabled. Both completed with cleanup finished. Sealed completion receipts and usage-ledger counts were verified. Task prompts, appended instructions, runtime, agent configuration, qualification and initial provider requests (excluding distinct session keys) matched. Serving revision and deterministic seed were unavailable; this is a functional admission check, not a full-corpus score or speed measurement.

The [sanitized run evidence](astra-results.json) contains named results and input identities. Both repairs received semantic review: [first patch](astra-1.patch), [first review](astra-1-review.md), [second patch](astra-2.patch), [second review](astra-2-review.md). Neither review found a semantic defect or grading shortcut. Both use a valid implementation different from the upstream helper extraction.

The three independent control exports are [round 1](qualification-round-1.json), [round 2](qualification-round-2.json) and [round 3](qualification-round-3.json). Private raw preparation, control and model records remain in the persistent controller data volume; credentials, account identifiers and raw model traces are not included here.

Moving this folder back into `cases/` requires no case or configuration changes. Admission binds file contents, not the holding-folder path.

**Prepared-source policy, 2026-10-20:** runnable additions and source migrations must follow [prepared fork sources](../../../docs/prepared-fork-sources.md). This record retains its original source versions and outcomes; [the later fork audit](../../prepared-forks-2026-10-20/README.md) records branch reuse and any new migration evidence separately.
