# Plausible benchmark task audit — 2026-10-14

Historical audit of the original twelve-case revision. The audited inputs are preserved in [the original fixture archive](../../verification/task-quality/original/README.md); the [subsequent promotion](../verification/task-quality-promotion-2026-10-14.md) applies the findings to the eleven-case v3 inventory.

**Runtime follow-up:** see the [completed execution report](../verification/task-quality-audit-2026-10-14.md) for final decisions. This document preserves the source-review reasoning and its pre-execution judgments; the runtime report confirms the 6300 DST reference defect.

All six Plausible PRs describe useful, concrete repository work. Their suitability depends on the task contract and observable checks, not on patch size or the fact that upstream merged them. This audit found material coverage gaps in all six; the most serious are the manually repaired tracker cache in #5956 and a possible contradiction between #6300's timezone requirement and its reference implementation. The latter needs a separate reference challenge before admission.

This document records source inspection and custom executable proposals. It does **not** claim that the new tests or mutants have executed. The coordinating audit runs them separately and records the results in its execution report. A suggested mutant surviving is a hypothesis until that run finishes. No build, model evaluation, speed benchmark, latency measurement, or throughput measurement was run by this research subtask. The repository requires behavioral failure on broken source, reference success, incomplete-repair rejection, and integrity-control rejection; source inspection alone cannot establish these properties. [Evaluation contract](../evaluation.md), [admission rules](../case-admission.md).

## Evidence and method

Read each ticket before checking its acceptance patch; then inspect the reference implementation, selected unchanged regression suites, and the exact historical source. Exact broken and fixed archives were read from `.local/task-audit/sources/`, matched by their receipt's repository revision to each case manifest. Five PR conversation pages were retrieved directly from GitHub. #5939's page timed out; its pinned source and recorded patch remain the primary implementation evidence. Commit links below point to the precise source revision examined, rather than today's default branch. [Case provenance](../../verification/task-quality/original/cases/plausible-pr-5939/provenance.json), [fixture source verification policy](../adr/0002-historical-upstream-repairs.md).

For each case, distinguish a demonstrated success path, a preservation witness, and a negative boundary. An existing test's title is not enough: inspect its data, execution path, and assertions. In particular, a cache disabled in test configuration, an unconditional refresh between write and read, or a test fixture with no disallowed data can make a test miss the production defect. These distinctions follow directly from the concrete source and test paths discussed below.

The tracked audit artifacts are under [verification/task-quality/cases](../../verification/task-quality/cases/). Each Plausible directory contains an additional `acceptance.patch` and `audit.json` with test paths and source-replacement mutants applied after the reference implementation. Every replacement was checked to occur exactly once in the pinned fixed source. They do not alter the published `cases/` fixtures. The #6300 DST challenge was incorporated into the tracked audit overlay as `test/reference_challenge_test.exs`; it deliberately challenges whether the reference meets the stated contract. A failed challenge is a reference/contract problem to investigate, not an ordinary successful reference qualification.

| Case | Value as a task | Source-audit verdict before new execution |
| --- | --- | --- |
| #5939 | Small authorization repair with guest/team role distinctions and persistent state | Retain; strengthen scope boundaries |
| #5956 | Configuration lifecycle and real cache behavior in CE | Hold for stronger write-to-endpoint checks |
| #6300 | Date arithmetic, option preservation, timezone handling, query integration | Hold for DST reference challenge and calendar variation |
| #6441 | Imported/native data semantics across SQL table selection and goal joins | Retain after positive import-preservation checks |
| #6449 | Create/edit trust boundaries and state preservation | Retain after malformed-edit and permission coverage |
| #6763 | SQL optimizer capability gating exposed through CSV export | Retain after aggregate preservation check |

These are suitability judgments, not model difficulty estimates. #5939 and #6763 have tiny reference implementation changes but require locating the correct boundary and preserving behavior. #5956 has a much larger reference refactor, yet its solver-facing task only requires correct CE script delivery. Requiring that refactor's architecture would unfairly reject other valid repairs. [5939 reference](../../verification/task-quality/original/cases/plausible-pr-5939/reference.patch), [5956 reference](../../verification/task-quality/original/cases/plausible-pr-5956/reference.patch), [6763 reference](../../verification/task-quality/original/cases/plausible-pr-6763/reference.patch).

## #5939 — Editors cannot change a site domain

The contract is unusually clear: both guest and team Editors may change a domain; the stored current and previous domains must be right; Admins and Owners retain access; Viewers and unrelated users must be denied. The reference adds `:editor` to the existing site-scoped role allowlist. The underlying query scopes team membership and optional guest membership to the selected site. [Ticket](../../verification/task-quality/original/cases/plausible-pr-5939/ticket.md), [reference](../../verification/task-quality/original/cases/plausible-pr-5939/reference.patch), [historical authorization query](https://github.com/plausible/analytics/blob/d6673fbbd510a96b56a9c6265bb850c2e3d40ea7/lib/plausible/sites.ex#L454-L505).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Guest Editor and team Editor can submit | Parameterized LiveView tests mount, submit and reload the site | Real end-to-end server flow; no implementation assertion |
| New and previous domains persist | Both database fields asserted for each allowed role | Stronger than checking only rendered success |
| Team Admin and Owner still work | Same parameterized test, plus original owner workflow | Covered |
| Guest and team Viewer denied | New tests expect mount denial | Covered for users with no Editor role elsewhere |
| User without access denied | Unrelated-user mount denial | Missing mixed memberships: Editor elsewhere, Viewer here |
| Existing validation and success behavior remains | Whole `change_domain_test.exs` selected | Empty/invalid/taken domains, transition conflicts, success navigation and CE notice remain covered |

Sources for this mapping: [acceptance patch](../../verification/task-quality/original/cases/plausible-pr-5939/acceptance.patch), [manifest](../../verification/task-quality/original/cases/plausible-pr-5939/case.json), [unchanged historical suite](https://github.com/plausible/analytics/blob/d6673fbbd510a96b56a9c6265bb850c2e3d40ea7/test/plausible_web/live/change_domain_test.exs).

The added audit checks deny a team Editor access to another team's site, and deny a guest Editor of site A who is a Viewer of site B in the same team. Both assert the foreign site's database fields remain unchanged. The proposed `global-editor-permission` mutant incorrectly treats any team Editor membership as global authority. It is a plausible permission repair error that the existing pure Viewer/unrelated examples do not exercise. The existing declared partial repair, which simply includes Viewers, remains useful and must remain rejected. [Existing partial probe](../../verification/task-quality/original/cases/plausible-pr-5939/case.json).

Tracked artifacts: [additional assertions](../../verification/task-quality/cases/plausible-pr-5939/acceptance.patch), [mutation specification](../../verification/task-quality/cases/plausible-pr-5939/audit.json).

The exact `Ecto.NoResultsError` denial assertion inherits existing application conventions. A repair that denied by redirect or another status could meet the broad English requirement but fail this oracle. Prefer explicitly preserving the existing denial convention in the ticket if the exact form remains part of grading. The task should not silently expand into live-session role revocation or new API authorization mechanisms; neither is the reported defect. [Acceptance denial assertions](../../verification/task-quality/original/cases/plausible-pr-5939/acceptance.patch), [mount implementation](https://github.com/plausible/analytics/blob/c4ea07d8bc38deacb7c6291ff073bcf814f113f8/lib/plausible_web/live/change_domain.ex#L22-L43).

## #5956 — Dedicated CE tracker scripts

This is a good stateful task, but the current oracle repairs part of the behavior it should observe. The ticket asks for create → serve → update → serve, repeated without restart, preserving site identity and other sites. Before every observed GET, the acceptance helper reads configurations from PostgreSQL, calls `Tracker.build_script`, and inserts those freshly generated scripts directly through `Adapter.put_many`. A submitted repair can omit its write-side cache updates and still have the test install the correct values for it. [Ticket](../../verification/task-quality/original/cases/plausible-pr-5956/ticket.md), [acceptance helper](../../verification/task-quality/original/cases/plausible-pr-5956/acceptance.patch).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Newly configured script works without restart | Configuration created, helper refreshes cache, endpoint checked | Does not establish automatic insertion after creation |
| Every successful update serves current settings | Repeated false/true settings, helper refresh before every read | Does not establish automatic refresh after updates |
| Repeated refresh does not create duplicate-key delivery errors | Helper inserts repeatedly into the application-started cache | Valuable coverage of actual ETS cache options; retain this check |
| Correct site and independent second site | Domain and setting substrings checked for both | Covered at payload level |
| Unknown ID remains unavailable | Endpoint response must be 404 | Covered |
| Valid script | Existing wrapper and setting substrings | Does not prove JavaScript parses; new direct check adds a Node syntax assertion |
| Existing cache and tracker behavior preserved | Cache unit suite and tracker plug suite | Tracker plug suite normally bypasses cache through database fallback, so it cannot replace a cache-enabled lifecycle test |

Sources: [acceptance](../../verification/task-quality/original/cases/plausible-pr-5956/acceptance.patch), [selected regression suites](../../verification/task-quality/original/cases/plausible-pr-5956/case.json), [cache enable/fallback behavior](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible/cache.ex#L15-L36), [historical tracker plug tests](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/test/plausible_web/plugs/tracker_plug_test.exs#L21-L73).

The audit adds a separate direct lifecycle test with caching enabled. It creates two configurations, immediately requests both, then repeatedly updates one and checks both responses without writing to the cache from the test. It checks syntax using `new Function(script)` in the pinned Node runtime; this parses JavaScript without executing it. The proposed `omit-write-cache-update` mutant replaces the CE upsert helper with `:ok`. This is the clearest experiment to establish the masking gap: run it against the old acceptance, then against old plus new acceptance. [Reference write-side update](../../verification/task-quality/original/cases/plausible-pr-5956/reference.patch), [Node supplied to fixture images](../../lib/eab/fixtures.ex#L294-L310).

Tracked artifacts: [additional assertions](../../verification/task-quality/cases/plausible-pr-5956/acceptance.patch), [mutation specification](../../verification/task-quality/cases/plausible-pr-5956/audit.json).

The upstream review independently explains why cache configuration matters: its early tests started a cache with different ETS options from the application, concealing the problem. The accepted repair separates CE and EE caches and removes bag semantics where overwriting is required. This is useful historical corroboration, not a requirement to reproduce those module names. [Upstream discussion](https://github.com/plausible/analytics/pull/5956).

Residual limits: parsing and configuration substrings do not establish browser analytics delivery, nor should that unrelated scope be smuggled into this CE cache repair. Minifier-specific fragments such as `fileDownloads:!0` are narrower than JavaScript semantics, but match the unchanged pinned tracker template. Document that preservation assumption; do not require a particular cache class, synchronization primitive, or read latency. The current ticket correctly says there is no response-time requirement. [Ticket](../../verification/task-quality/original/cases/plausible-pr-5956/ticket.md), [reference script builder path](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/plausible_web/tracker.ex).

## #6300 — Weekday matching for Today and Last 24h

The main behavior is legitimate and well specified. Upstream explains that Today moved to a precise datetime path and Last 24h never implemented weekday matching. The ticket gives exact UTC examples, asks for both options, preserves exact-date comparisons when disabled, and explicitly requires the site's timezone and intended time-of-day range. [Upstream PR](https://github.com/plausible/analytics/pull/6300), [ticket](../../verification/task-quality/original/cases/plausible-pr-6300/ticket.md).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Today weekday matching | Exact first and last UTC timestamps | Covered for 2023 → 2022, one-day shift |
| Last 24h weekday matching | Exact first and last UTC timestamps | Covered for the same calendar example |
| Disabled flag preserves exact-date behavior | New Today test and existing 24h test | Covered |
| Site timezone and time-of-day precision | Non-UTC Today example, existing 24h timezone tests | New weekday example does not cross unequal DST transitions |
| Returned analytics use the chosen range | Stored events distinguish exact date, matched weekday, and after-cutoff rows | Strong database-level Today check; 24h remains range-only |
| Other periods / previous period remain valid | Whole historical comparisons suite | Covered by explicit timestamps for month, year, custom and previous-period modes |

Sources: [acceptance](../../verification/task-quality/original/cases/plausible-pr-6300/acceptance.patch), [manifest](../../verification/task-quality/original/cases/plausible-pr-6300/case.json), [historical comparisons tests](https://github.com/plausible/analytics/blob/53569d76b63c27e89d10bf5b28f6a07c9ce50bdc/test/plausible/stats/comparisons_test.exs).

The ordinary audit adds 2024 → 2023 leap-year cases for both short periods, requiring a two-day adjustment, plus an east-of-UTC half-hour-offset Today case. The proposed `hardcode-one-day-shift` mutant should pass all currently added examples while failing the leap-year check. This is a meaningful calendar partition, not arbitrary random fuzzing. Keep the existing partial-repair control that fixes only Today and leaves Last 24h broken. [Reference algorithm](../../verification/task-quality/original/cases/plausible-pr-6300/reference.patch), [partial probe](../../verification/task-quality/original/cases/plausible-pr-6300/case.json).

**Separate reference challenge: unequal DST transition dates.** Inspecting the reference suggests a real contract violation. For US/Eastern at 2023-03-13 18:30Z, Today begins Monday March 13 at midnight EDT, or 04:00Z. Shifting that UTC instant back one year yields 2022-03-13 04:00Z, which is Saturday March 12 at 23:00 EST. The algorithm computes a two-day shift to Monday March 14 using that local date, but adds those days in UTC; after the DST change the result is Tuesday March 15 at 00:00 EDT. The correct matching Monday range is 2022-03-14 04:00Z through 18:30Z. This inference comes from the exact order of operations in the reference, not from treating all date arithmetic as timezone invariant. [Fixed algorithm](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/lib/plausible/stats/comparisons.ex#L156-L185), [timezone conversion helper](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/lib/plausible/times.ex).

The tracked audit overlay contains that precise assertion in `test/reference_challenge_test.exs`, alongside the ordinary new tests. If the reference fails, do not declare the task fully sound merely because it passes its existing tests. Either use a curator-corrected reference and make the intended timezone contract explicit, or deliberately narrow and disclose the task's supported calendar semantics. Upstream source reconstruction and the grading reference then need separate provenance, just as curated tests already have separate provenance. Do not silently weaken a stated requirement to protect an upstream patch. [Reference versus upstream artifact policy](../case-admission.md).

Tracked artifacts: [ordinary assertions and DST challenge](../../verification/task-quality/cases/plausible-pr-6300/acceptance.patch), [mutation and executed test-file specification](../../verification/task-quality/cases/plausible-pr-6300/audit.json).

Also avoid interpreting “same weekday-matching convention as other periods” as a new mathematical nearest-date algorithm. The historical `shift_to_nearest` implementation has its own convention; a benchmark should preserve the named application behavior unless the ticket deliberately changes it. [Historical helper](https://github.com/plausible/analytics/blob/53569d76b63c27e89d10bf5b28f6a07c9ce50bdc/lib/plausible/stats/comparisons.ex#L207-L246).

## #6441 — Property-restricted goals and imported analytics

This is the strongest reasoning task in this subset. Native events carry properties; imported aggregates do not necessarily contain the evidence required to evaluate those properties. A correct repair must remove unsupported contributions while preserving supported ones. It must also keep goal identities aligned after filtering the imported join inputs. The ticket states these distinctions rather than asking merely for “no crash.” [Ticket](../../verification/task-quality/original/cases/plausible-pr-6441/ticket.md), [upstream problem explanation](https://github.com/plausible/analytics/pull/6441), [reference SQL changes](../../verification/task-quality/original/cases/plausible-pr-6441/reference.patch).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Restricted event-goal filter returns native-only totals | API 200, exact visitors/events `[1, 1]`, imports metadata false | Covered |
| Restricted filtered goal breakdown | Exact dimension, totals and metadata | Covered |
| Mixed unrestricted/restricted event breakdown | Ordinary Signup retains `[3, 5]`; Purchase remains `[1, 1]` | Excellent positive witness against disabling all imports |
| Special-event supported URL combined with restricted goal | API exact native-only totals and imports metadata false | Covered for unsupported combined query |
| Property-restricted page goals | Unfiltered page-goal breakdown with native/imported rows | Missing filtered page-goal API path |
| Ordinary imported page goals preserved | No positive page import witness in selected acceptance | Missing |
| Supported special-event URL imports preserved | No ordinary special-event positive witness | Missing |
| Native matching and grouping remain correct | Original suite tests AND props, no props, conversion rate, time/multiple dimensions and same-event goals | Covered at native-data level |

Sources: [acceptance](../../verification/task-quality/original/cases/plausible-pr-6441/acceptance.patch), [selected suite](../../verification/task-quality/original/cases/plausible-pr-6441/case.json), [original custom-properties suite](https://github.com/plausible/analytics/blob/8f3970104aa77aedf2395868028e337169616267/test/plausible_web/controllers/api/external_stats_controller/query_goal_custom_props_test.exs).

The added audit exercises all three missing paths. A normal outbound-link goal filtered by its URL must include three imported visitors/five events and one native event, while excluding an imported row with a different URL. A restricted page-goal filter must return only the matching native property for both aggregate and breakdown shapes. A mixed page-goal breakdown must preserve an ordinary imported page goal under its correct name while excluding imports from the restricted one. Distinct counts and names make overcounting and identity swaps visible. The ordinary page goal is created before the restricted goal; upstream orders goals by descending ID, so the restricted goal occupies an earlier position and filtering must not renumber the ordinary goal incorrectly. [Goal ordering](https://github.com/plausible/analytics/blob/8f3970104aa77aedf2395868028e337169616267/lib/plausible/goals/goals.ex#L165-L180), [imported join mapping](../../verification/task-quality/original/cases/plausible-pr-6441/reference.patch).

Two proposed mutants deliberately overexclude: `drop-special-event-imports` rejects every otherwise-supported special-property query; `drop-all-imported-page-goals` excludes ordinary page goals from imported joins. The existing “drop all imported goals” probe remains necessary but is not sufficient to establish these narrower preservation boundaries. [Manifest partial probe](../../verification/task-quality/original/cases/plausible-pr-6441/case.json).

Tracked artifacts: [additional assertions](../../verification/task-quality/cases/plausible-pr-6441/acceptance.patch), [mutation specifications](../../verification/task-quality/cases/plausible-pr-6441/audit.json).

Keep HTTP responses, exact metrics, result identities and import metadata as the oracle. Do not require the newly introduced `goal_join_imported_data/1` function or exact SQL text. The full native property suite is important because a repair that changes property filtering globally could appear to fix the imported crash while overcounting native events. The task is CE-only by its manifest; no claim about unexecuted EE billing paths follows. [Manifest](../../verification/task-quality/original/cases/plausible-pr-6441/case.json), [reference](../../verification/task-quality/original/cases/plausible-pr-6441/reference.patch).

## #6449 — Shared-link identity and segment boundaries

The ticket is appropriately explicit about a subtle exception: a same-site segment changed from site-wide to personal remains valid when submitted during renaming. Do not infer the final contract from the PR's opening description, which says personal segments should be disallowed. A later commit changes that policy, and the accepted source validates site ownership without a segment-type restriction. This is a concrete example of why reading only the PR description can produce an unfair benchmark. [Ticket](../../verification/task-quality/original/cases/plausible-pr-6449/ticket.md), [PR conversation and later commit](https://github.com/plausible/analytics/pull/6449), [accepted site-scoping implementation](https://github.com/plausible/analytics/blob/63929d339231e107c5eda8b4499250ea16246a6d/lib/plausible/sites.ex#L417-L459).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Editing cannot replace secret slug | Real form submission with injected slug, database reload | Covered |
| Foreign-site segment rejected on create | Saves successfully with nil association | Covered |
| Foreign-site segment rejected on edit | Existing own segment is replaced with nil | Covered |
| Invalid/nonexistent ID saves with nil | New create loop checks malformed, negative and nonexistent IDs | Edit path not tested |
| Valid same-site segment attaches | Original create test and new edit test | Covered |
| Empty selection clears | New edit test with existing association | Covered |
| Downgraded personal segment survives rename | Type changed after link creation, real edit and persisted assertions | Covered and explicitly visible in ticket |
| Ordinary name/password edits preserved | Whole form suite | Covered |
| Permission boundaries preserved | Selected suite uses an authorized owner | Broader shared-link settings access/foreign-link tests are not selected |

Sources: [acceptance](../../verification/task-quality/original/cases/plausible-pr-6449/acceptance.patch), [manifest](../../verification/task-quality/original/cases/plausible-pr-6449/case.json), [original form suite](https://github.com/plausible/analytics/blob/ebf1fd81bd2e6884b5d31496b9f902cc337f1476/test/plausible_web/live/shared_link_settings/form_test.exs).

The audit adds malformed, negative and nonexistent segment selections during **editing**, starting with a real existing association and asserting successful rename, stable slug and nil segment. The `retain-association-on-malformed-edit` mutant ignores malformed inputs and preserves the old association. It still validates creation and positive foreign IDs, so it targets the uncovered edit transition. Preserve the existing partial control that removes mass assignment but also breaks valid segment editing. [Current partial probe](../../verification/task-quality/original/cases/plausible-pr-6449/case.json).

The audit adds `test/plausible_web/live/shared_link_settings_test.exs` to its executed test files. It is an offline ConnCase suite covering guest Editor access, deletion behavior, and rejecting attempts to edit a foreign site's link by its slug. It does not require a browser or external service beyond the already prepared databases. The new overlay also adds guest Viewer, team Viewer and unrelated-user denial checks against the parent LiveView, with stored link identity/name preserved. These fill the ticket's explicit permission-preservation requirement; neither the original form suite nor the broader suite contained those denial cases. [Additional historical suite](https://github.com/plausible/analytics/blob/ebf1fd81bd2e6884b5d31496b9f902cc337f1476/test/plausible_web/live/shared_link_settings_test.exs), [parent LiveView authorization](https://github.com/plausible/analytics/blob/ebf1fd81bd2e6884b5d31496b9f902cc337f1476/lib/plausible_web/live/shared_link_settings.ex#L10-L20).

Tracked artifacts: [additional assertions](../../verification/task-quality/cases/plausible-pr-6449/acceptance.patch), [mutation and preservation-suite specification](../../verification/task-quality/cases/plausible-pr-6449/audit.json).

The ticket intentionally specifies invalid selections as successful saves with no association. Rejecting the entire form instead is a reasonable product choice in the abstract, but not a solution to this declared contract. Conversely, do not add hidden constraints on newly selected same-site personal segments that contradict accepted source and the site's ownership policy. [Ticket](../../verification/task-quality/original/cases/plausible-pr-6449/ticket.md), [reference lookup](../../verification/task-quality/original/cases/plausible-pr-6449/reference.patch).

## #6763 — Page-filtered dashboard CSV export

The reproduction sets the crucial nullable cutoff explicitly; relying on ordinary factory defaults would miss the defect. The ticket requires a successful ZIP/CSV response, the full column schema, preserved counts on two days, and empty unavailable time-on-page values. The reference gates legacy metric inclusion by whether the query dimensions support its merge. Upstream identifies both aggregates (`[]`) and page breakdowns as supported. [Ticket](../../verification/task-quality/original/cases/plausible-pr-6763/ticket.md), [PR explanation](https://github.com/plausible/analytics/pull/6763), [legacy capability predicate](https://github.com/plausible/analytics/blob/fc5a4d8f65d055491df6ad0f40d220949cb83a11/lib/plausible/stats/legacy/time_on_page.ex#L18-L20).

| Requirement | Current executable evidence | Gap or interpretation |
| --- | --- | --- |
| Page-filtered export with nil cutoff succeeds | Real endpoint, HTTP 200, ZIP extraction and CSV parse | Covered |
| Full visitors.csv schema retained | Exact seven-column header | Covered |
| Jan 5 and Jan 7 counts remain correct | First four columns asserted for both rows | Covered for seeded matching pages |
| Missing time-on-page stays empty | Every nonempty row's value asserted empty | Covered; blanket column deletion or invented number rejected |
| Other export modes preserved | Whole dashboard export suite, fixture comparisons | Covers ordinary/path/property/goal/shared-link/imported modes |
| Supported legacy metric is not globally disabled | Custom page-breakdown test expects 60 seconds | Good negative-control witness, but only one of two supported query shapes |
| Aggregate legacy metric remains available | No nil-cutoff aggregate witness | Missing |

Sources: [acceptance](../../verification/task-quality/original/cases/plausible-pr-6763/acceptance.patch), [manifest](../../verification/task-quality/original/cases/plausible-pr-6763/case.json), [historical CSV suite](https://github.com/plausible/analytics/blob/fc5a4d8f65d055491df6ad0f40d220949cb83a11/test/plausible_web/controllers/api/stats_controller/dashboard_csv_export_test.exs).

The audit adds a page-filtered aggregate with nil cutoff and a one-minute `/blog` → `/next` transition, expecting one visitor and 60 seconds. The `preserve-only-page-breakdown` mutant keeps the existing page-breakdown witness working but disables legacy time-on-page for aggregates. The existing “disable every legacy metric” partial control remains useful. This checks behavior through the query engine and does not assert optimizer internals. [Reference gate](../../verification/task-quality/original/cases/plausible-pr-6763/reference.patch), [aggregate merge implementation](https://github.com/plausible/analytics/blob/fc5a4d8f65d055491df6ad0f40d220949cb83a11/lib/plausible/stats/legacy/time_on_page.ex#L22-L44).

Tracked artifacts: [additional assertions](../../verification/task-quality/cases/plausible-pr-6763/acceptance.patch), [mutation specification](../../verification/task-quality/cases/plausible-pr-6763/audit.json).

The added aggregate requirement is a targeted preservation condition for the same changed optimizer branch. If admission demands every preservation condition be spelled out beyond “preserve other export modes,” add a short ticket clarification that supported aggregate and page-breakdown legacy metrics must remain intact. Do not disguise a broader new feature as a regression. A useful optional extension is a nonmatching-page sentinel in the nil-cutoff CSV test; the current full suite already checks page filtering with configured cutoffs, so this is lower priority than the missing aggregate witness. [Ticket](../../verification/task-quality/original/cases/plausible-pr-6763/ticket.md), [existing page-filter tests](https://github.com/plausible/analytics/blob/fc5a4d8f65d055491df6ad0f40d220949cb83a11/test/plausible_web/controllers/api/stats_controller/dashboard_csv_export_test.exs#L805-L879).

## Execution and admission decisions still required

For each proposed new check, run the reference first and inspect failures as possible test mistakes or reference-contract mismatches; never force an expected answer merely to retain a PR. Then run each targeted mutant against the current acceptance and the strengthened acceptance. A current-suite survivor rejected by the new named assertion demonstrates improved discrimination. A mutant already rejected is still useful evidence, but does not prove the proposed gap. Re-run the standard four qualification controls after integrating any fixture changes, because old qualification receipts cannot certify a changed test contract. [Qualification policy](../evaluation.md), [receipt/version policy](../case-admission.md).

Preservation-only additions such as #5939's scope denial and #6763's aggregate result need not fail the original broken revision. The **reported defect** must still fail behaviorally somewhere in the acceptance suite; it is a mistake to require every boundary or preservation assertion to be fail-to-pass. Setup failures, missing Node, database errors, or compilation errors are not evidence that a mutant was behaviorally rejected. [Evaluation contract](../evaluation.md).

All six are historical public repairs. Their realism does not establish independence from training exposure, broad Elixir skill coverage, or a representative population of tasks. This subset is two closely related products' server-side code, with only six Plausible cases and substantial shared fixtures. Publish task-level outcomes and scope; avoid turning a small pass fraction into a general capability claim. [Public-case exposure policy](../evaluation.md), [inventory](../../verification/task-quality/original/config/benchmark.json).
