# Candidate admission and task contracts

Start with the [case-selection and validation guidelines](pr-selection-guidelines.md): prioritize coherent tasks spanning roughly 2–5 implementation files, review the shortest sufficient solver contract, and record project/runtime feasibility before preparing a bundle. Repairs usually need a short report; features and objective refactors may need a clarified outcome brief. File count guides curation; it is not a submission acceptance rule. The guidelines define the manual quality gates; this page describes the implemented bundle and API contract.

Draft cases live outside the scored inventory. `Eab.Candidates.import(directory)` validates a flat bundle of fixture files and stores an immutable version under `/data/candidates/<id>/<hash>/`. Importing does not alter `config/benchmark.json`, start a model, or claim that a case is qualified. These are curator/developer APIs; the model-run website remains the execution interface. Automated GitHub discovery and a curation website are separate work.

Every new case uses `schema_version: 2` and `task_kind: bug_fix | feature | refactor`. Keep the existing repository, runtime, edit-prefix and acceptance-patch fields. The `grading` object declares:

```json
{
  "adapter": "node",
  "acceptance": "node --test test/acceptance.mjs",
  "preservation": "node --test test/existing.mjs",
  "protected_paths": ["test/"],
  "test_suffixes": [".mjs"],
  "required": ["test/acceptance.mjs::requested capability"],
  "starting_failures": ["test/acceptance.mjs::requested capability"],
  "model_tests": "behavioral",
  "requirements": [
    {
      "id": "public-capability",
      "text": "Describe the observable result or specified interface here.",
      "kind": "behavior",
      "checks": ["test/acceptance.mjs::requested capability"]
    }
  ]
}
```

ExUnit uses `adapter: exunit`, explicit `mix test` commands and `_test.exs` suffixes. The nine active legacy manifests retain their repair policy. New Node contracts require explicit `.js`, `.mjs` or `.cjs` files; implicit discovery, globs and runner override flags are rejected. Test identities are `<relative file>::<test name>` and must be unique. The controller-owned runner consumes [Node test events](https://nodejs.org/api/test.html#class-testsstream), prefixes application stdout, rejects skipped/duplicate/incomplete results and distinguishes test-body failures from setup failures. Missing capabilities must become named assertions, not import/compiler crashes.

Every required assertion maps to a solver-visible requirement, also included in Pi's instructions. Keep requirement text at the level of the task's observable outcomes and visible project contract; do not use this field or `clarifications` to inject a repair recipe. Disclose product decisions the repository cannot settle, including compatibility policies in the exact tested configuration. Store curator investigation and assertion-mapping rationale separately. Pair negative cases with positive preservation cases, including mixed populations where an over-broad repair could discard valid behavior. Bug fixes and features require model-added/changed tests that pass after the change and fail in a test body on the pristine starting source. Refactors use `model_tests: preservation`: the added/changed tests must execute successfully on the submission, while separate protected preservation checks must pass before and after. Refactors also need at least one explicitly stated structural/interface requirement whose named acceptance check fails on unchanged code. Similarity to the reference implementation is never a criterion.

The bundle contains `ticket.md`, `case.json`, `provenance.json`, `reference.patch`, `reference-tests.patch`, `acceptance.patch`, `incomplete.patch` and `integrity.patch`. The incomplete patch is a standalone plausible partial solution against the starting tree. The integrity patch is applied after the reference solution and must demonstrate rejection of a bypass, such as early exit. Both controls must actually execute in qualification. Test overlays may only edit the declared protected test roots; grading resets those roots before acceptance and again before preservation checks, including newly introduced directories.

`reference-tests.patch` contains the regression/contract tests used to qualify the reference. Where curators added or adapted tests, preserve the exact upstream tests separately in `upstream-tests.patch`. `upstream-docs.patch` may retain omitted upstream Markdown/text changes, such as changelog entries. The source verifier reconstructs the recorded fixed tree using the implementation, exact upstream tests and documentation. It separately restricts curated test patches to protected test paths. Neither documentation nor upstream-only tests silently replaces the curated grading contract. Upstream and fixed snapshots exclude Git history from solver images.

`Eab.Candidates.review(ref, record)` records `author`, a different `reviewer`, `decision` (`approve`, `reject` or `defer`) and `rationale`. Approval additionally requires `requirements_read_before_checks: true` and `assertion_mapping_checked: true`. These are explicit curator attestations, not authenticated reviewer identities or an automated claim that someone performed a review. Every decision is retained; edits produce a new candidate version and need new review. No real review is fabricated by the importer.

`Eab.Candidates.qualify(ref, emit)` verifies source provenance, prepares the baseline and runs unchanged/reference/integrity/incomplete controls without a model. Stage/error records survive under the candidate version. A qualification receipt binds the candidate, exact runtime, source and evaluator. An interrupted preparation can be rerun using valid component caches; invalid qualification never admits the case. Functional qualification is allowed on this machine; speed measurement is not.

After approval and successful qualification, `Eab.Candidates.export(ref, destination)` produces a reviewable bundle including `admission.json`. Exporting it under `cases/` activates it automatically. During the [sequential curation loop](case-curation-loop.md), this activates only the new case for its two fresh model validations. After both successful repairs are reviewed, promotion moves the bundle to `cases_approved/` so it is no longer included in runs. Moving it back into `cases/` later restores it without configuration changes. Release freezing rejects missing, stale or mismatched admission evidence for schema-v2 cases. Existing releases and saved scores are unchanged. Checksums detect corruption and mismatched artifacts; they are not signatures against a malicious curator.

Export is the implemented fixture/review gate. The [manual validation policy](pr-selection-guidelines.md#qualify-behavior-before-running-a-model) additionally requires three fresh qualification rounds with matching named outcomes, followed by two reviewed fresh blind strong-model successes under matching frozen inputs/settings and no unresolved contract/grader concern. These repeated qualification and model gates are not checked by `export/2`. Use a provisional curation inventory with the existing Pi run flow and retain every attempt, including graded failures and infrastructure interruptions. Explicit fresh retries retain their source records; resume is not another independent attempt, and partial runs have no full-inventory score. Do not present fixture qualification alone as completed model validation.

An unmet gate keeps a candidate outside the validated inventory. Record the specific reason rather than treating every strong-model failure as a broken case. Removed bundles live under [cases_rejected](../cases_rejected/README.md); the v4 removal of Plausible 6763 and 6441 preserves their original content and all prior release results. Reconsideration follows the recorded reason: a corrected contract requires a new version and fresh validation; a further diagnostic attempt on unchanged inputs must be explicitly justified and preserve all outcomes.

Admission and upstream-reconstruction artifacts version the release and remain subject to their own validation. Adding that audit evidence does not invalidate unchanged executable fixture controls. Explicit acceptance files and unknown future grading artifacts still invalidate those controls, regardless of filename.

## Offline browser tasks

Set `runtime.browser: true` and declare a Node image for a browser case. The current browser recipe supports Ubuntu 24.04 toolchains and fails explicitly on other distributions. It installs the pinned Playwright lockfile and Chromium binaries from an immutable Playwright image during preparation. [Playwright requires matching browser and package versions](https://playwright.dev/docs/browsers); both are retained in the recipe identity. Non-browser recipes do not install these tools.

Node tests import `process.env.EAB_BROWSER_MODULE`, launch Chromium and bind application servers to loopback inside the same offline workspace. Launch/connect fixtures belong in setup hooks, so missing browser/server setup is not counted as a behavioral defect. Close browsers and servers after the suite. Use local assets and deterministic data. The browser uses the same Node completion contract; it does not introduce an AI judge or timing-based score. A synthetic Docker check exercises a local interactive page with networking disabled.

## Existing inventory qualification

`Eab.Qualification.run(emit, opts)` prepares and qualifies the frozen inventory without Pi or model calls. It writes a job manifest, per-case states, source receipts, runtime records and controls, uses the bounded preparation scheduler and retains completed artifacts. Execute it on the controller's data volume while no model run or other controller is using that volume. A failed case stays an error and does not cancel unrelated cases. Repeating the job reuses valid component and qualification records. This developer operation does not produce a model score or speed evidence.
