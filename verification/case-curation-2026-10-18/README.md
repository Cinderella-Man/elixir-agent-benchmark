# Sequential application case curation — 2026-10-18

The original nine validated folders were moved unchanged into `cases_approved/` in commit `6f5a112`. They have not been rerun by Astra during this curation. Folder discovery permits restoration with `mv cases_approved/*/ cases/`, without manifest or configuration edits. Keep the controller idle during membership changes and rebuild/recreate its Docker image afterward.

| Candidate | Current state | Evidence |
| --- | --- | --- |
| Operately #1069: check-in recipient identity | Approved, parked and pushed in `5b38487`; three fresh matching qualification rounds and two reviewed fresh Astra successes | [Record](operately-pr-1069/README.md) |
| LiveBeats #37: now-playing tab and media metadata | Approved, parked and pushed in `8a183fb`; three fresh matching qualification rounds and two reviewed fresh Astra successes | [Record](livebeats-pr-37/README.md) |
| Accent #183: compatible translation versions | Approved and parked; three matching qualification rounds and two reviewed fresh Astra successes, plus one retained provider-overload interruption | [Record](accent-pr-183/README.md) |

This is a sequential curation record, not a full-inventory model score. All qualification and model runs are functional checks with bounded resources. No speed/performance comparison is part of this work. Previous research candidates and recorded holds remain in the [application catalogue](../../docs/research/end-user-application-candidates-2026-10-18.md); this table does not declare that queue exhausted.

**Prepared-source policy, 2026-10-20:** runnable additions and source migrations must follow [prepared fork sources](../../docs/prepared-fork-sources.md). This record retains its original source versions and outcomes; [the later fork audit](../prepared-forks-2026-10-20/README.md) records branch reuse and any new migration evidence separately.
