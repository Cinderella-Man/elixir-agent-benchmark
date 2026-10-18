# Corrected features assembled from coherent upstream lineages

Research date: **2026-10-18**. A feature and its subsequent correctness repairs can form one credible task: implement the intended capability correctly from its original pre-feature state. This report investigates three concrete families and distinguishes semantic scope, source reconstruction and eventual qualification. It does not alter the earlier exclusions, create case bundles, change admission policy or modify the runner.

Work performed: primary PR/discussion/diff inspection, local Git ancestry and source review, and **static patch application in isolated scratch worktrees**. No project builds, tests, model attempts, fixture qualification or performance measurements ran. Network requests within this process were sequential. A clean `git apply` result establishes textual compatibility, not compilation, correctness or complete dependency compatibility.

## Recommendation

| Family | Proposed corrected task | Discovery disposition |
| --- | --- | --- |
| Ecto #4734 + #4736 + #4771 | Add per-field writable-violation policies that preserve returned-state semantics and apply after preparation callbacks | **Best reconsideration candidate.** Two implementation files. Exact selected patches transplant cleanly, but the minimal composition exposes an upstream-test wording dependency and creates a synthetic target tree. |
| Ecto #4697 + #4750; optionally include the earlier #4693 feature | Expand runtime fragment splices before the adapter boundary while preserving bindings and evaluation; optionally add compile-time splice syntax | **Coherent refactor reserve.** Three implementation files. Do not present the optional three-PR combination as a repair required by #4693 alone. |
| Plug #1309 + #1320 | Execute upgrade callbacks before adapter upgrade while the response remains mutable | **Focused corrected-source reserve.** One implementation file. Useful lifecycle behavior, without solving the corpus's concentration of one-file tasks. |

All three are **reconsidered families**, not unrelated new discoveries. The [October 15 shortlist](multi-file-pr-candidates-2026-10-15.md) deferred #4734; the [October 18 candidate report](new-case-candidates-2026-10-18.md) held #4697 and #1309 for follow-up review. Those decisions remain correct for the original references. A combined task would receive a new case identity/version and explicitly attributed patch lineage. Do not count its component PRs again as independent coverage, or put near-identical repair and corrected-feature variants on opposite sides of a development/confirmation split.

## 1. Ecto writable-violation policy: the strongest corrected-feature case

### What belongs in the lineage

[Ecto #4734](https://github.com/elixir-ecto/ecto/pull/4734) introduces `on_writable_violation`, letting fields ignore, warn about or reject attempted writes forbidden by `:writable`. [#4736](https://github.com/elixir-ecto/ecto/pull/4736) explicitly repairs a regression caused by that implementation: ignored changes were reflected in returned structs even though the adapter write excluded them. [Issue #4770](https://github.com/elixir-ecto/ecto/issues/4770) then reports that changes added by `prepare_changes/2` bypass enforcement; [#4771](https://github.com/elixir-ecto/ecto/pull/4771) reapplies the policy after preparation for insert and update. These repairs concern the same requested field-policy capability.

The smallest source set identified for that ordinary-field contract is **#4734 + #4736 + #4771**. “Smallest” here means the selected behavioral lineage found in this investigation, not a proof that no alternative smaller implementation exists.

| Source | Accepted commit | Role in a combined task |
| --- | --- | --- |
| [#4734](https://github.com/elixir-ecto/ecto/commit/e1d4be8c9488a0c6b34683af2b6994406cefeb3e), 2026-06-16 | `e1d4be8c9488a0c6b34683af2b6994406cefeb3e` | Introduces field-level policy and repository enforcement |
| [#4737](https://github.com/elixir-ecto/ecto/commit/0ff27f83b15ebecc6a48f6e29247b68e6097bd7f), 2026-06-17 | `0ff27f83b15ebecc6a48f6e29247b68e6097bd7f` | Optional schema-wide default with per-field override; coherent extension, not required for field-only policy |
| [Metadata implementation adjustment](https://github.com/elixir-ecto/ecto/commit/7cb27b3a5ec17066fc4eee4dab556af8aa740984), 2026-06-17 | `7cb27b3a5ec17066fc4eee4dab556af8aa740984` | Replaces generated metadata-map access with clauses; reference implementation detail, not a solver requirement |
| [#4736](https://github.com/elixir-ecto/ecto/commit/2e59540acfa1d53c13c3e31c1011044e787c20e6), 2026-06-18 | `2e59540acfa1d53c13c3e31c1011044e787c20e6` | Restores ignored-change handling and separately diagnoses values already in inserted structs |
| [#4738](https://github.com/elixir-ecto/ecto/commit/c4bb74a1140b341ef6667da288f535ee5620796a), 2026-06-19 | `c4bb74a1140b341ef6667da288f535ee5620796a` | Adds schema and policy context to diagnostics; useful semantic improvement, exact prose is incidental |
| [#4771](https://github.com/elixir-ecto/ecto/commit/3fff2a31af55338417f712db66c5dc64551535d1), 2026-07-28 | `3fff2a31af55338417f712db66c5dc64551535d1` | Enforces policy after preparation callbacks |
| [#4752](https://github.com/elixir-ecto/ecto/commit/d43c92ba8394e099551ffa0084641d99d5d7a226), 2026-08-14 | `d43c92ba8394e099551ffa0084641d99d5d7a226` | Optional `inserted_at` configuration through `timestamps/1`; omit from the initial ordinary-field task |

The original pre-feature base is **`129c2eaf68597101359a6b288042971792370ebc`**, #4734's sole parent. The first five commits in the table form an uninterrupted, coherent sequence from that base. #4771's actual parent is **`e2b35d254c41c2e5d4b085117e7f31f6e471575d`**, and #4752's is **`a33eed3363a59ee62734cbd37a0074fcef6fc8f9`**. Their intervening history is not part of a minimal field-policy task. [Original accepted commit](https://github.com/elixir-ecto/ecto/commit/e1d4be8c9488a0c6b34683af2b6994406cefeb3e), [later enforcement commit](https://github.com/elixir-ecto/ecto/commit/3fff2a31af55338417f712db66c5dc64551535d1), [timestamps commit](https://github.com/elixir-ecto/ecto/commit/d43c92ba8394e099551ffa0084641d99d5d7a226).

### A fair contract and its boundaries

Proposed clarified brief for the minimal version:

> Add a per-field `on_writable_violation` option with `:nothing`, `:warn` and `:raise`, defaulting to silent ignore. Apply it when inserts or updates attempt writes forbidden by the field's existing `:writable` setting, including changes introduced by `prepare_changes/2` and values supplied in an inserted struct. Warning mode must ignore the forbidden write and identify the offending field; raising must abort the write. Preserve ordinary writable fields and the existing returned-struct behavior for ignored writes.

If using the broader early series, add the public `@on_writable_violation` default/field-override requirement and require diagnostics to identify the schema and operation as well. These are legitimate outcome choices; generated `__schema__` dispatch shape and exact warning paragraphs need not be requirements. If invalid option values are to have a particular error contract, investigate and state it separately rather than inferring validation from the documented allowed values.

There is a subtle preservation rule to retain. #4736's discussion explicitly preserves the existing distinction between an ignored **explicit change**, which must not replace the original field value in the returned struct, and a value **already present in the input struct**, which can remain in that returned struct without being written to storage. The corrected task should not silently invent a uniform “set every ignored field to nil” policy. Check the adapter payload and returned struct separately, using the historical starting behavior to establish preservation. [Maintainer/author discussion](https://github.com/elixir-ecto/ecto/pull/4736).

Likewise, #4752 is an opt-in extension, not a prerequisite to the ordinary-field repair. Its review explicitly declines making `inserted_at` immutable by default for compatibility. If included later, the brief must expose `:inserted_at_writable` and `:inserted_at_on_writable_violation`, preserve unchanged defaults and settle the prohibition on `:never`. Do not fold these decisions into hidden tests for the smaller task. [Timestamps discussion and diff](https://github.com/elixir-ecto/ecto/pull/4752).

Useful behavioral witnesses would distinguish insert/update, `:never`/`:insert`, ignore/warn/raise, explicit changes/input-struct values, and callback-added changes. Pair forbidden values with legitimate writable values, so disabling the write cannot pass. For callback updates, include an ordinary writable change that causes the historical update/preparation path to run; do not inadvertently demand that no-op updates start running callbacks. Verify raised operations do not reach the adapter. These are **proposed checks**, not results from this research.

### Static transplantation succeeded, with a test dependency

Both production files and all test hunks from **#4734 → #4736 → #4771** applied cleanly, without manual edits, to the original pre-feature base. The resulting diff has **two implementation files** (`schema.ex`, `repo/schema.ex`) and **one test file**. No dependency or build configuration changed.

However, source inspection reveals a concrete mismatch despite clean application: the new #4771 tests expect #4738's later warning/error paragraph, while the minimal runtime composition still emits #4734's older message. This is a predicted assertion mismatch from inspected text, **not an executed failure**. It demonstrates why a clean patch stack is not enough. [#4771's new assertions](https://github.com/elixir-ecto/ecto/commit/3fff2a31af55338417f712db66c5dc64551535d1), [original diagnostic](https://github.com/elixir-ecto/ecto/commit/e1d4be8c9488a0c6b34683af2b6994406cefeb3e).

Two honest preparation choices remain:

- Keep the minimal behavioral lineage, retain the exact upstream tests as provenance, and adapt the grading tests to semantic diagnostic assertions. Such adaptations must be attributed and reviewed.
- Keep the coherent first five commits plus #4771. This composition also applied unchanged and includes the diagnostic evolution and schema-wide defaults; it changes two implementation and two test files. The brief and accepted implementations still need not reproduce its internal metadata design.

Adding #4752 to the latter composition also applied cleanly, but adds product scope rather than a required correction. None of these compositions has compiled or executed here.

**Natural incomplete controls:** the original #4734 implementation supplies the intended feature but misses returned-state preservation and callback enforcement. A version including #4736 but omitting #4771 isolates the callback omission. These are stronger task-shaped candidates for incomplete controls than deleting arbitrary code; they still need actual compilation and named-failure qualification.

### Why the later upstream commit is not the combined reference automatically

The exact upstream interval from the pre-feature base through #4771 contains **24 commits and changes 37 paths**, including unrelated UUID helpers, query features/repairs, association/changeset changes, a release, and `mix.exs`/`mix.lock` updates. The combined task should not require or conceal that work. Even within `repo/schema.ex` and `repo_test.exs`, endpoint file replacement risks importing unrelated edits; the static experiment used selected commit diffs, not whole files copied from July. [Upstream comparison](https://github.com/elixir-ecto/ecto/compare/129c2eaf68597101359a6b288042971792370ebc...3fff2a31af55338417f712db66c5dc64551535d1).

The selected patches leave the original `~> 1.14` Mix requirement and historical lockfile intact. The late correction uses existing preparation/enforcement functions, giving a plausible source-level transplant without a newly identified dependency. That is not proof the historical dependency set installs or the augmented tests pass offline. [Pre-feature Mix project](https://github.com/elixir-ecto/ecto/blob/129c2eaf68597101359a6b288042971792370ebc/mix.exs).

## 2. Ecto splicing: distinguish the feature from the later refactor

[Issue #4375](https://github.com/elixir-ecto/ecto/issues/4375) requests reusable fragment macros involving query bindings. The accepted design in [#4693](https://github.com/elixir-ecto/ecto/pull/4693) adds **compile-time** `splice([...])`, including bindings, literals, interpolated values and nested fragment modifiers/runtime splices. The discussion deliberately retains the old runtime splice behavior for a later PR. [#4697](https://github.com/elixir-ecto/ecto/pull/4697) then changes runtime expansion so adapters no longer need a splice-specific representation. [#4750](https://github.com/elixir-ecto/ecto/pull/4750) repairs dynamic-parameter duplication and repeated evaluation of preceding interpolation expressions in that later design.

Consequently, **#4750 does not by itself establish that #4693's original compile-time feature is defective**. Treating all three as one feature is a deliberate expanded scope choice, not merely recovering an obviously missing fix.

| Source | Accepted commit | Actual immediate parent |
| --- | --- | --- |
| [#4693](https://github.com/elixir-ecto/ecto/commit/1335593fd63e171ed8383db24aff9ecd982644fa), 2026-01-08 | `1335593fd63e171ed8383db24aff9ecd982644fa` | `8d6576282e66c6cbae759e3460e66e5574434346` |
| [#4696](https://github.com/elixir-ecto/ecto/commit/7224c12734f1a2ad4b87ba769db87dbc80be3468), 2026-01-09 | `7224c12734f1a2ad4b87ba769db87dbc80be3468` | `1335593fd63e171ed8383db24aff9ecd982644fa` |
| [#4697](https://github.com/elixir-ecto/ecto/commit/bf242348cdf89c056a977668da707b9937208efe), 2026-01-11 | `bf242348cdf89c056a977668da707b9937208efe` | `7224c12734f1a2ad4b87ba769db87dbc80be3468` |
| [#4750](https://github.com/elixir-ecto/ecto/commit/f1bd9d165a9cfa5790e563296f95b696297e50cc), 2026-07-08 | `f1bd9d165a9cfa5790e563296f95b696297e50cc` | `9d7b3010aad9f37c8c2fca3ac0a25d2aa691486a` |

#4696 moves `constant/1` unpacking into Ecto. It is an adjacent cleanup, not a necessary splice outcome. The three selected splice patches applied cleanly with it omitted. Do not require that constant refactor merely because it lies between the feature and runtime change.

### Two viable task scopes

**Narrower objective refactor:** start from `7224c12734f1a2ad4b87ba769db87dbc80be3468`, which already has compile-time splicing, and combine #4697 with #4750. Proposed brief:

> Expand runtime fragment splices within Ecto so adapters can consume ordinary fragment expressions and parameters without splice-specific handling. Preserve existing compile-time/runtime splice behavior, including composed dynamic expressions, correct binding order and evaluation of each interpolated expression once.

The ordinary adapter contract is the explicitly requested structural outcome. Test that boundary, not particular private helper functions or the reference's bookkeeping map. Without that requirement, retaining the older runtime representation can be a legitimate way to preserve behavior, and should not be rejected for failing to imitate #4697.

**Broader clarified feature:** start from `8d6576282e66c6cbae759e3460e66e5574434346` before #4693 and combine #4693, #4697 and #4750. Add the compile-time syntax/capabilities to the brief above. This is coherent if both user-facing macro flexibility and adapter-independent expansion are desired, but is more than “add compile-time splicing.” Do not force it solely to produce a larger reference patch.

Both complete accepted-patch sequences applied with `git apply --index` without manual edits. The narrower result has **three implementation and two test files**. The broader result has **three implementation files**, a **documentation-only change in `lib/ecto/query/api.ex`**, and **three test paths** including an integration case. Counting every `lib/` path as implementation would overstate its scope.

The direct-versus-dynamic comparison in [issue #4749](https://github.com/elixir-ecto/ecto/issues/4749) and #4750's counter-based evaluation test provide useful correction witnesses. Challenge nested dynamics, multiple splices with surrounding parameters, duplicate legitimate values and compile-time/runtime combinations. Preserve non-splice fragments and ordinary interpolation. The interface contract describes parameter treatment; do not grade a private AST/map layout where equivalent adapter behavior suffices. The PR body mistakenly links #4748, so preserve #4749 as the behaviorally matching report, as explained in the [earlier candidate analysis](new-case-candidates-2026-10-18.md#1-ecto-4750-bind-dynamic-fragment-parameters-correctly).

**Natural incomplete controls:** #4697 without #4750 for the narrower task, or #4693+#4697 without #4750 for the broader task. These retain the intended expansion but omit the later binding/evaluation correction. A #4693-only implementation is an incomplete control **only if adapter-independent runtime expansion is explicitly in scope**. None has been executed as a benchmark control.

The full upstream feature-to-fix interval contains **50 commits and 53 changed paths**; the refactor-to-fix interval contains **48 commits and 52 changed paths**. They include unrelated association, schema, query, repository and release work plus CI/dependency changes. The selected stacks retain their original `~> 1.14` Mix requirement and lockfile, with no build/dependency patch selected. Source compatibility is promising, while historical installation, unit tests and any real SQL integration remain unverified. [Full feature interval](https://github.com/elixir-ecto/ecto/compare/8d6576282e66c6cbae759e3460e66e5574434346...f1bd9d165a9cfa5790e563296f95b696297e50cc), [refactor interval](https://github.com/elixir-ecto/ecto/compare/7224c12734f1a2ad4b87ba769db87dbc80be3468...f1bd9d165a9cfa5790e563296f95b696297e50cc).

## 3. Plug upgrades: a small but particularly clear corrected behavior

[#1309](https://github.com/elixir-plug/plug/pull/1309) makes `upgrade_adapter/3` invoke registered before-send callbacks. Its accepted implementation invokes them after `adapter.upgrade` succeeds, with the connection already in an upgraded state. [#1320](https://github.com/elixir-plug/plug/pull/1320) moves callbacks before that adapter call, gives them switching-protocol status and a mutable pending-upgrade state, and adds a test that writes a response header. This is one lifecycle requirement corrected, rather than unrelated additions.

| Role | Commit |
| --- | --- |
| Original pre-feature base | `d2580b0579a7d804b2dfa0f9ed35d459236143ed` |
| [#1309 accepted](https://github.com/elixir-plug/plug/commit/041bb1bc08cda20e02ba6cf309ce536664664aa7), 2026-06-12 | `041bb1bc08cda20e02ba6cf309ce536664664aa7` |
| #1320 immediate parent | `82cbff630373c61696b246bd383f16da1ecc945b` |
| [#1320 accepted](https://github.com/elixir-plug/plug/commit/96f573e5aba02bec24bae8fcc05d467d39709bfc), 2026-06-30 | `96f573e5aba02bec24bae8fcc05d467d39709bfc` |

Proposed clarified brief:

> Run registered before-send callbacks before a successful adapter upgrade is performed. Callbacks must be able to modify response headers and assigns and observe status 101; preserve those changes in the returned upgraded connection and preserve ordinary response callbacks and unsupported-upgrade errors.

If compatibility requires callbacks to observe the exact public state atom `:set_upgrade`, state that explicitly; otherwise exercise mutability and ordering without requiring the reference's particular state name. Do not assume callbacks have no side effects on an unsupported adapter: the corrected implementation invokes them before asking the adapter whether it supports the upgrade, unlike the original. Resolve such an additional policy before asserting it.

Both accepted patches applied unchanged to the pre-feature base. The net task changes **one implementation file and one test file**, retaining the original Elixir `~> 1.15` requirement and lockfile. The original #1309 patch is a natural proposed incomplete control: assigning a flag can pass its original test, while mutating response headers before upgrade exposes the missing lifecycle behavior. A test adapter recording callback/upgrade events could add a direct ordering witness. These checks have not run.

The real upstream interval has **16 commits and 37 changed paths**, including independent HTTP/header/static-file changes, releases, dependency changes and optimizations. Those optimizations were inspected only as excluded intervening history; no speed work was run or assessed. This stays a focused reserve, and does not become a multi-file flagship merely because two PRs are combined. [Upstream comparison](https://github.com/elixir-plug/plug/compare/d2580b0579a7d804b2dfa0f9ed35d459236143ed...96f573e5aba02bec24bae8fcc05d467d39709bfc).

## 4. Static reconstruction evidence and the current provenance boundary

For each experiment, a detached scratch worktree began at the recorded original base. Exact **accepted-commit-to-parent** diffs, including their tests, were generated with `git diff --binary`. Each selected patch passed `git apply --index --check`, then was applied to the index without manual resolution. `git write-tree` recorded the resulting full tree. No source file was executed. The results are reproducible from the pinned commits above; scratch receipts are not qualification receipts.

| Composition, in applied order | Resulting synthetic tree | Scope |
| --- | --- | --- |
| Ecto #4734, #4736, #4771 | `3c899c951a58114505ac59e09fd9857eb3735df3` | Clean application; known diagnostic assertion mismatch described above |
| Ecto #4734, #4737, metadata adjustment, #4736, #4738, #4771 | `607378fb992a4735d0b6e8df1cb196b410b48b9d` | Clean application of coherent early series plus callback repair |
| Previous row plus #4752 | `e9de1235f4ceae2d9a5f954bbe413011cdebf3da` | Clean application with optional timestamps scope |
| Ecto #4693, #4697, #4750 | `6e493ff566e07d632049bfa512c9ebfe425d4a01` | Clean application, excluding #4696 |
| Ecto #4697, #4750 on the later pre-refactor base | `1247062fa80d39c6f2b69950e295ccbbe96d5a8a` | Clean application of corrected refactor |
| Plug #1309, #1320 | `0f0389dbf9dc10a4bc17e3d63abfaab4a95daa95` | Clean application of corrected upgrade behavior |

The actual upstream target trees are different: Ecto #4771 is `98a52fee38ee36a11a07607de0e435a547895daf`, Ecto #4750 is `1aba877c99feeb7769fd4ae1909dfe15f6b3662b`, and Plug #1320 is `748ce940ecffc82f3a60d774ed2180b8f5170da2`. Selecting the later commit as `fixed_revision` while claiming one of the synthetic trees would misstate provenance.

The current [`Provenance.validate!/2`](../../lib/eab/provenance.ex) does **not** require a single-commit change or an immediate-parent base. It accepts one primary PR URL and nonempty pair-selection rationale; extra lineage metadata can be retained in the provenance map. A coherent multi-PR **exact upstream range** can therefore fit the existing representation.

The binding constraint is elsewhere: [`Source.snapshot/4`](../../lib/eab/source.ex) fetches each recorded revision from the recorded GitHub repository, and `Provenance.verify_pair/4` requires the implementation plus exact upstream tests and allowed documentation patches to reconstruct the **entire actual fixed tree**. These isolated composites are synthetic trees, with no corresponding fetchable upstream commit identified. An explicit source-reconstruction contract/support change, or another deliberately reviewed fetchable-source arrangement with honest curator attribution, is needed before representing them as cases. A locally staged tree hash alone does not satisfy the current source contract.

Do not make the verifier pass by including unrelated interval work in `reference.patch`, by hiding it in the restricted documentation/test patches, or by treating feature changes as task-neutral environment setup. Reversing the feature out of a later tree merely moves the same synthetic-source question to the starting state. [Admission source rules](../case-admission.md).

## 5. What the next research-to-case step should preserve

For the first corrected-feature pilot, prefer the Ecto writable-policy family. Choose the ordinary-field or schema-default scope deliberately, then freeze an outcome brief before writing the final assertions. Retain every selected upstream patch separately from any curator-authored adaptation, the original base, source licenses, exact composite tree, omitted neighboring changes and the rationale connecting the commits. The Ecto and Plug repositories use Apache-2.0; preserve their starting-revision notices rather than treating a composite as solely curator-authored material. [Ecto notice](https://github.com/elixir-ecto/ecto/blob/129c2eaf68597101359a6b288042971792370ebc/LICENSE.md), [Plug notice](https://github.com/elixir-plug/plug/blob/d2580b0579a7d804b2dfa0f9ed35d459236143ed/LICENSE).

Then resolve the source-reconstruction support and independently review the contract, including returned-state and callback corner cases. Preserve exact upstream tests as source evidence; adapt acceptance/preservation checks where their internal metadata or exact-message assertions overconstrain the visible task. New schema options must be checked within named test bodies so the pre-feature state does not fail globally during test-module compilation.

Actual offline environment preparation, reference/unchanged/natural-incomplete/integrity controls, three fresh matching qualification rounds and two reviewed blind strong-model successes all remain outstanding. The static results justify investing in a corrected source; they do not rescind the old exclusions or admit the new composite.
