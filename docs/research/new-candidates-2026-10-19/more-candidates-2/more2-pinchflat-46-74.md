# Pinchflat #46+#74 — audio-only downloads (combined lineage)

**Status:** discovered  
**Source type:** historical PR lineage (combined per LINEAGE-MERGE-POLICY)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PRs:** [#46](https://github.com/kieraneglin/pinchflat/pull/46) *Support audio only downloads* (2024-03-02) + [#74](https://github.com/kieraneglin/pinchflat/pull/74) *Improve audio-only download* (2024-03-11, +9 days)  
**Task kind / family:** feature / media profile preference → yt-dlp option builder  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| #46 squash / merge | `fc52f16475ef9962c9f4cee834b0d261053ef206` | **1 parent** (squash) |
| #46 squash parent (case base) | `8cc36928f1e45c727f62b21dd2acda2624553954` | Matches PR API `base` — **start tree before either PR** |
| #74 squash / merge | `7e4f1a8412ee492fcb9b992f76b8b0bab97f8d85` | **1 parent** (squash) |
| #74 squash parent | `0e537d8f57ec45dea32be24bfdec71c85d107bf2` | Matches PR API `base` (after #46 and intermediate commits) |

**Combined reference tree:** #74 merge tip (final coherent audio-only behaviour).  
**Natural incomplete control:** #46-only tree (`format: "bestaudio"` without `extract_audio`; embedding disabled for audio).

Per [LINEAGE-MERGE-POLICY](../large-features/LINEAGE-MERGE-POLICY.md): #74 is an obvious product improvement of #46’s incomplete audio path (actually extract audio to m4a; keep thumbnail/metadata embed where valid). Ticket states the **final** behaviour. Do not score two cases.

## Why it is a good case

A media profile’s “preferred resolution” should support **audio-only** downloads. #46 added an `:audio` enum value and mapped it to yt-dlp format selection, but disabled embedding broadly and did not extract audio. #74 made audio-only real: `:extract_audio` + `bestaudio[ext=m4a]`, and restored thumbnail/metadata embed while still skipping subtitle embed for audio. Coordinated across profile schema, option builder, and the profile form; named upstream tests cover the #46-era embedding rules and quality options.

## Implementation file roles (union A+B)

| File | Role |
| --- | --- |
| `lib/pinchflat/profiles/media_profile.ex` | `:audio` on `preferred_resolution` enum |
| `lib/pinchflat/yt_dlp/download_option_builder.ex` (path moved from `lib/pinchflat/profiles/options/yt_dlp/download_option_builder.ex` between A and B) | Map `:audio` → extract/format opts; decide embed flags |
| `lib/pinchflat_web/controllers/media_profiles/media_profile_html/media_profile_form.html.heex` | Audio-only option + help text |
| `lib/pinchflat_web/controllers/media_profiles/media_profile_html.ex` | Friendly resolution labels |
| `lib/pinchflat_web/components/core_components.ex` | Form helpers used by the profile form |
| `test/.../download_option_builder_test.exs` | Embed/quality option checks (file path moves with the builder) |

**Counts:** ~4 substantive implementation files + tests across the lineage (module path rename is one logical change, not two). Feature, not a mega-diff.

## Cross-component behavior to verify

- Selecting audio-only produces yt-dlp options that **extract audio** (m4a) rather than merely preferring an audio stream.
- Thumbnail/metadata embed still work when requested on audio-only profiles; subtitle embed does not (no video stream).
- Non-audio resolutions keep their existing format-sort / codec behaviour.
- Form presents audio-only as a first-class preferred-resolution choice.

## Draft ticket (shortest sufficient)

> Let me download only the audio from a source. On a media profile, add an audio-only preferred format that saves a proper audio file (m4a), not a video container. When audio-only is selected, still allow thumbnail and metadata embedding where that makes sense, but do not try to embed subtitles. All existing video resolution choices must keep working.

Clarified implementation brief. Does not name yt-dlp flags or files.

## Proposed named acceptance checks

1. `builder audio-extracts-m4a` — audio-only profile emits extract-audio + bestaudio m4a options.
2. `builder audio-skips-sub-embed` / `builder audio-allows-thumb-meta-embed` — embed policy matrix.
3. `builder video-resolutions-unchanged` — 360p–2160p still emit their format-sort/codec opts (preservation).
4. `profile form exposes-audio-only` — enum saves and round-trips.
5. `builder default-unchanged` — default profile without audio-only matches pre-change options (preservation).

Upstream tests from #46 cover the embed-skip rules; #74’s extract-audio path needs the final assertion (curator extends).

## Plausible incomplete + integrity control

- **Incomplete:** #46-only (`preferred_resolution: :audio` + `format: "bestaudio"`, no `extract_audio`; broad embed disable). Compiling; fails check 1.
- **Integrity:** reject patches that force audio for all resolutions, that break video format-sort, or that embed subtitles on audio-only.

## Preservation

- Default 1080p profile option lists stay the same.
- Existing download tests for thumbnails/subs/metadata on video profiles stay green.

## Runtime / offline holds

- AGPL-3.0. SQLite + Oban; yt-dlp mocked — no YouTube.
- Module path moved between #46 and #74 — reconstruction at `8cc36928…` must use #46’s paths; applying only `pull/74.diff` onto #46’s parent will not apply cleanly. Preferred: apply `pull/46.diff` then `pull/74.diff` (or take the #74 tree minus unrelated commits).
- Re-verify test file path when building the bundle.

## Experiments (quick)

- Both diffs well-formed. #46: 6 paths; #74: 3 paths. Squash parents confirmed (1 parent each) and match PR API bases.
- #74 is a **narrow follow-up** (quality/extract + embed policy), not a rewrite — lineage merge is appropriate.

## Optional git apply

```
git checkout 8cc36928f1e45c727f62b21dd2acda2624553954
git apply pull/46.diff
git apply pull/74.diff   # may need -3 / path fix if module moved
```

Or reconstruct the #74 tip tree and diff against `8cc36928…` for a single combined patch.

## Status: discovered

Combined lineage case. Ticket = final audio-only behaviour. Intermediate #46 is the natural incomplete control.

## Next action

Build combined patch from `8cc36928…` → #74 tree → checks 1–5 with extract-audio assertion → incomplete = #46-only → three qualification rounds. Case id may be `pinchflat-46-74`.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Let me download only the audio from a source. On a media profile, add an audio-only preferred format that saves a real audio file in m4a, not a video container. When audio-only is selected, thumbnail and metadata embedding still work if the user asked for them; subtitle embedding is skipped. All existing video resolution choices must keep working.

Clarified brief, 4 sentences. Product decisions stated: audio-only is a preferred-format choice, output is extracted m4a, thumb/meta embed allowed, subs embed skipped, video resolutions unchanged. Does not name yt-dlp flags, modules, or files.

**Hidden requirement flagged:** the draft said embedding is allowed "where that makes sense" — that is not a contract. Diff evidence shows the final policy is precise: **thumb + metadata embed are re-enabled for audio; only subtitle embed is suppressed.** State that split or a solver who disables all embedding (the #46 policy) looks reasonable and fails.

### 2. Deterministic checks

ExUnit, pure option-builder unit tests (existing `download_option_builder_test.exs` style). No yt-dlp process.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `builder audio-extracts-m4a` | Media profile `preferred_resolution: :audio` | `DownloadOptionBuilder.build/1` | includes extract-audio **and** a format pin that selects m4a audio (accept `{:format, "bestaudio[ext=m4a]"}` or equivalent extract-audio+bestaudio; do not require the exact flag list beyond "extracts audio to m4a") |
| `builder audio-embed-policy` | audio + `embed_thumbnail: true` + `embed_metadata: true` + `embed_subs: true` | same | thumb and metadata embed flags present; subtitle embed flag **absent** |
| `builder video-resolutions-unchanged` | 360p / 1080p / 2160p profiles with embed flags | same | format-sort / codec opts match pre-change behaviour (preservation) |
| `builder default-unchanged` | Default 1080p profile, no audio-only | same | option list identical to pre-change baseline (preservation) |
| `profile audio-only-saves` | Media profile changeset / form with audio-only | repo round-trip | enum value persists and reloads |

Fake provider: none needed (option builder is pure). Do not run real yt-dlp.

### 3. Ambiguity / unfairness

- Exact yt-dlp flag spelling (`:extract_audio` vs `--extract-audio` vs `--audio-format m4a`) is implementation. Grade the **effect** (extract audio + m4a selection), not the atom list. The reference uses `[:extract_audio, format: "bestaudio[ext=m4a]"]` — a solver emitting `[:extract_audio, audio_format: "m4a"]` is defensible.
- "saves a proper audio file (m4a)" pins the container. That is a product decision and is in the ticket — fair. Alternative containers (mp3, opus) must be rejected only because the ticket says m4a.
- Label text "Audio Only" is cosmetic.
- Module path rename (`Profiles.Options.YtDlp.DownloadOptionBuilder` → `YtDlp.DownloadOptionBuilder`) is reconstruction noise, not a scored outcome. Checks must call whatever module exists after the solver's patch, or go through a stable façade. Prefer asserting via the public builder API the tests already use.

### 4. Shortcuts

- Ship #46 only (`format: "bestaudio"` + broad embed disable). Compiles. Fails `builder audio-extracts-m4a` and half of `builder audio-embed-policy`. **This is the planned natural incomplete** — make sure the bundle's incomplete control is exactly this tree.
- Force extract-audio for every resolution. Fails `builder video-resolutions-unchanged`.
- Extract audio but leave subtitle embed on. Fails `builder audio-embed-policy`.
- Add the enum + form only; builder ignores `:audio` and emits 1080p-style options. Fails check 1.

### 5. Flakiness / nondeterminism

Low — pure functions on a struct. No jobs, no clocks. Keep tests free of File/HTTP.

### 6. Coverage mix

- Positive: audio extracts; audio embed matrix.
- Preservation: every video resolution option list; default profile baseline.
- Mixed population in one test: one profile with audio-only **and** embed flags on, one 1080p profile with the same flags — both must get the right policy in one run so a global "disable embed" patch fails.
- Negative: subtitle embed must be absent only for audio-only.

### 7. Environment risk

- **AGPL-3.0-or-later.** SQLite + Oban; yt-dlp mocked.
- Reconstruction is the real risk: #74 does not apply cleanly onto `8cc36928…` because the builder path moved. Build a **combined tree diff** (base → #74 tip, minus unrelated commits) rather than stacking raw pull diffs. Re-verify test paths in the bundle.
- Exclude cosmetic `core_components.ex` class-string churn from the graded contract if it is incidental (it is layout-only).

### 8. Verdict

**READY-WITH-FIX** — coherent lineage, natural incomplete (#46 tree), clean unit surface; embed policy wording must be exact and the combined patch must be built as one tree.

### 9. Must-fix list

1. Rewrite the embed sentence: thumb+meta allowed, subs skipped — drop "where that makes sense".
2. Grade extract-audio+m4a effect, not exact flag atoms.
3. Build the reference as base→#74 combined tree; verify test module path.
4. Incomplete control = #46-only tree (format bestaudio, broad embed disable).
5. Keep a video-resolution preservation baseline list.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Vague embed policy + lineage reconstruction path drift |
