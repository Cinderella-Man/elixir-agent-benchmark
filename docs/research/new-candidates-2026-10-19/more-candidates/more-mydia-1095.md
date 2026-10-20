# Mydia #1095 — imports fail on filesystems that refuse chmod

**Status:** discovered  
**Source type:** historical PR  
**Project:** [getmydia/mydia](https://github.com/getmydia/mydia)  
**PR:** [#1095](https://github.com/getmydia/mydia/pull/1095) — *fix(import): stop failing imports on filesystems that refuse chmod*  
**Author:** arsfeld · **Merged:** 2026-10-10  
**Task kind / family:** bug_fix / storage copy semantics (SMB/NFS/FUSE)  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Merge commit | `60ed46b3c03689e3df61222568b872e38af6fbb1` | **2 parents** — `Merge pull request #1095 …` |
| **First-parent (mainline base)** | `e8b45af9b0441ec8600a8113e2c74a080566578e` | Parent #1 of the merge — use this as the task base |
| Second parent (PR head) | `6b33cd06fe24826d069c0f51932c3e344d817b60` | Branch tip `worktree-media-import-eperm-retry` |

**Not a squash.** Reconstruct at first-parent `e8b45af9…` and apply `pull/1095.diff` (equivalent to the merge). Do not use `60ed46b` as the starting tree.

PR metadata: `commitsCount: 2`, same-day open/merge.

## Why it is a good case

`File.cp/2` reports a **refused chmod** as a failed copy even when every byte has landed. On SMB/CIFS, some NFS exports, and FUSE mounts, chmod returns `:eperm` and mount options decide the mode anyway. Imports, trash moves, and organizer copies then fail spuriously. The PR introduces `Storage.Local.copy_file/2` (byte copy + best-effort mode copy) and routes the three copy call-sites through it. The ticket can describe “imports fail on my NAS share” without naming the helper or `:file.copy`. Three implementation files must agree; tests pin bytes, overwrite, and missing-source behavior.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/mydia/storage/local.ex` | New `copy_file/2`: `:file.copy` for bytes, then best-effort `copy_mode/2`; used by `put_local_file` and `copy_local_file` |
| `lib/mydia/library/file_organizer.ex` | Fallback copy and cross-device move (`:exdev`) use `Storage.Local.copy_file/2` instead of `File.cp/2` |
| `lib/mydia/library/trash_store.ex` | Trash copy path uses `Storage.Local.copy_file/2` |

**Counts:** 3 substantive implementation files, 1 test file. Coordinated copy-semantics fix.

## Cross-component behavior to verify

- Import/organize, cross-device move, and trash must all treat a **successful byte copy with refused chmod** as success.
- A real copy failure (missing source, permissions on write) must still fail.
- Mode is copied when the filesystem allows it and ignored when it does not (no crash, no false import failure).

## Draft ticket (shortest sufficient)

> On some network shares (SMB/NFS/FUSE), imports and library moves fail even though the file data is copied — the share refuses chmod and the app treats that as a failed copy. Make file copies succeed whenever the bytes land, keep the source mode when the filesystem allows it, and still report real copy errors. Fix it.

## Proposed named acceptance checks

1. `copy_file copies-bytes-and-mode` — source mode 0o640; dest bytes match and dest mode (0o777 mask) is 0o640.
2. `copy_file overwrites-destination` — longer old dest is replaced by shorter source content.
3. `copy_file missing-source-posix-error` — `{:error, :enoent}` for absent source.
4. `import-copy succeeds-when-chmod-refused` — copy path that returns `:eperm` on mode change still counts as `:ok` (organizer / trash / storage entry).
5. `import-copy still-fails-on-byte-error` — missing/unreadable source still surfaces as `{:error, …}` (preservation).

## Plausible incomplete + integrity control

- **Incomplete:** add `copy_file/2` in `Storage.Local` and wire only `file_organizer.ex`; trash and `put_local_file` still call `File.cp/2`. Compiling; fails check 4 on the trash/storage path.
- **Integrity:** reject patches that swallow all errors (including byte-copy failures), or that skip mode copy entirely when the FS allows it.

## Preservation

- Existing import, organizer, trash, and storage tests must pass.
- Ordinary local-disk copies keep identical success/failure behavior aside from chmod-tolerant mode handling.
- Do not change S3/backends — this is local copy semantics only (S3 write path is a different PR family).

## Runtime / offline holds

- AGPL-3.0. Elixir + SQLite (`ecto_sqlite3`); no live SMB required if the refused-chmod case is simulated (`:eperm` from mode step) and byte errors are faked.
- Tests in the PR use a `tmp_dir` and normal POSIX filesystems; the “chmod refused” branch needs a stub or a real FUSE/SMB mount recorded in harness notes.

## Experiments (quick)

- `pull/1095.diff` well-formed (4 paths). `git apply --check` in an empty repo correctly reports missing base files (diff parses).
- First-parent verified from the merge commit page (`2 parents e8b45af + 6b33cd0 commit 60ed46b`).

## Status: discovered

Clear 3-file coordinated bug with an authentic NAS/SMB failure mode. The refused-chmod simulation is the main harness item.

## Next action

Pin first-parent `e8b45af9…` → apply `pull/1095.diff` → stub `:eperm` on mode copy → checks 1–5 → incomplete = organizer-only wire-up → qualification. Keep AGPL notice in provenance.

## Grilling (2026-10-19)

### Minimum ticket
Good maintenance report. States the product rule (bytes land = success; keep mode when the FS allows it; still report real copy errors) without naming `Storage.Local.copy_file/2` or `:file.copy`. "the share refuses chmod" is close to the root cause but it is the observed environment fact a user would report — keep it. One gap: the ticket says "imports and library moves" but the reference also changes the **trash** path. Either say "imports, library moves, and trash" or accept a solver who only fixes the paths they can see failing; do not hide trash-only grading.

### Named deterministic checks
Unexecuted. Proposed set is usable but the refused-chmod case is still a stub story, not a named harness:
1. `copy_file copies-bytes-and-mode` — source 0o640 → dest bytes match, dest mode 0o640 (under 0o777 mask)
2. `copy_file overwrites-destination` — longer old dest replaced by shorter source
3. `copy_file missing-source-posix-error` — `{:error, :enoent}` for absent source
4. `import-copy succeeds-when-chmod-refused` — mode step returns `:eperm`, overall `:ok` (organizer **and** trash **and** storage entry)
5. `import-copy still-fails-on-byte-error` — missing/unreadable source still errors (preservation)

Without (4) on **all three** call-sites, the organizer-only incomplete passes. Without (5) the swallow-everything cheat passes. Without (2) a truncate-less overwrite bug survives. Without (1) a skip-mode-entirely patch passes.

Missing: cross-device move (`:exdev`) path uses the tolerant copy — name it or explicitly leave it ungraded.

### Ambiguity / unfairness
- "keep the source mode when the filesystem allows it" is fair to grade as: mode is attempted, success is not required. Do not grade a specific error tuple for the refused-chmod case beyond "overall success".
- Do not require the helper name `copy_file/2` / `copy_mode/2`. Grade call-site behavior.
- `0o640` exact mode is reference detail; grade "mode preserved when chmod works" with whatever source mode the fixture sets.
- Whether trash is in scope — see ticket gap above. Tighten before freeze.
- Do not grade S3 / remote backends. This is local copy semantics only.

### Shortcuts + compiling incomplete
Organizer-only wire-up (as stated) compiles and is the natural partial. Also: fix trash only; skip mode copy always (fails 1); swallow all errors including `:enoent` (fails 3 and 5); use `File.cp` for bytes and ignore the mode step entirely (fails 1); return `:ok` on missing source (fails 3/5 — integrity).

### Flakiness
Low if the `:eperm` is injected. **Do not** require a live SMB/CIFS/FUSE mount — that is non-reproducible external data and the guidelines defer it. Stub the mode step (or `:file.change_mode`) to return `:eperm` and assert the overall result. Mode assertions must mask with 0o777 (umask noise) and must not run on filesystems that ignore mode (CI container mounts) — if mode cannot be asserted portably, assert "mode step was attempted / bytes landed" instead and say so.

### Preservation
Existing import, organizer, trash, storage tests. Ordinary local-disk copies keep success/failure behavior. S3 path untouched. Add a named "ordinary copy still copies mode when chmod works" and "missing source still fails" so the tolerant path cannot become a black hole.

### Env
AGPL-3.0-or-later — keep the notice in provenance; AGPL is fine for this corpus but must not be dropped. Elixir + `ecto_sqlite3`. No live NAS. **Nothing executed** — no apply, no compile. First-parent base `e8b45af9…` is the right reconstruction (merge, not squash). 3 implementation files is a good coordinated count.

### Verdict
**READY-WITH-FIX** — coherent 3-file copy-semantics bug with a real user story and a clean success/failure boundary. The only design work left is the `:eperm` injection harness and naming trash/exdev in the ticket; both are small.

### Must-fix before qualification
1. Ticket: include trash (and cross-device move if graded). Do not leave trash as a hidden obligation.
2. Record the refused-chmod harness as an injected `:eperm` on the mode step — no SMB mount. Name check 4 across all three call-sites.
3. Incomplete = organizer-only wire-up. Integrity = swallow-everything, skip-mode, `:ok` on missing source.
4. Pin first-parent `e8b45af9…`, apply `pull/1095.diff`, run unchanged/reference/incomplete. Mode asserts masked; portable fallback if the FS lies about mode.
5. AGPL notice in provenance. Keep S3 out of the graded diff.
