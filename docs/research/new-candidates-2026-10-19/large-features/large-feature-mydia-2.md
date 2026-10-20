# Large feature — Mydia #1112 disable library indexers without removing them

**Status:** discovered
**Source type:** historical merged PR (closes discussion #1100)
**Project:** [getmydia/mydia](https://github.com/getmydia/mydia) — personal media companion
**PR:** [#1112](https://github.com/getmydia/mydia/pull/1112) — feat(indexers): disable library indexers without removing them
**Discussion:** [#1100](https://github.com/getmydia/mydia/discussions/1100) — Cardigann Indexers Status
**Author:** arsfeld · **Created:** 2026-10-11 · **Merged/closed:** 2026-10-11
**Source revisions:** base (merge first parent) `23916b76da3b6358a5fbedee12ceaf1700efa11e` → merge `45b1be8d7ae7d2925032234f10747902038a094f` (head `14c908930ca6a908462f597087a426839127e8b5`, 8 commits)
**Task kind / family:** bounded feature / status-flag split + admin UI + search membership filters
**Research date:** 2026-10-19
**License:** AGPL-3.0

---

## Why it is a LIMIT-TESTING case

A clear product decision from the discussion: switching an indexer off used to **remove it from the page**, so there was no way to pause one. The PR splits one overloaded boolean into two orthogonal concepts that must stay consistent:

- **`in_library`** — “added to my indexers” (membership / listed on the Indexers page).
- **`enabled`** — “used in searches / health checks”.

The hard coordination is not the migration; it is keeping **every consumer of the old meaning** correct:

1. Changesets must reject `enabled: true` without `in_library: true` (and reject nils).
2. Migration sets `in_library` from existing `enabled` so nothing moves on upgrade.
3. Indexers page lists **all library members**, including disabled ones (dimmed + “Disabled” badge).
4. Toggle only enables/disables; **Remove** takes it off the page but **keeps config and credentials** so re-add restores them.
5. Search / health / search-page still filter on `enabled` — a disabled indexer must stay out of searches while remaining listed.
6. Library browser toggle becomes Added / Not added with a matching filter; the old “was disabled, undo” banner goes away because nothing disappears.

A solver who only adds the field and updates the toggle will leave searches including disabled indexers (or listing never-added ones). That is a multi-component consistency trap.

## File inventory with roles

From `pull/1112.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/mydia/indexers/cardigann_definition.ex` | New `field :in_library, :boolean, default: false`; `membership_changeset/2`; `validate_enabled_in_library/1`. |
| `lib/mydia/indexers/cardigann_library.ex` | **New** module: `add/1`, `remove/1`, `enable/1`, `disable/1`, `set_membership/2`, `set_enabled/2`. |
| `lib/mydia/indexers.ex` | Query filters (`apply_cardigann_filters` gains `:in_library`); listing by membership vs enabled. |
| `lib/mydia/indexers/definition_sync.ex` | Sync path updated for membership vs enabled. |
| `priv/repo/migrations/20261011110156_add_in_library_to_cardigann_definitions.exs` | Add column; **backfill `in_library = enabled`**; reversible. |
| `lib/mydia_web/live/admin_indexers_live/index.ex` + `index.html.heex` | Indexers page: list all members, dim disabled, Remove action, toggle semantics. |
| `lib/mydia_web/live/admin_indexers_live/components.ex` | Shared admin components (badges, rows). |
| `lib/mydia_web/live/admin_indexers_live/library_browser_components.ex` | Library browser: Added / Not added toggle + filter. |
| `lib/mydia/logger.ex` | Operation messages (e.g. remove_library_indexer). |

**Counts:** ~8–10 substantive implementation files (schema, library module, queries, migration, admin LiveView family). Tests separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/mydia/indexers/cardigann_definition_test.exs` | Changeset: refuses enabled outside library; refuses nils; sets both flags. |
| `test/mydia/indexers/cardigann_membership_test.exs` | Membership module: add/remove/enable/disable; enable refuses non-member. |
| `test/mydia/indexers/adapter/cardigann_test.exs` | Adapter-level listing/filters. |
| `test/mydia/indexers/cardigann_download_resolution_test.exs` | Download resolution still respects enabled. |
| `test/mydia_web/live/admin_indexers_live/indexer_library_test.exs` | UI: switching off keeps it listed; Remove takes it off; disabled left out of enabled listing; filter by added. |
| `test/mydia/downloads/cardigann_download_grab_test.exs`, `queue_cookie_scope_test.exs` | Downstream consumers keep working. |
| `test/mydia/repo/migrations/add_in_library_to_cardigann_definitions_test.exs` | Migration backfill behaviour. |
| `test/support/fixtures/indexers_fixtures.ex` | Fixtures. |

### Generated / docs

| Path | Note |
| --- | --- |
| — | No lockfile/generated dumps in the core contract. |

## Draft clarified feature brief

> Turning an indexer off currently removes it from the Indexers page, so I cannot pause one. Split “added to my library” from “enabled for searches”. A disabled indexer must stay listed (clearly marked disabled) and keep its config and credentials. Removing an indexer takes it off the page but keeps its settings so I can add it back later. Searches and health checks must ignore disabled indexers. On upgrade, existing indexers must keep their current membership and enabled state. Expose add/remove and enable/disable in the admin Indexers page and the library browser (Added / Not added).

Do **not** name `in_library`, `CardigannLibrary`, migration names, or file paths in the solver ticket. The two concepts (“added to my library” vs “used in searches”) are the product language and stay visible.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Disable keeps listing:** toggling off leaves the indexer on the Indexers page, marked disabled; it is not deleted. |
| A2 | **Disable hides from search:** disabled indexer is excluded from search/health/enabled listing. |
| A3 | **Remove keeps config:** Remove drops it from the page but preserves config/credentials; add-back restores them. |
| A4 | **Add sets membership and enable:** add puts it in the library and enables it. |
| A5 | **Invariant:** cannot be enabled without being in the library (changeset rejects). |
| A6 | **Migration:** pre-existing rows get `in_library` matching their old `enabled` (nothing moves). |
| A7 | **Library browser:** Added / Not added filter and toggle; disabled members still discoverable as added. |
| A8 | **Preservation:** download/search pipelines that filter on enabled still work for enabled members; ordinary add→search→disable→search works. |

## Incomplete control

**Compiling partial that misses one subsystem:** add `in_library` + migration + Indexers-page listing, but leave **search queries still using only `enabled`** (or still treating `enabled` as membership).

- A1 may pass; **A2** fails (disabled indexer still searched) or **A5** fails (enabled without membership).
- Second partial: UI toggle only flips `enabled` and still deletes/hides the row when “off” → **A1** fails.

## Integrity / shortcut rejection

Reject patches that:

- Represent “disabled” by deleting the row or hiding it from the Indexers page (the bug being fixed).
- Wipe config/credentials on Remove (A3).
- Let `enabled: true` exist without `in_library: true`.
- Keep old “was disabled, undo” disappear-banner behaviour as the primary UX.
- Break migration reversibility or leave `in_library` null/false for previously-enabled rows.

## Preservation of existing behavior

- Existing enabled indexers continue to participate in searches and downloads.
- Cardigann download resolution and queue cookie scope tests stay green.
- Migration up/down is reversible; fixtures still build.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| SQLite (ecto_sqlite3) | Migration is a simple boolean add + backfill — verify test migrator. |
| No live indexer network | Cardigann adapter tests are local; no Jackett/prowlarr network required. |
| LiveView admin tests | LiveViewTest only. |
| Elixir `~> 1.20` | Match Mydia toolchain. |
| AGPL-3.0 | Provenance notice. |

Not verified here: compile/test/boot.

## Status: discovered

Strong second Mydia large feature. Distinct task family from #1119 (admin status model vs metadata provider policy) — do not count as duplicate coverage, but both share the same app runtime work.

## Next action

1. Pin base `23916b76da3b6358a5fbedee12ceaf1700efa11e`; confirm offline `mix test`.
2. Freeze brief with the two user-facing concepts named (added vs enabled) and no internal symbols.
3. Controls: incomplete = listing-only without search filter; integrity = enable-without-membership or Remove-wipes-config.
4. Qualify after (or with) Mydia #1119 once SQLite/deps are cached once per project.
