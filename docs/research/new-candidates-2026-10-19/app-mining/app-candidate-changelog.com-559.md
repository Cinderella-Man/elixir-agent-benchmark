# app-candidate-changelog.com-559

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/thechangelog/changelog.com/pull/559 |
| Title | Make episode publish idempotent |
| Project | thechangelog/changelog.com |
| Source type | Historical merged PR (bug fix + bounded publish contract) |
| PR head SHA | `9ac86216afc3f876ec3661e15157e5c41ad05927` (last of 2 commits) |
| First commit | `fe274ccdce515f80cafe23ba5dccdc7a48ae099f` |
| Parent of first commit (likely base) | `7c8d9fff2ad0598e9a064a8a7347e0828e8f5d1b` |
| Merged at | 2026-09-04T15:42:16Z |
| License | Custom: content/design © Changelog Media LLC; code under MIT-style permission (see repo `LICENSE`). Non-standard text — preserve notice. |
| Elixir | `~> 1.18` (from mix.exs at head) |
| Verification | **Unverified** — HTML/PR/diff inspected; tests not executed |

## Why it is a case

Publishing an episode creates/reconciles an episode-backed news item, a news queue entry, first-transition notes, search refresh, and guest thanks. Duplicate publish attempts (double-submit, concurrent admin writers, feed-only retry) used to insert a second `news_items` row and blew up episode pages with `Ecto.MultipleResultsError`.

What must stay consistent:

- Canonical episode-backed news item selection (`earliest inserted_at`, then `id`) vs. blind insert.
- Queue append-once behavior vs. re-publish / unpublish+republish / feed-only retry.
- Visibility policy: a later feed-only retry must not demote an existing non-feed-only item.
- Transaction boundary: durable publish state rolls back if first-transition notes cannot queue; search refresh and guest thanks run only after commit.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/changelog/schema/news/episode_news_item.ex` | Insert/reconcile/update/delete of canonical episode news item; result tuples; post-commit `refresh_search` |
| `lib/changelog/schema/news/news_queue.ex` | `append_once/1` deduped queue append |
| `lib/changelog/schema/episode/episode.ex` | `get_news_item` returns canonical item instead of crashing on duplicates |
| `lib/changelog_web/controllers/admin/episode_controller.ex` | Publish/unpublish/re-publish orchestration, side-effect ordering, edge cases |
| `lib/changelog_web/templates/admin/episode/_form.html.heex` | Admin publish UI affordances (supporting) |
| `lib/mix/tasks/news/feed_only.ex` | Feed-only writer aligned with reconcile path (supporting) |

Tests (separate count): `episode_test.exs`, `episode_news_item_test.exs`, `news_queue_test.exs`, `admin/episode_controller_test.exs` (+ `config/test.exs`).

## Draft ticket

> Publishing the same episode twice creates duplicate news items and the episode page crashes with a multiple-results error. Make episode publishing idempotent so repeated or concurrent publish attempts converge on one episode-backed news item and one queue entry, without demoting a non-feed-only item when a later feed-only publish is retried. Fix it.

(Short maintenance report; do not name files, locks, or the canonical-item policy.)

## Named acceptance checks

1. **canonical-on-duplicates** — `Episode.load_news_item` / `get_news_item` returns one canonical item when two episode-backed `news_items` already exist (does not raise).
2. **reconcile-not-insert** — publishing an episode that already has a news item does not create a second `news_items` row.
3. **queue-once** — re-publish does not append a second queue entry for the same item; unpublish+republish reuses the queue entry.
4. **feed-only-no-demotion** — feed-only retry leaves an existing non-feed-only canonical item visible as non-feed-only.
5. **rollback-on-notes-failure** — if first-transition notes cannot queue, publish rolls back and does not run search refresh or guest thanks.
6. **concurrent-converge** — concurrent publish attempts (or feed-only racing admin publish) end with one news item and one queue entry.

## Incomplete + integrity control

- **Incomplete (compiling):** add `append_once` and reconcile on one path (e.g. admin re-publish only) but leave `insert_published_feed_only_once` or the unpublish path still inserting a second row. Expect fail on **reconcile-not-insert** or **queue-once** for the untouched path; other paths pass.
- **Integrity:** unchanged tree must still fail at least **reconcile-not-insert** / **concurrent-converge**; reference must pass all six. Preservation checks below must pass on reference and unchanged.

## Preservation

- First publish of a new episode still creates exactly one news item and one queue entry.
- Unpublish still removes/hides the published item; guest thanks and search refresh still run for a successful first publish (positive examples, not only rejection).
- Non-feed-only visibility is preserved across a later feed-only write.

## Runtime / offline holds

- PostgreSQL (Ecto) required — supported by existing runner service handling.
- No S3/YouTube required for these checks.
- Search refresh / guest thanks must be stubbed or asserted as side-effect ordering (Algolia not required if checks observe calls or DB state only).
- **Hold (if any check needs real mail/search/network).** Offline fixtures feasible with DB + controller tests already in tree.

## Status

**discovered** — coherent multi-file publish contract with strong named tests already in the PR (including concurrent and rollback cases). Not yet executed at the pinned SHA.

## Next action

Pin base `7c8d9fff2ad0598e9a064a8a7347e0828e8f5d1b` (confirm parent is merge-base), run focused tests unchanged/reference/incomplete, then freeze ticket wording above.
