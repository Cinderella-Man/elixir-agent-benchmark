# Configuration normalization disappears inside maps

Our job runner uses NimbleOptions to normalize configuration loaded into maps. After a recent validation refactor, accepted configuration sometimes still contains strings where our custom validators returned integers, and defaults inside map-shaped sections disappear. The equivalent keyword-list configuration behaves differently. The validator still reports success, so the failure appears later in application code.

Investigate and repair the library's normalization behavior. A successful validation must return the values produced by custom validators, including conversions of both map keys and values. Map-shaped options and nested sections must retain defaults and keep their map shape. This must compose through lists and nested schemas without changing list order. Invalid input must still return a useful `NimbleOptions.ValidationError`; do not bypass validation to normalize values.

Keep the public API compatible. Add regression tests using realistic nested configuration and run the relevant existing tests. In your final response, explain the failure mechanism and the checks you ran.
