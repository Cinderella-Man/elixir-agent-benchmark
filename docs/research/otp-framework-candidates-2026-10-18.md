# New Oban and Phoenix candidate screening — 2026-10-18

This is **source screening, not executed qualification**. No project was built, no tests or model attempts ran, and no latency, throughput or speed measurements were taken. The three detailed leads below are outside the scored inventory. Draft tickets, check names and incomplete controls are curator proposals, not existing case artifacts or observed outcomes.

The investigation followed the [selection guidelines](../pr-selection-guidelines.md), [admission contract](../case-admission.md) and [previous candidate report](multi-file-pr-candidates-2026-10-15.md). It searched existing Markdown records for these repositories before discovery. Oban #744, #1466 and #1199 remain previously screened exclusions; none is presented as new. Phoenix #6840 is a new source identity but overlaps the URL-validation family already represented by the LiveView #4250 proposal.

## Recommendation

| New lead | Substantive implementation paths | Disposition from source inspection |
| --- | ---: | --- |
| [Phoenix #6840](https://github.com/phoenixframework/phoenix/pull/6840), consistent local-path validation | 4 | Best immediate preparation candidate here: service-free ExUnit boundaries and a coherent shared contract. Independently review the inferred ticket; avoid overconcentrating on URL validation. |
| [Phoenix #6762](https://github.com/phoenixframework/phoenix/pull/6762), LongPoll session tokens in headers | 2 | Useful client/server protocol and compatibility coverage. Defer preparation until one supported grading adapter can observe both sides. |
| [Oban #1413](https://github.com/oban-bg/oban/pull/1413), notifier-crash recovery | 3 | Particularly valuable OTP coverage, but **defer the supplied reference**: a later accepted fix establishes duplicate PostgreSQL notification delivery caused by its repeated subscription strategy. Also requires careful source ancestry and test bootstrap work. |

Do not interpret three source leads as three admission-ready cases. The Oban finding is a useful rejection of a superficially attractive reference, and the LongPoll finding identifies concrete adapter work before investment in a bundle.

## 1. Phoenix #6840 — one local-path contract across public consumers

**Kind:** bug fix. **Authorship:** SteffenDE; merged 2026-09-13. The PR body is empty, so the observed problem and draft ticket below are **inferred from the complete implementation/test diff**, rather than attributed to a user report. [PR metadata](https://api.github.com/repos/phoenixframework/phoenix/pulls/6840), [complete diff](https://github.com/phoenixframework/phoenix/pull/6840/files).

**Source identity:** fixed commit `3087baacf8d2f77534045767fa040c9c5b25f22a`; first parent and proposed starting commit `f9ec4fea6b8d9ffbadadba5c85913dc847773456`. The fixed commit's seven changed paths match the PR file inventory. [Commit and ancestry](https://api.github.com/repos/phoenixframework/phoenix/commits/3087baacf8d2f77534045767fa040c9c5b25f22a).

**Draft maintenance ticket:**

> Local redirects, static-asset helpers and unverified route helpers inconsistently accept paths that can escape the expected URL authority, including backslash and control-character variants such as the Elixir string `"/\n/example.com"` containing a newline; fix this. Preserve ordinary local paths, route prefixes and query parameters, explicit external redirects, and the empty path used to obtain an endpoint URL.

The visible source already supplies existing rejection behavior for scheme-relative paths and some unsafe characters. If the acceptance contract expands to a precise list of encoded characters beyond that source, explain the necessary policy in the ticket; do not secretly require every reference branch or exact error prose. The empty-path exception is essential, rather than incidental implementation detail.

### Complete changed-file inventory

| File | Actual role |
| --- | --- |
| `lib/phoenix/controller.ex` | Redirects use consistent local-path classification while retaining their public invalid-path errors. |
| `lib/phoenix/endpoint/supervisor.ex` | Endpoint static lookup applies local-path validation. |
| `lib/phoenix/url.ex` | New shared classifier/validator rejects invalid authority-like paths and browser-sensitive characters. |
| `lib/phoenix/verified_routes.ex` | Applies the contract to unverified paths/URLs, URI-context static paths and per-connection static URL overrides; retains the empty unverified-path exception. |
| `test/phoenix/controller/controller_test.exs` | Adds redirect cases involving newline, carriage return and combined control characters. |
| `test/phoenix/endpoint/endpoint_test.exs` | Covers unsafe `static_path` and `static_integrity` inputs. |
| `test/phoenix/verified_routes_test.exs` | Covers ordinary/empty unverified paths, authority confusion and bypasses through URI/connection static contexts. Also contains incidental formatting. |

All four production paths change executable behavior. This is not merely moving a helper: several consumers previously bypassed validation. A solver may solve the same contract with fewer paths. The exact helper name and internal error taxonomy should not be acceptance requirements. [Shared policy](https://github.com/phoenixframework/phoenix/blob/3087baacf8d2f77534045767fa040c9c5b25f22a/lib/phoenix/url.ex), [public consumers](https://github.com/phoenixframework/phoenix/blob/3087baacf8d2f77534045767fa040c9c5b25f22a/lib/phoenix/verified_routes.ex).

### Proposed functional witnesses

Use separate named assertions so an incomplete repair is diagnosable:

1. `redirect_rejects_browser_sensitive_local_path`: the example newline path raises through `Phoenix.Controller.redirect/2`; ordinary local and explicitly external redirects still work.
2. `endpoint_static_helpers_reject_unsafe_path`: both static path and integrity entry points reject unsafe inputs instead of generating browser-consumable output.
3. `static_override_and_uri_context_validate_inputs`: setting a connection's CDN override and using a `%URI{}` context must not bypass rejection; valid assets still retain their expected CDN/path prefixes.
4. `unverified_helpers_preserve_authority`: reject strings such as `@invalid/landing` that could change the authority when concatenated; preserve ordinary paths, forwarding prefixes and query parameters.
5. `empty_unverified_path_keeps_endpoint_url`: retain the endpoint URL itself, both with and without query parameters.

These names are proposals. The upstream tests give concrete starting examples, including positive cases. [Controller tests](https://github.com/phoenixframework/phoenix/blob/3087baacf8d2f77534045767fa040c9c5b25f22a/test/phoenix/controller/controller_test.exs), [endpoint tests](https://github.com/phoenixframework/phoenix/blob/3087baacf8d2f77534045767fa040c9c5b25f22a/test/phoenix/endpoint/endpoint_test.exs), [route-helper tests](https://github.com/phoenixframework/phoenix/blob/3087baacf8d2f77534045767fa040c9c5b25f22a/test/phoenix/verified_routes_test.exs).

**Plausible incomplete control:** add the shared policy and repair redirects plus endpoint static lookup, but leave the existing `VerifiedRoutes` direct-concatenation paths unchanged. This should compile and pass the first two groups while failing `static_override_and_uri_context_validate_inputs` and `unverified_helpers_preserve_authority`. It has not been constructed or run. Keep a mixed valid/invalid matrix to reject the shortcut of raising for every path. Also preserve empty paths only at interfaces that already accept them; the ticket does not imply that an empty redirect destination becomes valid.

### Historical runtime and remaining questions

The starting [Mix project](https://github.com/phoenixframework/phoenix/blob/f9ec4fea6b8d9ffbadadba5c85913dc847773456/mix.exs) requires Elixir `~> 1.15`, includes a local `installer` dependency, and copies an installer template during compilation. The [pinned CI matrix](https://github.com/phoenixframework/phoenix/blob/f9ec4fea6b8d9ffbadadba5c85913dc847773456/.github/workflows/ci.yml) includes Elixir 1.18.4 / OTP 27.3.4.13, providing a historically exercised pairing to consider, rather than an established benchmark image. The [test helper](https://github.com/phoenixframework/phoenix/blob/f9ec4fea6b8d9ffbadadba5c85913dc847773456/test/test_helper.exs) starts `plug_cowboy` and a router-support file. These selected tests do not require the separate generated-application integration suite or its databases. Inspect and cache the pinned [Mix lockfile](https://github.com/phoenixframework/phoenix/blob/f9ec4fea6b8d9ffbadadba5c85913dc847773456/mix.lock), including the local installer subtree, before an offline preparation attempt.

A proposed acceptance family is an explicit `mix test` command naming the three listed test modules or curated protected counterparts. Node/browser execution is not required to assert the documented Elixir rejection contract. This does not prove every browser URL-parser behavior: use concrete source-justified examples rather than claiming universal browser security coverage. License is [MIT at the starting revision](https://github.com/phoenixframework/phoenix/blob/f9ec4fea6b8d9ffbadadba5c85913dc847773456/LICENSE.md); retain the notice. No private edition or account is apparent in the selected paths. Contract review, offline build, all controls, three fresh qualification rounds and two reviewed blind successes remain outstanding.

## 2. Phoenix #6762 — LongPoll token transport with old-client compatibility

**Kind:** bounded feature. **Authorship:** SteffenDE; merged 2026-07-29. [Issue #6761](https://github.com/phoenixframework/phoenix/issues/6761) reports session-resume tokens in GET URLs and consequent logging/exposure concerns. Its speculation about Cloudflare behavior is not a benchmark requirement; no Cloudflare account or live external service is needed to test token transport. [PR](https://github.com/phoenixframework/phoenix/pull/6762).

**Source identity:** fixed `ea39afce00ff1823375fb0fa2a1b202ded2b2011`; first parent/start `0b7223a8c89062edcc3cf86c5b1ff82ff52978fd`. [Commit and ancestry](https://api.github.com/repos/phoenixframework/phoenix/commits/ea39afce00ff1823375fb0fa2a1b202ded2b2011).

**Draft clarified feature brief:**

> Send LongPoll session-resume tokens in the `X-Phoenix-Longpoll-Token` request header instead of the URL, for both polling and batched pushes. The server must still accept older clients' query tokens; when both are present, use the header. Keep resumed sessions working and mark LongPoll JSON transport responses `Cache-Control: no-store`.

The header name, precedence and cache behavior are public product decisions from the patch. Stating them avoids treating an otherwise reasonable implementation as incorrect because of hidden policy. The title says “configuring,” but the inspected patch changes the default and introduces no new client configuration switch. Do not invent such a requirement. [Complete diff](https://github.com/phoenixframework/phoenix/pull/6762/files).

### Complete changed-file inventory

| File | Actual role |
| --- | --- |
| `assets/js/phoenix/longpoll.js` | Leaves the poll URL unchanged and attaches the session token to request headers for GET and POST. |
| `lib/phoenix/transports/long_poll.ex` | Accepts header/query tokens, propagates the chosen token through resumed poll responses and marks JSON responses non-cacheable. |
| `assets/test/longpoll_test.js` | Jest checks for token headers on polls and batched pushes. |
| `test/phoenix/integration/long_poll_socket_test.exs` | Real local HTTP transport tests, old-query compatibility, header precedence and response cache policy. |
| `CHANGELOG.md` | Documents the new default and rolling-deployment prerequisite. |

This is a two-file implementation task with a real protocol relationship: a new client must resume the same server-side session, and the new server must continue to serve an old client. Server tests alone cannot establish the client half. [Client implementation](https://github.com/phoenixframework/phoenix/blob/ea39afce00ff1823375fb0fa2a1b202ded2b2011/assets/js/phoenix/longpoll.js), [server implementation](https://github.com/phoenixframework/phoenix/blob/ea39afce00ff1823375fb0fa2a1b202ded2b2011/lib/phoenix/transports/long_poll.ex).

### Proposed functional witnesses and adapter work

1. `new_client_poll_and_push_do_not_put_session_token_in_url`: establish a session using the actual client source, observe both subsequent GET and batched POST, assert the token header and absence of the resume token from URLs, and receive the expected session response.
2. `header_token_resumes_same_session`: an identifiable payload stored at initial connection survives a header-authenticated push/poll round trip.
3. `legacy_query_token_still_resumes`: repeat through the old query-token protocol, not a mocked compatibility flag.
4. `header_wins_over_stale_query_token`: send a valid header and bogus query token; verify successful continuation of the correct session. Also use distinct session data so accepting the wrong session cannot pass.
5. `longpoll_json_responses_are_not_cacheable`: inspect the response header on relevant new/resumed/error JSON transport responses justified by the final brief. OPTIONS and unsupported-method responses bypass the reference's JSON response helper; do not silently require the same header on those paths.

Preserve query arguments unrelated to the token, invalid-token handling, denied origins, ordinary messages and independent sessions. The upstream integration module exercises both Bandit and Cowboy; choosing one for initial qualification must be disclosed as reduced server-adapter coverage. [Upstream Jest tests](https://github.com/phoenixframework/phoenix/blob/ea39afce00ff1823375fb0fa2a1b202ded2b2011/assets/test/longpoll_test.js), [local HTTP integration tests](https://github.com/phoenixframework/phoenix/blob/ea39afce00ff1823375fb0fa2a1b202ded2b2011/test/phoenix/integration/long_poll_socket_test.exs).

**Plausible incomplete control:** implement the entire server patch but leave the client unchanged. Old-client compatibility and manually authored header requests should pass, while the named actual-client URL assertion fails. A second useful partial repair adds headers to GET only and omits batched POST. Both are proposed compiling controls, unexecuted.

**Current blocker:** upstream uses ExUnit plus Jest, while a benchmark contract selects one supported adapter. A promising design is a controller-owned Node test file that launches a loopback Phoenix fixture in setup, loads the submitted client source and observes the entire exchange. Browser support may be useful, but is not a substitute for this design. Any bundling must use the submitted source, not stale prebuilt `priv/static` output. Server-start or client-import failures must be setup failures; actual protocol assertions must have individual test identities. Preserve the exact upstream tests separately. Do not wrap `npm test` in one opaque assertion or declare the case solved by testing only the server.

### Historical runtime, deployment scope and license

The starting [Mix project](https://github.com/phoenixframework/phoenix/blob/0b7223a8c89062edcc3cf86c5b1ff82ff52978fd/mix.exs) requires Elixir `~> 1.15`; its [CI](https://github.com/phoenixframework/phoenix/blob/0b7223a8c89062edcc3cf86c5b1ff82ff52978fd/.github/workflows/ci.yml) includes Elixir 1.18.4 / OTP 27.3.4.13 and Node 24.x. The [package scripts](https://github.com/phoenixframework/phoenix/blob/0b7223a8c89062edcc3cf86c5b1ff82ff52978fd/package.json) run Jest with VM modules. The selected HTTP module configures a local endpoint and PubSub rather than a database; its fixed port should become isolated/deterministic in the fixture, with clean server shutdown. Full dependency caching, any asset build and the supported Node fixture still need verification.

The [changelog](https://github.com/phoenixframework/phoenix/blob/ea39afce00ff1823375fb0fa2a1b202ded2b2011/CHANGELOG.md) requires Phoenix 1.8.10 or a later 1.8 release before rolling between old/new nodes. The task should test old clients against the updated server; it should not promise that header-only clients work against arbitrary old servers. Token binding to different socket mounts is a separate issue: [#6791](https://github.com/phoenixframework/phoenix/issues/6791) was still open when inspected, and the existence of closed proposed [#6793](https://github.com/phoenixframework/phoenix/pull/6793) does not establish a merged fix. Do not silently expand this case into mount-binding authorization work. The starting license is [MIT](https://github.com/phoenixframework/phoenix/blob/0b7223a8c89062edcc3cf86c5b1ff82ff52978fd/LICENSE.md).

## 3. Oban #1413 — notifier recovery, with a reference defect to resolve first

**Kind:** bug fix; **disposition:** defer reference and preparation. **Authorship:** QuinnWilton; locally merged by sorentwo on 2026-02-12. The author explicitly says the original finding came from static analysis rather than observed operation. The task is still an accepted upstream repair, but should not be described as a production incident reported by that author. [PR and discussion](https://github.com/oban-bg/oban/pull/1413).

**Draft maintenance ticket, subject to reference correction:**

> After Oban's notifier restarts, dynamic queue start/stop commands and node discovery can stop working, and a notifier outage during staging can crash the stager; fix recovery while preserving normal notification delivery without duplicates.

The last clause is preservation of observable delivery, not a performance requirement. Avoid broadening this to all Oban listeners or promising complete cluster recovery: later [issue #1499](https://github.com/oban-bg/oban/issues/1499) reports producers that still fail to resubscribe, in a newer Oban/Pro configuration. It shows that the PR's scope cannot safely be summarized as “all queues recover after notifier failure.”

### Source ancestry is not the normal merge-parent recipe

The [GitHub PR metadata](https://api.github.com/repos/oban-bg/oban/pulls/1413) reports fixed/merge SHA `e8aa621d418c96632406c9060daa7e90401b18be`, whose immediate parent is `b7042ce7e86cede452670d8a8d95f6c838042442`. That parent already contains the Midwife and Sonar repair. Starting there would discard the central two-file task.

The actual coherent PR range is:

| Role | Exact commit |
| --- | --- |
| Before either repair; proposed PR starting tree | `eb96a30b028aae93722322083b645314906e95d0` |
| Midwife/Sonar repair | `b7042ce7e86cede452670d8a8d95f6c838042442` |
| Stager protection; PR-reported merge/head | `e8aa621d418c96632406c9060daa7e90401b18be` |
| Immediate maintainer follow-up: synchronous Sonar ping and removal of Stager test | `d840ec07fcdbc9d674e38930afdee2e67f9585ce` |

Each is a linear parent of the next. [First repair ancestry](https://api.github.com/repos/oban-bg/oban/commits/b7042ce7e86cede452670d8a8d95f6c838042442), [second repair ancestry](https://api.github.com/repos/oban-bg/oban/commits/e8aa621d418c96632406c9060daa7e90401b18be), [maintainer follow-up](https://github.com/oban-bg/oban/commit/d840ec07fcdbc9d674e38930afdee2e67f9585ce). Record the whole chosen range and explicit follow-ups in provenance; do not pretend `merge^` is the pristine task or silently substitute the later tree.

### Complete PR changed-file inventory

| File | Actual role |
| --- | --- |
| `lib/oban/midwife.ex` | Monitors the notifier and re-establishes dynamic-queue signal subscriptions after replacement. |
| `lib/oban/sonar.ex` | Re-listens during pings and catches notifier-call exits, allowing discovery to recover. |
| `lib/oban/stager.ex` | Contains notification-call exits during global staging. |
| `test/oban/midwife_test.exs` | Kills/restarts the notifier and observes a subsequently created dynamic queue. |
| `test/oban/sonar_test.exs` | Replaces the notifier, triggers a ping and observes external-node discovery without restarting Sonar. |
| `test/oban/stager_test.exs` | Adds a controlled notifier that exits on demand and a staging survival check; subsequently removed by the maintainer. |

All three production files change runtime behavior. [Complete PR diff](https://github.com/oban-bg/oban/pull/1413/files). The immediate follow-up adds a synchronous Sonar call and changes test synchronization; it removes the fake-notifier Stager test as too invasive. This is evidence that test shape and scope deserve review, not permission to omit a material Stager obligation.

### Why the supplied reference is currently unsuitable

[Oban #1441](https://github.com/oban-bg/oban/pull/1441) explicitly traces duplicate PostgreSQL notifier registrations to Sonar repeatedly calling `listen` after #1413. Its [complete diff](https://github.com/oban-bg/oban/pull/1441/files) changes `notifiers/postgres.ex` to deduplicate channel entries and adds the behavioral test `repeated listen calls don't duplicate channel entries or deliver multiple notifications`.

Although the report also discusses CPU growth, the relevant benchmark consequence is **multiple deliveries for one notification**. This can be checked without measuring time or performance. Testing only `Oban.Notifiers.Isolated` would miss the regression in the default PostgreSQL notifier. A reference that recovers listeners but introduces duplicate delivery should not pass a preservation-aware task.

Possible next step: independently review a single coherent recovery contract and construct a separately attributed corrected reference including necessary preservation repair, with explicit reconstruction provenance. Alternatively find another source. Do not combine unrelated PRs to inflate file count, remove PostgreSQL preservation merely to keep the original reference green, or count the later one-file fix as a second independent recovery case.

### Proposed named checks and incomplete control

1. `dynamic_queue_signal_works_after_notifier_replacement`: synchronize confirmed old-process death and new registration, send a queue-start signal, observe the new producer, then stop it. Confirm Midwife ownership/liveness as justified by the frozen contract.
2. `node_discovery_recovers_after_notifier_replacement`: force a ping after replacement and observe a new node through the public status/node interface.
3. `staging_survives_notifier_call_exit`: induce an exit at the actual notifier boundary with an explicit test barrier, observe the same stager process surviving and a later staging operation completing; also verify durable job state. A guard that merely stops staging must fail.
4. `repeated_subscription_delivers_one_notification`: with the real PostgreSQL notifier, deliberately repeat registration and confirm one logical delivery. Use a completion/barrier protocol to bound observation rather than a performance threshold.

**Plausible incomplete control:** repair Sonar and Stager but leave Midwife's original one-time registration. All modules should compile; recovery through dynamic queue control should fail while discovery and outage containment pass. This is a proposed behavioral discriminator, not an executed result.

Keep ordinary signals, ordinary discovery, staging due jobs, future jobs remaining scheduled and repeated restart cycles in the preservation plan. Existing upstream checks use `with_backoff`; the benchmark should replace uncontrolled races with explicit monitored process replacement and message/call barriers where possible. Avoid requiring a newly added synchronous helper on pristine code: a test that calls the follow-up's new `:ping` interface before asserting behavior could fail for the wrong reason. [Original Midwife tests](https://github.com/oban-bg/oban/blob/e8aa621d418c96632406c9060daa7e90401b18be/test/oban/midwife_test.exs), [original Sonar tests](https://github.com/oban-bg/oban/blob/e8aa621d418c96632406c9060daa7e90401b18be/test/oban/sonar_test.exs), [staging behavior](https://github.com/oban-bg/oban/blob/e8aa621d418c96632406c9060daa7e90401b18be/lib/oban/stager.ex).

### Historical environment has a non-obvious multi-database trap

The [starting Mix project](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/mix.exs) requires Elixir `~> 1.15`. [CI](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/.github/workflows/ci.yml) covers Elixir 1.15 / OTP 24.3 and Elixir 1.19 / OTP 28.1, PostgreSQL 12.13/18 and MySQL 8.4/9.1. These are historical inputs to investigate, not a declaration that any arbitrary modern image is compatible.

The [test helper](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/test/test_helper.exs) unconditionally starts PostgreSQL, MySQL/Dolphin and SQLite/Lite repos. The [configuration](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/config/config.exs) lists all three as `ecto_repos`, so plain `mix test.setup` provisions all three. Merely naming the selected test files is not evidence of PostgreSQL-only runtime compatibility. `test/support` is compiled in test mode, and [dependencies](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/mix.lock) include SQLite native-build requirements to audit.

A plausible fixture would use a protected test-helper adaptation that starts only the required repos, explicit PostgreSQL repo creation/migration rather than the all-repo alias, bounded scheduler/pool settings, and the existing PostgreSQL service. Preserve the exact upstream helper/tests separately. This can be a legitimate scope choice because the proposed recovery contract is not a MySQL feature, unlike previously deferred #1199; it still needs proof that the adaptation preserves relevant production behavior. Real PostgreSQL notifications are needed for the regression preservation above, and multi-node clustering remains unqualified. The historical [license is Apache-2.0](https://github.com/oban-bg/oban/blob/eb96a30b028aae93722322083b645314906e95d0/LICENSE.txt); inspected code belongs to public Oban, not Oban Pro.

## Additional leads screened; do not rediscover them as new priorities

| Lead | Inspection and decision |
| --- | --- |
| [Oban #1400](https://github.com/oban-bg/oban/pull/1400/files), period-form snoozes | Complete six-file diff inspected. Three executable paths: `job.ex`, new `period.ex`, `queue/executor.ex`; `worker.ex` changes docs/types/aliases, and two paths are tests/support. A useful bounded feature reserve, but much of the apparent coordination is extracting the existing period conversion. The visible snooze requirement can plausibly be solved in the executor alone, which must be accepted. Upstream tests chiefly assert executor results; real scheduling and preservation of uniqueness-period handling need additional witnesses. Not fully runtime/provenance-qualified in this pass. |
| [Oban #1509](https://github.com/oban-bg/oban/pull/1509/files), releasing jobs after a cancellation race | Complete diff inspected: only `queues/producer.ex` changes. The PR body mentions a regression test, but the recorded changed-file inventory contains no test. Keep as a possible focused one-file task; do not count the advertised test as present or call this a coordinated multi-file task. |
| [Phoenix #6839](https://github.com/phoenixframework/phoenix/pull/6839/files), nil-host handling | Complete two-file diff inspected. Makes endpoint URL building and origin checks use the same `nil`/environment-host fallback. No tests in that PR; [#6850](https://github.com/phoenixframework/phoenix/pull/6850) is a later test lead visible in the discovery inventory, not an inspected or qualified reference here. A small fallback-policy reserve, below the richer workflows above. |
| [Phoenix #6867](https://github.com/phoenixframework/phoenix/pull/6867), connection races | PR body and complete file inventory screened, not the full large test diff. Four implementation files but many separate lifecycle scenarios across Socket, LongPoll, asynchronous encoders/decoders, callbacks and visibility/heartbeat handling. Defer for scope and deterministic test design; satisfying the file-count target does not make this a short coherent initial case automatically. Its body discloses AI assistance; preserve that provenance if revisited. |
| Oban #744, #1466, #1199 | Already screened in the [2026-10-15 record](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals): executable one-file change, test-only change and unsupported central MySQL capability respectively. They were excluded before this new shortlist. |

## Evidence boundaries and next work

Public GitHub REST metadata, PR files/patches, commit ancestry, comments/reviews, relevant follow-up searches and pinned raw source were inspected. For the three detailed PRs, every returned file patch's added/deleted line counts matched its API totals, and full fixed files were fetched for context; no missing patch was treated as a complete diff. Discovery examined one recent closed-PR page for each repository plus targeted follow-ups, not all historical PRs. Network requests within this research process were sequential.

Before admission, independently review each minimal solver-visible contract before exposing hidden checks; map each obligation to a named assertion; preserve exact upstream provenance; construct and execute unchanged/reference/plausible-incomplete/integrity controls; obtain three fresh matching qualification rounds; then obtain two reviewed fresh blind strong-model successes. Keep source-screening decisions, functional qualification, model validation and any future separately authorized performance work distinct. These findings establish useful preparation priorities and concrete reasons to defer, not benchmark scores or demonstrated solvability.
