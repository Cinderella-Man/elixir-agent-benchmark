# Additional Elixir projects and corrected feature candidates — 2026-10-18

This is **source screening, not executed qualification**. The strongest new leads from this pass are Absinthe document descriptions, Broadway custom batch splitting with its later timer correction, and Bandit opt-in streaming compression. They add language processing, stateful message batching, and HTTP response serialization. None is ready for admission: no project builds, tests, fixture controls, model attempts, or performance measurements were run.

The review follows the [selection guidelines](../pr-selection-guidelines.md) and [admission contract](../case-admission.md). Existing research notes and rejected-case records were screened before proposing these projects; these sources were not previously listed there. In particular, this report does not relabel any previously screened Phoenix, Oban, Ecto, Plug, Livebook, or Plausible source as new. A feature and its coherent later corrections may form one case, but a broad chronological commit interval is not automatically a coherent reference patch.

## Recommendations and evidence boundary

| Source | Substantive implementation scope | Disposition | Main outstanding issue |
| --- | --- | --- | --- |
| Absinthe [#1404](https://github.com/absinthe-graphql/absinthe/pull/1404) | 6 implementation paths; 1 test path | First preparation candidate; coherent exception to the 2–5 preference | Prove named failures on pristine code without new-struct compilation errors; review execution preservation |
| Broadway [#289](https://github.com/elixir-broadway/broadway/pull/289) + [602931c](https://github.com/elixir-broadway/broadway/commit/602931c981d194c6e07e699ab45b6e3747cf44a0) | 3 unique implementation paths; 1 upstream test path | Strong combined-outcome candidate | Deterministic timer regression and composite-source provenance |
| Bandit [#707](https://github.com/mtrudel/bandit/pull/707) | 3 implementation paths; 3 test paths | Strong candidate conditional on runtime preparation | Full zstd streaming needs OTP 29; inspected inherited CI matrix stops at OTP 28 |
| Bandit [#671](https://github.com/mtrudel/bandit/pull/671) + [#688](https://github.com/mtrudel/bandit/pull/688) + [d88b219](https://github.com/mtrudel/bandit/commit/d88b21953c65061f21136ea76a89a4f95a2ac7a1) | 5 unique implementation paths across logical lineage | Defer extraction and grading design | Intervening refactoring, deterministic deadline checks, broader visible contract |
| Absinthe [#1386](https://github.com/absinthe-graphql/absinthe/pull/1386) + [#1394](https://github.com/absinthe-graphql/absinthe/pull/1394) + [#1438](https://github.com/absinthe-graphql/absinthe/pull/1438) + [#1439](https://github.com/absinthe-graphql/absinthe/pull/1439) | 5 Elixir implementation paths + 1 shipped GraphQL query | Defer: even the combined reference has an unresolved contract defect | Explicit-null handling contradicts the cited GraphQL specification |

Counts describe the logical patches, not all files changed between the earliest and latest upstream revisions. A combined case must record each source patch, curator adaptations, and its actual derived fixed tree. These are public sources with exposure risk; file count, recency, and author or model identity do not establish difficulty or unseen status.

Complete implementation and test diffs were inspected for the three main entries and the corrective lineages discussed below. Historical `mix.exs`, lockfiles, CI configuration, test setup, and license files were inspected for the main projects. Search/history checks were bounded: the Absinthe parser/description history, Broadway batcher history, and Bandit compression/connection histories were examined for relevant corrections. “No later correction found” below means in that inspected evidence, not an exhaustive guarantee. Smaller leads in the final ledger distinguish inventory-only screening from full-diff inspection.

The only local source experiment was text manipulation in a temporary directory: both Broadway patches applied in sequence, and the resulting three implementation files matched the later correction's pinned versions byte for byte. This executed no Elixir code and proves neither compilation nor behavior, nor equality of the complete repository tree.

## 1. Absinthe: preserve descriptions across the document pipeline

**Source and identity.** Feature, clarified implementation brief, public GraphQL parser/representation/rendering family. [PR #1404 and its full diff](https://github.com/absinthe-graphql/absinthe/pull/1404/files), merged 2026-04-03, was authored by `jwaldrip`; its description discloses Claude Code assistance. Preserve that provenance and the upstream review record rather than claiming independent human authorship of the reference.

| Revision role | Exact SHA |
| --- | --- |
| Starting parent | `8fba7023f944e093036b89131b9e47a4ad2f7ecc` |
| Merged fixed commit | `c029a611640a764b687f6e3b5ce647880eff99fd` |

The [fixed commit's ancestry](https://github.com/absinthe-graphql/absinthe/commit/c029a611640a764b687f6e3b5ce647880eff99fd) supplies the parent; this is a single-commit source, with no synthetic composite required. No later description correction was identified in the inspected parser history and targeted description search.

**Why six files are coherent.** The new information must survive three representations and rendering. `src/absinthe_parser.yrl` accepts descriptions; `lib/absinthe/language/operation_definition.ex` and `lib/absinthe/language/fragment.ex` retain them in parsed nodes and pass them onward; `lib/absinthe/blueprint/document/operation.ex` and `lib/absinthe/blueprint/document/fragment/named.ex` retain them in execution blueprints; `lib/absinthe/language/render.ex` emits them. These are six data-bearing implementation changes, including small but necessary struct-field changes, not six independent fixes. The seventh path, `test/absinthe/document_description_test.exs`, contains the upstream regression matrix. No generated parser output should be counted as a separate implementation path. [Implementation and tests](https://github.com/absinthe-graphql/absinthe/pull/1404/files).

**Draft solver brief.**

> Support string and block-string descriptions on named GraphQL queries, mutations, subscriptions, and fragments. Preserve descriptions through parsing, Blueprint conversion, and rendering, without changing execution or the behavior of documents without descriptions.

This identifies requested public behavior without naming source files or grammar edits. It deliberately does not claim complete conformance to every change in GraphQL September 2025. The [specification's document-description semantics](https://spec.graphql.org/September2025/#sec-Executable-Definitions) support treating descriptions as metadata, not execution instructions. Named operations/fragments are the proposed scope; acceptance of other syntactic placements needs independent review before adding checks.

**Proposed named checks and controls.**

| Named outcome | Discriminating observation |
| --- | --- |
| `descriptions survive parsing and blueprint conversion` | Named operation and fragment nodes retain normalized string/block-string text; distinguish an empty description from an absent description |
| `rendered descriptions survive a document round trip` | Render and reparse a mixed document; operation and fragment descriptions, variables, directives, and definition order remain associated correctly |
| `descriptions do not alter execution` | Equivalent described and undescribed operations return the same result against a small local schema; mixed documents retain all needed definitions |
| `ordinary documents retain their behavior` | Undescribed named operations, shorthand queries, fragments, variables, and directives still parse/render/execute |

The upstream tests cover parsing, all three named operation kinds, fragments, string forms, representation conversion, rendering, and mixed documents. The execution-preservation witness above is a proposed curator addition, not an executed upstream result. A plausible incomplete control implements parsing plus AST/Blueprint propagation but omits descriptions when rendering. It should compile, pass the parsing check, and fail the named round-trip outcome. An operation-only implementation provides a second useful alternative failure shape; do not require either specific implementation structure from model submissions. [Upstream tests](https://github.com/absinthe-graphql/absinthe/blob/c029a611640a764b687f6e3b5ce647880eff99fd/test/absinthe/document_description_test.exs).

**Starting-state hazard.** Blindly overlaying tests containing `%NewOrChangedStruct{description: ...}` can fail compilation against the parent before any test body runs. Curated checks should access newly introduced metadata through `Map.get/2` after asserting successful parsing inside a named test. The pristine parser's unsupported description must become a named behavior failure. The exact upstream tests remain separately preserved under the admission contract.

**Runtime and license.** The [parent's Mix project](https://github.com/absinthe-graphql/absinthe/blob/8fba7023f944e093036b89131b9e47a4ad2f7ecc/mix.exs) requires Elixir `~> 1.15`, adds the Yecc compiler, and compiles test support. Its [CI matrix](https://github.com/absinthe-graphql/absinthe/blob/8fba7023f944e093036b89131b9e47a4ad2f7ecc/.github/workflows/ci.yml) includes Elixir 1.17–1.19 and OTP 25–28 with exclusions and both ordinary and persistent-term schema-provider runs. A historical pairing such as Elixir 1.18/OTP 27 is a preparation lead, not an executed compatibility claim. [Test setup](https://github.com/absinthe-graphql/absinthe/blob/8fba7023f944e093036b89131b9e47a4ad2f7ecc/test/test_helper.exs) uses ExUnit and local schema managers; the candidate does not require a database, browser, or remote GraphQL server. Dependencies must be prepared from the [historical lockfile](https://github.com/absinthe-graphql/absinthe/blob/8fba7023f944e093036b89131b9e47a4ad2f7ecc/mix.lock), and parser generation must be included in the offline preparation identity. The project carries an [MIT license](https://github.com/absinthe-graphql/absinthe/blob/8fba7023f944e093036b89131b9e47a4ad2f7ecc/LICENSE.md).

**Next action.** Prepare this project first if a low-service new-project pilot is wanted. Review the brief and named assertions independently, then establish compilation, unchanged/reference/incomplete/integrity controls, three fresh matching qualification rounds, and blind solvability. None of those gates has been completed here.

## 2. Broadway: custom batch splitting with correct timer lifecycle

**Source and identity.** Feature, clarified implementation brief, local OTP pipeline/state family. [PR #289](https://github.com/elixir-broadway/broadway/pull/289), merged 2022-11-05 by author `kenspirit`, adds custom splitting. A later [timer-lifecycle correction](https://github.com/elixir-broadway/broadway/commit/602931c981d194c6e07e699ab45b6e3747cf44a0), dated 2023-01-18, repairs an assumption that expired timer messages have already arrived. The repository has moved from `dashbitco/broadway` to `elixir-broadway/broadway`; the linked source identity is the same project.

| Revision role | Exact SHA |
| --- | --- |
| Feature starting parent | `45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d` |
| Feature merged commit | `cfb8117061f4dcec18035717c35e9b26d6c31dc2` |
| Later correction's immediate parent | `214c0e48ef07bcd3852a8deee42861fc2b75dfa9` |
| Later corrected upstream commit | `602931c981d194c6e07e699ab45b6e3747cf44a0` |

These are component-source identities. There is no recorded full synthetic fixed-tree SHA for the compact two-patch case yet. Using the full chronological interval would import unrelated work. The exact [feature diff](https://github.com/elixir-broadway/broadway/pull/289/files) and correction diff both applied textually to the feature parent in sequence; the three resulting implementation files matched their versions at `602931c` exactly. This supports selective extraction, but does not satisfy the current full-tree source-reconstruction contract by itself.

**Coordinated scope.** Three implementation paths and one upstream test path:

- `lib/broadway.ex` validates the relationship between custom `batch_size` and explicit `max_demand`; its change is executable, not only documentation.
- `lib/broadway/options.ex` validates a positive integer or `{initial_accumulator, function/2}` and exposes `max_demand`.
- `lib/broadway/topology/batcher_stage.ex` owns per-batch state, invokes the splitter, emits real batch lengths and reasons, and coordinates key/partition state with timers. The later correction only changes this path.
- `test/broadway_test.exs` supplies the upstream feature tests, including manual producers, custom splitting, configuration rejection, key isolation, and flushing. The later correction has no accompanying test addition; a curator regression is essential. [Feature diff](https://github.com/elixir-broadway/broadway/pull/289/files), [correction](https://github.com/elixir-broadway/broadway/commit/602931c981d194c6e07e699ab45b6e3747cf44a0).

The PR body's early proposal describes a different accumulator convention. Freeze the contract from the merged implementation/documentation, not that stale prose.

**Draft solver brief.**

> Allow a batcher's `batch_size` to be either a positive integer or `{initial_accumulator, splitter}`, where the two-argument splitter receives a message and accumulator and returns `{:cont, accumulator}` or `{:emit, accumulator}`. Custom splitters require an explicit positive `max_demand`. Start each batch with its own initial accumulator, isolate batches by their existing key/partition rules, and preserve integer batching, flush, timeout, shutdown, and acknowledgement behavior without losing or duplicating messages.

This is a clarified feature brief because callback shape, demand policy, and per-batch state are API decisions. The merged implementation reinitializes state for each new batch; do not silently score an alternative interpretation that retains the emitted accumulator into a later batch.

**Proposed named checks and controls.**

| Named outcome | Discriminating observation |
| --- | --- |
| `custom splitting respects accumulated message state` | Use heterogeneous message payloads to cross a content-based threshold; assert exact ordered batch contents and actual `BatchInfo.size` |
| `custom state is isolated across keys and new batches` | Interleave two keys with different content totals and emit multiple batches per key; each fresh batch starts from its initial accumulator |
| `invalid custom configuration is rejected` | Wrong splitter arity, malformed tuple, and missing/invalid `max_demand` are rejected at startup; valid integer configuration still starts |
| `flush and shutdown preserve pending messages` | Explicitly synchronize production, flushing/draining, and acknowledgement; assert each message appears once with the correct batch reason |
| `late expired timers do not crash or flush a replacement batch` | Exercise the expired-but-not-yet-delivered state, complete the old batch, start another with the same key, then deliver the stale timeout; the new batch remains intact |
| `integer batching and normal timeout delivery remain valid` | Existing fixed-size splitting and a current batch's own timeout still emit the expected messages and acknowledgements |

The last two timer checks are needed because the correction separates a batch identity from its timer and ignores stale timeout messages. Previously, failure to cancel an expired timer followed by a zero-wait receive could raise when that timer's message was not yet available. A stale message must also not act on a replacement batch with the same key. [Correction source](https://github.com/elixir-broadway/broadway/commit/602931c981d194c6e07e699ab45b6e3747cf44a0).

The original feature patch without the later timer correction is a plausible compiling incomplete control for the combined outcome. A separate partial implementation that handles one key but shares accumulator state should fail the isolation check. Both are hypotheses until qualification. Deterministic timer delivery needs careful construction: a callback-level fixture can control the timer state and mailbox ordering, but its connection to a reachable pipeline state must be reviewed, and public pipeline preservation checks must remain. Sleeps that merely hope to hit the ordering are insufficient.

**Runtime and license.** The [feature parent's Mix project](https://github.com/elixir-broadway/broadway/blob/45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d/mix.exs) requires Elixir `~> 1.7`, with GenStage, NimbleOptions, and telemetry dependencies. [Historical CI](https://github.com/elixir-broadway/broadway/blob/45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d/.github/workflows/ci.yml) uses Elixir 1.7.4/OTP 21.3.8.17 and 1.13.3/OTP 24.2.1 on Ubuntu 18.04. The newer historical pair is a sensible compatibility investigation target; availability in the current fixture toolchain remains unknown. The [local test module](https://github.com/elixir-broadway/broadway/blob/45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d/test/broadway_test.exs) defines a manual producer; no Kafka/RabbitMQ/SQS service is needed. Pin the [lockfile](https://github.com/elixir-broadway/broadway/blob/45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d/mix.lock), use plain local ExUnit rather than CI coverage upload commands, and set processor/batcher concurrency explicitly to one where isolation is intended. The project is [Apache-2.0 licensed](https://github.com/elixir-broadway/broadway/blob/45ee6bf6ff09e2a0cdc3ed6c56fc37e14e25c18d/LICENSE).

**Next action.** Resolve composite provenance and a deterministic, named timer witness before constructing a case bundle. No later correctness change to the batcher was found in the inspected path history; that bounded search does not remove the need for full qualification.

## 3. Bandit: opt-in streaming compression and codec fallback

**Source and identity.** Feature, clarified implementation brief, HTTP adapter/compression lifecycle family. [PR #707](https://github.com/mtrudel/bandit/pull/707), authored by `iStefo`, merged 2026-10-12. Its body discloses Claude Code assistance and the merge commit retains an AI co-author trailer. Record this alongside Absinthe #1404's disclosure as provenance/exposure metadata: neither automatic exclusion nor independent proof of agent solvability follows. This candidate concerns readable incremental output, framing, and codec selection. Upstream throughput or memory claims are not part of the proposed task or evidence.

| Revision role | Exact SHA |
| --- | --- |
| Starting parent | `d88b21953c65061f21136ea76a89a4f95a2ac7a1` |
| Merged fixed commit | `fb95a179b5e333f8bf7b65a1dca88807746ca11b` |

The [commit ancestry](https://github.com/mtrudel/bandit/commit/fb95a179b5e333f8bf7b65a1dca88807746ca11b) fixes this single-PR baseline. It already contains the HTTP/2 security correction described later in this report; do not remove that unrelated prior behavior to manufacture extra scope. No subsequent compression correction was found in the inspected history as of this research.

**Coordinated scope.** Three implementation files and three tests. `lib/bandit.ex` adds the opt-in `compress_chunked` option to the executable allowlist as well as documentation. `lib/bandit/adapter.ex` carries negotiated encoding preferences and coordinates response lifecycle and byte accounting. `lib/bandit/compression.ex` chooses an encoding that can stream, manages gzip/zstd state, flushes chunks, consumes zstd input remainders, and finishes/releases the compressor. The tests cover HTTP/1 protocol, HTTP/1 telemetry, and HTTP/2 protocol behavior. [Complete diff](https://github.com/mtrudel/bandit/pull/707/files).

**Draft solver brief.**

> Add opt-in `compress_chunked` support for negotiated gzip, x-gzip, and zstd responses, so each application chunk can be decoded before the response finishes. Preserve the default behavior, response framing, and existing compression exclusions. If a preferred accepted codec cannot stream on the running OTP version, use the next supported accepted encoding.

The option remains off by default, as settled in the upstream review. The task is functional: decoding before an explicit server continuation signal is an ordering/capability assertion, not a latency target.

**Proposed named checks and controls.**

| Named outcome | Discriminating observation |
| --- | --- |
| `gzip and x-gzip chunks decode before completion` | Server emits one chunk and waits for an explicit test message; client decodes it, permits the next chunk, then verifies the complete payload and final trailer |
| `zstd streaming consumes all input and flushes each chunk` | Same synchronization on OTP 29, plus a bounded seeded payload that exercises the API's unconsumed-input path; exact decoded bytes must match |
| `codec fallback respects available streaming support` | On a separately pinned runtime without zstd flush, zstd-first negotiation chooses the next accepted supported codec rather than silently dropping available compression |
| `compression remains opt-in and exclusions remain valid` | Default gzip behavior remains unchanged; existing deflate behavior is preserved; length-delimited streams, no-transform/already-encoded responses, strong ETags, and bodyless/excluded responses retain their appropriate semantics |
| `ordinary responses and telemetry remain coherent` | Non-streamed responses still decode correctly; method and byte accounting agree with the transmitted representation without scoring elapsed time or exact compressor-dependent output sizes |

A plausible incomplete control accepts the option and produces a valid final compressed body but omits per-chunk flushing. It should compile and pass final-body decoding while failing the first named streaming check. Another control implements gzip correctly but leaves the zstd remainder path incomplete. Its failure must be a named decoded-content assertion, not an unsupported-runtime setup crash. Actual compilation and discriminating failures remain unverified.

The upstream change adjusts exact compressed byte counts and includes telemetry assertions with a duration upper bound. Those are not suitable task requirements. Preserve exact upstream tests separately, and adapt curated checks to semantic byte accounting and explicit synchronization. Do not execute latency bounds here as qualification, and do not substitute a compression-ratio score. A watchdog may detect a hang; its elapsed time is not evidence about speed. [Upstream tests and review](https://github.com/mtrudel/bandit/pull/707/files).

**Runtime gap that matters.** The new zstd path checks for `:zstd.flush/1`, documented as available since OTP 29.0. The API flushes pending output while leaving a stream open. [Official Erlang documentation](https://www.erlang.org/doc/apps/stdlib/zstd.html#flush/1). The [parent's workflow](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/.github/workflows/elixir.yml) calls a [pinned shared workflow](https://github.com/mtrudel/elixir-ci-actions/blob/18c287f5666c0873f6c8c585551b9416694a731c/.github/workflows/test.yml) whose default OTP matrix is 26, 27, and 28. Therefore the inspected workflow does not establish execution of the new zstd-flush branch. A full feature case needs an explicitly prepared OTP 29 runtime. An older-runtime fallback check needs a second declared functional compatibility environment, or a transparently narrower case contract; skipping the central branch is not success.

The [historical Mix project](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/mix.exs) declares Elixir `~> 1.13`, Thousand Island `~> 1.5`, Plug `~> 1.18`, WebSock, HPAX, and telemetry, with Req/Finch among development/test dependencies. The PR author reports testing OTP 29/Elixir 1.20 and OTP 28/Elixir 1.19; these are upstream claims, not independently reproduced qualification. The [lockfile](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/mix.lock) and OTP/Elixir pairing need actual preparation checks; a declared Elixir minimum does not establish OTP 29 support. [Test helpers](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/test/support/server_helpers.ex) use loopback and ephemeral ports with repository-local TLS material. Use bounded connection/process counts and explicit teardown; no external service or browser is needed. The [test entry point](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/test/test_helper.exs) excludes `:slow` tests by default, so required checks must not silently disappear through tag configuration. The project carries an [MIT license](https://github.com/mtrudel/bandit/blob/d88b21953c65061f21136ea76a89a4f95a2ac7a1/LICENSE).

**Next action.** Establish OTP 29 offline preparation and a first-chunk handshake fixture. Independently review which compression exclusions belong in preservation, then perform the ordinary admission controls. This is a promising bounded feature, but source review alone does not demonstrate the zstd reference works.

## 4. Deferred Bandit lineage: blocked HTTP/2 sends and deadlines

This is a useful alternative for OTP lifecycle coverage, but the compact case is less ready than #707. [#671](https://github.com/mtrudel/bandit/pull/671) adds cancellation and expiry for sends blocked by HTTP/2 flow control. [#688](https://github.com/mtrudel/bandit/pull/688) handles resets while blocked on a stream's own window. The later [security correction d88b219](https://github.com/mtrudel/bandit/commit/d88b21953c65061f21136ea76a89a4f95a2ac7a1), associated with [GHSA-69m6-wcv4-rwcf](https://github.com/mtrudel/bandit/security/advisories/GHSA-69m6-wcv4-rwcf), prevents small or empty updates from perpetually renewing a blocked send's deadline. These changes concern one lifecycle, but the final corrected behavior requires more than the original PR.

| Revision role | Exact SHA |
| --- | --- |
| #671 starting parent | `d38cf046c9a3cae4d0f88001c2ceb4143f86366b` |
| #671 merged commit | `f6914aad14bb1365dd6f306aa592cfb0819bed3e` |
| #688 immediate parent | `9c66edc5934cbb8f79d3629be00e57082a73eafd` |
| #688 merged commit | `6dec0557c6d820e5c849a5134bdde46f51dd1ddc` |
| Security correction immediate parent | `ee85a5667bb569b14bf3f1f75fe94dbd20175823` |
| Security correction fixed commit | `d88b21953c65061f21136ea76a89a4f95a2ac7a1` |

The unique logical implementation scope is five paths: HTTP/2 `connection.ex`, `handler.ex`, `stream.ex`, `stream_collection.ex`, and `flow_control.ex`. #671 changes four of those; #688 only revisits `stream.ex`; the final correction changes `connection.ex`, `stream.ex`, and `flow_control.ex`. The protocol-test path is reused, with changelog metadata in the security correction. Counting those modifications repeatedly would inflate the case. Conversely, the full chronological interval contains unrelated work and cannot be used as this logical scope. [#671 diff](https://github.com/mtrudel/bandit/pull/671/files), [#688 diff](https://github.com/mtrudel/bandit/pull/688/files), [security diff](https://github.com/mtrudel/bandit/commit/d88b21953c65061f21136ea76a89a4f95a2ac7a1).

The correction preserves a deadline across retries and grants bounded credit for bytes actually sent. It cannot be faithfully represented as “reset a timeout after every frame.” The proposed observable contract is: blocked sends release on peer reset or expiry, terminated streams do not retain queued bytes, zero/tiny progress cannot renew a blocked send indefinitely, and valid continuing progress can finish normally. If exact deadline/credit constants are scored, the clarified brief must disclose them; they are not fair hidden policy choices.

Proposed named outcomes are `reset releases a connection-window-blocked sender`, `reset releases a stream-window-blocked sender`, `terminated streams never emit stale pending bytes`, `non-progress frames cannot renew a send forever`, and `valid window progress still completes the response`. The original #671+#688 implementation without the final correction is a plausible incomplete control for the renewal check. Upstream socket tests include sleeps, slow tags, and real multi-second deadline waits; those are inspected source, not executed evidence. A stronger design should use deterministic logical time for deadline decisions and synchronized socket fixtures for cancellation. Watchdogs identify hangs only; neither these tests nor deadline arithmetic should become latency/throughput measurements.

Selective extraction also crosses [#673](https://github.com/mtrudel/bandit/pull/673), an intervening pending-send performance refactor. Do not import it merely to make a patch apply or count it as another functional requirement. The compact source patch needs its own reviewed derivation and fixed-tree identity; textual application of this three-part lineage has not been established. Runtime/license considerations are similar to #707 but do not require zstd or OTP 29. **Disposition: defer** until a compact reference, sufficient brief, and deterministic meaningful deadline control exist.

## 5. Deferred Absinthe lineage: OneOf still needs contract repair

The apparent feature-plus-fixes opportunity is [OneOf input objects #1386](https://github.com/absinthe-graphql/absinthe/pull/1386), followed by [empty/all-null validation #1394](https://github.com/absinthe-graphql/absinthe/pull/1394), [introspection #1438](https://github.com/absinthe-graphql/absinthe/pull/1438), and [nested/list validation #1439](https://github.com/absinthe-graphql/absinthe/pull/1439). Full implementation and test changes were inspected. Combining them is coherent in subject, but it does not automatically create a sound reference.

| Component | Immediate parent | Merged fixed SHA |
| --- | --- | --- |
| #1386 | `4230cc4a33ec8dc00ae5f8650cb012e652780738` | `01e8e4b67dd8c380094cb6cf66d2a7f6da661a68` |
| #1394 | `77155e3f5593d802e24b94cf49f9d78e3541fcab` | `a035261bd0172d84c1d8ac72f74d72e64aaa4769` |
| #1438 | `dd5e2aa680ec3aedb29f9461f7727b32eec237f6` | `112f05162ad5a70cccab614cbb30052eead2e82d` |
| #1439 | `112f05162ad5a70cccab614cbb30052eead2e82d` | `b9023869a56a822983d90880bfc21092a1a68bbf` |

The combined logical scope contains five Elixir implementation paths—document validation, schema validation, pipeline, prototype notation, and introspection—plus the shipped `priv/graphql/introspection.graphql` query, which is a real consumer and should be counted separately as a sixth behavioral path. Tests and changelog edits do not increase that count.

Two explicit source discrepancies block using the combined upstream patch as a standards-conforming reference. The document validator counts non-null fields, and an upstream test accepts an object with one populated field plus another explicitly null field. The specification requires exactly one supplied entry before coercion, so that input should fail. The schema validator also insists on at least two fields, while the specification permits an input object with one or more fields. It requires nullable members without defaults; the inspected OneOf validator has no default-value check, leaving an additional question about the wider validation pipeline. These are source-review findings, not test-run results. [OneOf specification](https://spec.graphql.org/September2025/#sec-OneOf-Input-Objects), [original implementation/tests](https://github.com/absinthe-graphql/absinthe/pull/1386/files), [null-count correction](https://github.com/absinthe-graphql/absinthe/pull/1394/files), [nested validation correction](https://github.com/absinthe-graphql/absinthe/pull/1439/files).

**Disposition: defer, do not rediscover as a corrected complete feature.** Reconsider only with an independently reviewed contract and corrected reference, or an explicitly narrower compatibility task that is honest about the behavior. If prepared later, nested lists, variables, explicit-null versus absent fields, valid one-field schemas, and `isOneOf` introspection are distinct required witnesses. Schema fixtures invoking a previously missing directive at module compilation can turn the pristine control into a setup crash; schema creation must occur within named assertions or another reviewed test boundary. No synthetic fixed tree or extraction proof was produced for this lineage.

## Other screened leads and reasons not to promote them here

| Source | Screening depth and disposition |
| --- | --- |
| Absinthe [#1290](https://github.com/absinthe-graphql/absinthe/pull/1290) | Full diff inspected. Nested argument/variable validation; one implementation file plus tests/changelog. Keep as a focused reserve, not a multi-file discovery. |
| Absinthe [#1336](https://github.com/absinthe-graphql/absinthe/pull/1336) | Full diff inspected. Individual unsubscription on a shared topic; one implementation file and a test. Useful focused lifecycle reserve. |
| Absinthe [#1341](https://github.com/absinthe-graphql/absinthe/pull/1341) | File patches inspected. Preserving extension metadata from subscription configuration errors; one implementation file, one test, changelog. Focused reserve. |
| Absinthe [#1391](https://github.com/absinthe-graphql/absinthe/pull/1391) | File inventory/API metadata screened only. GraphQL sigil and formatter configuration: two implementation paths, one of them a small formatter configuration change. Potential bounded interface task; not deeply qualified here. |
| Broadway [#362](https://github.com/elixir-broadway/broadway/pull/362) | File patches inspected. Terminator call/cast ordering change; one implementation file and no added regression. Functional race candidate, but lacks multi-file scope and a demonstrated deterministic witness. |
| Broadway [#344](https://github.com/elixir-broadway/broadway/pull/344), [#345](https://github.com/elixir-broadway/broadway/pull/345), [#346](https://github.com/elixir-broadway/broadway/pull/346) | #344 inventory screened, not fully reviewed; follow-up patches inspected. Config-storage interface/backends with module-loading and ETS-name corrections. Original motivation includes performance. Do not promote on that basis; reconsider only for an independently justified observable interface/refactor contract. |
| Bandit [#624](https://github.com/mtrudel/bandit/pull/624) + [#695](https://github.com/mtrudel/bandit/pull/695) | Full diffs inspected. Expect/100-continue behavior plus later correction; still only one unique implementation file. Combining related PRs does not make this a multi-file task. Keep as a focused HTTP reserve. |
| Bandit [#673](https://github.com/mtrudel/bandit/pull/673) | Pending-send performance refactor identified in corrective-lineage history. Exclude as an independent functional task; do not add its speed claims to this machine's evidence. |

## What remains before any case is admitted

The proposed briefs and assertions are curator drafts. They have not received the independent contract review required by this repository. Runtime availability, offline dependency preparation, initial/reference compilation, and named control behavior remain unknown unless explicitly stated as text-only evidence above. Preserve exact upstream implementation/tests/docs and authorship, identify any composite fixed tree honestly, and keep acceptance adaptations distinct from upstream tests.

Preparation should start with Absinthe #1404, then Broadway if its deterministic timer fixture and provenance can be resolved. Bandit #707 is the strongest third project once OTP 29 support is demonstrated. Complete a candidate's unchanged/reference/incomplete/integrity controls and three fresh qualification rounds before blind model validation, preserve every outcome, and retain the existing inventory until the admission gates are actually met. No candidate was imported or added to the benchmark by this report.
