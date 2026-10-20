# Original twelve-case audit inputs

This is the exact inventory and fixture set examined by the 2026-10-14
[task-quality audit](../../../docs/verification/task-quality-audit-2026-10-14.md),
before the eleven-case v3 promotion. `sha256.json` binds every original fixture,
the inventory and `release.json`. The archive is outside the scored `cases/`
directory and is not copied into the deployed controller image.

Plausible 6300 is retained here solely for historical reproduction. Its reference
fails the audit's legitimate daylight-saving requirement: for a US/Eastern site,
Today on Monday 2023-03-13 must match Monday 2022-03-14, while the reference starts
on Tuesday 2022-03-15. The task is retired from v3, not repaired by changing the
expected answer. Readmission would require a separately reviewed reference and
complete qualification.

The original scores and recorded audit evidence are not reinterpreted under the
new grader. The audit scripts select these archived inputs explicitly. Current
qualification and promotion replay scripts use the active eleven-case inventory.

**Prepared-source policy, 2026-10-20:** runnable additions and source migrations must follow [prepared fork sources](../../../docs/prepared-fork-sources.md). This record retains its original source versions and outcomes; [the later fork audit](../../prepared-forks-2026-10-20/README.md) records branch reuse and any new migration evidence separately.
