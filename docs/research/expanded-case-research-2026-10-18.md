# Further candidate research and corrected feature cases

Second research pass, **2026-10-18**, following the request to investigate more candidates and consider a feature together with its later fixes. This report extends the [first shortlist](new-case-candidates-2026-10-18.md); it does not admit cases or change scoring. It used primary upstream evidence, local verifier inspection and bounded static Git patch composition. No project builds, fixture tests, model attempts or performance measurements ran.

**Further expansion:** the [project-diversity pass](project-diversity-candidates-2026-10-18.md) investigates concrete leads in seventeen additional projects, with separate drafting, focused-reserve and hold lists. The source decisions below remain part of the research history.

## Yes: one complete capability can span several PRs

A case can start before a feature and ask for its **corrected observable behavior**, using the feature PR and its necessary corrections as the reference. This can produce a better task than treating the feature and its regression repair as unrelated cases. A later fix is a reason to inspect the reference, not a permanent reason to discard the whole task family. The existing guideline against combining **unrelated** PRs does not prohibit this. [Current selection guidance](../pr-selection-guidelines.md#source-candidates-deliberately).

For a suitable pair, the three meaningful states are:

| Source state | Role in the case | Expected qualification result |
| --- | --- | --- |
| Before the feature | Solver starting point | Missing capability fails named assertions while relevant existing behavior still works |
| Original feature, without its necessary correction | Natural plausible-incomplete control | Ordinary feature examples can pass; the corrected edge/error behavior must fail |
| Feature plus coherent corrections | Reference solution | All declared feature, error-path and preservation checks pass |

These are expected controls to establish by execution, not results inferred from a merged PR. The intermediate feature is especially useful because it is an authentic plausible partial implementation, rather than an arbitrarily damaged patch.

The task kind follows what is absent at the starting point. Starting before a new capability usually makes this a **feature** task. Starting after the feature but before its correction is a **repair** task. A representation/dependency-boundary change to an already existing capability can instead be an objective **refactor**. Do not require a particular internal “shape” merely because upstream chose it; only expose and grade structural/API decisions that are actual task requirements.

Before combining sources:

1. Define one stakeholder outcome. Include fixes necessary to make that outcome correct; keep optional extensions and unrelated cleanup outside it.
2. Write the final contract from the behavior and compatibility obligations. The solver does not need the story of which PR introduced each defect or instructions to reproduce the historical architecture.
3. Record every contributing PR/commit, exact base, patch order, omitted changes, adaptations and final tree identity. Keep authorship and licenses attributable.
4. Review the *combined* tests. A later test may rely on a helper, schema change or error wording absent from an earlier base even when its patch applies without conflict.
5. Qualify the combined reference, original feature/incomplete controls, valid preservation cases and integrity controls, then apply the existing review and blind-solvability gates to this new case version.

Prefer one case per coherent family in a comparison set. If both a pre-feature task and a post-feature repair are retained, disclose their relationship and avoid treating them as independent coverage or placing them across development/confirmation partitions. A compound case is not admitted merely because the component PRs were accepted.

## What this pass adds to the shortlist

My first drafting choices from this additional search are **Absinthe #1404** for a new project and **Livebook #2618** for an application/session workflow. **Broadway #289 plus its timer correction** is a promising new OTP feature family. **Ecto's corrected writable-policy feature** is the strongest reconsideration of an earlier deferred source. The latter two need selected-patch reconstruction support before they can become honest case bundles. These priorities concern coverage and preparation uncertainty, not measured difficulty.

| Candidate family | Outcome and substantive scope | Recommendation / remaining dependency |
| --- | --- | --- |
| [Absinthe #1404](https://github.com/absinthe-graphql/absinthe/pull/1404) | Preserve operation/fragment descriptions through parsing, language structures, blueprint conversion and rendering; six implementation paths | First drafting choice from a new project. A coherent exception to the usual 2–5-file discovery target; establish semantic round trips and unchanged execution. |
| [Livebook #2618](https://github.com/livebook-dev/livebook/pull/2618) | Generic app proxy requests coordinate session startup, evaluation and idle lifecycle; three active implementation paths | First application drafting choice in this pass. Design synchronized session/handler witnesses and qualify the historical runtime. |
| [Broadway #289](https://github.com/elixir-broadway/broadway/pull/289) + [timer correction](https://github.com/elixir-broadway/broadway/commit/602931c981d194c6e07e699ab45b6e3747cf44a0) | Custom batch splitting through configuration and batcher state; three implementation paths | Strong corrected-feature candidate. Implementation patches apply cleanly; resolve synthetic provenance and deterministic timer/message controls. |
| [Ecto #4734](https://github.com/elixir-ecto/ecto/pull/4734) + [#4736](https://github.com/elixir-ecto/ecto/pull/4736) + [#4771](https://github.com/elixir-ecto/ecto/pull/4771) | Writable-field policy, returned-state preservation and callback enforcement; two implementation paths | Reconsidered family, not a new discovery. Choose minimal or broader coherent scope, resolve diagnostic-test dependence and synthetic provenance. |
| [Plausible #6470](https://github.com/plausible/analytics/pull/6470) | Membership confirmation, mutation and post-change navigation; two implementation paths | Useful browser-workflow candidate. Requires a real cancellation/persistence/navigation witness and historical CE setup. |
| [Bandit #707](https://github.com/mtrudel/bandit/pull/707) | Opt-in incremental gzip/zstd compression, negotiation and transport; three implementation paths | Promising protocol feature. Full zstd scope requires OTP 29 qualification; preserve default behavior and exclude speed assertions. |
| [Plausible #5027](https://github.com/plausible/analytics/pull/5027) + [#5076](https://github.com/plausible/analytics/pull/5076) | Rename goals while keeping saved segments and validation errors consistent; two implementation paths | Strong illustration of a combined feature, held for synthetic provenance and quoted-name/filter reference challenges. |

The [additional-project report](additional-project-candidates-2026-10-18.md) contains full contracts, historical environments and exclusions for Absinthe, Broadway and Bandit. The [corrected-lineage report](corrected-feature-lineages-2026-10-18.md) records Ecto and Plug compositions, including the narrower Ecto splice refactor and Plug upgrade-callback reserves. The application investigations follow below. Earlier priorities such as Ecto #4750 and Plug #1269 remain available; this search adds options rather than silently replacing their prior assessments.

Two tempting combinations remain deferred: Bandit's HTTP/2 blocked-send lineage needs another deadline/progress correction and deterministic functional controls; the inspected Absinthe `oneOf` feature/fix family still conflicts with the declared specification. Combining a feature with a fix does not itself establish a correct reference. Neither is counted as a ready candidate in the table.

## The current source verifier: what already works and what needs support

The implementation does **not** enforce one commit or an immediate-parent pair. [`Provenance.validate!/2`](../../lib/eab/provenance.ex) checks a primary PR URL, exact GitHub source revisions/tree hashes and a nonempty `pair_selection`. An exact upstream range containing only the coherent feature/corrections can therefore fit the existing model. Additional lineage metadata can be retained in the provenance map, although there is no dedicated validated multi-PR schema or automatic lineage review.

However, [`verify_pair/4`](../../lib/eab/provenance.ex) fetches both recorded revisions from the same upstream repository and requires the retained implementation, exact upstream tests and allowed documentation patches to reproduce the **whole fixed tree**. [`Source.snapshot/4`](../../lib/eab/source.ex) fetches the exact revision and verifies its tree. A curated combination on an earlier base normally produces a synthetic tree that is different from the later upstream commit.

| Construction | Current support |
| --- | --- |
| Exact upstream base → exact upstream fixed revision, with a coherent complete interval | Compatible in principle; still needs allowed-path checks, reconstruction and all functional gates |
| Selected accepted patches applied to an earlier upstream base, with unrelated intervening commits omitted | The research can construct and identify this tree, but production provenance cannot currently fetch/verify it as a local synthetic target |
| Corrected reference requiring curator-authored adjustments | Needs explicit reconstruction provenance/support; do not label it an untouched upstream commit |
| Later source with a feature removed to create the starting state | Also needs an explicit synthetic starting-state contract; the current source exporter expects a fetchable upstream starting revision |

The required future extension is a reconstruction recipe: a pinned upstream anchor, ordered source patches and adaptations with hashes, and the expected derived tree, retaining the same exact reconstruction and solver-isolation guarantees. That is an implementation direction, not something added in this research. Do not put unrelated source changes in the environment/test/documentation overlays to evade provenance or test-path restrictions. The current `environment.patch` preparation mechanism does not make synthetic source provenance valid. [Admission contract](../case-admission.md).

## New application candidates

### Livebook #2618 — proxy into an automatically started app session

**Recommendation:** source-screened feature candidate for the next drafting cohort. It adds an application request → app/session lifecycle → runtime-handler boundary, rather than another isolated formatter/query helper.

**Draft brief:** “Support proxy requests through the generic `/apps/:slug/proxy/*` URL for single-session apps, starting a session when needed. For both generic and explicit-session app URLs, wait for session evaluation before forwarding the request. Reject the generic URL for multi-session apps, keep their explicit-session URLs working, and refresh idle shutdown for proxied sessions.” The URL and session-mode policy are explicit requested behavior. Exact internal exception modules and subscription messages are not requirements. [PR #2618](https://github.com/livebook-dev/livebook/pull/2618), [complete diff](https://github.com/livebook-dev/livebook/pull/2618/files).

| Path | Responsibility |
| --- | --- |
| `lib/livebook/session.ex` | Coordinates idle-shutdown renewal and app-state notification behavior |
| `lib/livebook_web/plugs/proxy_plug.ex` | Resolves generic/explicit routes, obtains sessions and waits for evaluation before invoking the handler |
| `lib/livebook_web/errors.ex` | Keeps the not-found exception and adds the bad-request exception |
| `lib/livebook_web/errors/not_found_error.ex` | Deleted because the exception moved; do not count the same exception relocation twice |
| `test/livebook/proxy_test.exs` | Existing HTTP-method coverage plus generic path, on-demand session start and multi-session rejection |

This is three active implementation paths, one deleted relocation path and one test file. Most coordination lies in the session and proxy modules; the error module is a small supporting part, not evidence of difficulty. [Accepted commit](https://github.com/livebook-dev/livebook/commit/197f4868e15d216b9fb3297ec7cd75373a38d70d).

**Proposed witnesses:** a local notebook handler returns a recognizable body after a deliberately controlled evaluation barrier; the first generic request boots the session, waits for the barrier and receives that body; a second request reuses the session. An explicit-session app request must also wait at the evaluation barrier before reaching its handler. Existing explicit-session methods remain supported; multi-session generic access fails with the declared client error while its valid explicit-session URL works. Challenge a compiling implementation that adds the route and starts the session but calls the handler before evaluation completes. Pair rejection checks with a real valid multi-session request so rejecting all app traffic cannot pass. These checks remain unimplemented and unexecuted.

Idle shutdown is a functional lifecycle obligation, not a speed score. Use controlled state/timer messages or an audited clock seam with explicit synchronization, rather than elapsed-time comparisons. Review session termination or app removal while a request waits: the reference's receive loop has no explicit terminal-state exit when the session disappears. This is a source-review question to resolve before claiming robust cancellation, not a locally demonstrated failure or an automatic reason to add every lifecycle edge to this task.

**Historical runtime:** the [starting Mix project](https://github.com/livebook-dev/livebook/blob/55274f811776247c9fd0d6436a341fa1e30bfdd6/mix.exs) requires Elixir `~> 1.16` and OTP 25+. Dependencies are locked, and asset setup uses npm. The [helper](https://github.com/livebook-dev/livebook/blob/55274f811776247c9fd0d6436a341fa1e30bfdd6/test/test_helper.exs) initializes embedded runtimes and local Teams test support; it does not use the newer Python initialization seen in some later Livebook candidates. The [existing proxy fixture](https://github.com/livebook-dev/livebook/blob/55274f811776247c9fd0d6436a341fa1e30bfdd6/test/livebook/proxy_test.exs) builds its handler directly in a notebook, without installing Kino during the attempt. This is positive offline feasibility evidence from source, not a successful preparation. Use ExUnit and bounded process concurrency. [Apache-2.0 license](https://github.com/livebook-dev/livebook/blob/55274f811776247c9fd0d6436a341fa1e30bfdd6/LICENSE).

**Follow-up scope:** [#3211](https://github.com/livebook-dev/livebook/pull/3211/files), merged in 2026, adds `request_path` to the forwarded connection for clients that sign full URLs. It exposes a separate metadata limitation in the proxy family. The bounded #2618 case above tests session startup and routing; it does not certify complete signed-request proxy compatibility. If the intended task includes complete request metadata, use an explicitly corrected family and account for intervening route changes such as [#2666](https://github.com/livebook-dev/livebook/pull/2666), rather than silently borrowing a later URL contract. #3211 is a newly inspected focused repair, not an admitted second case.

### Plausible #6470 — confirmations and navigation after membership changes

**Recommendation:** source-screened application-workflow candidate, with a real browser acceptance path still to design. Two implementation files coordinate rendered member controls with the current user's updated access state. [PR](https://github.com/plausible/analytics/pull/6470), [complete diff](https://github.com/plausible/analytics/pull/6470/files).

**Draft brief:** “Confirm member removal and self-demotion to billing/editor/viewer before applying the action. After a successful self-demotion, take the user to that team's general settings; after self-removal, take them to the sites list with no team selected. Preserve allowed changes to other members and the existing last-owner protections.” Do not require the reference's exact warning prose. Redirect destinations and the action scope are public behavior described by upstream; the repository provides the relevant permission rules.

| Path | Responsibility |
| --- | --- |
| `lib/plausible_web/live/components/team.ex` | Renders confirmation hooks for removal and eligible self-demotion |
| `lib/plausible_web/live/team_management.ex` | Identifies the current member and selects navigation after membership changes |
| `test/plausible_web/live/team_management_test.exs` | Confirmation attributes and self-removal/self-demotion redirects |
| `CHANGELOG.md` | User-facing change note |

The upstream tests assert rendered `data-confirm` attributes and server redirects, but do not establish that canceling a browser confirmation prevents a mutation. A workflow-level acceptance should exercise cancel and accept, inspect persisted roles/memberships, and verify navigation after successful actions. Keep a second owner in self-demotion/removal fixtures, and independently verify that a sole owner cannot remove the last owner. Preserve changes to other members and avoid assigning self-demotion warnings to every role change. A plausible partial solution adds confirmations while leaving the user on a page they no longer have access to; another redirects correctly but still mutates after cancellation. [Pinned tests](https://github.com/plausible/analytics/blob/bc1954e7292bdbeb76cde4a4740b5e123adb4657/test/plausible_web/live/team_management_test.exs).

Do not disguise DOM-attribute checks as proof of the entire browser workflow. A supported controller-owned Node/Chromium fixture can observe confirmation, persistence and navigation together, with server/browser setup errors distinguished from behavioral failures. That fixture has not been written. The single-adapter contract means an opaque wrapper around ExUnit plus browser tooling is insufficient. [Browser admission contract](../case-admission.md#offline-browser-tasks).

The [starting Mix project](https://github.com/plausible/analytics/blob/8a0d359aec1b4611511988d847c31e42959ddd44/mix.exs) requires Elixir `~> 1.18`, includes CE test paths, and has a [committed dependency lock](https://github.com/plausible/analytics/blob/8a0d359aec1b4611511988d847c31e42959ddd44/mix.lock). The selected [test module](https://github.com/plausible/analytics/blob/8a0d359aec1b4611511988d847c31e42959ddd44/test/plausible_web/live/team_management_test.exs) uses CE/EE mail-prefix variants rather than excluding the whole workflow from CE. Exact PostgreSQL/ClickHouse setup, CE browser bootstrap, assets and historical data migrations remain to qualify. [AGPL source license](https://github.com/plausible/analytics/blob/8a0d359aec1b4611511988d847c31e42959ddd44/LICENSE.md); preserve any relevant edition-specific notices.

### Plausible #5027 + #5076 — rename goals without breaking saved segments or error handling

**Recommendation:** a strong example of the user's combined-feature approach; defer admission pending synthetic-source support and the reference challenge below. This is a new source family, distinct from rejected imported-goal #6441 and CSV #6763.

[Feature #5027](https://github.com/plausible/analytics/pull/5027) updates saved segments when a goal's display name changes. [Fix #5076](https://github.com/plausible/analytics/pull/5076) explicitly says that the feature broke the display of goal validation errors and restores their transaction handling. Their shared outcome is maintaining consistent goal/segment state while preserving useful failures.

**Draft brief:** “When a goal's display name changes, update references to that goal in the same site's saved segments, including personal and site segments. Preserve other goals, filters and sites. Invalid updates must still return/display validation errors and leave the goal and segment data unchanged.” If only a particular filter operator is supported, establish and disclose that policy before grading; do not infer support for every operator from a single equality-filter example.

The combined source changes two implementation files, `lib/plausible/goals/goals.ex` and `lib/plausible/segments/segments.ex`, plus goal-context and LiveView form tests. The implementation coordinates the goal write, JSON filter transformation and transaction result consumed by the form. The original feature is the natural incomplete control: it can update segments successfully while returning a nested success/error shape on invalid input. A complementary incomplete control could repair validation but update only site segments, dropping personal segments from the propagation path. [Feature diff](https://github.com/plausible/analytics/pull/5027/files), [fix diff](https://github.com/plausible/analytics/pull/5076/files).

**Static composition actually performed:** fetched the four exact accepted source commits into a scratch Git repository, checked out the pre-feature revision, then applied both accepted-commit diffs with `git apply --index --whitespace=nowarn`. Both applied without conflict. No code or tests were executed.

| Evidence | Recorded value |
| --- | --- |
| Pre-feature source | `70bfc9ef66c6a648332cc69a55d423d6800e78c9` |
| Accepted #5027 | `9f1d8ec2b7813c51b33d3bc512fdb3ec49275082` |
| Parent of #5076 | `29b7d141d6cef2781e27944e6a3bb2f004de77c2` |
| Accepted #5076 | `7ae88c2c97ce902bd6fe62e54151c6882809b3e3` |
| Derived selected-patch tree | `37bdd65acfad503698375e703a848a4970c65564` |
| Actual later upstream tree | `d461594c40f5b25cf8f6863dbc5244b364609f07` |
| Selected combined change | 4 files; 130 inserted / 7 deleted lines |
| Whole upstream interval | 62 changed files; the derived selected-patch tree differs from the later upstream tree on 58 paths |

Source links: [accepted feature commit](https://github.com/plausible/analytics/commit/9f1d8ec2b7813c51b33d3bc512fdb3ec49275082), [accepted correction](https://github.com/plausible/analytics/commit/7ae88c2c97ce902bd6fe62e54151c6882809b3e3), [complete interval](https://github.com/plausible/analytics/compare/70bfc9ef66c6a648332cc69a55d423d6800e78c9...7ae88c2c97ce902bd6fe62e54151c6882809b3e3). The derived tree hash is an audit identity from local composition, not a public commit or an admission receipt. This is a concrete example of why clean patch application and exact upstream reconstruction are separate questions.

**Reference challenge still needed:** the feature preselects rows using a regex over JSON text, interpolating `Regex.escape(stale_goal.display_name)`. The [starting goal schema](https://github.com/plausible/analytics/blob/70bfc9ef66c6a648332cc69a55d423d6800e78c9/lib/plausible/goal/schema.ex) does not forbid ordinary quotes/backslashes in display names. JSON escaping can change their serialized representation; regex-escaping the unencoded name does not establish a match against JSON text. Challenge quoted/backslashed names, nested filters, mixed goal names and cross-site isolation. This is source-level concern, not an executed failing reference. Do not omit a legitimate input solely to preserve the composed reference; if it fails, attribute the further correction and requalify.

The [historical Mix project](https://github.com/plausible/analytics/blob/70bfc9ef66c6a648332cc69a55d423d6800e78c9/mix.exs) requires Elixir `~> 1.17`; `ce_test` excludes `extra/lib`, and the [test helper](https://github.com/plausible/analytics/blob/70bfc9ef66c6a648332cc69a55d423d6800e78c9/test/test_helper.exs) enables saved segments and excludes EE-only tests. The two added ordinary-goal witnesses are not marked EE-only. The test alias creates/migrates databases and cleans ClickHouse, so exact historical setup and bounded pool sizes matter even though the changed behavior mainly uses PostgreSQL. The [license](https://github.com/plausible/analytics/blob/70bfc9ef66c6a648332cc69a55d423d6800e78c9/LICENSE.md) is AGPL; no cloud service is needed for the proposed goal/segment behavior. CE execution remains unverified.

## Further leads excluded or deferred during application discovery

| Newly inspected source | Disposition |
| --- | --- |
| [Livebook #3134](https://github.com/livebook-dev/livebook/pull/3134/files) | Two runtime files, but combines a persistence-dialog mount-event fix with credential redaction. Only the dialog fix has an added test. Do not inflate a compound issue into a coherent two-file feature; consider separately reviewed focused tasks or a justified shared workflow. |
| [Livebook #2783](https://github.com/livebook-dev/livebook/pull/2783/files) | Two runtime files; URL/file validation work without added tests. Reserve pending a contract and meaningful acceptance/preservation witnesses. |
| [Livebook #2309](https://github.com/livebook-dev/livebook/pull/2309/files) | Seventeen paths, broad output/async rendering changes and dependency update, no test changes. Defer from the initial cohort rather than treating the async title as a ready behavioral task. |
| [Livebook #2167](https://github.com/livebook-dev/livebook/pull/2167/files) | Twenty-one paths spanning runtime callbacks, session state, file management and UI. Coherent larger feature but a separate scope/runtime investigation, not a forced 2–5-file task. |
| [Plausible #5917](https://github.com/plausible/analytics/pull/5917/files) | Goal limit spans CE/EE controllers, context and UI; source request links a private Basecamp record. Defer until sufficient public outcome policy and edition scope are independently established. A private link alone is not an executable contract. |
| [Plausible #6153](https://github.com/plausible/analytics/pull/6153/files) | One-line implementation plus browser tests/support: useful focused browser repair, not a multi-file implementation candidate. |
| [Plausible #6388](https://github.com/plausible/analytics/pull/6388) | A follow-up search result, **not merged** when inspected. Broad changes and tests do not establish an accepted reference. Exclude from the historical merged-source shortlist; no runtime validation attempted. |

The [previous exclusion history](new-case-candidates-2026-10-18.md#do-not-rediscover-or-relabel-the-old-decisions) still applies. None of Plausible #6300/#6763/#6441, existing cases, or previously screened candidates is relabeled as a new discovery here. Corrected-family reconsideration is a new version with explicit evidence, never a retrospective rewrite of past outcomes.

## Source identities, search scope and remaining work

| New single-PR candidate | Starting revision | Accepted revision |
| --- | --- | --- |
| Livebook #2618, merged 2024-05-24 | `55274f811776247c9fd0d6436a341fa1e30bfdd6` | `197f4868e15d216b9fb3297ec7cd75373a38d70d` |
| Plausible #6470, merged 2026-07-07 | `8a0d359aec1b4611511988d847c31e42959ddd44` | `bc1954e7292bdbeb76cde4a4740b5e123adb4657` |

For both single-PR candidates and both Plausible composition components, complete PR file counts matched metadata and patch line counts. Accepted-commit paths matched PR inventories. #5027 had two different final blobs because its base advanced; inspection found only hunk-offset changes between the PR and accepted diffs. Static composition used the accepted diffs.

Application discovery queried merged PRs with `app`/`file` in Livebook titles and `team`/`goal` in Plausible titles, fetching up to 45 recent results each, then inspected ten selected complete file inventories. Targeted proxy/goal/segment searches led to the additional #3211 and unmerged #6388 inspections. Overlapping search pages are not independent cases or an admission-yield estimate. Primary evidence included full diffs, discussions, accepted ancestry, historical code/tests, Mix setup/locks and licenses.

The [corrected-lineage investigation](corrected-feature-lineages-2026-10-18.md) extends this work into Ecto and Plug, with additional actual static compositions and their limitations. The [additional-project investigation](additional-project-candidates-2026-10-18.md) broadens the corpus toward Broadway, Bandit and Absinthe, keeping follow-up defects and runtime risks explicit.

The next actionable stage is to choose a small drafting cohort, settle each visible contract and finish source/runtime support. Then implement meaningful checks and controls, run the existing qualification rounds and obtain the required independent review and two reviewed blind successes. The research has established source-grounded candidates and several reproducible patch compositions; it has not established functional qualification or solvability.
