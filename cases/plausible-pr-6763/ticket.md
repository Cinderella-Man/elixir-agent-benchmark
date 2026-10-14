# Exporting a page-filtered dashboard fails for some sites

Dashboard CSV export returns HTTP 500 when a page filter is active for a site whose legacy time-on-page cutoff is unset. The error reports that the time_on_page field is missing from a subquery. Exports for otherwise similar sites with a configured cutoff work.

For a concrete reproduction, use a site without that cutoff, record visits to /blog on 2020-01-05 and 2020-01-07, and include an engagement event for the first visit. Export the seven-day dashboard ending at the 2020-01-08 reference date with the /blog page filter, including visitors.csv.

The export should succeed and produce valid CSV with the usual date, visitors, pageviews, visits, bounce_rate, time_on_page and scroll_depth columns. Each of those two days should retain its one visitor, pageview and visit. Time-on-page values unavailable for this report should remain empty, consistent with existing exports; do not drop the column or invent values to avoid the error.

Fix the regression, preserve other export modes, and add a test reproducing this site configuration.

Keep the same report totals when exporting without a page filter or with a supported page or goal breakdown; repairing the filtered case must not discard other export modes.
