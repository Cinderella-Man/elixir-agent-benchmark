# Readiness review of the eleven existing cases

Audit date: 2026-10-15. Scope: the eleven cases in `elixir-agent-benchmark-v3`, assessed against the [proposed task-quality guidance](../research/benchmark-design-recommendation-2026-10-15.md). This report evaluates the current short prompts, not the earlier detailed tickets. Case bundles, the scored inventory and historical results are unchanged.

## Decision

**Keep ten task ideas; repair Plausible 6449 before treating its current prompt as a fair scored task.** Of the ten, prioritize five for the growing corpus and retain five as focused maintenance examples. Do not expand by copying the present distribution: all eleven are public historical bug fixes from just two applications.

These are case-quality decisions. **No qualifying pair of blind strong-model passes was found for any current case.** The controller's saved 11/11 run used the previous detailed prompts. A reference implementation passing is not a blind model attempt, and those older scores cannot validate the shortened tickets. A read-only account-status check found subscription authentication available but zero signed-in accounts, so this audit could not perform those subscription-backed attempts. No credentials were exposed or account settings changed.

| Case | Recommendation | Implementation paths in reference | Reason |
| --- | --- | ---: | --- |
| Plausible 5939 | Keep as a focused maintenance example | 1 | Clear role-permission defect; meaningful scope checks, but a very small repair |
| Plausible 6763 | Keep as a focused maintenance example | 1 | Real export/query diagnosis and preservation of supported metrics; tiny final edit |
| Plausible 6449 | **Repair the contract before scoring** | 3 | Good multi-component task, but hidden tests choose an unstated invalid-input policy |
| Plausible 6441 | **Prioritize** | 3 | Coordinates imported/native data semantics, filtering and goal identities |
| Plausible 5956 | **Prioritize** | 8 | Stateful write/cache/read behavior; the reference also contains optional restructuring and EE work |
| Livebook 2219 | **Prioritize** | 4 | Coordinates frame traversal, input state and LiveView updates |
| Livebook 2527 | **Prioritize despite one-file repair** | 1 | Substantive trust-boundary problem involving signed content and authorization |
| Livebook 2663 | Keep as a focused maintenance example | 1 | Clear round-trip invariant and numeric boundaries; relatively localized implementation |
| Livebook 2800 | Keep as a focused maintenance example | 1 | Useful diagnostic conversion task with semantic checks and a demonstrated formatting alternative |
| Livebook 2822 | **Prioritize despite one-file repair** | 1 | Requires understanding evaluation state, rollback and context merging |
| Livebook 3076 | Keep as a focused maintenance example | 1 | Authentic form-to-persistence defect with useful negative checks; small repair |

“Prioritize” describes value for the intended corpus, not measured difficulty. “Focused” does not mean invalid. Keep those cases as a minority as the corpus grows; do not inflate their patches or retire them merely because models solve them. The [scope audit](case-scope-audit-2026-10-15.md) gives raw counts, which never constrain a submitted solution.

## Evidence and limits

Read every current ticket, manifest, reference patch and acceptance overlay, followed by relevant exact starting-source functions and tests. Verified the SHA-256 of each locally retained starting archive against its source receipt and checked the receipt's tree against `provenance.json`. The review copies live outside the benchmark under the ignored audit directory.

Compared every case file with the [October 14 promotion evidence](task-quality-promotion-evidence-2026-10-14.json). **Only `ticket.md` differs for each of the eleven cases.** The implementation and test artifacts retain the earlier executed evidence: accepted references, rejected targeted wrong repairs and two accepted formatting alternatives. However, the current grader hash differs from the recorded one, so these are historical results rather than current qualification receipts.

Fresh functional qualification and the shared-link policy replay use [the audit script](../../verification/case-readiness-2026-10-15/recheck.exs). It uses a separate data directory, existing immutable prepared images, offline test workspaces, one preparation worker and one case at a time. It does not start a model or measure speed.

**All eleven cases passed fresh qualification: 44 expected control outcomes.** Every reference passed the complete grader, including submitted-test validation, acceptance, preservation and a test exposing the starting defect. All eleven unchanged, eleven incomplete and eleven early-exit controls were rejected. This establishes current executable qualification, not fairness of every hidden requirement or model solvability.

Two additional full-grader experiments completed: the shared-link policy alternative was rejected solely by the undisclosed clearing requirement, and a smaller two-file tracker implementation was accepted. The [portable evidence](existing-case-readiness-evidence-2026-10-15.json) records current fixture/source/grader/runtime identities, stage outcomes and named failures without timing measurements. Qualified release: `d8bbd09451c2608dd23de679c813c291d070731bd83dc6caa1a097febb61e8e3`. [Reproduction notes](../../verification/case-readiness-2026-10-15/README.md).

The source review is an agent review, not an independent human attestation. Coverage remains finite. The tests establish behavior in the selected historical runtime and edition, not every browser, enterprise feature or possible implementation. All cases remain public and potentially exposed during training.

## Per-case review

### Plausible 5939 — Editor domain changes

**Keep, focused.** The ticket clearly identifies the actor and blocked operation. The starting LiveView already uses a site-scoped role allowlist, so allowing Editors while preserving existing denial behavior follows from the visible code and the general preservation instruction. There is no need to disclose the one-line fix.

Acceptance exercises guest and team Editors through form submission and persisted domain fields. Existing owner/admin and validation behavior remains covered. The custom checks distinguish a scoped permission change from granting an Editor authority over other sites or teams. The earlier global-Editor mutation was rejected by the promoted grader.

The tests expect the existing `Ecto.NoResultsError` denial convention. That is justified as preservation of this route's existing behavior; it should not be mistaken for a universal requirement for authorization UIs. Keep the task's scope to this operation, not new session-revocation behavior. [Ticket](../../cases/plausible-pr-5939/ticket.md), [checks](../../cases/plausible-pr-5939/acceptance.patch), [reference](../../cases/plausible-pr-5939/reference.patch).

### Plausible 6763 — Page-filtered CSV export

**Keep, focused.** “Some sites” leaves investigation to the solver. The exact starting code exposes the nullable legacy cutoff, supported metric shapes and export pipeline; the tests do not require guessing a new product policy.

Checks call the real export endpoint, unpack the ZIP and inspect the CSV schema and seeded counts. Aggregate and page-breakdown witnesses reject a shortcut that suppresses legacy metrics everywhere. The existing export suite preserves other filters and modes. The one-line reference follows investigation across the query pipeline, so its size alone is a poor difficulty measure.

The nil-cutoff example has limited data diversity, but broader page-filter tests provide preservation evidence. No new blocking defect was established here. A small reproduction example would be an optional usability improvement, not a requirement to reveal the cutoff or optimizer. [Ticket](../../cases/plausible-pr-6763/ticket.md), [checks](../../cases/plausible-pr-6763/acceptance.patch), [reference](../../cases/plausible-pr-6763/reference.patch).

### Plausible 6449 — Shared-link editing

**Repair before scoring the current prompt.** The task is valuable: schema mass assignment, site-scoped segment lookup and the form/context boundary must agree. The current ticket establishes immutable secret URLs and prohibition of foreign-site segment associations.

It does **not** settle what a malformed or nonexistent selection should do. Rejecting the form, keeping the previous valid selection, or saving with no selection are plausible policies. The visible form already supports changeset errors. Hidden checks insist that create/edit succeeds and clears the association. The older full ticket explicitly chose that policy; shortening removed it while retaining the assertions.

The tests also cover creation although the ticket says editing, and preserve an already-linked segment later changed to personal. The latter has a preservation argument in the old code, but is sufficiently subtle to disclose alongside the chosen policy. These are behavioral requirements, not implementation hints.

The replay uses the previously retained `retain-association-on-malformed-edit` variant: valid and foreign positive IDs still go through the scoped lookup; malformed nonempty IDs retain the existing association; empty selections still clear it; slug protection is unchanged. The current ticket does not justify calling that repair wrong. [Current ticket](../../cases/plausible-pr-6449/ticket.md), [hidden assertions](../../cases/plausible-pr-6449/acceptance.patch), [exact alternative](../../verification/task-quality/cases/plausible-pr-6449/audit.json), [old explicit contract](../../verification/task-quality/original/cases/plausible-pr-6449/ticket.md).

**Fresh replay confirmed the rejection.** Submitted tests, original preservation and the fail-before/pass-after requirement all passed. The only acceptance failure was `malformed and nonexistent segment selections clear existing associations on edit`, in its test body. This is an executed example of a reasonable policy alternative rejected by a requirement absent from the shortened prompt, rather than a compilation or infrastructure failure.

Recommended revised ticket, **not applied during this audit**:

> Shared-link forms let me overwrite a link's secret URL or attach another site's segment. Keep the URL fixed; on create and edit, save other valid changes with no segment when the selection is empty, invalid, nonexistent, or belongs to another site. Valid same-site selections must still work, including an already-linked segment later made personal.

Alternatively, deliberately accept several invalid-input policies and revise the tests. The first option retains the historical accepted behavior and is the smaller change. It requires fresh blind attempts against the revised prompt; it does not require reproducing the reference's new helper functions.

### Plausible 6441 — Imported analytics and restricted goals

**Prioritize.** This is the clearest coordinated query task in the set. Imported aggregates do not contain the same property evidence as native events. The solver must follow goal selection, table eligibility and grouping while keeping goal identities aligned.

The short report is sufficient together with the source: arbitrary custom-property filters cannot be evaluated from aggregates that lack them. Existing special-event URL support remains a visible exception that must be preserved. Checks cover filtered and mixed event/page goals, native property matching, supported imports and import metadata. They use query results rather than new helper names or exact SQL.

The prior challenge replays reject both dropping all imported page goals and dropping supported special-event imports. This is useful evidence against broad “avoid the crash” shortcuts. Keep it as a CE functional task; neither the prompt nor the tests certify EE behavior. [Ticket](../../cases/plausible-pr-6441/ticket.md), [checks](../../cases/plausible-pr-6441/acceptance.patch), [reference](../../cases/plausible-pr-6441/reference.patch).

### Plausible 5956 — Tracker configuration and cache state

**Prioritize.** The observed create/update/restart behavior gives a credible maintenance request. The CE scope is disclosed in the instructions. Correctness requires successful writes, current script delivery and isolation between sites, rather than merely making a cache lookup stop throwing.

The promoted integration check performs create → GET → repeated updates → GET without manually refreshing the cache. A separate refresh-path check exercises repeated cache insertion. Both matter: the earlier suite only observed reads after repairing the cache itself. The promoted grader rejects omission of write-side updates.

Do not treat the reference's eight paths as a required architecture. It splits caches, touches telemetry/readiness and includes EE-specific work beyond the CE task. Current acceptance uses the existing tracker APIs and cache adapter, not the newly introduced module names. A smaller valid repair is desirable evidence of fairness, not failure to meet complexity. Script checks cover current serialization, configuration fragments and JavaScript syntax; they do not execute browser ingestion. [Ticket](../../cases/plausible-pr-5956/ticket.md), [checks](../../cases/plausible-pr-5956/acceptance.patch), [reference](../../cases/plausible-pr-5956/reference.patch).

**A two-file alternative passed the complete current grader.** It retains the existing cache modules, changes the tracker cache to one value per key, and writes CE configuration updates locally before returning. Submitted tests, acceptance, original preservation and the fail-before/pass-after check all passed. This demonstrates that the eight-path reference restructuring is not required by the oracle. It is a curator-authored positive control, not a blind model success, and does not qualify untested EE behavior. [Executed alternative patch](../../verification/case-readiness-2026-10-15/plausible-5956-alternative.patch), [runner](../../verification/case-readiness-2026-10-15/check_alternative.exs).

### Livebook 2219 — Inputs introduced through frame updates

**Prioritize.** The symptom describes a real state/rendering mismatch. Existing output structures and input conventions establish the expected defaults and retained edited values without a long specification.

Checks exercise numeric and text inputs, replacement and append updates, editing, nested frames and sibling output. They observe rendered controls, messages and session state. The numeric-only repair is rejected. This tests coordination across notebook traversal, state initialization and LiveView updates.

The reference also changes the app-session view, while selected acceptance/preservation suites exercise notebook sessions. Count that as a scope limit, not proof that every reference hunk is necessary. The current notebook wording supports keeping this narrower scope. A future task explicitly promising deployed-app parity would need app-session checks. These are server-side LiveView interactions, not full browser execution. [Ticket](../../cases/livebook-pr-2219/ticket.md), [checks](../../cases/livebook-pr-2219/acceptance.patch), [reference](../../cases/livebook-pr-2219/reference.patch).

### Livebook 2527 — Signed notebook authorization

**Prioritize despite one file.** This is a substantial trust-boundary task: imported executable content must not inherit authorization based only on a signed prefix. The prompt states the security outcome; the existing import/export and warning behavior supplies the compatibility contract.

Checks require inserted Elixir and Erlang cells to remain imported while losing stamp verification and hub-secret authorization. Positive cases preserve a freshly signed Unicode notebook and harmless whitespace around stamp metadata. Prior probes reject Elixir-only detection and character-count/byte-offset confusion; the standard partial control rejects disabling verification entirely.

The reference is compact because the key boundary lives in one importer, not because the task is merely a text edit. Keep it with explicit scope: the tested notebook format and authorization path, not a comprehensive security assessment of every hub or parser. [Ticket](../../cases/livebook-pr-2527/ticket.md), [checks](../../cases/livebook-pr-2527/acceptance.patch), [reference](../../cases/livebook-pr-2527/reference.patch).

### Livebook 2663 — Numbered-list round trips

**Keep, focused.** The task establishes a clear invariant: saving should retain the nesting of existing content. The starting formatter's visible tests establish its canonical style, so the solver need not infer a new formatting preference.

Checks cover two- and three-digit markers, nested bullets and fenced code, semantic AST equivalence and stable repeated formatting. The standard partial control caps indentation at two digits and is rejected. An extra-space alternative already passed the promoted full grader, providing positive evidence that at least one different implementation is accepted.

Some assertions still compare exact canonical output. Their justification is the existing formatter contract, not an assumption that only one Markdown representation is semantically valid. Keep those limits explicit; a future generalized Markdown-rendering task should favor semantic assertions more broadly. [Ticket](../../cases/livebook-pr-2663/ticket.md), [checks](../../cases/livebook-pr-2663/acceptance.patch), [reference](../../cases/livebook-pr-2663/reference.patch).

### Livebook 2800 — Erlang error rendering

**Keep, focused.** Reporting the actual parser/scanner error instead of an exception-formatting crash is a clear outcome. The existing evaluator constructs typed errors with file/line/column data, supporting preservation of meaningful source locations.

The promoted checks cover incomplete input, parser and tokenizer errors, multiline locations and ordinary runtime exceptions. They inspect meaning and location rather than decorative indentation. A wrong first-line-only repair is rejected; an indented diagnostic alternative is accepted by the full promoted grader.

This remains a narrow compatibility/diagnostic task. Specific error types and location syntax follow the pinned runtime and existing evaluator conventions; do not generalize those checks to an unrestricted diagnostic redesign. [Ticket](../../cases/livebook-pr-2800/ticket.md), [checks](../../cases/livebook-pr-2800/acceptance.patch), [reference](../../cases/livebook-pr-2800/reference.patch).

### Livebook 2822 — State after failed evaluations

**Prioritize despite one file.** Understanding this repair requires distinguishing state inherited from successful cells from bindings, aliases, modules and dictionary mutations introduced by a failed cell. The source's context-merging model explains why keeping the entire failed context or resetting everything is wrong.

Checks compare exact imported function/macro membership without prescribing order, then execute later cells using those imports and dictionary values. They also exercise merged contexts, dictionary rollback, failed-module cleanup and another assertion failure. Prior probes reject widening imports and retaining failed dictionary writes.

The English ticket is short but sufficient because it identifies earlier successful state as the state to preserve. The test assertions use an existing context-inspection API and observable subsequent execution. This is a good example of why one changed file can still involve substantial repository reasoning. [Ticket](../../cases/livebook-pr-2822/ticket.md), [checks](../../cases/livebook-pr-2822/acceptance.patch), [reference](../../cases/livebook-pr-2822/reference.patch).

### Livebook 3076 — Adding S3 storage

**Keep, focused.** The personal-workspace scope is explicit. The source connects a form, an S3 changeset and a persisted hub identity, making the correct identifier discoverable. The tiny reference edit is a legitimate maintenance fix.

Acceptance submits the fields users actually see, avoiding the older fixture's accidental injection of the missing hub ID. It checks creation/editing and uses a local S3 stub. Added checks reject missing credentials and failed connectivity without persisting storage. Prior probes reject ignoring connectivity failures and skipping credential validation.

This does not verify real AWS connectivity or every team/Git storage path; some unrelated original tests are excluded. The current prompt is appropriately limited. Keep it as a small diagnostic example rather than the template for new feature-development tasks. [Ticket](../../cases/livebook-pr-3076/ticket.md), [checks](../../cases/livebook-pr-3076/acceptance.patch), [reference](../../cases/livebook-pr-3076/reference.patch).

## Remaining admission work

The ten retained ideas are suitable to continue validating; that does not complete the proposed admission protocol. Resolve 6449's visible policy first. Then freeze the intended case versions and obtain two fresh, matching strong-model attempts for each, keeping failed attempts and reviewing successful patches. Do not count the earlier detailed-prompt runs or reference qualification as those attempts.

For repeatability, distinguish the historical seed-0/seed-101 checks from this fresh run. The proposed three-repeat qualification rule has not been retroactively satisfied merely by reading old receipts. No new blind model evaluation or independent human implementation was performed in this audit.

A failure under a future model run needs classification against its prompt and checks. It must not automatically be labeled model weakness. Conversely, a model solving a focused case does not make the case defective. Keep future expansion centered on coordinated work and broader projects rather than using the current eleven-case aggregate as a general coding-ability score.
