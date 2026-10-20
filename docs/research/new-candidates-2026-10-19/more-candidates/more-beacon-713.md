# Beacon #713 — media uploads read files on the wrong node

**Status:** discovered  
**Source type:** historical PR  
**Project:** [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon)  
**PR:** [#713](https://github.com/BeaconCMS/beacon/pull/713) — *Fix media uploads in multi node deployments*  
**Author:** APB9785 · **Merged:** 2025-01-07  
**Task kind / family:** bug_fix / distributed file ownership (media library)  
**Research date:** 2026-10-19  
**License:** MIT

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `cc0ca8e9c6e28326cc0feacceea2081adfcae3de` | Title `…(#713)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `9db90ad9e9f871e9d74626fe5152af70af58e567` | Sole parent of the squash commit |

PR metadata: `commitsCount: 3`, `baseBranch: main`, head `apb/media-upload-fix`. Reconstruct at **base `9db90ad9…`** and apply `pull/713.diff`. Do not treat a later main tip as the base.

## Why it is a good case

Media upload processing (`UploadMetadata`, processors) called `File.read!/1` and `File.stat/2` on `metadata.path` **locally**. In a multi-node deployment the upload lands on one node while the loader/processor runs on another, so file access fails or reads the wrong path. The PR records which node owns the file (`UploadMetadata.node`) and routes `read`/`stat` through `:erpc.call/4` to that node. Coordinated across the metadata struct, the MediaLibrary API, both processors, and the loader’s default logo upload. Users see failed media uploads / missing images in multi-node setups; the ticket can describe the symptom without naming `:erpc` or the `node` field.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/beacon/media_library/upload_metadata.ex` | Add `:node` to the struct; `new/4` takes the owning node; `size` uses remote `File.stat` |
| `lib/beacon/media_library.ex` | `read_binary/1`, `read_binary!/1`, `file_stat/2` — all access the file **on `metadata.node` / `node`** via `:erpc` |
| `lib/beacon/media_library/processors/default.ex` | Default processor reads via `MediaLibrary.read_binary!/1` instead of `File.read!/1` |
| `lib/beacon/media_library/processors/image.ex` | Image processor reads via `MediaLibrary.read_binary!/1` then `Image.from_binary!/2` |
| `lib/beacon/loader/worker.ex` | Default logo `UploadMetadata.new` passes `Node.self()` |
| `lib/beacon/test/fixtures.ex` | Fixture `UploadMetadata.new` passes `Node.self()` |

**Counts:** 5 substantive implementation files + 1 test fixture. Coordinated ownership fix (not a one-liner).

## Cross-component behavior to verify

- Every file read/stat used during upload processing must target the **node that holds the file**, not the node running the process.
- Image and default processors must agree on that rule (both go through the same MediaLibrary helper).
- `UploadMetadata` size and output must still be correct for a local (single-node) upload — `Node.self()` path must keep working.

## Draft ticket (shortest sufficient)

> When Beacon runs on more than one node, media uploads sometimes fail or produce empty/broken assets because the processor looks for the uploaded file on the wrong machine. Make upload processing read and stat the file on the node that actually has it, without breaking single-node installs. Fix it.

## Proposed named acceptance checks

1. `media_upload reads-file-on-owning-node` — metadata.node = node A, processor runs on node B; assert file bytes come from A (e.g. process trap / assert `:erpc` target).
2. `media_upload image-processor-uses-remote-read` — image path uses the same remote-read helper (not local `File.read!`).
3. `media_upload default-processor-uses-remote-read` — non-image path uses the same helper.
4. `media_upload size-from-remote-stat` — `UploadMetadata.new` size is taken from the owning node’s `File.stat`.
5. `media_upload local-self-node-still-works` — `Node.self()` upload (fixtures / single-node) still produces a valid asset (preservation).

## Plausible incomplete + integrity control

- **Incomplete:** add `node` to the struct and fix only the image processor; default processor still uses `File.read!(metadata.path)` locally. Compiling; fails named check 3.
- **Integrity:** reject patches that ignore `metadata.node` and always use `Node.self()`, or that drop the single-node/`Node.self()` path so fixtures break.

## Preservation

- Existing media library / asset tests and `Beacon.Test.Fixtures` must pass.
- Single-node and CI paths (where node == `Node.self()`) must behave as before.
- Do not change public asset URL/hash behavior — this is storage ownership, not the encoding work of #727.

## Runtime / offline holds

- MIT license. Elixir/Phoenix/Ecto; no external service required for the functional check.
- True multi-node proof needs at least two nodes or a test double for `:erpc`; a single-node suite can still verify the ownership field and that reads go through the helper. Record the chosen harness (two `:peer` nodes vs. injected reader) before freezing checks.
- PR itself ships fixture updates but no new multi-node test file — curator must add the named checks.

## Experiments (quick)

- `pull/713.diff` is well-formed (paths under `lib/beacon/`, `CHANGELOG.md`). Full `git apply` against base `9db90ad9…` not executed here (no local clone in this pass).
- Re-verify `UploadMetadata.new/3` → `new/4` arity in any follow-up commit before freeze.

## Status: discovered

Strong 5–6 file coordinated bug in a trusted app. Multi-node harness is the main open item.

## Next action

Pin base `9db90ad9…` → prepare two-node or erpc-double fixture → draft checks 1–5 → incomplete = image-only fix → qualification rounds. Do not open a `cases/` bundle until the multi-node path is demonstrated offline.

## Grilling (2026-10-19)

### Minimum ticket
Good maintenance report. Symptom (uploads fail / empty assets in multi-node) plus the ownership rule without naming `:erpc` or the `:node` field. "without breaking single-node installs" is the right preservation clause. Do not add "route through the owning node's RPC" — that is the fix. One trim risk: "the processor looks for the uploaded file on the wrong machine" is already near-root-cause; keep it because the symptom alone (failed upload) is too vague for the ownership outcome. Acceptable.

### Named deterministic checks
Unexecuted. Proposed set is directionally right but **not freeze-ready** — harness is undefined, so none of these are named protected tests yet:
1. `media_upload reads-file-on-owning-node` — metadata.node ≠ process node; bytes come from the owner
2. `media_upload image-processor-uses-remote-read` — image path goes through the shared helper
3. `media_upload default-processor-uses-remote-read` — non-image path goes through the same helper
4. `media_upload size-from-remote-stat` — `UploadMetadata` size from owner's `File.stat`
5. `media_upload local-self-node-still-works` — `Node.self()` / fixtures path unchanged

Without (3) the image-only incomplete passes. Without (5) a solver can break every single-node fixture and still "fix" multi-node. Without (2)+(3) both, a solver can remote-read in one processor only.

Missing from the set: a check that **writes/processors that never touch files** still work (or at least the loader default-logo path from `worker.ex`), and an integrity witness that `metadata.node` is actually consulted (not hardcoded `Node.self()`).

### Ambiguity / unfairness
- Ticket is fair. Do not grade `:erpc` specifically — `:rpc`, `:erpc`, or a `Node.spawn`/remote `File` apply must all pass if bytes come from the owner.
- `UploadMetadata.node` field name is reference detail. Grade ownership behavior.
- Multi-node scope: ticket says "more than one node". Do not also require disk-sharing false-path behavior or distributed Mnesia setup.
- Fixture updates (`test/fixtures.ex`) are mechanical follow-along; do not grade them as product.

### Shortcuts + compiling incomplete
Image-only fix (incomplete as stated) compiles and is the obvious partial. Also: default-only fix (miss image processor — the common case). Always-`Node.self()` (integrity must reject). Drop `File.stat` size and hardcode 0 / use local stat (check 4). Break `Node.self()` arity so `Beacon.Test.Fixtures` fails to compile (check 5 / suite integrity). Read via `File.read!` after a local `:erpc` copy-to-tmp (behaviorally OK if bytes match — do not reject).

### Flakiness
High if the harness is careless. Two `:peer` nodes need deterministic node names and explicit sync before the processor runs. Do **not** assert on `:erpc` call targets as strings; assert file bytes and result. Single-node CI must stay green — do not make the graded suite require epmd if a reader-injection double can express the same contract. Prefer injected reader / meck-free process trap over a live cluster until the runner proves multi-node offline.

### Preservation
Single-node/`Node.self()` upload path, `Beacon.Test.Fixtures`, existing media library tests, asset URL/hash behavior (this is storage ownership only — not #727 encoding). Add a named "single-node upload produces a readable asset" so an over-eager remote-everything rewrite fails.

### Env
MIT. Elixir/Phoenix/Ecto. **Nothing executed** — no clone, no apply, no compile. Multi-node is **not** in the current runner contract (guidelines: "does not automatically support … multi-node topologies"). Either prove `:peer`/injected-reader works under the Pi offline policy or this case cannot be graded. `new/3`→`new/4` arity change is a cross-file consistency risk.

### Verdict
**HOLD** — coherent ownership bug and a fine ticket, but the multi-node harness is unsolved and the runner does not currently support multi-node. Zero execution. Do not open a `cases/` bundle.

### Must-fix before leaving HOLD
1. Choose and record the harness (`:peer` pair vs injected reader) and prove it runs offline under the current runner; if multi-node is unsupported, this stays deferred for execution support.
2. Freeze named checks 1–5 as protected tests; add default-processor preservation + loader logo path.
3. Grade ownership behaviorally (bytes from owner), not `:erpc` / field names.
4. Integrity: reject always-`Node.self()`, size-from-local-stat, fixtures-breakage.
5. Pin base `9db90ad9…`, run unchanged/reference/incomplete. MIT in provenance.
