# Use actual upstream repairs for the Plausible cases

On 2026-10-11 the user replaced invented Plausible regressions with actual solved upstream problems, using merged PRs as provenance for the broken state, reference repair and regression coverage. Preserve each case's historical pre-fix revision rather than recreating the defect on the previously proposed shared `v3.2.1` baseline; this favors authentic developer work while requiring qualification of several historical environments.

Independent broken branches remain the public authoring layout. The upstream patch is a reference solution, not a required implementation, and the PR description must be reconciled with final merged behavior before producing a symptom-focused ticket. Only deterministic executable checks determine attempt outcomes; neither a merged PR nor a source-only review establishes that a benchmark fixture is qualified.
