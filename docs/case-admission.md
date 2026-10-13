# Candidate admission and task contracts

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

ExUnit uses `adapter: exunit`, explicit `mix test` commands and `_test.exs` suffixes. The existing twelve legacy manifests retain their repair policy. New Node contracts require explicit `.js`, `.mjs` or `.cjs` files; implicit discovery, globs and runner override flags are rejected. Test identities are `<relative file>::<test name>` and must be unique. The controller-owned runner consumes [Node test events](https://nodejs.org/api/test.html#class-testsstream), prefixes application stdout, rejects skipped/duplicate/incomplete results and distinguishes test-body failures from setup failures. Missing capabilities must become named assertions, not import/compiler crashes.

Every required assertion maps to a solver-visible requirement, also included in Pi's instructions. Bug fixes and features require model-added/changed tests that pass after the change and fail in a test body on the pristine starting source. Refactors use `model_tests: preservation`: the added/changed tests must execute successfully on the submission, while separate protected preservation checks must pass before and after. Refactors also need at least one explicitly stated structural/interface requirement whose named acceptance check fails on unchanged code. Similarity to the reference implementation is never a criterion.

The bundle contains `ticket.md`, `case.json`, `provenance.json`, `reference.patch`, `reference-tests.patch`, `acceptance.patch`, `incomplete.patch` and `integrity.patch`. The incomplete patch is a standalone plausible partial solution against the starting tree. The integrity patch is applied after the reference solution and must demonstrate rejection of a bypass, such as early exit. Both controls must actually execute in qualification. Test overlays may only edit the declared protected test roots; grading resets those roots before acceptance and again before preservation checks, including newly introduced directories.

`reference-tests.patch` contains the regression/contract tests used to qualify the reference. Where curators added or adapted tests, preserve the exact upstream tests separately in `upstream-tests.patch`. `upstream-docs.patch` may retain omitted upstream Markdown/text changes, such as changelog entries. The source verifier reconstructs the recorded fixed tree using the implementation, exact upstream tests and documentation. It separately restricts curated test patches to protected test paths. Neither documentation nor upstream-only tests silently replaces the curated grading contract. Upstream and fixed snapshots exclude Git history from solver images.

`Eab.Candidates.review(ref, record)` records `author`, a different `reviewer`, `decision` (`approve`, `reject` or `defer`) and `rationale`. Approval additionally requires `requirements_read_before_checks: true` and `assertion_mapping_checked: true`. These are explicit curator attestations, not authenticated reviewer identities or an automated claim that someone performed a review. Every decision is retained; edits produce a new candidate version and need new review. No real review is fabricated by the importer.

`Eab.Candidates.qualify(ref, emit)` verifies source provenance, prepares the baseline and runs unchanged/reference/integrity/incomplete controls without a model. Stage/error records survive under the candidate version. A qualification receipt binds the candidate, exact runtime, source and evaluator. An interrupted preparation can be rerun using valid component caches; invalid qualification never admits the case. Functional qualification is allowed on this machine; speed measurement is not.

After approval and successful qualification, `Eab.Candidates.export(ref, destination)` produces a reviewable bundle including `admission.json`. Publishing it under `cases/` and adding its ID to a new inventory revision remains an explicit repository change. Release freezing rejects missing, stale or mismatched admission evidence for schema-v2 cases. Existing releases and saved scores are unchanged. Checksums detect corruption and mismatched artifacts; they are not signatures against a malicious curator.

## Offline browser tasks

Set `runtime.browser: true` and declare a Node image for a browser case. The current browser recipe supports Ubuntu 24.04 toolchains and fails explicitly on other distributions. It installs the pinned Playwright lockfile and Chromium binaries from an immutable Playwright image during preparation. [Playwright requires matching browser and package versions](https://playwright.dev/docs/browsers); both are retained in the recipe identity. Non-browser recipes do not install these tools.

Node tests import `process.env.EAB_BROWSER_MODULE`, launch Chromium and bind application servers to loopback inside the same offline workspace. Launch/connect fixtures belong in setup hooks, so missing browser/server setup is not counted as a behavioral defect. Close browsers and servers after the suite. Use local assets and deterministic data. The browser uses the same Node completion contract; it does not introduce an AI judge or timing-based score. A synthetic Docker check exercises a local interactive page with networking disabled.

## Existing inventory qualification

`Eab.Qualification.run(emit, opts)` prepares and qualifies the frozen inventory without Pi or model calls. It writes a job manifest, per-case states, source receipts, runtime records and controls, uses the bounded preparation scheduler and retains completed artifacts. Execute it on the controller's data volume while no model run or other controller is using that volume. A failed case stays an error and does not cancel unrelated cases. Repeating the job reuses valid component and qualification records. This developer operation does not produce a model score or speed evidence.
