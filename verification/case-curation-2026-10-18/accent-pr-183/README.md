# Accent 183 curation

Status: approved after three fresh matching qualification rounds and two reviewed fresh Astra successes. One earlier provider-overload interruption remains retained. The unchanged bundle is parked in `cases_approved/accent-pr-183/`; only this case was active for its model runs. The [independent requirements-first review](../../../docs/research/accent-183-contract-review-2026-10-18.md) approves the feature/assertion mapping and records environment readiness separately.

The case adds project-scoped semantic-version selection for real translation export, sync and merge requests. Exact literal tags take priority; otherwise choose the highest compatible version, accepting ordinary lowercase-v tags and ignoring malformed/non-version candidates. Existing unmatched responses (404 export, 422 mutations), unversioned behavior and other project/version data are preserved. The fixed reference is the exact upstream PR183 tree from its first parent.

## Preparation history

The initial runtime pinned Elixir 1.9.4/OTP 22.3.3, matching historical CI, and PostgreSQL 10.23. The first build failed during dependency compilation, before tests: `fast_yaml` could not load its C compiler plugin. A focused diagnostic reproduced the plugin failure and identified a package-resolver error after loading the dependency's unpinned publishing plugin. Removing only that unused plugin allowed the C compiler plugin to load and exposed the missing YAML header. [Diagnostic log hashes and disposition](preparation-history.json).

A neutral environment overlay now runs native preparation before `deps.loadpaths`: pin the observed working C compiler plugin, omit the unused publishing plugin, and build pinned libyaml 0.2.5 as a static PIC library with two jobs. The app's feature modules and locked dependency versions are unchanged. Compatibility edits to dependency build/source declarations are explicit below. Prepared workspaces need no network for these steps. The second preparation succeeded, including the actual application compile and pristine database initialization. The subsequent offline tests executed, but qualification was invalid for the completion-event reason below; this is not case admission.

Before qualification, independent review also added the visible two-component requirement example and a combined comparison check. A parent review removed the original scope doctest from protected preservation because the accepted feature makes that helper database-reading and upstream deliberately changes the doctest's sandbox case. Three real controller suites remain protected; the corrected upstream scope tests remain submitted reference tests.

All work is functional validation with bounded resources. No speed comparison or performance claim is made.

## ExUnit completion compatibility amendment

Version `30d3791ee20fd4065c391924423fc84ab811b8ec7033683567e04fc462c8d064` executed the intended controls: the reference had six acceptance, sixteen preservation and twenty-five submitted named passes; unchanged source failed the three feature checks, and the partial implementation failed sync/merge while passing export. Every suite nevertheless had `completed: false`, so qualification correctly rejected the version. [Retained named outcomes](invalid-controls-1.json).

A minimal real ExUnit 1.9 probe confirmed a three-element `suite_finished` event. The unchanged trusted formatter handles the two-element form introduced in Elixir 1.12. The first compiler adaptation pinned Elixir 1.12.3 within the project's declared `~> 1.9` range, retaining OTP 22.3.3, locked application dependencies and all assertion/reference/environment artifacts. Its compatibility required fresh qualification; this is not an exact historical CI toolchain claim. The grader and existing parked admission records remain unchanged. The old invalid version and its controls remain retained, and no model ran against it.

The first compiler adaptation (`bef1e552ff2a839eaa2ed00dc67800493cdf4d17407defae078e156e43e96baf`) stopped during dependency extraction before any controls: the generic installer's Hex 2.5.3 calls `filelib.safe_relative_path/2`, which OTP 22 lacks. The current recipe therefore pins Elixir 1.12.3 with OTP 23.3.4.20. This is an explicit compatibility adaptation from historical CI, leaving the locked application source/dependencies and all nine non-manifest artifacts unchanged. The failed build log is retained in the preparation history.

The OTP 23 recipe (`7d40877e08e8108352b25a71118b75e73b73fb83a464056b12720e90636aec21`) reached dependency compilation and found `ex_minimatch` 0.0.1's imported `tap/2` ambiguous with `Kernel.tap/2`, added in Elixir 1.12. The locked package tarball was verified against its lockfile checksum. A narrowly scoped compatibility edit now qualifies its six calls as `ExMinimatch.Helper.tap`, retaining the original binding and verifying the expected call count. Locked dependency versions remain unchanged; this explicit source-binding adaptation is part of the environment overlay, not an application feature repair. The new immutable candidate reached the startup issue documented below.

## Documentation dependency compatibility amendment

Version `11b2f47985cfd796d933e8f70178eb05402a9e0f614b7e3b213f4a1d99334397` compiled the app and initialized the database, but every ordinary control suite stopped before tests because `markdown.app` was absent. [Retained invalid outcomes](invalid-controls-4.json). This is an infrastructure failure, not a feature result.

A minimized offline application-start probe reproduced the same error without Accent or PostgreSQL. Both historical globbing libraries declare a Git Markdown documentation renderer without an environment restriction, although their runtime source never uses it and the locked Hex graph does not supply it. Changing only those two declarations to development-only, then regenerating their compiled manifests, made application startup and real JSON glob match/nonmatch checks pass. The environment overlay now applies that explicit compatibility correction; the acceptance and reference artifacts are unchanged. New candidate `2250e8fea0c36881b0e03011c8b1a0b5fae23ff02855889ae054f85bf86e4e37` must still pass the full original qualification loop. No model attempt has run.

The original full qualification loop now passes for `2250e8fea0c36881b0e03011c8b1a0b5fae23ff02855889ae054f85bf86e4e37`: the reference completes 6 acceptance, 16 preservation and 25 submitted tests, with behavioral regression coverage. Unchanged source completes its suites and fails exactly the three feature assertions in test bodies; the scope-only partial passes export but fails sync/merge assertions while preserving existing behavior. The early-exit integrity control is rejected for incomplete suites. All three fresh rounds then matched on named outcomes, completion, failure phases and failure types. See [round 1](qualification-round-1.json), [round 2](qualification-round-2.json) and [round 3](qualification-round-3.json). The prepared image is reused, with fresh workspaces and database/service state per control.

Two read-only launch checks failed before a run was created: one sign-in connectivity failure and one model-catalogue connectivity failure. A subsequent lookup recovered, creating run `20261018-121147-9cccf1f3`. The connection errors are not Astra attempts. Model validation uses the ordinary Pi runner, `gpt-6-astra`, high reasoning effort, a 262,144-token response-boundary soft threshold, compaction disabled and no automatic retries. Only this case is active; approved cases remain excluded.

## Retained infrastructure interruption

Run `20261018-121147-9cccf1f3` stopped on its fifth model call after four completed responses accounting for 927 generated tokens. The provider's HTTP-200 response stream contained `server_is_overloaded` / `service_unavailable_error`; the gateway surfaced it to Pi as HTTP 502. No submitted patch was graded, cleanup completed, and the saved provider error was inspected before reconnecting. [Sanitized interruption and raw-receipt hashes](infrastructure-interruption.json). This is retained as an infrastructure error, not a graded task result.

A fresh retry is justified specifically by that provider overload. It starts with a fresh context and unchanged case/settings rather than replaying a request or resuming the interrupted conversation. The curation history will retain all three attempts if two fresh completed validations succeed; the interrupted attempt is not silently replaced. No automatic retry is enabled.

## Two completed fresh Astra validations

| Run | Calls | Generated tokens | Acceptance / preservation / submitted |
| --- | ---: | ---: | --- |
| `20261018-121356-0d0a7e22` | 20 | 5,691 | 6 / 16 / 43 passed |
| `20261018-121818-26caefaa` | 23 | 5,601 | 6 / 16 / 41 passed |

Both completed runs finished cleanup and passed behavioral regression coverage. Sealed completion receipts, usage ledgers, frozen release/experiment/settings/prompts/runtime/qualification and initial requests were verified. Initial requests match after excluding distinct session keys. No serving revision is available; this establishes matching recorded inputs, not an unpublished backend revision. [Machine-readable results](astra-results.json) retain the overloaded-provider attempt as well as both completed validations.

Both submitted repairs use a shared endpoint resolver: establish project scope, prefer an exact literal, otherwise parse the requirement and choose the greatest matching stored semantic version. They preserve unmatched responses and omitted-version paths. This is a valid alternative to the upstream scope/schema implementation. Existing test assertions remain intact, with additional real endpoint/persistence tests. Parent and independent reviews found no actionable defect, test weakening or grader shortcut. Independent reviews: [repair 1](astra-1-review.md) and [repair 2](astra-2-review.md). Submitted artifacts: [patch 1](astra-1.patch) and [patch 2](astra-2.patch).

The accepted reference remains the original qualified upstream implementation; model output does not replace it. The earlier invalid fixture versions and infrastructure-interrupted attempt remain recorded. No further model attempt is needed.

Promotion preserves all eleven bundle files byte-for-byte, including the admission receipt; [bundle hashes](bundle-sha256.json) bind the moved files. Relocated admission verification passed and the active inventory is empty. Restoring this case later requires only moving its folder back into `cases/`, with no registry or manifest edits. Keep the controller idle and rebuild/recreate its image to pick up host folder changes.

**Prepared-source policy, 2026-10-20:** runnable additions and source migrations must follow [prepared fork sources](../../../docs/prepared-fork-sources.md). This record retains its original source versions and outcomes; [the later fork audit](../../prepared-forks-2026-10-20/README.md) records branch reuse and any new migration evidence separately.
