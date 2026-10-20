# Pinchflat #640 — Per-source cookie behaviour across indexing, download, metadata

**Status:** discovered  
**Source type:** historical PR (FR #595)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#640](https://github.com/kieraneglin/pinchflat/pull/640)  
**Source revisions:** base `b790e051330f085cf8b52b373d097adab7bc3e00` → merge `ac895944a8d80c69f0da0f8846668f6f521866ef`  
**Author:** kieraneglin · **Merged:** 2025-03-05  
**Task kind / family:** bounded feature / source policy propagated to all yt-dlp consumers  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Why it is a good case

Real user need: cookies are required to *see* a private playlist (Watch Later) but should not be attached to every video download. The feature replaces boolean `use_cookies` with `cookie_behaviour` (`:disabled | :when_needed | :all_operations`) and a single policy function `Sources.use_cookies?(source, operation)` that every consumer must use consistently. Cross-component: schema + migration with data mapping, download, slow/fast indexing, metadata workers, source form. Tests assert the policy at each boundary. This is exactly “several parts must stay consistent” work.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/sources/source.ex` | Replace `:use_cookies` boolean with `Ecto.Enum` `:cookie_behaviour`. |
| `lib/pinchflat/sources/sources.ex` | `use_cookies?/2` policy (`:indexing` / `:downloading` / `:metadata`); source-details changeset uses `:all_operations` only. |
| `priv/repo/migrations/20250304185528_add_cookie_behaviour_to_sources.exs` | Add column, map `use_cookies=true` → `all_operations`, reverse for rollback, drop old column. |
| `lib/pinchflat/downloading/media_downloader.ex` | Download + downloadable-status use `Sources.use_cookies?(source, :downloading)`. |
| `lib/pinchflat/slow_indexing/slow_indexing_helpers.ex` | Indexing runner opts use `:indexing`. |
| `lib/pinchflat/fast_indexing/fast_indexing_helpers.ex` | Fast index metadata fetch uses `:metadata`. |
| `lib/pinchflat/metadata/metadata_file_helpers.ex` + `source_metadata_storage_worker.ex` | Thumbnail/source metadata use `:metadata`. |
| `lib/pinchflat_web/controllers/sources/source_html.ex` + `source_form.html.heex` | Friendly labels for the three behaviours; form field rename. |

Tests across downloader, fast/slow indexing, metadata helpers/worker, sources. `erd.png` is generated — ignore.

**Counts:** 7–8 substantive implementation files (schema, context policy, migration, four call-site families, form), tests separate.

## Cross-component behavior to verify

- `:when_needed` — cookies on slow indexing only (per PR at merge time), not on download / metadata / fast index.
- `:all_operations` — cookies everywhere cookies were used before.
- `:disabled` — never.
- Migration preserves existing `use_cookies=true` as `:all_operations` (data compatibility).
- Source create/details still works when cookies are not needed (UI path skips sleep interval — careful not to conflate with #559).

## Draft ticket (clarified implementation brief)

> Let a source choose when YouTube cookies are used: never, only when needed for indexing private collections, or for every operation. The choice must be honored consistently on slow indexing, fast indexing, downloads (including the download-ready pre-check), and metadata/thumbnail fetches. Existing sources that previously enabled cookies should behave as “use for all operations”. Expose the choice on the source form. Keep downloads working for sources that do not need cookies.

## Proposed named acceptance checks

1. `use_cookies? policy-table` — unit table for each behaviour × operation.
2. `download respects-when-needed` — `:when_needed` ⇒ download `use_cookies: false`; `:all_operations` ⇒ true.
3. `slow-index respects-when-needed` — indexing `use_cookies: true` only for `:when_needed`/`:all_operations` per stated rule.
4. `metadata-and-thumbnails disabled-cookies` — `:when_needed` does not attach cookies on metadata/thumbnail ops.
5. `migrate legacy-use-cookies` — fixture with old true/false maps correctly (up/down).
6. **Preservation:** `:disabled` sources still index/download without cookie files.

## Plausible incomplete + integrity control

- **Incomplete:** implement enum + form + download only; slow indexing still reads old boolean (or always false).
- **Integrity:** reject patches that pass `use_cookies: true` for all operations once `:when_needed` is set, or that break migration rollback.

## Preservation

Existing cookie-on/off download tests rewritten to the new enum must still express the old true/false behavior.

## Runtime / offline holds

- yt-dlp mocked; **no YouTube**.
- SQLite + migrations (data migration with `execute` up/down) — verify SQLite test sandbox.
- PR text says “when needed only uses cookies for slow indexing” at merge time; later PRs (#641 etc.) change this. **Freeze the merge-time rule in the ticket** or the hidden checks will be unfair.

## Status: discovered

Best Pinchflat multi-file feature candidate this pass.

## Next action

Draft with the merge-time cookie policy stated explicitly. Do not mix #641 (retry with cookies) into the same case.
