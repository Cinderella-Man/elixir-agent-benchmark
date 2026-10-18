# Sequential application case curation — 2026-10-18

The original nine validated folders were moved unchanged into `cases_approved/` in commit `6f5a112`. They have not been rerun by Astra during this curation. Folder discovery permits restoration with `mv cases_approved/*/ cases/`, without manifest or configuration edits. Keep the controller idle during membership changes and rebuild/recreate its Docker image afterward.

| Candidate | Current state | Evidence |
| --- | --- | --- |
| Operately #1069: check-in recipient identity | Approved, parked and pushed in `5b38487`; three fresh matching qualification rounds and two reviewed fresh Astra successes | [Record](operately-pr-1069/README.md) |
| LiveBeats #37: now-playing tab and media metadata | Approved and parked; three fresh matching qualification rounds and two reviewed fresh Astra successes | [Record](livebeats-pr-37/README.md) |

This is a sequential curation record, not a full-inventory model score. All qualification and model runs are functional checks with bounded resources. No speed/performance comparison is part of this work. Previous research candidates and recorded holds remain in the [application catalogue](../../docs/research/end-user-application-candidates-2026-10-18.md); this table does not declare that queue exhausted.
