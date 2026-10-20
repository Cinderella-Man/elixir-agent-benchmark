# Active benchmark cases

Every case directory here is discovered automatically and included in a benchmark run. During [case curation](../docs/case-curation-loop.md), move approved case directories unchanged to `cases_approved/` and leave only the candidate being validated here.

After the requested additions are complete, restore all approved directories to `cases/`. Check destination names before moving; case contents and configuration do not need editing.

Keep the controller idle during membership changes, then rebuild/recreate it with `docker compose up --build -d` and verify its inventory. The complete workflow, Astra solver settings, evidence gates and interruption handoff are in the linked guide.

Every runnable case must use a [prepared branch in the user’s fork](../docs/prepared-fork-sources.md), pinned by immutable commit and tree with recorded baseline/reference branch names. Inspect existing refs before creating branches. See the [case-by-case source audit](../verification/prepared-forks-2026-10-20/README.md) for branch reuse and validation evidence.
