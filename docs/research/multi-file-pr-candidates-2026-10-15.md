# Multi-file PR candidates

Inspected **2026-10-15**. This is a source-screening note, not an admission record. None of these PRs has been imported, built, qualified, independently reviewed for admission, or solved by a model in this investigation. Follow the [selection guidelines](../pr-selection-guidelines.md) and [admission contract](../case-admission.md) before promotion.

The six detailed entries below were checked against upstream PR metadata, the complete changed-file list, implementation and test diffs, and the merge commit's file list. Counts exclude tests, test support and standalone documentation from implementation files. Documentation embedded in an otherwise substantively changed implementation file does not add another file. No candidate changes generated output or lockfiles. File count is a selection observation, never a requirement imposed on a solver.

The most promising first drafts are **Livebook #3169** for application work and **Ecto #4726** for a new project with an ExUnit-only test surface. **LiveView #4332** adds realistic browser/history work but needs curated browser checks. These are judgments from source inspection, not evidence that the fixtures work offline.

| PR | Substantive implementation files | Test/support files | Standalone docs | Total | Screening status |
| --- | ---: | ---: | ---: | ---: | --- |
| [Livebook #3169](https://github.com/livebook-dev/livebook/pull/3169) | 3 | 3 | 0 | 6 | Screened; draft next, verify offline Python/runtime preparation |
| [Ecto #4726](https://github.com/elixir-ecto/ecto/pull/4726) | 2 | 1 | 0 | 3 | Screened; draft next, explicitly declare the new public option |
| [LiveView #4332](https://github.com/phoenixframework/phoenix_live_view/pull/4332) | 2 | 5 | 1 | 8 | Screened; browser-contract adaptation needed |
| [LiveView #4250](https://github.com/phoenixframework/phoenix_live_view/pull/4250) | 5 | 3 | 0 | 8 | Screened; cross-language grading design needed |
| [Plausible #6617](https://github.com/plausible/analytics/pull/6617) | 2 | 4 | 1 | 7 | Screened; clarify policy and verify CE execution |
| [Ecto #4734](https://github.com/elixir-ecto/ecto/pull/4734) | 2 | 1 | 0 | 3 | Screened; defer pending reference-completeness checks |

## Source identities

For these six inspected merges, the recorded candidate starting revision is the merge commit's first parent; qualification must still reconstruct the exact merged tree. A PR's reported base SHA is not always that parent, and first-parent selection is not a general extraction rule for uninspected merge/rebase histories. The full PR file lists were fetched with `per_page=100` and their lengths matched each PR's `changed_files`. Merge file lists contain the same paths. LiveView #4332 has intervening edits in three blobs; Plausible #6617 has an intervening changelog edit. Their merge-parent diffs were checked separately; do not blindly apply an old PR diff to the merge parent.

| PR | Merged UTC | Starting revision: first parent | Merged revision |
| --- | --- | --- | --- |
| Livebook #3169 | 2026-04-02 | `6592a0faf973943a3c8de5e9871a4c9493d78671` | [`131ef751ddb6ba86642f01584fb6461684aae0db`](https://github.com/livebook-dev/livebook/commit/131ef751ddb6ba86642f01584fb6461684aae0db) |
| Ecto #4726 | 2026-05-13 | `270acebe3d76779dcb0e97c40b0271b2103cbfc9` | [`10b337297e24fc0e1e7699467f1395a7751fa9aa`](https://github.com/elixir-ecto/ecto/commit/10b337297e24fc0e1e7699467f1395a7751fa9aa) |
| LiveView #4332 | 2026-07-27 | `c7cb9769f6caf54182dfbe965c986a27337de9e0` | [`6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae`](https://github.com/phoenixframework/phoenix_live_view/commit/6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae) |
| LiveView #4250 | 2026-05-29 | `233583b97885f15a5eb718653f97d8fc788c4b50` | [`961bb68aa8f2b107476e188192c04839734ef745`](https://github.com/phoenixframework/phoenix_live_view/commit/961bb68aa8f2b107476e188192c04839734ef745) |
| Plausible #6617 | 2026-09-08 | `9241af8c1f4cc777f1c3d56c24d303eafb38acc5` | [`b7e86f6d26e432828cb188f2183deb020bbc127c`](https://github.com/plausible/analytics/commit/b7e86f6d26e432828cb188f2183deb020bbc127c) |
| Ecto #4734 | 2026-06-16 | `129c2eaf68597101359a6b288042971792370ebc` | [`e1d4be8c9488a0c6b34683af2b6994406cefeb3e`](https://github.com/elixir-ecto/ecto/commit/e1d4be8c9488a0c6b34683af2b6994406cefeb3e) |

The identities above are discovery inputs. Source-tree hashes, patch reconstruction and immutable runtime receipts still belong to qualification.

## 1. Livebook #3169 — URL parameters reach app sessions

**Task kind: feature.** Draft ticket: “Let new multi-session app sessions read `lb_`/`LB_` URL query parameters through `app_info.session_params`, with the prefix removed.” The [PR description](https://github.com/livebook-dev/livebook/pull/3169) explicitly describes this interface. Prefix spelling and the result key are public behavior, so they must remain visible; a generic “support query parameters” ticket would not justify those hidden assertions.

Complete [changed-file list and diff](https://github.com/livebook-dev/livebook/pull/3169/files):

| File | Role |
| --- | --- |
| `lib/livebook_web/live/app_live.ex` | Retains incoming parameters, selects the two supported prefixes, and passes session options |
| `lib/livebook/app.ex` | Carries options across the app process and starts the session with them |
| `lib/livebook/session.ex` | Retains parameters and exposes them in runtime app information |
| `test/livebook_web/live/app_live_test.exs` | Exercises the actual URL/new-session flow and prefix filtering |
| `test/livebook/app_test.exs` | Checks propagation through app session creation |
| `test/livebook/session_test.exs` | Checks runtime app-information replies |

This is a natural UI → process → runtime boundary. Upstream tests cover prefixed values, ignoring unrelated/mixed-case prefixes, and retaining user information. A useful incomplete control would implement direct app/session propagation while leaving the web entry point unchanged: API tests can pass while the URL-driven test fails. Another would forward every query parameter and fail a filtering assertion. Neither control has been built or executed.

Keep single-session behavior, missing parameters, and independent simultaneous sessions in preservation/acceptance coverage. Do not require the reference's internal function names. If exact mixed-case rejection is graded, the visible interface must say that only the two stated prefixes are recognized.

Runtime fit is plausible but unverified. The [pinned Mix project](https://github.com/livebook-dev/livebook/blob/131ef751ddb6ba86642f01584fb6461684aae0db/mix.exs) requires Elixir `~> 1.18`, checks OTP 25+, and prepares assets using Bun. The [test helper](https://github.com/livebook-dev/livebook/blob/131ef751ddb6ba86642f01584fb6461684aae0db/test/test_helper.exs) uses embedded runtimes and initializes Python through `Pythonx.uv_init`; prefetch its dependencies during preparation and verify the exact tests with networking disabled. The web test constructs a notebook without Teams enabled, providing source evidence that the behavior is not confined to paid Teams, but this is not an offline execution result. The pinned [license is Apache-2.0](https://github.com/livebook-dev/livebook/blob/131ef751ddb6ba86642f01584fb6461684aae0db/LICENSE).

## 2. Ecto #4726 — join-table conflicts during associated inserts

**Task kind: feature.** Draft ticket: “Let `many_to_many` associations use `on_join_through_conflict: :nothing` to ignore duplicate join rows, while retaining the current raising default.” The [original issue](https://github.com/elixir-ecto/ecto/issues/4725) reports an upsert unexpectedly inserting an existing join row. The [merged PR](https://github.com/elixir-ecto/ecto/pull/4726) resolves that with an explicit association option. Do not present this as an automatic bug fix and secretly require the option: that would mismatch the original observed symptom and the chosen interface.

Complete [changed-file list and diff](https://github.com/elixir-ecto/ecto/pull/4726/files):

| File | Role |
| --- | --- |
| `lib/ecto/schema.ex` | Accepts and documents the association option |
| `lib/ecto/association.ex` | Validates/stores it and passes conflict behavior to join insertion |
| `test/ecto/repo/many_to_many_test.exs` | Checks default, table-name joins, and schema-backed joins |

The upstream checks observe options received by Ecto's test adapter, for both `insert_all` and schema insertion paths. An incomplete control could handle table-name joins but leave schema-backed joins using the default. This should fail the schema-join behavior check while passing the table-name check; it still needs execution proof. Preserve ordinary inserts and default raising behavior. Add invalid-option coverage if the allowed option set is part of the visible contract.

The new schema option is absent from the starting tree. Copying upstream schema declarations into top-level acceptance setup would cause compilation failure before named tests. Construct the relevant schema inside a named test and turn unsupported capability into an explicit assertion; qualify that unchanged source fails for the requested behavior.

This is a new project with a favorable fit for the existing ExUnit adapter. The [pinned test helper](https://github.com/elixir-ecto/ecto/blob/10b337297e24fc0e1e7699467f1395a7751fa9aa/test/test_helper.exs) loads `test/support/test_repo.exs`; these tests do not demonstrate real PostgreSQL conflict behavior. The [README](https://github.com/elixir-ecto/ecto/blob/10b337297e24fc0e1e7699467f1395a7751fa9aa/README.md#running-tests) separates core tests from integration tests run through a sibling `ecto_sql` checkout. Start with the core public adapter contract; stronger database evidence would require separately pinned dependencies and setup. The [Mix project](https://github.com/elixir-ecto/ecto/blob/10b337297e24fc0e1e7699467f1395a7751fa9aa/mix.exs) requires Elixir `~> 1.14`; the [license is Apache-2.0](https://github.com/elixir-ecto/ecto/blob/10b337297e24fc0e1e7699467f1395a7751fa9aa/LICENSE.md). No paid edition is involved in the inspected code.

## 3. LiveView #4332 — cancel navigation without losing unsaved work

**Task kind: feature.** Draft ticket: “Add a cancelable `phx:before-navigate` event for live links and browser back/forward so a page can protect unsaved changes.” The [linked issue](https://github.com/phoenixframework/phoenix_live_view/issues/2926) describes a dirty-form guard that cannot stop live navigation. The [PR](https://github.com/phoenixframework/phoenix_live_view/pull/4332) introduces the named event. Its documented scope excludes server-triggered redirects/navigation and ordinary unloads; do not silently grade an all-navigation guard.

Complete [changed-file list and diff](https://github.com/phoenixframework/phoenix_live_view/pull/4332/files):

| File | Role |
| --- | --- |
| `assets/js/phoenix_live_view/dom.ts` | Returns cancellation state from event dispatch; small but functionally necessary |
| `assets/js/phoenix_live_view/live_socket.ts` | Guards links/history navigation and restores cancelled history movement |
| `guides/client/syncing-changes.md` | Public event contract and exclusions |
| `test/e2e/support/form_unsaved_live.ex` | Dirty-form fixture |
| `test/e2e/support/navigation.ex` | Navigation fixture and event observations |
| `test/e2e/test_helper.exs` | Fixture routes |
| `test/e2e/tests/form-unsaved.spec.js` | Cancellation, retained form state and a still-connected page |
| `test/e2e/tests/navigation.spec.js` | Links, browser history, and server-navigation preservation |

The reference coordinates browser events, navigation history and continued application operation. A strong incomplete control would cancel live-link clicks but omit history cancellation; a back-navigation test should fail while the click case passes. Add forward and patch cases to the supplied back/navigation examples. Confirm that cancellation produces no navigation request, the URL is restored, and editing still works. Grade semantic event details only when their public names are visible in the contract; avoid asserting exact implementation bookkeeping.

The upstream tests use Playwright's runner, not Node's built-in runner. The benchmark can prepare Chromium, but this does **not** make `npx playwright test` an accepted grading command. Preserve upstream tests separately and adapt behavioral cases to controller-owned Node tests using `EAB_BROWSER_MODULE`, a loopback LiveView server, and setup/teardown hooks. The [pinned package scripts](https://github.com/phoenixframework/phoenix_live_view/blob/6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae/package.json) also install browsers at test time; that step must move to preparation. [Upstream browser configuration](https://github.com/phoenixframework/phoenix_live_view/blob/6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae/test/e2e/playwright.config.js) covers three engines, whereas the current benchmark recipe provides Chromium: record that narrower coverage. The [Mix project](https://github.com/phoenixframework/phoenix_live_view/blob/6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae/mix.exs) requires Elixir `~> 1.15` and an `:e2e` environment; no database is evident in these fixtures. Source/assets and package dependencies still need a proven offline build. The pinned [license is MIT](https://github.com/phoenixframework/phoenix_live_view/blob/6b7765803c683cd1bb42b5c6a73ccfa9b0a989ae/LICENSE.md).

## 4. LiveView #4250 — consistent live-navigation destination checks

**Task kind: bug fix.** Draft ticket: “Reject unsupported schemes in LiveView links/JS navigation and cross-origin client navigation, without breaking valid same-origin paths.” This is a **curator inference from the diff**: the [PR body](https://github.com/phoenixframework/phoenix_live_view/pull/4250) does not supply a detailed user report. Its contract needs independent review before becoming a case.

Complete [changed-file list and diff](https://github.com/phoenixframework/phoenix_live_view/pull/4250/files):

| File | Role |
| --- | --- |
| `lib/phoenix_component.ex` | Validates `navigate`/`patch` link destinations |
| `lib/phoenix_live_view/js.ex` | Validates server-produced JS navigation commands |
| `lib/phoenix_live_view/utils.ex` | Distinguishes URI schemes from colons in paths/query/fragment |
| `assets/js/phoenix_live_view/utils.ts` | Validates a URL against the browser's current origin |
| `assets/js/phoenix_live_view/js_commands.ts` | Applies browser validation before navigation side effects |
| `test/phoenix_component/components_test.exs` | Link rendering, rejected schemes and colon preservation |
| `test/phoenix_live_view/js_test.exs` | Command construction and invalid destinations |
| `assets/test/js_test.ts` | Client origin checks and absence of navigation side effects |

This is the clearest five-file coordination candidate: changing server validation alone leaves the client path wrong. Use exactly that as a proposed incomplete control; require a client-origin assertion to reject it. Preservation should include relative URLs, full same-origin HTTP(S) URLs, colons outside the scheme, and ordinary links. Avoid requiring the reference's error prose or helper names. The server accepts HTTP(S) destinations without knowing a browser's current origin; do not incorrectly demand server-side origin validation.

The current case contract selects one adapter. Upstream coverage spans ExUnit and Jest, so a few `mix test` cases would not establish the full five-file task. Design a supported contract that observes both language surfaces, or defer it; simply invoking a nested runner and treating its exit code as named acceptance evidence is insufficient. Node browser checks could observe the public rendered/client behavior, but setup failures must remain distinct from missing behavior. This design is **not implemented or verified**. The pinned [Mix project](https://github.com/phoenixframework/phoenix_live_view/blob/961bb68aa8f2b107476e188192c04839734ef745/mix.exs), [package configuration](https://github.com/phoenixframework/phoenix_live_view/blob/961bb68aa8f2b107476e188192c04839734ef745/package.json) and [MIT license](https://github.com/phoenixframework/phoenix_live_view/blob/961bb68aa8f2b107476e188192c04839734ef745/LICENSE.md) are available; service-free offline execution remains unverified.

## 5. Plausible #6617 — name validation meets onboarding

**Task kind: feature.** Draft ticket: “Limit team names to 50 characters and reject URL schemes, while keeping team setup usable for people with long or invalid profile names.” This follows the [PR request](https://github.com/plausible/analytics/pull/6617), which also declares a dependency on #6616. The first parent recorded above already contains the integrated source; do not substitute a convenient older baseline.

Complete [changed-file list and diff](https://github.com/plausible/analytics/pull/6617/files):

| File | Role |
| --- | --- |
| `lib/plausible/teams/team.ex` | Validation across changesets and safe suggested names |
| `lib/plausible_web/live/team_management.ex` | Uses safe suggestions when initializing/persisting onboarding state |
| `test/plausible/teams/team_test.exs` | Boundaries, URL policy, Unicode, existing names and suggestions |
| `test/plausible_web/controllers/settings_controller_test.exs` | Settings persistence and existing invalid-name preservation |
| `test/plausible_web/live/team_setup_test.exs` | Onboarding with long/invalid names and rejected submissions |
| `e2e/tests/dashboard/team-setup.spec.ts` | Browser registration/setup flow |
| `CHANGELOG.md` | User-facing policy announcement |

Adding only changeset validation is a plausible partial fix: ordinary invalid-name tests pass but onboarding may try to persist an invalid suggestion. A named onboarding test should reject this incomplete control. Upstream has useful server-side ExUnit coverage, so preserving the exact browser test as upstream evidence does not require pretending the current runner supports its Playwright command.

The principal admission risk is **hidden product policy**. The patch also caps names at 255 **bytes**, permits bare hostnames, preserves existing invalid names when unchanged, and selects exact fallback/truncation strings. The draft ticket does not justify all those exact choices. Prefer outcome checks for safe persistence and a usable suggestion, or explicitly surface a necessary public policy; do not append the whole reference specification as a disguised requirement block. If the real policy cannot be stated briefly and fairly, defer this PR.

The [pinned tests](https://github.com/plausible/analytics/blob/b7e86f6d26e432828cb188f2183deb020bbc127c/test/plausible_web/live/team_setup_test.exs) contain CE/EE-specific mail prefixes without a whole-module EE exclusion, and changed implementation is under `lib/`; these are positive signs, not proof of CE success. The [Mix project](https://github.com/plausible/analytics/blob/b7e86f6d26e432828cb188f2183deb020bbc127c/mix.exs) distinguishes CE compilation paths and uses PostgreSQL/ClickHouse setup. Reuse the existing runtime family only after exact dependency/migration checks. Inspect retained upstream files and edition licensing before copying a bundle: the [README](https://github.com/plausible/analytics/blob/b7e86f6d26e432828cb188f2183deb020bbc127c/README.md) identifies CE as AGPLv3-or-later, with the [license here](https://github.com/plausible/analytics/blob/b7e86f6d26e432828cb188f2183deb020bbc127c/LICENSE.md). No paid services were tested or assumed available.

## 6. Ecto #4734 — make ignored writes diagnosable

**Task kind: feature; defer for now.** Draft ticket: “Let schema fields warn or raise when an insert/update writes a non-writable field, while keeping silent-ignore as the default.” The [PR description](https://github.com/elixir-ecto/ecto/pull/4734) explains that ignored updates can look successful to callers. A final ticket must name `on_writable_violation` and its allowed values if acceptance depends on that public API.

Complete [changed-file list and diff](https://github.com/elixir-ecto/ecto/pull/4734/files):

| File | Role |
| --- | --- |
| `lib/ecto/schema.ex` | Records the new field policy and exposes schema metadata |
| `lib/ecto/repo/schema.ex` | Applies policy during inserts and updates, including surfaced struct values |
| `test/ecto/repo_test.exs` | Warning/exception behavior, default behavior and persisted writable fields |

An incomplete control could implement updates but omit inserts or values surfaced from an existing struct. Upstream named tests distinguish these paths and provide a basis for such a control. As with #4726, new option-bearing schema definitions must not make the pristine acceptance suite fail during module compilation.

Do not take the merged reference as proof that the full feature is correct. The later [#4771 diff](https://github.com/elixir-ecto/ecto/pull/4771/files), also inspected, adds enforcement after `prepare_changes` for both insert and update. This exposes a real reference-scope question: either document a defensible bounded task, or build a separately attributed corrected reference and requalify it. Do not remove a reasonable callback scenario just to preserve a green upstream reference. The [pinned Mix project](https://github.com/elixir-ecto/ecto/blob/e1d4be8c9488a0c6b34683af2b6994406cefeb3e/mix.exs) and [Apache-2.0 license](https://github.com/elixir-ecto/ecto/blob/e1d4be8c9488a0c6b34683af2b6994406cefeb3e/LICENSE.md) suggest the same core ExUnit/runtime fit as #4726; it has not been built here.

## Representative rejections and deferrals

These are selection decisions from the sampled diffs, not statements that the upstream changes are poor work.

| Sample | Evidence and reason |
| --- | --- |
| [LiveView #4471](https://github.com/phoenixframework/phoenix_live_view/pull/4471/files) | Seven changed files, but one implementation file (`channel.ex`); the other six are tests/support. Does not improve the desired multi-file distribution. |
| [Ecto #4790](https://github.com/elixir-ecto/ecto/pull/4790/files), [#4782](https://github.com/elixir-ecto/ecto/pull/4782/files), [#4758](https://github.com/elixir-ecto/ecto/pull/4758/files) | Each has one implementation and one test file. Useful potential small cases, not this expansion's priority. |
| [Oban #744](https://github.com/oban-bg/oban/pull/744/files) | Two `lib/` paths, but executable behavior changes only in `engines/basic.ex`; `job.ex` changes types/docs. Do not inflate it into a two-file implementation task. |
| [Oban #1466](https://github.com/oban-bg/oban/pull/1466/files) | A race-related title, but the entire patch changes one test file. No implementation repair to benchmark. |
| [Oban #1199](https://github.com/oban-bg/oban/pull/1199/files) | Four implementation files spanning the engine callback, Basic, Dolphin and Lifeline; it adds MySQL/Dolphin rescue support. Deferred: the current service adapter supports PostgreSQL/ClickHouse, not MySQL, so testing only Basic would omit a central requested capability. |
| [Livebook #3160](https://github.com/livebook-dev/livebook/pull/3160/files) | Nineteen total files: fourteen production paths including CSS/JS and thirteen non-CSS implementation paths, plus five tests. Too broad for the initial 2–5-file cohort; do not mistake its larger patch for automatic realism. |
| [Plausible #6646](https://github.com/plausible/analytics/pull/6646/files) | Ten implementation/template paths and three tests. Coherent registration work, but larger than the first cohort's target. |
| [Livebook #3190](https://github.com/livebook-dev/livebook/pull/3190/files) | Two production paths and one test, but its test lives in `test/livebook_teams/`. Deferred until Teams/server and edition assumptions are established; do not import solely because the file count fits. |

## What remains before any case is added

The local [fixture builder](../../lib/eab/fixtures.ex) accepts a pinned GitHub repository and generic Mix setup commands; [service handling](../../lib/eab/service_images.ex) currently recognizes PostgreSQL and ClickHouse. The [baseline policy](../../lib/eab/baseline.ex) defaults database migration commands specifically for `plausible_ce`. A new library can fit the generic service-free path, but a new database project still needs explicit bootstrap/setup and offline proof.

For each chosen draft, establish the minimal visible behavior before writing acceptance assertions, preserve exact upstream test/docs provenance, adapt only the necessary tests, and implement an actual partial-fix control. Then run unchanged/reference/incomplete/integrity qualification, obtain the required independent contract review, and perform the agreed two fresh blind model attempts. These are separate pieces of evidence. A strong model passing twice does not repair hidden policy, weak acceptance, or a buggy reference.

This investigation used public GitHub REST metadata/raw source and upstream pages only. Network fetching used at most two concurrent requests; there were no builds, tests, model calls, latency measurements, or changes to the scored inventory.
