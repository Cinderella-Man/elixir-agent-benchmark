# Pinchflat #542 — SponsorBlock “mark segments as chapters” option

**Status:** discovered  
**Source type:** historical PR (feature)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#542](https://github.com/kieraneglin/pinchflat/pull/542)  
**Source revisions:** base `967e21a8a1f16f72d5ccc20876374f85a2ebe600` → merge `e150355874c9b942cc52ff0053b18563391a8ec2`  
**Author:** kieraneglin · **Merged:** 2025-01-03  
**Task kind / family:** bounded feature / profile enum → yt-dlp option builder  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Why it is a good case

Small but coherent feature: media profiles can `:remove` SponsorBlock segments today; users want `:mark` (chapters) without removal. Enum + friendly form labels + download option builder must agree, including the empty-categories and disabled cases. Good focused multi-file option-pipeline task with sharp unit tests (no network).

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/profiles/media_profile.ex` | `sponsorblock_behaviour` enum gains `:mark`. |
| `lib/pinchflat_web/controllers/media_profiles/media_profile_html.ex` | `friendly_sponsorblock_options/0` gains “Mark Segments as Chapters”. |
| `lib/pinchflat/downloading/download_option_builder.ex` | `{:mark, categories}` → `sponsorblock_mark: joined`; still no option when categories empty or behaviour disabled. |

Test: `test/pinchflat/downloading/download_option_builder_test.exs`.

**Counts:** 3 substantive implementation files, 1 test file.

## Cross-component behavior to verify

- `:mark` + categories ⇒ `sponsorblock_mark` option, **not** `sponsorblock_remove`.
- Empty categories ⇒ no sponsorblock option for either behaviour.
- `:disabled` ⇒ no options (preservation).
- Form label/value round-trip for `mark` (HTML helper).

## Draft ticket (shortest sufficient)

> Besides removing SponsorBlock segments, let a media profile mark those segments as chapters instead. Empty category lists should not emit any SponsorBlock flags. Keep the existing remove and disabled behaviors. Fix it.

## Proposed named acceptance checks

1. `option-builder mark-uses-sponsorblock-mark`
2. `option-builder mark-does-not-remove`
3. `option-builder empty-categories-no-flags`
4. `option-builder disabled-no-flags`
5. **Preservation:** `:remove` still emits `sponsorblock_remove`.

## Plausible incomplete + integrity control

- **Incomplete:** add enum value + form but builder only handles `:remove`.
- **Integrity:** reject patches that send both mark and remove, or that emit empty category lists.

## Preservation

Existing remove/disabled option-builder tests.

## Runtime / offline holds

- Pure unit tests + one form helper; yt-dlp not invoked.
- SponsorBlock network is **not** exercised — offline OK.
- Smaller than preferred 2–5 *deep* files; keep as focused feature reserve.

## Status: discovered

Focused reserve — quick win for option-builder family coverage.

## Next action

Use if a tiny bounded feature is needed for mix balance; otherwise prefer #485/#640/#610/#559/#535 first.
