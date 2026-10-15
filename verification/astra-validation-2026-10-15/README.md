# Two fresh Astra rounds — 2026-10-15

Both requested rounds have finished through the existing dashboard/controller and Pi runner. **Validation of all eleven cases is incomplete.** Five cases have two reviewed successful attempts. Four have one successful attempt and an infrastructure interruption. Two failed their first attempt and were interrupted in their second.

| Round | Run ID | Passed | Failed repairs | Infrastructure interruptions | Full-run score |
| --- | --- | ---: | ---: | ---: | --- |
| 1 | `20261015-164328-37cabdb0` | 9 | 2 | 0 | 81.82% |
| 2 | `20261015-173713-5825b230` | 5 | 0 | 6 | Unavailable: incomplete grading |

The second run ended with controller status `error`, as intended when cases cannot be evaluated. Its five graded passes must not be reported as a 100% benchmark score. All 22 planned attempts remain recorded; no resume, replacement attempt, or automatic retry was performed. Controller cleanup completed for both runs.

## Results by case

The two-success gate requires two graded passes with reviewed patches. An interrupted attempt does not satisfy it.

| Case | Round 1 | Round 2 | Two-success gate |
| --- | --- | --- | --- |
| plausible-pr-5939 | Pass | Pass | Met |
| plausible-pr-6763 | Fail | Interrupted: authentication | Not met |
| plausible-pr-6449 | Pass | Pass | Met |
| plausible-pr-6441 | Fail | Interrupted: overload | Not met |
| plausible-pr-5956 | Pass | Pass | Met |
| livebook-pr-2219 | Pass | Interrupted: overload | Not met |
| livebook-pr-2527 | Pass | Interrupted: overload | Not met |
| livebook-pr-2663 | Pass | Pass | Met |
| livebook-pr-2800 | Pass | Interrupted: overload | Not met |
| livebook-pr-2822 | Pass | Interrupted: overload | Not met |
| livebook-pr-3076 | Pass | Pass | Met |

The clarified **Plausible 6449** case passed both times. The five cases meeting the gate are Plausible 5939, 6449 and 5956, plus Livebook 2663 and 3076. These findings do not change the frozen inventory or its historical qualification record.

## Failed repairs and interruptions

**Plausible 6763, round 1:** the repair prevents the CSV-export crash but removes `time_on_page` from the `visitors.csv` header. One acceptance assertion fails. The existing, model-visible export test also specifies that column. The remaining acceptance tests, preservation tests, submitted tests and regression-coverage check pass. See the [submitted patch](round-1/plausible-pr-6763.patch).

**Plausible 6441, round 1:** the repair disables imported data for an entire mixed goal query when any matching goal has property constraints. Valid imported-only ordinary goals consequently disappear. Two acceptance assertions fail, covering event and page goals. The other required checks pass. See the [submitted patch](round-1/plausible-pr-6441.patch).

**Round 2:** Plausible 6763 was interrupted during ChatGPT token renewal by `Cannot contact ChatGPT sign-in. Try again.` The gateway recorded 11 requests and 10 completed responses. The generic authentication error does not retain the underlying transport status.

Plausible 6441 and Livebook 2219, 2527, 2800 and 2822 were interrupted by `server_is_overloaded`. Their saved provider records show HTTP 200 streams containing an `error` event. The 502 visible in Pi's error message is the local gateway's error wrapper, not a recorded HTTP 502 from OpenAI. Completed-response counts and sanitized provider error details are in `results.json`. These six attempts have partial workspace patches but no final submission or grading receipt; no repair verdict is inferred from them. Usage for an interrupted request may be unreported.

The interruptions are infrastructure outcomes, independent of case solvability. The two graded failures identify concrete preservation problems in the submitted repairs. Neither finding proves complete test coverage or excludes every possible ambiguity in a case.

## Frozen configuration and checks

- Release: `9a5256a9d0d791c4384a3859b1bf353843dd5bc858919b4d76da42df84c2378d`, from the [eleven-case freeze](../frozen-cases-2026-10-15/README.md).
- Model: `gpt-6-astra` through the benchmark's own ChatGPT subscription connection; reasoning `high`.
- Pi: `@earendil-works/pi-coding-agent` 1.2.0, with the frozen lockfile and agent images.
- Budget: 262,144 generated tokens per case, including reported reasoning tokens, checked between completed responses. This is a soft threshold; the last response may exceed it. Context and per-response limits are provider-enforced. No fixed serving revision or sampling seed is claimed.
- Execution: one solver attempt at a time, two preparation workers, lookahead 4; offline workspaces with controller-mediated model access. Compaction and automatic Pi retries are disabled.

Before round 1, the deployed release and every prepared project/service runtime were compared with the freeze. The controller received the eleven exact agent-image cache records through the ordinary validated cache path. No qualification receipts or credentials were imported. Its ordinary fresh qualification of all eleven fixtures reproduced every named outcome in the frozen controls; round 2 reused those identity-bound qualification receipts.

For all 22 attempts, the saved prompt, appended instructions, Pi identity, settings, agent image, runtime identity, qualification identity and normalized qualification outcomes match the freeze. Each initial model request matches its captured frozen request except for the fresh session `prompt_cache_key`. The two rounds have distinct session keys for every case. Their private experiment identities also match, including the same account binding; account identifiers are omitted from this export.

Every passing patch was reviewed for fulfillment of the ticket, preservation of behavior and test integrity. Failed repairs were inspected against the actual failing assertions. All completed attempts have matching request, response-usage and generated-token ledgers. Interrupted attempts retain their available usage without guessing unreported tokens. Functional outcomes only are evaluated; no speed or performance comparisons were performed.

## Evidence and export

- [results.json](results.json): outcomes, named grading results without raw output, hashes of original grading/request artifacts, input checks, usage completeness, patch reviews and the two-success gate.
- `round-1/*.patch` and `round-2/*.patch`: all submitted or interrupted workspace patches, including an empty patch where no edits had occurred. These are evidence files, not changes applied to the case fixtures.
- [checksums.json](checksums.json): SHA-256 checksums for this public package, excluding the checksum file itself.
- [inspect_results.py](inspect_results.py) and [export.py](export.py): local audit/export code. They make no model requests. Export requires the original private run copies under `.local/astra-validation-2026-10-15/round-1/` and `round-2/`, plus the hash-bound `reviews.json` written during patch review. Run `python3 verification/astra-validation-2026-10-15/export.py` to revalidate and export those records.

The controller retains the full original run artifacts. The public package excludes credentials, account identifiers, provider request IDs, response traces and raw model reasoning. The two session/catalog checks that failed before round 1 started are recorded separately; neither submitted a case inference request.

The broad eleven-case validation goal remains unfinished. The five cases with two reviewed passes meet the recorded model-feasibility criterion; the other six do not. Public historical cases may have appeared in training data, and two successes are feasibility evidence rather than proof of perfect case quality.
