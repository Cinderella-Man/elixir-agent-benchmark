# Weekday matching is ignored for short reporting periods

When comparing Today or Last 24h with the previous year, enabling weekday matching does not change the comparison to the corresponding weekday. Other reporting periods already support that option.

For a UTC site at 2023-03-15 18:30:00 (Wednesday):

- Today with year-over-year and weekday matching should compare against 2022-03-16 00:00:00 through 18:30:00 (Wednesday).
- Last 24h with the same options should compare against 2022-03-15 18:30:00 through 2022-03-16 18:30:00.
- Disabling weekday matching should retain the existing exact-date comparison.

The comparison should follow the site's timezone, preserve the intended time-of-day range, and use the same weekday-matching convention as the other supported periods. Previous-period comparisons should continue to work.

Fix the behavior and add regression coverage for the uncovered paths.
