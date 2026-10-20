# changelog.com #201 — JSON Feed endpoint for news

**Status:** discovered  
**Source type:** historical PR (fixes upstream issue #196)  
**Project:** [thechangelog/changelog.com](https://github.com/thechangelog/changelog.com)  
**PR:** [#201](https://github.com/thechangelog/changelog.com/pull/201) — *fixes #196: expose a json feed endpoint*  
**Author:** (upstream) · **Merged:** 2018-03-05  
**Task kind / family:** feature / feed serialization + routing  
**Research date:** 2026-10-19  
**License:** MIT (code); content/design copyright Changelog Media LLC

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `1d7a8eba21c7c622cfcf22458c5a9c7b43bb5547` | **1 parent** (squash-merge despite repo default MERGE) |
| First-parent / squash parent (base) | `4f53b9da20b9a5bad57eac62d1d586919308bcd5` | Sole parent on commit page — **task base** (PR API `base` was `0ce2bf74…`; master moved) |

Reconstruct at **`4f53b9da…`** and apply `pull/201.diff`.

## Why it is a good case

Upstream issue #196 asked for a [JSON Feed](https://jsonfeed.org) of Changelog news alongside the existing XML feeds. The PR adds `JsonFeedController` + `JsonFeedView` (header + per-item maps for nil object / Episode / Post), a `:json_feed` router pipeline and `GET /feed.json`, extracts `NewsItem.latest_news_items/0` so XML and JSON share one query, adds `TimeView.rfc3339/1` for date formatting, and ships controller/view tests. Coordinated across query, routing, serialization and cache pipeline.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/changelog_web/controllers/json_feed_controller.ex` | New action; `application/json` + `PlugEtsCache` |
| `lib/changelog_web/views/json_feed_view.ex` | JSON Feed 1.0 header + `news_item.json` for nil / Episode / Post |
| `lib/changelog_web/views/time_view.ex` | `rfc3339/1` (nil-safe) for `date_published` |
| `lib/changelog_web/router.ex` | `:json_feed` pipeline + `get "/feed.json"` |
| `lib/changelog_web/controllers/feed_controller.ex` | Reuse `NewsItem.latest_news_items` (remove private `get_news_items/0`) |
| `lib/changelog/data/news/news_item.ex` | `latest_news_items/0` (published, newest, preload, limit 50, `load_object`) |
| `lib/changelog/data/factory.ex` | Test factories (`bytes`, story helpers) |
| `test/changelog_web/controllers/json_feed_controller_test.exs` | Route / payload tests |
| `test/changelog_web/views/json_feed_view_test.exs` | Item mapping tests |
| `test/changelog_web/views/time_view_test.exs` | RFC3339 tests |
| `test/changelog_web/controllers/feed_controller_test.exs` | XML feed still works (preservation) |

**Counts:** 6 substantive implementation files + 4 test files. Feature with a shared query boundary.

## Cross-component behavior to verify

- `GET /feed.json` returns JSON Feed 1.0 (`version`, `title`, `home_page_url`, `items`).
- Each news item maps by object kind: plain news (no object), Episode-backed (podcast + numbered title), Post-backed (post URL).
- `date_published` is RFC3339 or omitted when `published_at` is nil.
- Existing XML news feeds still render the same items (shared `latest_news_items`).
- Response is cached like the XML feeds.

## Draft ticket (shortest sufficient)

> Expose the latest news as a JSON Feed (jsonfeed.org version 1) at `/feed.json`, alongside the existing XML feeds. Include the same latest published news items the XML feed uses, with title, URL, publication time, author, and HTML/text content. Episode-backed and post-backed items should carry the right canonical URLs. Keep the XML feeds unchanged.

Clarified implementation brief (JSON Feed 1.0 + route + shared item set). Does not name controllers or view modules.

## Proposed named acceptance checks

1. `json-feed route-and-header` — `GET /feed.json` is 200 JSON with Feed 1.0 `version` / `title` / `items`.
2. `json-feed maps-episode-item` — episode-backed news includes podcast/episode URL fields.
3. `json-feed maps-post-item` — post-backed news includes post URL.
4. `json-feed maps-plain-item` — items with nil object still render title/url/content.
5. `json-feed rfc3339-or-omit` — `date_published` format / nil policy.
6. `xml-feed unchanged` — existing `FeedController` news XML still lists the same latest items (preservation).

Upstream tests cover 1–5; check 6 is a curator preservation addition.

## Plausible incomplete + integrity control

- **Incomplete:** controller + route only; view still raises or returns empty `items` / wrong shapes. Compiling; fails checks 2–3.
- **Integrity:** reject patches that break XML feeds, that omit `content_html`/`content_text`, or that invent a non-JSON-Feed schema.

## Preservation

- `/feed` and `/news/feed` XML endpoints keep current item selection (limit 50, published, newest first).
- `load_object` still attaches Episode/Post for consumers of `latest_news_items`.

## Runtime / offline holds

- MIT (code). PostgreSQL; PlugEtsCache in-process. No external feed service.
- Older Phoenix/Elixir (2018) — pin historical toolchain at `4f53b9da…`; record mix/OTP in the bundle.
- Issue #196 is the product request; PR body aligns.

## Experiments (quick)

- `pull/201.diff` well-formed; 11 paths as listed. Diff parses.
- Squash parent `4f53b9da…` from commit page (`parents:[…]`, “1 parent”). Prefer over PR API `base` `0ce2bf74…`.

## Optional git apply

```
git checkout 4f53b9da20b9a5bad57eac62d1d586919308bcd5
git apply pull/201.diff
```

## Status: discovered

Coordinated multi-file feature with a clear visible contract (JSON Feed 1.0) and strong upstream tests. Adds a feed/serialization family not covered by changelog 339/559/562.

## Next action

Pin `4f53b9da…` → apply `pull/201.diff` → map checks 1–6 → incomplete = route without item mapping → three qualification rounds.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Expose the latest news as a JSON Feed (jsonfeed.org version 1) at `/feed.json`, alongside the existing XML feeds. Use the same latest published news items the XML feed uses. Each item must carry a title, a canonical URL, publication time in RFC3339, and HTML/text content; episode-backed items also carry an audio attachment, post-backed items link to the post. Keep the XML feeds unchanged.

Clarified brief. The JSON Feed 1.0 spec is the visible contract for envelope fields (`version`, `title`, `items`, …). Does not name controllers, views, or helpers.

**Hidden requirements flagged:**
- Draft ticket required **author** on every item. Reference: plain and post items have `author`; **episode items do not**. Either drop "author" from the ticket, or say "author when known", or add author to episode items in the reference. As drafted it over-promises vs the reference.
- Nil `published_at` policy: reference `TimeView.rfc3339(nil)` returns `""`, which is not valid JSON Feed (should omit the key or use null). Say "omit publication time when unknown" and grade that, or accept `""` explicitly. Prefer omit.

### 2. Deterministic checks

Phoenix ConnCase + ExMachina factories (existing style). PlugEtsCache in-process — no external cache. No sleep.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `json-feed route-and-header` | Insert ≥1 published news item | `GET /feed.json` | 200, `content-type` json, body has `version` = jsonfeed 1 URL, `title`, `items` list |
| `json-feed maps-episode-item` | Episode-backed news item | item map | canonical episode URL; audio attachment with url/mime/length |
| `json-feed maps-post-item` | Post-backed news item | item map | post URL |
| `json-feed maps-plain-item` | News item with nil object | item map | title/url/content_html/content_text present |
| `json-feed rfc3339-or-omit` | Item with published_at set; item with nil | `date_published` | RFC3339 string when set; **omitted** when nil (or documented alternative) |
| `xml-feed unchanged` | Same fixtures as JSON test | `GET /feed` (news XML) | still 200 and still lists the same items (preservation) |
| `json-feed same-item-set` | Mixed published + unpublished + old items | both feeds | JSON and XML select the same latest published set (shared query) |

Fake provider: none. PostgreSQL only.

### 3. Ambiguity / unfairness

- Exact JSON key casing is forced by the JSON Feed spec (`content_html`, `date_published`, `home_page_url`) — fair to grade; the spec is public.
- Field sets per kind (episode vs post vs plain) are the contest. Do not require `author` on episodes unless the ticket says so.
- Title formatting for episodes (`podcast.name <> numbered_title`) is presentation — grade presence of a non-empty title and the canonical URL, not the exact string, unless the ticket states the title shape.
- `description`, `home_page_url`, `attachments[].length` semantics are in the spec / draft brief — `length` as bytes is fine (factory sets `bytes: 42`).
- HTML escaping of titles: reference escapes. Do not grade escape style.

### 4. Shortcuts

- Route + controller return `{"items": []}` always. Fails item mapping checks.
- Copy XML item selection but serialize with `Jason` from a hand-rolled map missing `content_text` or attachments. Fails per-kind checks.
- Break XML feed while adding JSON. Fails `xml-feed unchanged`.
- JSON Feed 0.9 / custom schema (`"feed_version": 1`). Fails header check.
- Implement `/feed.json` as a static fixture. Fails `json-feed same-item-set` with mixed population.

### 5. Flakiness / nondeterminism

Low. PlugEtsCache could cache a previous test's response — clear the ETS cache between tests or use unique paths/hosts per test (the existing FeedController tests seem fine; verify). Timestamps: use factory-inserted `published_at`, not `DateTime.utc_now`, in assertions. `hours_ago` without_microseconds change is incidental.

### 6. Coverage mix

- Positive: each of the three item kinds + envelope.
- Preservation: XML news + titles feeds still work; shared `latest_news_items` selection.
- Mixed population: plain + episode + post + unpublished + stale published in one DB state; assert JSON items match the XML set and exclude unpublished.
- Negative: unpublished and non-latest items absent.

### 7. Environment risk

- **MIT** code; content/design copyright Changelog Media LLC — do not ship content fixtures that copy site content; factories are synthetic.
- PostgreSQL required. PlugEtsCache in-process — offline-safe.
- **2018 Phoenix / older Elixir** — pin historical toolchain at `4f53b9da…` and record mix/OTP in the bundle. This is the biggest practical risk: modern Elixir may not compile the 2018 deps. Prove `mix test test/changelog_web/controllers/json_feed_controller_test.exs` offline before spending qualification rounds.
- No external feed service.

### 8. Verdict

**READY-WITH-FIX** — excellent visible contract (public JSON Feed 1.0) and coordinated query/route/serialization work; author/nil-date policy and the 2018 toolchain must be settled first.

### 9. Must-fix list

1. Align author policy with the reference (drop from ticket, or "author when known", or extend reference).
2. State nil `date_published` policy (prefer omit) and fix `rfc3339(nil)` accordingly or grade the documented alternative.
3. Prove the 2018 toolchain + dep cache offline; record exact Elixir/OTP.
4. Incomplete = route + empty/stub view (compiling), fails per-kind mapping.
5. Mixed-population test that JSON and XML share the item set.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Author/nil-date over-spec vs 2018 toolchain risk |
