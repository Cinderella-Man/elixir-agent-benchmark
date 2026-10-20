# Astra repair 1 review — 2026-10-20

Run: `20261020-122019-f5c38807`. Reviewer: primary Codex curator. This is a review of the completed submission; the separate requirements-first contract review remains the independent review of the unchanged case.

The repair changes only the singular project query's optional milestone preload and its existing endpoint test file. It adds an explicit `is_nil(m.deleted_at)` predicate to the association query while retaining its `:project` preload. Ecto still supplies the association's project scope. The parent lookup retains `with_deleted: true`, so archived projects and inverse-parent serialization continue to work. The existing include parser still controls omitted and false flags. No persistence, authentication, authorization, global repository policy, or unrelated query changes are introduced.

This is a valid alternative to the reference's separate after-load callback. The explicit child predicate remains effective when the parent lookup propagates `with_deleted: true`. It does not filter by completion status or discard legitimate active rows. The protected checks confirm mixed pending/completed populations, other-project isolation, serialized identities and payloads, archived-parent retrieval, optional inclusion, empty results, and unchanged stored history.

The submission adds optional-inclusion and archive-transition endpoint tests and strengthens the existing archived-project test. Existing assertions remain intact. All 4 acceptance checks, 22 protected preservation tests, and 24 submitted tests completed and passed. On pristine starting source, the submitted archive-transition and archived-parent assertions fail in test bodies with `ExUnit.AssertionError`; the remaining submitted tests pass. Behavioral regression coverage therefore distinguishes the defect without relying on compilation or setup errors.

No actionable defect, test weakening, answer leakage, or grader shortcut was found. The full submitted patch is retained as [astra-1.patch](astra-1.patch), with checksummed completion and named outcomes in [astra-results.json](astra-results.json). The qualified upstream reference remains unchanged.
