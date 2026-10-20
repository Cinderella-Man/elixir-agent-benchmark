# Combining PR lineages into one honest case

**Date:** 2026-10-19  
**Status:** curator policy note (guidance for this research folder)

## Rule

We are **not** required to freeze a single upstream PR if that PR is incomplete, unfair, or immediately corrected. When a follow-up (or a cleaner design) is an **obvious product improvement** that a careful solver could implement from the ticket alone:

1. **Merge the lineage** into one case whose reference is the **final coherent outcome**.
2. Write the ticket for that **final behavior**, not the buggy intermediate.
3. Attribute both upstream sources in provenance; do not score two near-duplicate cases.
4. Keep the intermediate as a **natural incomplete control** when it compiles and shows the missing piece.
5. If the “improvement” is **not** obvious from the ticket (policy contest, second product decision), state the decision in the brief or split/defer — do not hide it in tests.

This matches existing corpus guidance on corrected features and original requests (`pr-selection-guidelines.md`, `corrected-feature-lineages-2026-10-18.md`): reference patches are qualification evidence, not a byte-for-byte solution matcher; product decisions must be visible.

## When to merge

| Situation | Action |
| --- | --- |
| PR A ships a rule; PR B (same day / clear follow-up) fixes that rule’s obvious hole | **One case**, ticket describes B’s outcome (A+B reference) |
| PR A under-specifies behavior; the community/spec settles it later | Ticket states the **settled** outcome; reference is the tree that matches it |
| PR A is fine; PR B is an unrelated later feature | Keep A; mention B only as out of scope |
| Two PRs fight (conflicting product policy) | Defer or write a clarified brief that picks one policy explicitly |
| Reference **test** is flaky/isolated-wrong (not product) | Fix grading isolation; do **not** change the product ticket |

## When not to merge

- Inflating file count by stapling unrelated cleanups.
- Importing a large later rewrite when the first PR was already fair.
- Claiming the model “should have found” a private convention that is not in the visible contract.

## Implications for current large-feature set

| Case | Old freeze | Combined / improved case |
| --- | --- | --- |
| Pinchflat #640 | `:when_needed` = indexing only; **exclude #641** | **#640+#641**: `:when_needed` covers slow indexing **and** cookie-related error recovery; ticket states both. Intermediate indexing-only = incomplete control. |
| Cachex #306 | “default remains Evented” | Ticket matches **head**: scheduled LRW is the default when configured; no false freeze on Evented. |
| Absinthe #1404 | “named operations only” | Ticket matches **spec + reference**: descriptions on anonymous non-shorthand ops too; shorthand policy stated explicitly. |
| Broadway #344 | 98/129 suite noise | Product ticket unchanged; **grading** isolation or test `on_exit` fix (not a second product PR). |
| Beacon #687 | sitemap as merged | Optional later #740/#746/#749 URL placement is a **separate** redesign unless the brief clearly wants that layout. |
| Mydia / Craftplan / ecto_sql #703 | as filed | No forced merge; optional rename (`:ignore_errors`→`:ignore`) stays out of brief. |

## Naming and provenance

- Case ID may be `pinchflat-640-641` (or a new case version) so lineage is visible.
- `provenance.json` / research note lists **every** upstream commit/PR used in the reference tree.
- Scores and research records must not pretend the case is “only PR #640” if the reference includes #641.

## Next actions (this folder)

1. Add combined case notes for Pinchflat #640+#641 (primary example).
2. Patch Absinthe brief wording and Cachex default wording in their dossiers.
3. Note Broadway grading isolation as harness work, not a ticket change.
