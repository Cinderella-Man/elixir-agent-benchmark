# xl-pinchflat-282

**Status:** discovered
**Project:** kieraneglin/pinchflat
**PR:** [#282 — Optionally use the YouTube API for improved fast indexing](https://github.com/kieraneglin/pinchflat/pull/282)
**Issue:** [Resolves #280](https://github.com/kieraneglin/pinchflat/issues/280)

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/kieraneglin/pinchflat/pull/282 |
| Title | [Enhancement] Optionally use the YouTube API for improved fast indexing |
| Source type | Historical merged PR (bounded feature; resolves #280) |
| Merge style | **Squash** — one parent |
| Merge commit | `f6708a327cfd2cefe6135a762d322829c053c33e` |
| Parent of merge (= base) | `582eb53698bc1e88d76646dc99f9969876f71364` |
| PR head SHA | `9cb20049996cf755ec83f9a2bb803bc0c17d8996` (13 commits) |
| Merged at | 2024-06-10T18:45:41Z |
| License | **AGPL-3.0** |
| Verification | **Unverified** — PR body + `pull/282.diff` inspected; suite not executed |

## Why it is a LIMIT-TEST

One product outcome — *let the user opt into the YouTube Data API for more reliable fast indexing, defaulting to today's RSS behavior, and fall back to RSS when the API errors* — requires coordination across five layers:

1. **Strategy interface** (`YoutubeBehaviour`) so the indexing helpers do not hardcode the provider.
2. **Two implementations** (`YoutubeApi` and the pre-existing `YoutubeRss`) that must expose the same result shape.
3. **Selection + fallback** in `FastIndexingHelpers`: read the configured API key, choose the API when present, catch API errors and still produce an index list via RSS.
4. **Persistent setting + migration** (`Setting` field + migration seeding/allowing `youtube_api_key`).
5. **Settings UI and source help** (form field, explanation of API vs RSS, source-form wording) so the option is actually reachable.

A solver who adds only `YoutubeApi` leaves helpers stuck on RSS (or crash when the key is missing). A solver who wires helpers but skips the migration/setting cannot configure the key. A solver who removes RSS breaks the documented default.

## File inventory (honest count)

**Implementation — 13 substantive** (tests counted separately):

| File | Role |
| --- | --- |
| `lib/pinchflat/fast_indexing/youtube_behaviour.ex` | **New** provider interface (`get_video_ids/1` style contract) |
| `lib/pinchflat/fast_indexing/youtube_api.ex` | **New** YouTube Data API implementation |
| `lib/pinchflat/fast_indexing/youtube_rss.ex` | Existing RSS provider, aligned to the behaviour |
| `lib/pinchflat/fast_indexing/fast_indexing_helpers.ex` | Provider selection + **fallback to RSS on API error** |
| `lib/pinchflat/http/http_client.ex` | HTTP seam used by the API client (small widening) |
| `lib/pinchflat/settings/setting.ex` | `youtube_api_key` field on settings |
| `lib/pinchflat/sources/source.ex` | Supporting field/association touch for indexing mode |
| `priv/repo/migrations/20240604221531_add_youtube_api_key_setting.exs` | Persist the new setting |
| `lib/pinchflat_web/controllers/settings/setting_html.ex` | Settings view helpers |
| `lib/pinchflat_web/controllers/settings/setting_html/setting_form.html.heex` | API key input |
| `lib/pinchflat_web/controllers/sources/source_html.ex` | Source view helpers |
| `lib/pinchflat_web/controllers/sources/source_html/fast_indexing_help.html.heex` | In-app docs for API vs RSS |
| `lib/pinchflat_web/controllers/sources/source_html/source_form.html.heex` | Source form wording/tie-in |

Supporting / not counted as product logic: `docker-compose.yml` (compose key passthrough).

**Tests — 3** (separate): `fast_indexing_helpers_test.exs` (+53), `youtube_api_test.exs` (+85 new), `youtube_rss_test.exs` (+14).

**Generated / deps:** none in the diff. No lockfile.

**Total files in diff:** 17 = 13 impl + 3 tests + 1 compose.

## Draft minimum ticket

> Fast indexing is unreliable for some channels when it only reads the RSS feed. Let an operator opt into the YouTube Data API for fast indexing by configuring an API key, and keep RSS as the default when no key is set. If the API request fails, indexing must still return results the RSS way. Expose the setting in the UI and document the difference.

(Shortest sufficient form: one sentence + the default/fallback rule.)

## Named deterministic checks

1. **api-used-when-key-configured** — with `youtube_api_key` set, fast indexing requests go through `YoutubeApi` (observable via mocked HTTP / behaviour call).
2. **rss-default-without-key** — with no key, indexing uses RSS exactly as before (preservation).
3. **api-error-falls-back-to-rss** — when `YoutubeApi` raises/returns error, helpers still return the RSS-derived id list (no crash, no empty index).
4. **setting-persisted-and-loaded** — the migration + `Setting` changeset round-trip `youtube_api_key`.
5. **settings-ui-exposes-key** — the settings form includes the API key field (view test / rendered form).
6. **fast-index-help-mentions-api** — help partial describes opt-in API behavior (doc preservation; optional soft check).

## Incomplete that compiles (misses one subsystem)

Ship `YoutubeApi` + `YoutubeBehaviour` + helper switch **without** the settings migration/UI. Compiles and unit-tests for the behaviour pass, but an operator cannot configure the key: fail **setting-persisted-and-loaded** and **settings-ui-exposes-key**.

Alternative incomplete: wire the API always when the module is present (ignore missing key) → fail **rss-default-without-key**.

## Integrity shortcuts

- Unchanged base fails **api-used-when-key-configured** (no API module) and **api-error-falls-back-to-rss**.
- Positive **rss-default-without-key** blocks “always use API / delete RSS” cheats.
- **api-error-falls-back-to-rss** blocks hard-fail on API outage.
- Reference passes all named checks.

## Preservation

- Default remains RSS; no behavior change without an API key.
- Existing fast-indexing helpers tests extended, not replaced — RSS path still green.
- Source form and existing settings rows remain valid.

## Offline holds

| Hold | Notes |
| --- | --- |
| PostgreSQL | Pinchflat uses PG; required for settings/source tests. |
| Network | **No live YouTube calls** — `YoutubeApi` tests must use the HTTP client seam or Bypass/mocks. Keep e2e YouTube fetches out of the graded surface. |
| yt-dlp | Not required for these checks (fast indexing is separate from download). |
| AGPL-3.0 | Preserve license notice in any bundled tree. |

## Cross-component contract

> Provider choice and fallback live in `FastIndexingHelpers`; the behaviour is what `YoutubeApi`/`YoutubeRss` implement; the key is operator-configurable only after the setting + form exist. All four must agree or the feature is unreachable or brittle.

## Next action

Prepare offline PG + Mix tree at base `582eb53698bc1e88d76646dc99f9969876f71364`; mock HTTP for both providers; run the three fast-indexing test files at base/unchanged (fail), reference (pass), incomplete (fail named checks).

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Fast indexing is unreliable for some channels when it only reads the RSS feed. Let an operator opt into the YouTube Data API for fast indexing by configuring an API key, and keep RSS as the default when no key is set. If the API request fails, indexing must still return results the RSS way. Expose the setting in the UI and document the difference.

Bounded feature brief. Default/fallback policy is explicit (good). Three tightenings before this is fair:

- "the YouTube Data API" hides the **playlist transform**. The reference rewrites channel ids `UC…` → `UU…` to query the uploads playlist. That is a product decision, not an implementation detail. Either state it ("use the channel uploads playlist") or accept any API strategy that returns recent video ids for a channel/playlist source. Do not require `UC→UU` in hidden checks.
- "configuring an API key" — the storage key `:youtube_api_key` and the form field name are hidden if checks assert exact strings. Grade "a setting exists, is persisted, and the form exposes it", not the atom name.
- "document the difference" is soft. Either make the help-partial check optional/soft (as the dossier already does) or drop it from scored obligations.

### 2. Deterministic checks

ExUnit + Ecto + **Postgres** (Pinchflat uses PG). **Fakes required:** HTTP client for both providers (the tree already has a `Pinchflat.HTTP.HTTPClient` seam / `Application.get_env(:pinchflat, :http_client, …)`). Use Mox or a test client module. **Never** call YouTube or yt-dlp.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `api-used-when-key-set` | setting has a key; HTTP client fakes an API playlist response | fast indexing call | API client is the one invoked; ids come from API payload |
| `rss-default-without-key` | no key | same | RSS path used; existing RSS behaviour preserved |
| `api-error-falls-back` | API client returns `{:error, _}` or raises | same | RSS-derived ids returned; no crash; not empty-when-RSS-would-succeed |
| `setting-round-trip` | settings changeset / Settings get-put | persisted field | value survives migration + changeset |
| `settings-form-exposes-field` | render settings form | HEEx render | an input for the API key is present |
| `blank-key-disables` | key = `""` or nil | indexing call | RSS used (same as no key) |
| `preservation-rss-path` | existing RSS helpers tests | suite | green |
| `preservation-existing-settings` | existing settings rows/form | suite | green |
| `soft-help-mentions-api` | render help partial | text | mentions API/RSS difference (optional) |

Without `api-error-falls-back`, a hard-fail-on-outage fix passes. Without `rss-default-without-key` + `blank-key-disables`, "always call API" passes. Without `settings-form-exposes-field`, a runner-only patch makes the feature unreachable and still passes backend checks. Without `setting-round-trip`, a form that renders but does not persist passes the UI check alone.

### 3. Ambiguity / unfairness

- **UC→UU playlist rewrite is hidden product** (see ticket). Biggest unfairness risk in this case.
- `YoutubeApi.enabled?/0` and `get_recent_media_ids/1` are the reference behaviour callbacks. The brief must not require those names unless it says "introduce a provider behaviour" and lists them. Prefer: grade through `FastIndexingHelpers` observable ids, and accept any internal split.
- Setting atom `:youtube_api_key` / migration module name / form field name: do not grade exact names. Grade persisted value + rendered input.
- "API request fails" — what counts? HTTP error, decode error, empty `items`? Reference treats `{:error, reason}` and falls back; empty items returns `{:ok, []}` and **does not** fall back. That is a real policy fork. State it: "fall back when the API request errors; an empty successful response is a valid empty result" **or** "fall back on empty too". Do not leave it in tests.
- Exact help-text wording must not be graded.
- `docker-compose.yml` env_file change is mechanical — exclude from graded file counts.

### 4. Shortcuts

- Ship `YoutubeApi` + behaviour + helper switch **without** settings migration/UI → fails `setting-round-trip` and `settings-form-exposes-field`. Correct incomplete.
- Wire API always when the module is present (ignore key) → fails `rss-default-without-key`.
- Ignore errors and return `{:ok, []}` on API failure → fails `api-error-falls-back`.
- Delete RSS entirely → fails preservation and default.
- Form field renders but never saves → fails `setting-round-trip`.
- Setting saves but helpers read a hardcoded env var instead → fails `api-used-when-key-set` if the test sets the setting and expects API.
- UI-only setting with RSS hardcoded → fails `api-used-when-key-set`.

### 5. Flakiness

Low–medium. PG + Ecto sandbox. HTTP is fully fakeable via the existing seam. No yt-dlp in the graded surface. Do not spawn real downloads. Oban jobs in Pinchflat exist elsewhere — keep the graded surface inside the three fast-indexing test files + settings tests. Migration runs once; do not re-run migrations per test.

### 6. Coverage mix

- Positive: API used when key set; RSS default; fallback on error; setting persists; form exposes.
- Negative: no key / blank key → RSS; API error does not crash.
- Preservation: RSS path and existing settings.
- Mixed: one test that sets a key, forces an API error, and still gets RSS ids — the fallback cannot be a silent `{:ok, []}`.

### 7. Environment

- **AGPL-3.0** — preserve notices in any bundled tree.
- **PostgreSQL** required (settings/source tests).
- **Network:** no live YouTube. HTTP must be mocked at the client seam. Keep e2e YouTube/yt-dlp out of the graded surface.
- **Nothing executed.** No apply, no compile, no migration run.
- 13 impl files is large for this project family; see XL note.

### 8. XL-specific

13 impl files is **mostly real coordination** (behaviour + two providers + selection/fallback + setting + migration + form + help) — a solver who stops at the provider layer leaves the feature unreachable. That is genuine cross-layer work, and the outcome is one story. But it **does inflate** at the edges: `source.ex` "supporting touch", two source HTML files, and `docker-compose.yml` are thin. Honest core is ~8–9. Possible split: (a) provider + fallback (~4 files), (b) settings persistence + UI (~5 files). **Split is tempting** because (b) is a generic settings feature; keep as one XL case only if the ticket insists the feature is operator-reachable end-to-end. Otherwise two fair 2–5 cases beat one padded 13.

### 9. Verdict

**READY-WITH-FIX** — authentic product outcome and a real fallback contract, but the UC→UU policy, empty-vs-error fallback, and name-pinning must be settled; consider splitting off the settings/UI slice if you need a tighter 2–5 case instead.

### 10. Must-fix before qualification

1. State playlist/channel handling policy (or explicitly accept any equivalent id source).
2. State empty-success vs error-fallback policy.
3. Do not grade setting atom, migration name, form field name, or help copy.
4. Fake HTTP at the existing client seam; no live YouTube/yt-dlp in graded checks.
5. Incomplete = API+behaviour without settings/UI. Integrity = always-API; ignore errors; blank-as-enabled; form-no-save.
6. AGPL notice; PG; pin base `582eb536…`; run the three fast-indexing files + settings tests only.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Hidden UC→UU / empty-vs-error product policy; UI+backend must both be graded |
