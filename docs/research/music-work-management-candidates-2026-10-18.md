# Music and work-management application candidates — 2026-10-18

This pass follows the request for actual applications like LiveBeats. It investigates user workflows in **LiveBeats** and **Operately**, not framework exercises. All findings below are source inspection and proposed qualification work; no application was built, executed, imported or admitted. No speed measurements were run. Apply the existing [selection rules](../pr-selection-guidelines.md), [admission contract](../case-admission.md) and [rejection history](../../cases_rejected/README.md).

## Product-purpose screening

- **LiveBeats** is a social music application for uploading music and listening together. Its first-party [README](https://github.com/fly-apps/live_beats#readme) and [author's description](https://fly.io/blog/livebeats/) establish that purpose. The selected historical tasks concern music, files and playback. They precede the later Whisper/FLAME integration.
- **Operately** is an application for team projects, goals, discussions and documents, as described by its [README](https://github.com/operately/operately#readme). The selected 2024 changes concern explicit user actions and project records. Historical [runtime configuration](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/config/runtime.exs) includes optional browser Sentry reporting; this is not a claim that the application contains no telemetry. Future offline fixtures should leave external reporting disabled. These are project-management tasks, not employee surveillance tasks.

This is a purpose-and-selected-source screen, not a whole-repository security audit. No surveillance, covert tracking or device-monitoring product was selected.

## Prioritized candidates

| Candidate | Substantive implementation / other files | Outcome and disposition |
| --- | --- | --- |
| LiveBeats [#37](https://github.com/fly-apps/live_beats/pull/37) | 2 runtime: LiveView player and JavaScript audio hook; no added tests | **Draft first for music/UI variety:** current song information reaches the browser title and supported Media Session metadata. Needs a real browser witness. |
| Operately [#1069](https://github.com/operately/operately/pull/1069) | 4 runtime paths, including 2 helpers extracted from an existing operation; 1 API test file | **Draft first for transactional application work:** overlapping author/invite/mention populations produce one subscription per person. Physical path count overstates the amount of new logic. |
| Operately [#1205](https://github.com/operately/operately/pull/1205) | 2 substantive runtime paths; 3 alias-only runtime edits; 1 API test + 2 test-support files | **Draft:** archived milestones disappear from project results while active milestones and optional inclusion still work. |
| Operately [#1202](https://github.com/operately/operately/pull/1202) | 3 runtime paths; no added tests | **Draft after contract review:** saving a project timeline without a due date succeeds through request parsing, mutation and activity persistence. |
| LiveBeats [#23](https://github.com/fly-apps/live_beats/pull/23) | 3 runtime; 1 test file | **Reference hold:** expiry coordinates song rows, per-user counts and local files, but missing-file error logging appears to crash. Historical notice and scheduler/sandbox preparation also remain unresolved. |
| Operately [#997](https://github.com/operately/operately/pull/997) | 2 small runtime changes; 1 API test | **Focused reserve:** contributor search returns only eligible people in the caller's company. |
| Operately [#1754](https://github.com/operately/operately/pull/1754) | 3 runtime, 2 TypeScript + 1 Elixir; no added tests | **Browser hold:** comment mentions use the containing project/space across four comment surfaces. Useful breadth, but most implementation is frontend. |

“Draft” is an investigation priority, not qualification or admission. No prior rejected identity is reintroduced here.

## LiveBeats #37 — now-playing information

**Exact pair:** `a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d` → `d25554632f960a959a4d1c60abf09be804cb298c`, the accepted merge and its first parent. [Accepted diff](https://github.com/fly-apps/live_beats/commit/d25554632f960a959a4d1c60abf09be804cb298c).

The server includes artist/title in the existing play event and assigns a playing title; the audio hook forwards that information to Media Session when available. The reference also restores the ordinary page title on stop. It does **not** implement media action handlers or clearing Media Session metadata on stop, and the PR explicitly excludes the duration/scrubber visible in its screenshots. Do not silently score those capabilities. [PR and discussion](https://github.com/fly-apps/live_beats/pull/37), [player at the starting revision](https://github.com/fly-apps/live_beats/blob/a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d/lib/live_beats_web/live/player_live.ex).

**Proposed brief:** “Show the current song's title and artist in the browser tab and, where supported, the browser's media-session metadata. Update both when the song changes, restore the ordinary tab title when listening stops, and preserve playback in browsers without Media Session support.” Exact tab punctuation should only be scored if stated in the brief; otherwise accept equivalent readable text.

**Witness:** use local seeded accounts and a small locally served audio fixture; start playback by user interaction, change to a second song and stop listening. Assert `document.title`, `navigator.mediaSession.metadata` and ordinary playback state. Cross-check the real LiveView event so a hook-only fake cannot pass. A second browser context with the optional API unavailable should retain playback. A complete browser fixture is still to be designed: a server assign assertion alone does not establish that the nested player actually changes the browser title.

**Partial control:** a compiling server-only implementation updates the title and sends metadata but leaves the browser integration absent. An inverse hook-only partial misses the real server event. Preserve profile ownership controls and existing play/pause behavior without turning this into an unrelated authorization task.

**Environment:** starting [Mix file](https://github.com/fly-apps/live_beats/blob/a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d/mix.exs) declares Elixir `~> 1.12`, LiveView `~> 0.17.6`, esbuild and Tailwind; [lockfile](https://github.com/fly-apps/live_beats/blob/a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d/mix.lock) pins Phoenix to Git SHA `8d2b33ac9691bd624ede602088d213f89600d233`. Do not upgrade it to current Phoenix as incidental setup. The lock also contains historical Git entries that need dependency-closure verification; presence in the lock alone does not prove they remain active dependencies. [Test configuration](https://github.com/fly-apps/live_beats/blob/a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d/config/test.exs) uses PostgreSQL, localhost file ownership and the primary repo as the replica, with the HTTP server disabled by default. Browser preparation must start the local endpoint, serve built assets, and authenticate through test fixtures rather than real GitHub OAuth. The starting tree includes the [MIT notice](https://github.com/fly-apps/live_beats/blob/a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d/LICENSE.md). Exact OTP/browser compatibility remains unexecuted.

## Operately #1069 — one subscription per person

**Exact pair:** `4a223d0077e0027219546d184115b9fe1dc9d1a9` → `eda760952eeacc927ed4107420cf474d840c4a26`. [Accepted commit](https://github.com/operately/operately/commit/eda760952eeacc927ed4107420cf474d840c4a26).

The application creates subscriptions from the author, explicitly selected recipients and people mentioned in rich text. The repair combines those populations, deduplicates across them, retains invited status when someone is also mentioned, and normalizes omitted subscriber IDs at the mutation boundary. Two new modules mostly extract existing subscription/list logic. [Implementation diff](https://github.com/operately/operately/pull/1069/files).

**Proposed brief:** “Posting a project check-in can create duplicate notification subscriptions when the same person is selected or mentioned more than once, including the author. Keep one subscription per person, preserve every distinct intended recipient, and keep explicitly invited recipients invited even when they are also mentioned. Posting without an explicit recipient list must still work.”

**Witness:** invoke the authenticated mutation with author A, invited B/B, mentioned A/B/C/C, plus an unrelated person D. Assert one row for A/B/C, none for D, invited precedence, correct parent/list links and a successfully persisted check-in. Repeat with omitted and empty recipient lists, and with no mentions. This checks persisted subscriptions, not an invented requirement about exactly how many emails are sent. The upstream test adds overlap coverage, but its `assert Enum.filter(...)` membership checks are weak because even an empty list is truthy in Elixir; use explicit ID-set and type assertions. [Upstream test](https://github.com/operately/operately/blob/eda760952eeacc927ed4107420cf474d840c4a26/test/operately_web/api/mutations/post_project_check_in_test.exs).

**Partial control:** deduplicate within the invited and mentioned lists separately but retain duplicates between them; this compiles and fails the mixed-population assertion. A drop-all implementation must fail recipient preservation and check-in linkage checks. Do not demand the reference's helper module layout.

**Lineage:** [#1038](https://github.com/operately/operately/pull/1038) introduced mention subscriptions; #1069 corrects overlap. This is a concrete feature-plus-fix candidate for the user's earlier idea. The maintenance case can simply start at #1069's parent. The [pre-feature interval](https://github.com/operately/operately/compare/f3cb34220c1dda131ea2ef6550fc41aa224d450d...eda760952eeacc927ed4107420cf474d840c4a26) contains 27 commits and 131 changed paths, including unrelated forms and privacy UI. Selecting only #1038 and #1069 would need explicit synthetic-source reconstruction support; do not label that selected tree with the real upstream endpoint SHA. Later [#1108](https://github.com/operately/operately/pull/1108/files) moves mention decoding into `RichContent` and changes other notification code; the inspected extraction preserves the deduplication behavior, so it is not automatically part of this case.

## Operately #1205 — archived milestones

**Exact pair:** `784ec4d6bca669b9b48af1152024d2d1d21e02dc` → `ef2bac5edc50f8490e98fd7fecaa52a975e9434e`. [Accepted commit](https://github.com/operately/operately/commit/ef2bac5edc50f8490e98fd7fecaa52a975e9434e), [user report #1200](https://github.com/operately/operately/issues/1200).

The project loader changes how milestones are fetched; the application's [Repo](https://github.com/operately/operately/blob/784ec4d6bca669b9b48af1152024d2d1d21e02dc/lib/operately/repo.ex) supplies soft-deletion filtering. Three additional runtime edits merely introduce/use an alias. This is **two substantive implementation paths**, not a five-component task. The accepted tests exercise omitted includes, two active milestones, then archiving one and preserving the other. [Diff and tests](https://github.com/operately/operately/pull/1205/files).

**Proposed ticket:** “Archived milestones still appear in a project's milestones list; fix this while keeping active milestones visible.” Use the real authenticated project query with `include_milestones`, mixed active/archived records and a second project. Preserve omission behavior and milestone serialization. A compiling partial that filters only direct milestone queries while leaving nested project retrieval unchanged must fail. No exact preload strategy or helper name is required. A browser is optional for this data-return defect; API results at the same product boundary are meaningful.

## Operately #1202 — timeline without a due date

**Exact pair:** `f8944712b2f3fcad08af29434876d64b55e5576f` → `9af48cab40916d947318a2ffccf0743ebe1731d4`. [Accepted commit](https://github.com/operately/operately/commit/9af48cab40916d947318a2ffccf0743ebe1731d4), [production report #1187](https://github.com/operately/operately/issues/1187).

The repair crosses input parsing, mutation handling and the activity-content changeset. A narrower parser-only fix would still leave an activity validation failure. No upstream regression test was added. [Full diff](https://github.com/operately/operately/pull/1202/files).

**Proposed ticket:** “Saving a project's timeline fails when no project due date is set. Allow saving it with an omitted or empty due date while preserving the start date and milestone changes.” Clarify “empty” as JSON null in the frozen brief, not an arbitrary malformed date string. Exercise the real mutation for absent/null/set due dates and inspect project, milestones and timeline activity after the transaction. Preserve invalid non-date rejection and the existing required start date. The reference's generic null clause must be reviewed against the rest of the API; do not turn a timeline ticket into a hidden demand that every API field accept null.

**Partial control:** allow the input and mutation to accept null but leave the activity schema requiring a due date. That should compile and fail on persistence, providing a useful cross-component witness.

## Operately historical environment

The September candidates have root-level Mix projects, avoiding the current repository's later `app/` layout. At #1069's parent, [Mix](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/mix.exs) declares Elixir `~> 1.14`, Phoenix `~> 1.7.0`, Ecto/PostgreSQL, Oban, bcrypt, Wallaby and Cabbage. [Compose](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/docker-compose.yml) identifies PostgreSQL 14.5 and optional development services; those services are not automatically necessary for the selected database/API workflows. Preserve the historical [Apache-2.0 notice](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/LICENSE).

The [test configuration](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/config/test.exs) uses DB environment variables, local HTTP, test mail and inline Oban. The [global test helper](https://github.com/operately/operately/blob/4a223d0077e0027219546d184115b9fe1dc9d1a9/test/test_helper.exs) starts Wallaby even for API-only files and enables local storage. Inspect its ChromeDriver/browser dependency before calling onboarding easy; a neutral preparation overlay may isolate genuinely unused browser setup, but must not remove the product interaction being scored. UI cases additionally need the pinned React/TypeScript assets and actual local browser flow. OTP/Node/native bcrypt availability and offline dependency closure remain to be verified. No real Google OAuth, cloud object storage or external email delivery is part of the proposed API contracts.

## Conditional reserves and exclusions

### LiveBeats #23: automatic song expiry

Pair `be420bdc445e1c5386ef446cdadaf6d0d63c4fcc` → `75d82eed3f927c92bea936960da88549778b658f`. The [accepted patch](https://github.com/fly-apps/live_beats/commit/75d82eed3f927c92bea936960da88549778b658f) adds a supervised periodic cleaner, transactional row deletion and per-user count updates, followed by file cleanup. A clarified feature brief can require default seven-day retention, startup/periodic cleanup, valid-song preservation and restored quota. Verify multiple users, old/new songs, actual temporary files and repeated cleanup without negative counts. The upstream tests do not establish real file cleanup or the worker lifecycle. A DB-only partial should fail the retained-old-file assertion.

**Reference challenge found during independent source review:** the expiry query selects only `user_id` and `mp3_filepath`, while `delete_song_file/1` interpolates `song.id` when file removal returns an error. A missing or unremovable file can therefore raise `KeyError` after database rows/counters have already changed, including during cleaner startup. Info-level logging must evaluate the message to expose this path; the quiet test configuration can mask it. This is a static concern, not an executed failure. Hold the original reference until missing-file cleanup is challenged and the intended recovery behavior is resolved; do not omit that ordinary filesystem condition merely to obtain a passing fixture. [Accepted query and error handler](https://github.com/fly-apps/live_beats/blob/75d82eed3f927c92bea936960da88549778b658f/lib/live_beats/media_library.ex#L358).

Prepare a controlled worker trigger and SQL sandbox ownership instead of waiting an hour or measuring cleanup speed. Use database-relative timestamps well away from the cutoff; the upstream test's “month” helper approximates months as 30 days. The immediate source pair predates the project's [MIT notice addition](https://github.com/fly-apps/live_beats/commit/9f5abd842acbfe7d110083d59a3f18fcf54db3cf); document notice coverage before exporting a historical bundle rather than assuming the file existed in that tree.

Later [server-ownership filtering](https://github.com/fly-apps/live_beats/commit/de2f4736246a5d990c74f12c79d8d395ffc8b4c8) followed the introduction of distributed file ownership, and [admin retention](https://github.com/fly-apps/live_beats/commit/b5edfdd9cd317a1b4afa9da25f098b2446f5fdd1) changes the product policy. Do not score either policy on the earlier single-server task without explicitly changing its brief and source lineage. The broader interval also includes unrelated application changes.

### Operately #997: company-scoped contributor search

Pair `22ef674d56a5ef07463118bd16c21ca40717855f` → `27888f2428091f04fb1102339d8090e30bb59e1f`. The [accepted patch](https://github.com/operately/operately/commit/27888f2428091f04fb1102339d8090e30bb59e1f) threads the current company into contributor search. Use a visible tenant-isolation ticket, then mixed-company positive results, suspended people, existing contributors, search text and permission-denied requests. Assert result IDs, not only counts. A filter that rejects all people must fail. Useful small application reserve, but it adds less implementation variety than the check-in case.

### Operately #1754: mentions across comment surfaces

Pair `fb9aaa20bdf7f194023a08db2ee5150844d90737` → `cc0a90ef72a6c670d384073cd9935adf2c43e7c6`. [Diff](https://github.com/operately/operately/commit/cc0a90ef72a6c670d384073cd9935adf2c43e7c6). The reported retrospective failure expands in the patch to discussion, retrospective, resource document and file comments. A case testing all four must name those surfaces in the brief. It changes the mention-search container ID, loads the needed discussion space and corrects the resource-hub association. Test actual suggestion lookup and saved mention content with valid and out-of-scope users; a single-screen partial is a meaningful control. Defer until browser preparation and all four scopes have reference evidence. This is predominantly a TypeScript/Elixir application-integration case, not predominantly Elixir implementation.

### LiveBeats changes not selected

| Source | Reason |
| --- | --- |
| [#77 active-user synchronization](https://github.com/fly-apps/live_beats/pull/77/files) | Static reference concern: separate desktop/mobile streams are initialized, but active/inactive handlers mutate only `:active_users`. A contract requiring both views would likely fail. The accepted patch also changes Whisper startup, session salt and unrelated presentation, so it is not a clean reference for sidebar synchronization. No failure was executed. |
| [#68 Whisper transcription](https://github.com/fly-apps/live_beats/pull/68/files) | Seventeen paths spanning native model/media execution and deployment. Much heavier than the earlier playback workflow; offline model/runtime support is unqualified. |
| [#5 song quota](https://github.com/fly-apps/live_beats/pull/5/files) | Plausible feature across five paths, but no added tests, an early pre-notice snapshot, and later counter/import/concurrency changes require a dedicated lineage review. Do not assume the first quota implementation is the corrected target. |
| [#7 duplicate uploads](https://github.com/fly-apps/live_beats/pull/7/files) | Two very small runtime edits and no added tests, predating the notice. Keep as a later focused reserve rather than inflate its scope. Any future oracle must preserve valid mixed uploads according to the explicitly chosen transaction policy. |
| [#27 mixed-case usernames](https://github.com/fly-apps/live_beats/pull/27/files), [#44 untagged MP3](https://github.com/fly-apps/live_beats/pull/44/files), [#20 playlist accessibility](https://github.com/fly-apps/live_beats/pull/20/files) | Inspected small patches, lower priority for the desired coordinated-task mix. Accessibility attribute edits alone must not be sold as a verified keyboard interaction. |
| [Operately #1239 retrospective editing](https://github.com/operately/operately/pull/1239/files) | Real application workflow with feature tests, but the implementation is entirely TypeScript; retain only if deliberately broadening the benchmark to frontend-heavy tasks. |

## Next preparation order

Prepare one Operately API case (#1069 or #1205) and one LiveBeats browser case (#37), then evaluate a third application from the [application catalogue](end-user-application-candidates-2026-10-18.md). Obtain source reconstruction, offline runtime, named unchanged/reference/compiling-partial/integrity controls, independent contract review, three matching fresh qualification rounds and two reviewed blind strong-model successes before admission. Keep this research separate from the inventory and all prior failed attempts.
