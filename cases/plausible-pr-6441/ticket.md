# Imported analytics break goals restricted by custom properties

On a site with imported analytics, a goal restricted by custom event properties can cause a query to fail or can count imported events that do not establish those properties. This affects filtering by the goal and breaking results down by goals.

For example, define a Purchase goal restricted to variant=A. Record one native Purchase event with that property, and import an aggregate Purchase row containing three visitors and five events, without property information. Query visitors and events for that goal with imports enabled. It should return HTTP 200 and [1, 1], with metadata indicating that imports were not included for this unsupported filtered query.

In an unfiltered breakdown by goal, the same Purchase goal must still count only its native matching event. A separate ordinary Signup goal should retain its imported three visitors and five events. Do not disable imported analytics for the entire report simply because one goal needs properties unavailable in imports.

Apply this behavior consistently to property-restricted event goals and page goals, including queries that also filter a supported special-event property such as an outbound-link URL. Preserve normal imported-data behavior where the query's conditions can be evaluated from that data.

Fix the crash and incorrect totals, and add regression coverage through the query API.
