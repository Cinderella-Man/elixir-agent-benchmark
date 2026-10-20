# xl-mydia-1072

**Status:** discovered
**Project:** getmydia/mydia
**PR:** [#1072 — Stream links for external players](https://github.com/getmydia/mydia/pull/1072)
**Issue:** (no linked issue number in PR body; authentic product request from the media-library player workflow)

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1072 |
| Title | Stream links for external players |
| Source type | Historical merged PR (bounded feature; Stash-style stream links) |
| Merge style | **True merge commit** (2 parents) |
| Merge commit | `a60ce87ce7b172ea533467c165ffea7ed765b6f5` |
| First parent (mainline at merge) | `423921b98f3eb2489385e85470687232a5daf033` |
| Second parent (PR head) | `f00edc137a3b1f8fe8804d1231bd302a53a5711c` (7 commits) |
| PR recorded base (may lag first parent) | `67238ed514289b699cb0289c917e503b5a6ade25` |
| Merged at | 2026-10-07T17:04:16Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body + `pull/1072.diff` inspected; suite not executed |

**Identity note:** reconstruct the base as the **first parent** `423921b9…` (or verify `git merge-base` of head and first parent). The diff of `first_parent → merge` equals the PR head content for this merge.

## Why it is a LIMIT-TEST

One outcome — *every movie/episode file row exposes a durable, access-checked stream URL for external players (VLC/mpv/Infuse), with Range support and a copy affordance* — coordinates:

1. **Token module** (`StreamLink`): encode `{user_id, media_file_id}` as a `Phoenix.Token`; verify + reload both sides on every request.
2. **HTTP controller** (`StreamLinkController`): 404 for every failure (bad token, trashed file, deleted user, restricted library, missing disk file), `cache-control: private, no-store`, relative-safe paths.
3. **Range extraction** (`RangeHelper.send_file_ranged/2` shared with `Api.StreamController`): 200/206/416 behavior must not regress direct play.
4. **Router + LiveView UI**: link icon on movie/episode file rows, Stream Link block + Copy in the file-details modal (Clipboard API with HTTP fallback), shown whether or not the in-app player is enabled.
5. **JS clipboard hook** in `assets/js/app.js`.

Authorization is re-evaluated on **every** hit (not only at mint time). That cross-layer invariant is what makes this a limit-test rather than a URL-minting exercise.

## File inventory (honest count)

**Implementation — 10 substantive:**

| File | Role |
| --- | --- |
| `lib/mydia_web/stream_link.ex` | **New** token mint/verify; reload user + file |
| `lib/mydia_web/controllers/stream_link_controller.ex` | **New** `GET /stream/:token/:filename` + uniform 404s |
| `lib/mydia_web/controllers/api/range_helper.ex` | Range parse + `send_file_ranged/2` extracted |
| `lib/mydia_web/controllers/api/stream_controller.ex` | Uses shared helper; keeps session tracking |
| `lib/mydia_web/router.ex` | Public stream route (no session) |
| `lib/mydia_web/live/media_live/show.html.heex` | File-row link markup |
| `lib/mydia_web/live/media_live/show/components.ex` | Row link component |
| `lib/mydia_web/live/media_live/show/modals.ex` | File-details Stream Link + Copy |
| `lib/mydia_web/live/media_live/show/season_components.ex` | Episode rows |
| `assets/js/app.js` | Clipboard / external-open helper |

**Tests — 5** (separate): `range_helper_test.exs`, `stream_link_controller_test.exs`, `stream_link_test.exs`, `media_live/show/stream_link_test.exs`, `unrestricted_route_crawl_test.exs` (+1 route).

**Generated / mechanical:** none. No migrations, no lockfile.

**Total files in diff:** 15 = 10 impl + 5 tests.

## Draft minimum ticket

> Movie and episode files should offer a stream link I can open in an external player or copy into VLC/mpv. The link must serve the raw file with byte-range support, stop working if the user or file is deleted or restricted, and not require the in-app player to be enabled. Fix it.

(Policy already stated upstream: uniform 404, no session on the route, relative hrefs. Keep those as visible constraints in a clarified brief if hidden checks need them.)

## Named deterministic checks

1. **stream-link-mints-and-serves** — minted path returns 200 with file bytes and `cache-control: private, no-store`.
2. **range-206-and-416** — valid `Range:` yields 206 partial; unsatisfiable range yields 416 (shared helper).
3. **tampered-token-404** — wrong/old token → bare 404, no body leak.
4. **trashed-file-404** — valid token + trashed file stops serving.
5. **deleted-user-404** — valid token + deleted user stops serving.
6. **restricted-user-404** — valid token + library restriction reload fails the check.
7. **missing-on-disk-404** — DB row without file → 404 (not 500).
8. **ui-link-on-movie-and-episode-rows** — LiveView renders link targeting the right user/file; modal Copy block present even when player disabled.
9. **direct-play-range-preserved** — `Api.StreamController` still returns correct ranged responses after the extract (preservation).
10. **filename-ignored** — path basename does not select a different file (token is authority).

## Incomplete that compiles (misses one subsystem)

Implement `StreamLink` + `StreamLinkController` + router **but leave range handling only in the new controller** (do not extract/share `RangeHelper` / do not update `Api.StreamController`). Compiles; new link tests pass; **direct-play-range-preserved** fails.

Alternative incomplete: mint tokens but check restrictions only at mint time → fail **restricted-user-404** (authorization must reload per request).

## Integrity shortcuts

- Unchanged tree fails **stream-link-mints-and-serves** (no route).
- **tampered-token-404**, **trashed-file-404**, **restricted-user-404**, **deleted-user-404** block “serve any token” shortcuts.
- **filename-ignored** blocks open-file-via-filename cheats.
- **direct-play-range-preserved** + **range-206-and-416** block disabling ranges or breaking the API player.

## Preservation

- In-app `Api.StreamController` direct play and session tracking unchanged in behavior.
- Player-disabled installs still show stream links (explicit product rule).
- Existing media LiveView suites stay green.

## Offline holds

| Hold | Notes |
| --- | --- |
| SQLite **or** PostgreSQL | Both supported; pick one pinned adapter per qualification run. |
| Network | None required — no transcoding, no external player in tests. |
| Secret key | `secret_key_base` rotation revokes tokens (document; do not require live rotation test). |
| AGPL-3.0 | Preserve notices. |

## Cross-component contract

> `StreamLink` is the only mint/verify authority; the controller must re-load user/file and apply trash + library rules; `RangeHelper` is shared with the API player; UI only shows paths that `StreamLink` would accept.

## Next action

Pin base at first parent `423921b9…`; run controller + LiveView suites unchanged (fail stream checks), reference (pass), incomplete-without-shared-range (fail preservation only). Confirm route crawl covers `/stream/:token/:filename`.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Movie and episode files should offer a stream link I can open in an external player or copy into VLC/mpv. The link must serve the raw file with byte-range support, stop working if the user or file is deleted or restricted, and not require the in-app player to be enabled.

Repair/feature brief with an explicit product rule (player-disabled still shows links). Good. Must add before it is fair:

- **Authorization must be re-checked on every request**, not only when the link is minted. The dossier knows this is the invariant; it is not in the draft ticket. Put it in one sentence ("the link must re-check the user's access on every request") or the restricted-user check becomes a hidden requirement.
- **Uniform 404** for every failure (bad token, trashed file, deleted user, restriction, missing on disk). State "a single 404 with no distinguishing body for every failure". Do not grade the exact body string `"Not found"`.
- Range policy is underspecified. The reference also changes shared range parsing (suffix `bytes=-N`, end clamp, empty file → error). If those are scored, state them. If not, only require "valid range → 206, unsatisfiable → 416, no header → 200" and accept old or new parse for the edge cases. **Do not** hide suffix-range support in checks.
- Filename in the path is decorative; the token is authority. State it ("any filename works; the token identifies the file") or the check is a hidden trap.

### 2. Deterministic checks

ExUnit + Phoenix.ConnTest + LiveViewTest. **Fakes:** none for HTTP (local files in tmp). Use real files on disk in the test tmp dir. No transcoding, no external player, no network.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `link-serves-file` | valid user+file, minted path | `GET` | 200, file bytes, `cache-control: private, no-store` |
| `range-valid-206` | `Range: bytes=0-1` | `GET` | 206 + partial body |
| `range-unsatisfiable-416` | `Range: bytes=999999-` on small file | `GET` | 416 |
| `tampered-token-404` | flipped token bytes | `GET` | 404 |
| `trashed-file-404` | valid token, `trashed_at` set **after** mint | `GET` | 404 |
| `deleted-user-404` | valid token, user deleted **after** mint | `GET` | 404 |
| `restricted-user-404` | valid token, restriction applied **after** mint | `GET` | 404 |
| `missing-on-disk-404` | DB row, file deleted from disk | `GET` | 404 (not 500) |
| `filename-ignored` | `/stream/:token/anything.mkv` | `GET` | 200 |
| `ui-link-movie-and-episode` | LiveView show for movie + episode | render | link present, targets that user/file; modal Copy present with player disabled |
| `preservation-direct-play-range` | existing `Api.StreamController` ranged responses | suite | unchanged |

The three "after mint" cases are the real authorization invariant. Without them, mint-time-only checks pass.

### 3. Ambiguity / unfairness

- **404 body string:** reference uses `"Not found"`. Dossier says "bare 404, no body leak". Grade status 404 and absence of file bytes / absence of error details — **not** the exact string.
- **Cache header** `private, no-store` is named in the dossier checks but not the draft ticket. If graded, put it in the brief or accept "not publicly cacheable". Otherwise drop from scored obligations.
- **Range suffix/clamp behaviour** is an unstated product change (see ticket). Serious hidden-requirement risk if checks demand `bytes=-N`.
- **Route shape** `/stream/:token/:filename` is needed to write the UI check. The brief should say the link is a path under the app that serves the file; if checks call `StreamLink.path/2` that is name-pinning. Prefer: render the UI and follow the href (parse the link from the LiveView HTML), so any path shape works. The reference module `MydiaWeb.StreamLink` should not be required by name unless the brief names it as the token authority.
- `Phoenix.Token` salt, `max_age: :infinity`, and `secret_key_base` rotation are internal. Do not grade them. A solver may use a different signed-token mechanism — accept any tamper-evident token.
- Clipboard JS behaviour is not unit-testable offline. Grade the LiveView markup / `phx` hook presence loosely, not the JS runtime.

### 4. Shortcuts

- **Broken incomplete in the dossier.** "Implement StreamLink + controller but do not extract RangeHelper / do not update Api.StreamController" does **not** fail `preservation-direct-play-range` — leaving `Api.StreamController` untouched preserves direct play. That incomplete passes the stated preservation check. **Replace it** with: "authorize only at mint time" → fails `restricted-user-404` / `trashed-file-404`. Or "serve without range support" → fails `range-valid-206`.
- Serve any valid token without reload → fails the three after-mint checks.
- Use filename to open the file → fails `filename-ignored`.
- 500 instead of 404 on missing disk file → fails `missing-on-disk-404`.
- Links shown only when in-app player is enabled → fails the player-disabled UI check.
- Range handling only in the new controller, and the new controller lacks 416 → fails `range-unsatisfiable-416`.
- Return 206 with wrong `content-range` → make at least one range check assert the header (the reference sets it). Or accept any 206 with the right slice; pick one.

### 5. Flakiness

Low. Local files, ConnTest, LiveViewTest. No timers. Token tests are pure. Do not spin the JS clipboard. Route crawl test (unrestricted routes) is static. Watch out for `File.stat!` races only if tests delete files concurrently — use unique tmp paths.

### 6. Coverage mix

- Positive: serve, 206, UI links, player-disabled still shows.
- Negative: tampered token, trashed, deleted user, restricted (after mint), missing disk, 416.
- Preservation: `Api.StreamController` direct play + session tracking.
- Mixed: mint a link, then change access state, then request — one fixture that would pass mint-time-only auth.

### 7. Environment

- SQLite **or** Postgres — pick one pinned adapter for the whole qualification. Do not mix.
- AGPL-3.0 — preserve notices.
- No network, no yt-dlp, no transcoding. Good offline story.
- `secret_key_base` rotation revokes tokens — document only.
- **Nothing executed.** No apply, no compile.
- Elixir `~> 1.20` at base is very new — confirm the runner image has it.

### 8. XL-specific

10 impl files is **partly inflated**. Core coordination is real: token authority ↔ controller re-auth ↔ shared range helper ↔ UI only shows accepted paths. But 4 of 10 are UI/JS (show.html.heex, components, modals, season_components, app.js). Honest core is ~5–6 backend files. Possible split: (a) stream link serve + auth + range (~5 files), (b) UI affordance (~5 files). The user story is one ("I can copy a link and it keeps working"), so keep as one case only if the ticket scores both serve **and** UI. If you want a tight 2–5, drop UI to preservation notes and take (a). The "shared RangeHelper extract" is a refactor that only pays off if `Api.StreamController` behaviour is checked — which is the broken incomplete's domain.

### 9. Verdict

**READY-WITH-FIX** — strong per-request auth invariant and good negative coverage, but the dossier's incomplete control is wrong, range/404 policies are hidden, and the UI/backend split may be padding.

### 10. Must-fix before qualification

1. **Replace the incomplete control** — mint-time-only auth (fails after-mint checks) or no-range (fails 206/416). The RangeHelper-extract incomplete does not fail its claimed check.
2. Put "re-check access on every request" and "uniform 404" in the ticket.
3. Decide range edge policy (suffix/clamp) — state or descope.
4. Do not grade exact `"Not found"` body, `Phoenix.Token` internals, or `StreamLink` module name (unless the brief names it).
5. UI checks follow the rendered href; do not require a path helper name.
6. Pin base first-parent `423921b9…`; pick one DB adapter; Elixir 1.20 image proof.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Broken incomplete control; hidden range/404 policy |
