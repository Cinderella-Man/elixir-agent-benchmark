# Astra repair 2 review — 2026-10-20

Run: `20261020-122235-10d057a6`. Reviewer: primary Codex curator. The solver received a fresh context and workspace with the same frozen task, model and settings as run 1, without its solution or feedback.

The repair supplies the optional milestone preload as an explicit child query plus nested `:project` preload. Its sole production change adds `is_nil(m.deleted_at)` to the singular project request. Association scoping still restricts children to their parent, completed active milestones are retained, and the parent lookup's existing `with_deleted: true` permits archived-project retrieval and serialization. Optional inclusion and the existing authentication/access-control path are unchanged.

This is a valid alternative to the upstream after-load implementation. An explicit predicate filters archived children even when `with_deleted: true` is inherited from the parent query. The tuple-form preload retains inverse-parent data without changing the serializer or repository's global policy. The protected acceptance checks passed for mixed populations, archived parents, project scope, payload preservation, optional includes, empty lists and unchanged persistence.

The patch adds endpoint tests for active/completed/archived populations, omitted and false inclusion, and empty/all-archived lists, then strengthens the existing archived-parent test. It removes or weakens no existing assertion. All 4 acceptance checks, 22 protected preservation tests, and 24 submitted tests completed and passed. The pristine-source replay completes and fails three submitted assertions in test bodies: filtering archived milestones, returning an empty all-archived list, and filtering children of an archived parent. All three are `ExUnit.AssertionError` failures rather than setup or compilation failures.

No actionable defect, test weakening, answer leakage, or grader shortcut was found. See [astra-2.patch](astra-2.patch) and the checksummed receipts and named results in [astra-results.json](astra-results.json). The qualified upstream reference remains unchanged.
