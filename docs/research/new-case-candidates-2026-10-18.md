# New benchmark candidates and the exclusion history

Researched **2026-10-18**. This is a discovery and source-review report, not an admission record. No candidate was imported, built, qualified, independently approved, or attempted by a model. The active nine-case inventory, existing policies and prior results are unchanged. No speed benchmarks or performance measurements were run.

Read this alongside the [selection-methodology findings](case-selection-evidence-2026-10-18.md) and the [new Phoenix/Oban investigation](otp-framework-candidates-2026-10-18.md). The governing rules remain [PR selection](../pr-selection-guidelines.md), [case admission](../case-admission.md) and the [blind-validation ADR](../adr/0009-validate-minimal-tasks-with-blind-model-attempts.md).

**Follow-up:** the [second research pass](expanded-case-research-2026-10-18.md) adds application and new-project candidates and investigates corrected features spanning several PRs. Its [Ecto/Plug lineage study](corrected-feature-lineages-2026-10-18.md) supplies new evidence for reconsidering selected families. Holds below describe the original references; they are not blanket exclusions of a newly constructed and qualified corrected feature.

## Recommendation

Prepare **Ecto #4750** and **Plug #1269** first among the new discoveries. They add distinct query-binding and adapter/API work, have ordinary ExUnit boundaries, and have historical dependency locks. **Ecto SQL #699** is a useful next feature candidate across several responsibilities. **Phoenix #6840** is a promising coordinated repair, with the family-overlap caveat below. These rankings concern curation value and preparation risk, not measured difficulty or runtime performance.

For the existing policy's initial three-project pilot, retain the already-screened **Livebook #3169** as the supported-project candidate and choose two new projects from the new shortlist or the previously screened **Ecto #4726**. The earlier candidates are still outstanding; this research does not replace them or call them new.

| New source | Kind / coverage contribution | Substantive scope | Recommendation and principal uncertainty |
| --- | --- | --- | --- |
| [Ecto #4750](https://github.com/elixir-ecto/ecto/pull/4750) | Repair; query construction → dynamic expansion → parameter binding | 2 implementation, 2 test files | First drafting cohort. Challenge nested scopes, repeated legitimate values and interpolation side effects. |
| [Plug #1269](https://github.com/elixir-plug/plug/pull/1269) | Feature; public connection API → optional adapter → test construction | 3 runtime implementation files, 1 callback/type declaration file, 2 test files | First drafting cohort. Strengthen the upstream custom-value witness and make unsupported-adapter semantics visible. |
| [Ecto SQL #699](https://github.com/elixir-ecto/ecto_sql/pull/699) | Feature; migration option → dialect DDL → creation logging | 5 implementation, 4 test files | Next drafting cohort. A service-free SQL-generation contract is plausible; historical driver availability and offline execution remain unverified. |
| [Phoenix #6840](https://github.com/phoenixframework/phoenix/pull/6840) | Repair; local-path policy across controller, endpoint and route helpers | 4 implementation, 3 test files | First drafting cohort if application-boundary coverage is wanted. Shares URL-validation family with previously screened LiveView #4250; do not count those as wholly independent coverage. |
| [Phoenix #6762](https://github.com/phoenixframework/phoenix/pull/6762) | Feature; LongPoll header tokens and older-client compatibility | 2 implementation, 2 test files | Defer until both client/server behaviors have a supported single-adapter grading design. |
| [Oban #1400](https://github.com/oban-bg/oban/pull/1400) | Feature; period-form job snoozing through worker execution | 3 executable implementation files, 1 docs/types-only file, 2 test/support files | Reserve for jobs coverage. Check whether the coordination is substantial enough for the desired mix and verify PostgreSQL setup. |
| [Ecto SQL #758](https://github.com/elixir-ecto/ecto_sql/pull/758) | Feature; migration transaction lifecycle and cleanup | 1 runtime implementation file, 1 callback/declaration file, 2 test/support files | Focused reserve, not a two-runtime-file expansion flagship. Real connection-affinity coverage needs more than the upstream simulated repo. |

The Phoenix/Oban rows are detailed in the [companion report](otp-framework-candidates-2026-10-18.md), including exact source identities and additional deferrals. All suggested checks and incomplete solutions below are **unexecuted proposals**.

## Do not rediscover or relabel the old decisions

“Rejected,” “deferred,” “already screened” and “low expansion priority” mean different things. The first three rows below are release exclusions, not interchangeable diagnoses. Keep source repository plus PR/commit lineage as the identity; a different case ID or paraphrased ticket does not make an excluded source new.

| Existing source(s) | Recorded disposition | Condition before further consideration |
| --- | --- | --- |
| Plausible #6300 | Retired: the reference violates the timezone/DST contract | A separately reviewed task/reference and fresh qualification; do not restore the old reference as correct. [Executed promotion decision](../verification/task-quality-promotion-2026-10-14.md) |
| Plausible #6763 | Rejected from v4: CSV column policy is ambiguous in the tested configuration | Clarify the essential outcome, create a new version and redo validation. One successful repair does not settle the ambiguity. [Rejection register](../../cases_rejected/README.md) |
| Plausible #6441 | Rejected from v4: only one of three graded attempts passed; second reviewed success missing | Preserve the successful and failed attempts. Further diagnostics need justification; no fixture defect or unsolvability was established. Preserve legitimate imported goals in any repair. [Rejection register](../../cases_rejected/README.md) |
| Livebook #3169; Ecto #4726; LiveView #4332 and #4250; Plausible #6617 | Already screened, not yet admitted | Continue their documented runtime, interface or policy work. Do not advertise them as this round's discoveries. [October 15 shortlist](multi-file-pr-candidates-2026-10-15.md) |
| Ecto #4734, with corrective #4771 | Deferred for reference completeness after `prepare_changes` | Review the follow-up and reference scope; do not narrow tests merely to retain a green reference. [Earlier analysis](multi-file-pr-candidates-2026-10-15.md#6-ecto-4734--make-ignored-writes-diagnosable) |
| LiveView #4471; Ecto #4790, #4782, #4758; Oban #744 | Lower expansion priority: one substantive implementation file | May supply useful focused cases later. Tests or documentation do not inflate implementation count. [Earlier screening](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals) |
| Oban #1466 | Test-only patch | Not an implementation task. [Earlier screening](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals) |
| Oban #1199 | Deferred: MySQL/Dolphin rescue is central, but MySQL is unsupported here | Add and qualify the required runtime support; a PostgreSQL-only subset would miss the requested capability. [Earlier screening](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals) |
| Livebook #3160; Plausible #6646 | Larger than the initial cohort's target | Revisit only as a deliberately larger coherent task, not to satisfy a raw file-count target. [Earlier screening](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals) |
| Livebook #3190 | Deferred: Teams/server and edition assumptions | Establish public-code and offline execution feasibility. [Earlier screening](multi-file-pr-candidates-2026-10-15.md#representative-rejections-and-deferrals) |
| Plausible #6725; Livebook #3204 | Workflow-only / comment spelling | Not meaningful source tasks. [Earlier discovery sample](../benchmark-expansion-plan.md) |
| Livebook #3222 | Windows-reported EPMD race, without an added test in the sampled patch | Establish platform relevance and a deterministic functional oracle before reconsidering. [Earlier discovery sample](../benchmark-expansion-plan.md) |

The [active inventory](../../config/benchmark.json) also excludes rediscovery of Plausible #5939, #6449, #5956 and Livebook #2219, #2527, #2663, #2800, #2822, #3076. Related issues such as Ecto #4725 or LiveView #2926 are supporting provenance for already-screened work, not additional cases.

## 1. Ecto #4750: bind dynamic fragment parameters correctly

**Draft maintenance ticket:** “Splicing a list into a fragment inside `dynamic/2` duplicates query parameters. Fix parameter binding, including composed dynamic expressions, and ensure preceding interpolated expressions are not evaluated again during fragment construction.” This describes two externally relevant outcomes from the PR without prescribing its implementation.

[Issue #4749](https://github.com/elixir-ecto/ecto/issues/4749) supplies a direct-versus-dynamic reproduction: three list values become nine planned parameters only in the dynamic path. The [PR](https://github.com/elixir-ecto/ecto/pull/4750) also addresses repeated evaluation of a preceding interpolation. Its body says “Fixes #4748,” but #4748 is a different CTE change; keep #4749 as the behaviorally matching report and record the metadata discrepancy rather than trusting closing references automatically.

| Changed file | Responsibility |
| --- | --- |
| `lib/ecto/query/builder.ex` | Constructs splice expressions without re-evaluating earlier runtime interpolation expressions |
| `lib/ecto/query/builder/dynamic.ex` | Carries shared splice bindings through expansion, with separate identity scopes for nested dynamics |
| `test/ecto/query/planner_test.exs` | Checks two spliced lists surrounded by ordinary parameters, including final binding positions |
| `test/ecto/query_test.exs` | Uses an explicit counter to check a preceding interpolation is evaluated once |

Source: [complete PR diff](https://github.com/elixir-ecto/ecto/pull/4750/files), checked against the [accepted commit diff](https://github.com/elixir-ecto/ecto/commit/f1bd9d165a9cfa5790e563296f95b696297e50cc). The two implementation edits must agree on parameter identity and evaluation semantics. One of them is a one-line edit, but it changes behavior; this is not documentation padding.

**Acceptance design.** Retain the upstream named tests `normalize: params around splicing inside dynamic` and `evaluates interpolated expressions before runtime splicing once`, adapted to avoid unnecessary internal representation requirements. Observe the ordered cast/dump parameter values and their correspondence to placeholders at the adapter boundary, not private bookkeeping maps or one exact pretty-printed AST. Add nested dynamics with colliding local indexes, empty/singleton/multiple splices and repeated equal values that must remain distinct parameters. These are reference challenges to execute, not claims that the reference has already passed them. Preserve direct fragments, ordinary interpolation, parameter order and the existing query suite. [Pinned tests](https://github.com/elixir-ecto/ecto/blob/f1bd9d165a9cfa5790e563296f95b696297e50cc/test/ecto/query/planner_test.exs), [query tests](https://github.com/elixir-ecto/ecto/blob/f1bd9d165a9cfa5790e563296f95b696297e50cc/test/ecto/query_test.exs).

**Proposed incomplete controls:** apply only the builder change and leave dynamic expansion unchanged; separately apply only the dynamic change and retain repeated interpolation evaluation. Each should compile and fail a different named behavioral assertion. A blanket `Enum.uniq` over parameter values is another plausible wrong behavior that repeated-value witnesses should reject. None has been constructed or run here.

**Environment and scope.** The unchanged historical [Mix project](https://github.com/elixir-ecto/ecto/blob/9d7b3010aad9f37c8c2fca3ac0a25d2aa691486a/mix.exs) requires Elixir `~> 1.14`; the [lockfile](https://github.com/elixir-ecto/ecto/blob/9d7b3010aad9f37c8c2fca3ac0a25d2aa691486a/mix.lock) pins its dependencies. The [test helper](https://github.com/elixir-ecto/ecto/blob/9d7b3010aad9f37c8c2fca3ac0a25d2aa691486a/test/test_helper.exs) uses Ecto's test adapter, and the issue reproduces the defect without a database. This is query-planning evidence, not end-to-end PostgreSQL execution. The pinned [CI matrix](https://github.com/elixir-ecto/ecto/blob/f1bd9d165a9cfa5790e563296f95b696297e50cc/.github/workflows/ci.yml) provides historical toolchain choices; select and pin one during preparation. [Apache-2.0 license](https://github.com/elixir-ecto/ecto/blob/f1bd9d165a9cfa5790e563296f95b696297e50cc/LICENSE.md). Existing APIs allow named test-body assertions on the starting tree; no missing-module scaffolding is needed.

**Lineage exclusion:** do not also promote the earlier [Ecto #4697](https://github.com/elixir-ecto/ecto/pull/4697) refactor as an independently clean candidate. Its new splice representation is the context corrected by #4750. The original refactor has two implementation and two test files, but its brief is sparse and its reference requires preservation review in light of this later defect. This is a source-based concern, not a locally reproduced failure.

## 2. Plug #1269: expose optional socket and TLS metadata

**Draft clarified feature brief:** “Expose local socket information through `Plug.Conn.get_sock_data/1` and negotiated TLS information through `Plug.Conn.get_ssl_data/1`, using optional adapter callbacks. Non-TLS connections return `nil` for SSL data; requesting metadata an adapter does not support raises. Add `Plug.Test.put_sock_data/2` and `put_ssl_data/2` so tests can supply custom metadata, preserving it when constructing another test connection. Preserve existing peer-information behavior.” These API names and the unsupported-versus-non-TLS distinction are product/interface decisions and must be visible if graded.

The [PR and discussion](https://github.com/elixir-plug/plug/pull/1269) explicitly separate the optional interface from later server-adapter implementations. Do not turn this into a requirement to implement Cowboy, Bandit or an actual TLS server. Source scope is the Plug abstraction and its test adapter.

| Changed file | Responsibility |
| --- | --- |
| `lib/plug/conn.ex` | Public getters and missing-callback handling |
| `lib/plug/adapters/test/conn.ex` | Initializes, exposes and carries metadata when constructing test connections |
| `lib/plug/test.ex` | Public custom-metadata setters |
| `lib/plug/conn/adapter.ex` | Callback/type declarations and optional-callback metadata; count separately from runtime implementation |
| `test/plug/adapters/test/conn_test.exs`, `test/plug/conn_test.exs` | Custom metadata and defaults |

Source: [complete diff](https://github.com/elixir-plug/plug/pull/1269/files), identical changed-file paths and fixed blobs in the [accepted commit](https://github.com/elixir-plug/plug/commit/8abdd30f30f2457da305938498111986195ce8d9).

**A concrete test-quality gap.** The upstream `use custom sock data` example writes exactly the same address and port as the test adapter's default. It therefore cannot, by itself, reject a socket-data setter that returns the connection unchanged. Use a distinct local address/valid port and check both the direct read and the reconstructed connection. Also test a non-`nil` TLS payload, a fresh non-TLS connection, an adapter implementing the optional callbacks, and an adapter without them. Preserve peer data, HTTP protocol and ordinary test-connection construction. [Pinned upstream test](https://github.com/elixir-plug/plug/blob/8abdd30f30f2457da305938498111986195ce8d9/test/plug/adapters/test/conn_test.exs), [default values and reconstruction](https://github.com/elixir-plug/plug/blob/8abdd30f30f2457da305938498111986195ce8d9/lib/plug/adapters/test/conn.ex).

**Proposed incomplete controls:** a no-op socket setter; a solution that supports direct metadata reads but drops custom values on test-connection reconstruction; or a solution that treats unsupported SSL metadata as `nil`, conflating it with a supported non-TLS connection. Avoid requiring an incidental error string, private state-map shape or the upstream default port value. Before invoking newly introduced functions in acceptance, assert their availability inside a named test; do not let a top-level import fail compilation on unchanged code.

**Environment and review caveat.** The starting [Mix project](https://github.com/elixir-plug/plug/blob/91de0050ba73e5aa9ecd74bd1c2c5b75b8bd0e8b/mix.exs) requires Elixir `~> 1.10`, and its [lockfile](https://github.com/elixir-plug/plug/blob/91de0050ba73e5aa9ecd74bd1c2c5b75b8bd0e8b/mix.lock) includes `plug_crypto` 2.0.0. Historical [CI](https://github.com/elixir-plug/plug/blob/8abdd30f30f2457da305938498111986195ce8d9/.github/workflows/ci.yml) includes Elixir 1.18/OTP 27.2 with the matching crypto configuration. The [helper](https://github.com/elixir-plug/plug/blob/91de0050ba73e5aa9ecd74bd1c2c5b75b8bd0e8b/test/test_helper.exs) needs no external service for this boundary; offline preparation is still unproven. [Apache-2.0 license](https://github.com/elixir-plug/plug/blob/8abdd30f30f2457da305938498111986195ce8d9/LICENSE).

Review legacy-adapter conversion separately: the internal test-connection reconstruction helper invokes adapter metadata functions directly, whereas the new public getters check availability. Do not silently promise that converting arbitrary historical server adapters through that helper is supported; investigate the legitimate compatibility surface before freezing the brief. This is an unresolved source-review question, not an established failing fixture.

## 3. Ecto SQL #699: carry table modifiers through DDL generation

**Draft clarified feature brief:** “Accept an optional string `:modifiers` in `Ecto.Migration.table/2`, placed before `TABLE` in PostgreSQL and MySQL create statements, including `create_if_not_exists`. Preserve ordinary table creation when it is absent. PostgreSQL and MySQL must reject non-string, non-`nil` modifiers; MSSQL must reject modifier strings. Creation logs for `create` operations should identify the modifier.” The scope is migration construction and adapter SQL output; no speed objective is involved. The type-error policy still needs independent review as noted below.

The [PR](https://github.com/elixir-ecto/ecto_sql/pull/699) connects the change to creating unlogged tables, and its discussion explicitly adds MySQL support and MSSQL rejection. Its predecessor #601 is an experiment in the same family, not another independent candidate. The relevant outcome here is functional DDL support, irrespective of why an application might choose unlogged tables.

| Changed file | Responsibility |
| --- | --- |
| `lib/ecto/migration.ex` | Stores the public table option |
| `lib/ecto/adapters/postgres/connection.ex` | Emits PostgreSQL modifiers and rejects invalid types |
| `lib/ecto/adapters/myxql/connection.ex` | Emits MySQL modifiers and rejects invalid types |
| `lib/ecto/adapters/tds/connection.ex` | Rejects unsupported MSSQL modifiers |
| `lib/ecto/migration/runner.ex` | Includes modifier information in `create` operation logging |
| Three adapter test files and `test/ecto/migrator_test.exs` | Generated SQL, unsupported dialect and logging |

Source: [complete diff](https://github.com/elixir-ecto/ecto_sql/pull/699/files), matching the [accepted commit](https://github.com/elixir-ecto/ecto_sql/commit/2096c33dfb16b873a3cf4bfd8850fd779cdc9598). Two emitter edits are similar, but the whole task coordinates option representation, supported/unsupported dialects and a migration consumer.

**Acceptance design.** Exercise the actual table constructor and dialect DDL functions for absent/string/invalid values, both create commands, schemas/prefixes and existing table options. Require PostgreSQL and MySQL support and MSSQL rejection; keeping only PostgreSQL would silently shrink the upstream task. Observe SQL meaning and placement while permitting harmless whitespace. For logging, check semantic inclusion, not timestamps, exact prose or elapsed migration output. The reference only adds modifier-aware logging for `:create`; do not infer a universal logging policy for every operation from that change. [Pinned PostgreSQL tests](https://github.com/elixir-ecto/ecto_sql/blob/2096c33dfb16b873a3cf4bfd8850fd779cdc9598/test/ecto/adapters/postgres_test.exs), [MySQL tests](https://github.com/elixir-ecto/ecto_sql/blob/2096c33dfb16b873a3cf4bfd8850fd779cdc9598/test/ecto/adapters/myxql_test.exs), [MSSQL tests](https://github.com/elixir-ecto/ecto_sql/blob/2096c33dfb16b873a3cf4bfd8850fd779cdc9598/test/ecto/adapters/tds_test.exs).

**Proposed incomplete controls:** store the option but omit one supported dialect; or implement the supported dialects while silently ignoring the MSSQL option. Each should compile and be distinguishable from a complete solution by a named assertion. Preserve modifier-free DDL and unrelated migration behavior. Build option-bearing structs at runtime within named tests so the starting source's missing struct field produces a deliberate assertion failure rather than a suite compilation error.

**Contract/reference question:** MSSQL's reference uses a truthiness check, so `false` bypasses its rejection even though it is outside the documented string-or-`nil` input type. PostgreSQL/MySQL reject that value. The draft above exposes the narrower demonstrated dialect policy; it does not establish that this asymmetry is desirable. Have the reviewer decide whether uniform invalid-type rejection is an obligation. If it is, challenge and correct the reference with attributed provenance or defer the case; do not hide the discrepancy behind the ordinary string test. This is source analysis, not an executed failure.

**Environment distinction.** Unlike deferred Oban #1199, the inspected acceptance boundary does not inherently require a running MySQL service: these are real adapter **SQL-generation** unit tests. This is not a claim of actual MySQL/MSSQL execution. The [historical Mix project](https://github.com/elixir-ecto/ecto_sql/blob/a703c2edb90d3b85ca55767e12877da4f221faa9/mix.exs) separates default `test/` from `ECTO_ADAPTER` integration paths; [CI](https://github.com/elixir-ecto/ecto_sql/blob/2096c33dfb16b873a3cf4bfd8850fd779cdc9598/.github/workflows/ci.yml) separates unit and database jobs. The [helper](https://github.com/elixir-ecto/ecto_sql/blob/a703c2edb90d3b85ca55767e12877da4f221faa9/test/test_helper.exs) loads a simulated migration repo. Use the existing ExUnit adapter with explicit files, not `mix test.all` and its broader service matrix.

The Mix requirement is Elixir `~> 1.14`; historical unit CI includes Elixir 1.17.2 on OTP 25.0.4/27.0.1. Although `mix.exs` names Ecto's `master`, the [committed lockfile](https://github.com/elixir-ecto/ecto_sql/blob/a703c2edb90d3b85ca55767e12877da4f221faa9/mix.lock) pins Ecto to `3ab6a20b255fe2cee1fd9f6ae160c6fde772dce7` and locks Postgrex/MyXQL/Tds. Preserve that lock rather than resolving today's branch. All three driver modules must load in the prepared image. [Apache-2.0 license](https://github.com/elixir-ecto/ecto_sql/blob/2096c33dfb16b873a3cf4bfd8850fd779cdc9598/LICENSE.md). No installation or offline execution was attempted.

## 4. Focused reserve: Ecto SQL #758 transaction callbacks

[PR #758](https://github.com/elixir-ecto/ecto_sql/pull/758) adds `before_transaction/1` and `after_transaction/1` around transactional migrations, on the same checked-out connection. The visible brief would need to require cleanup after commit, migration failure and a failing before-callback; both callbacks are skipped when no transaction runs. The repo argument and existing `after_begin/0`/`before_commit/0` ordering are public interface behavior. Its central implementation is `migrator.ex`; `migration.ex` adds declarations/docs. Do not count that as two substantial runtime changes merely to fit the preferred distribution. [Complete diff](https://github.com/elixir-ecto/ecto_sql/pull/758/files).

The supplied tests use explicit event messages and a simulated checked-out flag. They cover up/down order, dynamic repositories, after-only callbacks, disabled/unsupported transactions and cleanup after exceptions. Those are useful semantic witnesses but do not establish physical database-connection identity. A compiling partial solution that calls cleanup only on success should fail the error-path witness. A fuller same-connection claim needs a suitable real PostgreSQL witness or an independently justified adapter-contract test. Do not claim SQLite's `PRAGMA` use case was exercised. [Pinned migrator tests](https://github.com/elixir-ecto/ecto_sql/blob/bf126d6be628dafdf54409464e5607a665dc9c15/test/ecto/migrator_test.exs), [test repo](https://github.com/elixir-ecto/ecto_sql/blob/bf126d6be628dafdf54409464e5607a665dc9c15/test/support/test_repo.exs).

The [Mix project](https://github.com/elixir-ecto/ecto_sql/blob/bf126d6be628dafdf54409464e5607a665dc9c15/mix.exs) requires Elixir `~> 1.15`; the [starting lockfile](https://github.com/elixir-ecto/ecto_sql/blob/f0491981b5c3f427c8b42d57be6e6d7eb5d8a86b/mix.lock) pins Ecto to `8959c439c7618ed88be98fe7741ba9986a57a7e5`. Same [Apache-2.0 license](https://github.com/elixir-ecto/ecto_sql/blob/bf126d6be628dafdf54409464e5607a665dc9c15/LICENSE.md). Keep it as a useful smaller lifecycle case if that coverage is needed.

## New leads screened out or deferred in this pass

These decisions are based on the stated inspection level. They are not criticisms of upstream work, automatic permanent rejections, or findings from executed fixtures.

| Source | Evidence inspected | Disposition / reason |
| --- | --- | --- |
| [Ecto #4697](https://github.com/elixir-ecto/ecto/pull/4697/files) | Full implementation/test diff, source identity, runtime, later #4750 | Hold: reference preservation concern and sparse objective-refactor brief. Prefer the corrective #4750; retain their family relationship. |
| [Ecto #4700](https://github.com/elixir-ecto/ecto/pull/4700/files) | Metadata and complete changed-file list; documentation/runtime roles | Focused reserve: `repo.ex` changes docs, with behavior concentrated in `repo/schema.ex`. Not two runtime implementation files. |
| [Ecto #4722](https://github.com/elixir-ecto/ecto/pull/4722/files), [#4795](https://github.com/elixir-ecto/ecto/pull/4795/files) | Metadata and complete changed-file lists | Focused reserves: each one implementation plus one test file. #4795 adds meaningful insertion coverage, but does not solve the current concentration of one-file cases. |
| [Ecto SQL #750](https://github.com/elixir-ecto/ecto_sql/pull/750/files) | Metadata and complete changed-file list | Focused reserve: one migrator implementation plus one test file. |
| [Ecto SQL #741](https://github.com/elixir-ecto/ecto_sql/pull/741/files) | Metadata and complete changed-file list | Defer: read-only transactions span real PostgreSQL/MySQL transaction semantics. Do not infer execution feasibility from SQL-string tests or remove MySQL to fit existing services. |
| [Plug #1289](https://github.com/elixir-plug/plug/pull/1289/files), [#1272](https://github.com/elixir-plug/plug/pull/1272/files) | Metadata and complete changed-file lists | Focused reserves: useful upload cleanup and custom proxy-header support, each one implementation plus one test file. |
| [Plug #1309](https://github.com/elixir-plug/plug/pull/1309/files) | Metadata/file list and discovery of later #1320 | Hold for follow-up review: one-file callback change, followed by `Fix register_before_send with upgrade_adapter`. Do not select the earlier patch as a complete reference without inspecting that correction. |
| [Livebook #3161](https://github.com/livebook-dev/livebook/pull/3161/files) | Full PR explanation and complete changed-file list | Reserve/contract review: one implementation file; combines smart-cell identity and adjacent-cell diff repair. Do not call its two defect manifestations multi-file coordination. |
| [Livebook #3154](https://github.com/livebook-dev/livebook/pull/3154/files) | PR explanation and all 26 paths | Defer from initial cohort: broad dev-endpoint/synchronization feature across notebook, sessions, UI and settings. Do not split it into artificial fragments without a credible independent task. |
| [Livebook #3191](https://github.com/livebook-dev/livebook/pull/3191/files), [#3217](https://github.com/livebook-dev/livebook/pull/3217/files) | Metadata and complete changed-file lists | Focused reserves: one runtime implementation each. |
| [Livebook #3207](https://github.com/livebook-dev/livebook/pull/3207/files) | Metadata and complete changed-file list | Defer for grading/runtime work: one CLI source file, no added tests, packaging/extraction behavior needs a controlled executable witness. |
| [Oban #1413](https://github.com/oban-bg/oban/pull/1413) | Full ancestry, implementation/tests and later #1441/#1499 in companion report | Defer despite attractive OTP coverage: unusual multi-commit source extraction and later duplicate/missed-subscription corrections. [Detailed findings](otp-framework-candidates-2026-10-18.md) |

Recent Plug title samples included many optimizations. They were not pursued as candidates based on a speed objective. No claim about admission yield follows from this purposive sample.

## Exact source identities and inspection limits

For the five detailed Ecto/Plug/Ecto SQL entries below, the accepted commit has one parent. All changed-file paths match the complete PR list. For Ecto #4750, two final blobs differ from the PR-head blobs because the base advanced; comparing PR and accepted-commit patches showed only hunk-offset changes. Extract from the recorded accepted commit and parent, not an assumed historical PR base. All other four entries have matching PR-head changed blobs. This checks source-selection inputs, not full fixture reconstruction or source-tree hash receipts.

| Source | Merged UTC date | Starting revision | Accepted revision |
| --- | --- | --- | --- |
| Ecto #4750 | 2026-07-08 | `9d7b3010aad9f37c8c2fca3ac0a25d2aa691486a` | [`f1bd9d165a9cfa5790e563296f95b696297e50cc`](https://github.com/elixir-ecto/ecto/commit/f1bd9d165a9cfa5790e563296f95b696297e50cc) |
| Plug #1269 | 2025-05-24 | `91de0050ba73e5aa9ecd74bd1c2c5b75b8bd0e8b` | [`8abdd30f30f2457da305938498111986195ce8d9`](https://github.com/elixir-plug/plug/commit/8abdd30f30f2457da305938498111986195ce8d9) |
| Ecto SQL #699 | 2025-12-08 | `a703c2edb90d3b85ca55767e12877da4f221faa9` | [`2096c33dfb16b873a3cf4bfd8850fd779cdc9598`](https://github.com/elixir-ecto/ecto_sql/commit/2096c33dfb16b873a3cf4bfd8850fd779cdc9598) |
| Ecto SQL #758 | 2026-10-08 | `f0491981b5c3f427c8b42d57be6e6d7eb5d8a86b` | [`bf126d6be628dafdf54409464e5607a665dc9c15`](https://github.com/elixir-ecto/ecto_sql/commit/bf126d6be628dafdf54409464e5607a665dc9c15) |
| Ecto #4697, held | 2026-01-11 | `7224c12734f1a2ad4b87ba769db87dbc80be3468` | [`bf242348cdf89c056a977668da707b9937208efe`](https://github.com/elixir-ecto/ecto/commit/bf242348cdf89c056a977668da707b9937208efe) |

The primary discovery pass fetched 70 recently updated merged PR records each from Ecto, Ecto SQL and Plug, plus 65 from Livebook: **275 metadata records**, not 275 inspected or eligible tasks. Queries used `repo:<repo> is:pr is:merged -label:documentation`, sorted by updated date; each returned `incomplete_results: false`, which does not make the one-page sample exhaustive. Complete file lists and PR descriptions were inspected for 17 initial leads, plus Ecto #4750 discovered during follow-up review. Only the five detailed entries received the deeper merged-source/runtime inspection described above. The Phoenix/Oban companion has its own search scope; do not add incomparable headline counts into an eligibility estimate.

GitHub REST metadata, complete file lists, raw pinned source, PR discussion and issue reports supplied the primary evidence. Some searches have no matching results; that is not evidence of no later defect. In particular, the review found two reasons to avoid assuming merged references are complete: Ecto's subsequent splice repair and Oban's notifier follow-ups.

## What drafting must establish next

For a selected candidate, first freeze the shortest sufficient solver contract and have another reviewer derive its obligations before reading the reference/checks. Record the exact configuration and reasonable alternative outcomes. Turn each material obligation into an observable check plus a preservation witness; the proposed partial solutions above guide that work.

Then establish source reconstruction, dependency/runtime pins and offline setup. Construct real compiling incomplete controls, integrity controls and any necessary valid-alternative/reference challenges. Run the required three fresh qualification rounds with matching named outcomes, followed by the independent review and two reviewed fresh blind model successes under frozen inputs/settings. Keep unsuccessful attempts and infrastructure failures distinct. The [methodology report](case-selection-evidence-2026-10-18.md) proposes separate bounded order-robustness diagnostics; it does not silently change the existing seed or admission rule.

A documentation shortlist is not a validation shortcut. The current outcome is a ranked research backlog, with explicit reasons for keeping old and newly problematic sources out of the admitted inventory.
