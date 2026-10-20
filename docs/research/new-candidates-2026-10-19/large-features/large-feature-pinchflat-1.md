# Large feature — Pinchflat #640 per-source cookie behaviour across yt-dlp consumers

**Status:** discovered
**Source type:** historical merged PR (feature request #595)
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat) — YouTube media manager
**PR:** [#640](https://github.com/kieraneglin/pinchflat/pull/640)
**Author:** kieraneglin · **Merged:** 2025-03-05
**Source revisions:** base (merge first parent) `59f8aa69cdbc27625120fe85a236ff2166445562` (dossier also records `b790e051330f085cf8b52b373d097adab7bc3e00` as PR base — **re-verify which is the reconstruction parent**) → merge `ac895944a8d80c69f0da0f8846668f6f521866ef`
**Task kind / family:** bounded feature / source policy propagated to every yt-dlp consumer
**Research date:** 2026-10-19
**License:** AGPL-3.0

---

## Why it is a LIMIT-TESTING case

Real product need (FR #595): cookies are required to *see* a private playlist (Watch Later) but must **not** be attached to every video download. The PR replaces a boolean `use_cookies` with a three-way policy `cookie_behaviour` (`:disabled | :when_needed | :all_operations`) and a single decision function that **every** yt-dlp consumer must use.

Coordination that is hard:

1. Schema + **data migration** mapping `use_cookies=true` → `all_operations` (and rollback).
2. One policy function used by download, slow indexing, fast indexing, metadata/thumbnail workers, and source-details UI lookups.
3. Source form labels for the three behaviours (and the source-details path that historically forced cookies).
4. Tests at **each** consumer boundary — a patch that fixes download but not metadata is incomplete.

This is not “ten copies of a string”: it is one policy with several call sites that must agree. File count (7–8) is a signal of that spread.

**Contract footgun to freeze at merge time:** at merge, `:when_needed` used cookies for **slow indexing only** (later PRs such as #641 change this to retry-with-cookies). The ticket must state the merge-time rule or hidden checks become unfair.

## File inventory with roles

From `pull/640.diff` (17 paths; `erd.png` generated — ignore).

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/pinchflat/sources/source.ex` | Replace `:use_cookies` boolean with `Ecto.Enum` `:cookie_behaviour`. |
| `lib/pinchflat/sources/sources.ex` | `use_cookies?(source, operation)` policy for `:indexing / :downloading / :metadata`; source-details changeset uses `:all_operations` only. |
| `priv/repo/migrations/20250304185528_add_cookie_behaviour_to_sources.exs` | Add column, map legacy true→`all_operations`, reverse for rollback, drop old column. |
| `lib/pinchflat/downloading/media_downloader.ex` | Download + downloadable-status use `:downloading`. |
| `lib/pinchflat/slow_indexing/slow_indexing_helpers.ex` | Indexing runner opts use `:indexing`. |
| `lib/pinchflat/fast_indexing/fast_indexing_helpers.ex` | Fast index metadata fetch uses `:metadata`. |
| `lib/pinchflat/metadata/metadata_file_helpers.ex` + `source_metadata_storage_worker.ex` | Thumbnail/source metadata use `:metadata`. |
| `lib/pinchflat_web/controllers/sources/source_html.ex` + `source_form.html.heex` | Friendly labels; form field rename. |

**Counts:** 7–8 substantive implementation files (schema, context policy, migration, four call-site families, form). Tests separate.

### Tests (contract-describing)

Downloader, fast/slow indexing, metadata helpers/worker, and sources tests assert the policy at each boundary. (Exact file names in upstream tree; keep upstream tests as evidence and add curator boundary checks.)

### Generated

| Path | Note |
| --- | --- |
| `erd.png` | Generated ER diagram — do not count or require. |

## Draft clarified feature brief

> Let a source choose when YouTube cookies are used: never, only when needed for indexing private collections, or for every operation. The choice must be honored consistently on slow indexing, fast indexing, downloads (including the download-ready pre-check), and metadata/thumbnail fetches. For “when needed”, use cookies on slow indexing only (not on downloads, fast indexing, or metadata). Existing sources that previously enabled cookies should behave as “use for all operations”. Expose the choice on the source form. Keep downloads working for sources that do not need cookies.

The three behaviour names/labels are product language and may appear. Do **not** name `use_cookies?/2`, migration filenames, or module paths.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Policy table:** each behaviour × operation yields the documented cookie flag (unit table). |
| A2 | **Download:** `:when_needed` ⇒ download `use_cookies: false`; `:all_operations` ⇒ true; `:disabled` ⇒ false. |
| A3 | **Slow index:** `:when_needed` and `:all_operations` attach cookies on indexing; `:disabled` does not. |
| A4 | **Metadata/thumbnails:** `:when_needed` does **not** attach cookies on metadata/thumbnail ops. |
| A5 | **Migration:** legacy `use_cookies=true` ⇒ `:all_operations`; false ⇒ disabled; rollback restores boolean. |
| A6 | **Preservation:** `:disabled` sources still index/download without cookie files; sources that never needed cookies still work. |

## Incomplete control

**Compiling partial that misses one subsystem:** implement enum + form + download call sites, but leave slow indexing still reading the old boolean (or always false).

- A2 may pass; **A3** fails (private playlist indexing never gets cookies).
- Second partial: always pass `use_cookies: true` once any cookie behaviour is set → A2/A4 fail for `:when_needed`.

## Integrity / shortcut rejection

Reject patches that:

- Attach cookies for every operation whenever the field is non-nil (ignores `:when_needed` / `:disabled`).
- Break migration rollback or lose legacy true→all_operations mapping.
- Apply cookies to metadata/thumbnail under `:when_needed`.
- Change download-ready pre-check to ignore the policy.

## Preservation of existing behavior

- Existing cookie-on/off download tests rewritten to the new enum must still express old true/false behaviour.
- Sources with cookies disabled continue to index and download.
- Source create/details flows keep working (careful not to conflate sleep-interval UI skip from #559).

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| yt-dlp mocked | Existing `test/support/scripts/yt-dlp-mocks/`; **no YouTube**. |
| SQLite | `ecto_sqlite3`; data migration with `execute` up/down — verify sandbox. |
| Oban | Workers tested via existing helpers. |
| Freeze merge-time rule | Ticket states slow-index-only for `:when_needed`; do not import #641 retry-with-cookies. |
| AGPL-3.0 | Provenance notice. |

Not verified here: compile/test/boot, offline Hex/git deps.

## Status: discovered

Best Pinchflat multi-file feature alongside #610. Limit-testing because the same policy must hold at four external-command boundaries.

## Next action

1. Resolve base SHA (`59f8aa69…` vs `b790e051…`) before reconstruction.
2. Freeze the merge-time cookie rule in the brief.
3. Incomplete = download-only; integrity = always-cookies or broken rollback.
4. Qualify after Pinchflat SQLite/Oban/mocks runtime is confirmed.
