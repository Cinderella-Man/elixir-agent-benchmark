# Plausible 6763: clarify the CSV schema requirement before promotion

The additional blind attempt failed the frozen grader, but this failure is not a clean measure of model ability. The repair fixes the reported crash, passes all 22 existing preservation tests, passes all 23 tests in the submitted suite, and satisfies the fail-before/pass-after regression requirement. Of 25 acceptance tests, only the hidden CSV-header assertion fails. The supported page-breakdown and aggregate metric checks pass.

The patch omits `time_on_page` from the legacy-only `visitors.csv` time series. The hidden test requires that column to remain, with unavailable values blank. This is the same output-policy distinction behind the first-round failure. The successful intervening attempt establishes that the frozen case is solvable; it does not establish that the omitted-column interpretation is clearly forbidden by the visible task.

## Why the requirement is ambiguous

The ticket only reports a page-filtered CSV export returning HTTP 500. It does not state the schema policy for an unavailable metric.

Read-only inspection of the exact frozen agent image found:

- `lib/plausible/stats/dashboard/csv_export.ex` routes CSV requests through `Dashboard.QueryParser` and derives CSV headers from the resulting query metrics.
- `lib/plausible/stats/dashboard/query_parser.ex` enables `drop_unavailable_time_on_page: true` for dashboard requests.
- `lib/plausible/stats/query_optimizer.ex` already removes the metric under an availability condition, describing unavailability as functionality not implemented in that context. The submitted repair extends this existing mechanism to unsupported legacy time series.
- The model-visible CSV test specifies a `time_on_page` column for a default site. `lib/plausible/site.ex` defaults its cutoff to `1970-01-01`; `lib/plausible/stats/time_on_page.ex` treats a non-nil cutoff as enabling the new metric. The hidden test deliberately changes the cutoff to nil, disabling that metric. The visible test therefore does not settle the policy for the failing configuration.

These facts make the alternative interpretation plausible. They do not establish that this patch is correct across every untested query or that the upstream product intended to remove the column. The frozen grade remains **failed**. The curation recommendation is **hold for clarification**, not to silently change its score or weaken its tests.

This supersedes the earlier categorical interpretation that the visible header assertion alone established the requirement for legacy-only sites. The earlier reports and failed artifacts remain unchanged as historical evidence.

## Proposed resolution

Keep the original report and add one observable requirement:

> Keep the CSV columns unchanged; leave unavailable values blank.

This communicates the intended behavior without revealing the query-optimizer fix. If preserving that schema is the product requirement, adopt this as a new case version and collect fresh blind validation attempts. If both output policies are acceptable, revise the acceptance contract deliberately instead. No prompt, test, fixture or inventory was changed during this run, and no additional attempt was started beyond the two requested.

The [baseline source receipt](baseline-source-checksums.json) records the inspected image, upstream revision and hashes of the six relevant files. The [submitted patch](patches/plausible-pr-6763.patch) and named grading outcomes in [results.json](results.json) retain the executed evidence.
