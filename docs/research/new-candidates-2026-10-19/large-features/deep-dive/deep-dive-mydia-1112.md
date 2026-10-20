# Deep-dive dossier — Mydia #1112 disable library indexers without removing them

**Case-prep status:** deep-inspected 2026-10-19/20 (API + full pull/N.diff + git clone + patch-apply at both candidate bases + later-commit audit; mydia mix not run — Elixir ~> 1.20 unavailable).
**Verdict:** strong large-feature candidate. **Base-SHA correction required** (see §1). Patch applies cleanly at the merge first-parent. Later commits extend the new module but do not change the membership/enabled contract.

---

## 1. Identity (corrected)

| Field | Value |
| --- | --- |
| Repo | [getmydia/mydia](https://github.com/getmydia/mydia) |
| PR | [#1112 feat(indexers): disable library indexers without removing them](https://github.com/getmydia/mydia/pull/1112) |
| Discussion | [#1100](https://github.com/getmydia/mydia/discussions/1100) — Cardigann Indexers Status |
| Diff | https://github.com/getmydia/mydia/pull/1112.diff (1132 lines) |
| Author | arsfeld (owner/maintainer) |
| PR body | Substantial (explains `enabled` doing two jobs; split into `in_library` + `enabled`; migration backfill; Remove keeps config; search still filters on `enabled`) |
| Created / Merged | 2026-10-11T15:22:47Z / 2026-10-11T16:15:22Z |
| Head SHA | `14c908930ca6a908462f597087a426839127e8b5` (`worktree-cardigann-indexer-disable-toggle`) |
| **Base SHA (merge first-parent)** | **`23916b76da3b6358a5fbedee12ceaf1700efa11e`** — confirmed: `git rev-parse 45b1be8^1` == `23916b76` |
| API `base.sha` | `b928ffb39f00385f56e56ddf794fe251cf9d461c` — **earlier ancestor** (PR opened against this; merge landed on `23916b76`). Both are valid for `git apply` (see experiments) but **reconstruction parent is the first-parent `23916b76`**. |
| Merge commit | `45b1be8d7ae7d2925032234f10747902038a094f` (parents = `23916b76` + `14c90893`) |
| Size | 8 commits, +477 / −150, **19 changed files** (API) — matches `pull/1112.diff` |
| License | **AGPL-3.0** |
| Elixir requirement at base | `~> 1.20` |

**Correction vs short dossier:** dossier recorded `23916b76…` as base — that is **correct as the merge first-parent**. The GitHub API `base.sha` is `b928ffb3…` (a different, earlier commit). Both SHAs exist and the patch applies cleanly at **both**. Use `23916b76` for reconstruction (it is the tree the merge was actually built on). Record the API-vs-first-parent distinction so future runs do not "correct" the dossier the wrong way.

---

## 2. Limit-testing story

A clear product decision from discussion #1100: switching an indexer off used to **remove it from the page**, so there was no way to pause one. The PR splits one overloaded boolean into two orthogonal concepts that must stay consistent:

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

---

## 3. File inventory with roles (verified against `pull/1112.diff`)

Counts: **19 files total** (API `changed_files: 19`). Implementation = 9 substantive + 1 migration. Tests = 8 + 1 fixtures file. Matches short dossier's “8–10 substantive”.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/mydia/indexers/cardigann_definition.ex` | New `field :in_library, :boolean, default: false`; `membership_changeset/2`; `validate_enabled_in_library/1`; `toggle_changeset/2` gains the same guard. |
| `lib/mydia/indexers/cardigann_library.ex` | **NEW module**: `add/1`, `remove/1`, `enable/1`, `disable/1`, `set_membership/2`, `set_enabled/2`. |
| `lib/mydia/indexers.ex` | Query filters (`apply_cardigann_filters` gains `:in_library`); listing by membership vs enabled. |
| `lib/mydia/indexers/definition_sync.ex` | Sync path updated for membership vs enabled. |
| `priv/repo/migrations/20261011110156_add_in_library_to_cardigann_definitions.exs` | Add column; **backfill `in_library = enabled`**; reversible (`remove :in_library` in `down`). |
| `lib/mydia_web/live/admin_indexers_live/index.ex` + `index.html.heex` | Indexers page: list all members, dim disabled, Remove action, toggle semantics. |
| `lib/mydia_web/live/admin_indexers_live/components.ex` | Shared admin components (badges, rows). |
| `lib/mydia_web/live/admin_indexers_live/library_browser_components.ex` | Library browser: Added / Not added toggle + filter. |
| `lib/mydia/logger.ex` | Operation messages (e.g. `remove_library_indexer`). |

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

---

## 4. Ticket / brief (draft clarified feature brief)

> Turning an indexer off currently removes it from the Indexers page, so I cannot pause one. Split “added to my library” from “enabled for searches”. A disabled indexer must stay listed (clearly marked disabled) and keep its config and credentials. Removing an indexer takes it off the page but keeps its settings so I can add it back later. Searches and health checks must ignore disabled indexers. On upgrade, existing indexers must keep their current membership and enabled state. Expose add/remove and enable/disable in the admin Indexers page and the library browser (Added / Not added).

Do **not** name `in_library`, `CardigannLibrary`, migration names, or file paths in the solver ticket. The two concepts (“added to my library” vs “used in searches”) are the product language and stay visible.

---

## 5. Key implementation snippets (quoted from `pull/1112.diff`)

### Changeset invariant (`cardigann_definition.ex`)

```elixir
def membership_changeset(definition, attrs) do
  definition
  |> cast(attrs, [:in_library, :enabled])
  |> validate_required([:in_library, :enabled])
  |> validate_enabled_in_library()
end

defp validate_enabled_in_library(changeset) do
  if get_field(changeset, :enabled) == true and get_field(changeset, :in_library) != true do
    add_error(changeset, :enabled, "add the i...")  # "add the indexer to your library first"
  ...
```

`toggle_changeset/2` also pipes through `validate_enabled_in_library/1`, so enabling a non-member is rejected at both entry points.

### Membership operations (`cardigann_library.ex`, NEW)

```elixir
@spec add(CardigannDefinition.t()) :: result()
def add(%CardigannDefinition{} = definition), do: set_membership(definition, true)

@spec remove(CardigannDefinition.t()) :: result()
def remove(%CardigannDefinition{} = definition), do: set_membership(definition, false)

@spec enable(CardigannDefinition.t()) :: result()
def enable(%CardigannDefinition{} = definition), do: set_enabled(definition, true)

@spec disable(CardigannDefinition.t()) :: result()
def disable(%CardigannDefinition{} = definition), do: set_enabled(definition, false)

defp set_membership(definition, member?) do
  definition
  |> CardigannDefinition.membership_changeset(%{in_library: member?, enabled: member?})
  |> Repo.update()
end
```

Note `set_membership` sets **both** flags together on add/remove — add enables, remove disables — which is the A4 contract.

### Migration backfill

```elixir
def up do
  alter table(:cardigann_definitions) do
    add :in_library, :boolean, null: false, default: false
  end
  execute "UPDATE cardigann_definitions SET in_library = enabled"
end

def down do
  alter table(:cardigann_definitions) do
    remove :in_library
  end
end
```

---

## 6. Named acceptance checks ↔ upstream tests

| ID | Observable obligation | Upstream test name(s) |
| --- | --- | --- |
| A1 | **Disable keeps listing:** toggling off leaves the indexer on the page, marked disabled. | `"switching an indexer off keeps it listed"`, `"disable keeps a definition in the library"` |
| A2 | **Disable hides from search:** disabled indexer excluded from search/health/enabled listing. | `"a disabled member is left out of the enabled listing searches use"` |
| A3 | **Remove keeps config:** Remove drops it from the page but preserves config/credentials; add-back restores them. | `"remove takes it out of the library and keeps its config"`, `"Remove takes an indexer off the page"` |
| A4 | **Add sets membership and enable:** add puts it in the library and enables it. | `"add puts a definition in the library and enables it"` |
| A5 | **Invariant:** cannot be enabled without being in the library. | `"refuses an enabled definition outside the library"`, `"refuses enabled without in_library"`, `"enable refuses a definition outside the library"` |
| A6 | **Migration:** pre-existing rows get `in_library` matching old `enabled`. | `"an enabled definition starts in the library, a disabled one does not"` (migration test file) |
| A7 | **Library browser:** Added / Not added filter and toggle; disabled members still discoverable as added. | `"filters by whether an indexer is added"`, `"adds an indexer from the library"`, `"does not list definitions that were never added"` |
| A8 | **Preservation:** download/search pipelines that filter on enabled still work for enabled members. | `"keeps the config warning on an added but disabled private indexer"`, download-grab / queue-cookie tests |

Additional: `"toggle_changeset returns an invalid changeset for enabled: nil"`, `"membership_changeset returns an invalid changeset for in_library: nil"`, `"sets both flags"`, `"switching a disabled indexer back on enables it"`.

---

## 7. Incomplete control (compiling partial)

**Partial A — `in_library` + migration + Indexers-page listing, but search queries still using only `enabled` as membership** (or still treating `enabled` as membership).

- A1 may pass; **A2** fails (disabled indexer still searched) or **A5** fails (enabled without membership).
- Named failure: `"a disabled member is left out of the enabled listing searches use"`.

**Partial B — UI toggle only flips `enabled` and still deletes/hides the row when “off”.**

- **A1** fails: `"switching an indexer off keeps it listed"`.

Both partials compile: the field and module exist; the missed consumer is a query filter or a LiveView render path.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Represent “disabled” by deleting the row or hiding it from the Indexers page (the bug being fixed).
- Wipe config/credentials on Remove (A3).
- Let `enabled: true` exist without `in_library: true`.
- Keep old “was disabled, undo” disappear-banner behaviour as the primary UX.
- Break migration reversibility or leave `in_library` null/false for previously-enabled rows.

---

## 9. Preservation of existing behavior

- Existing enabled indexers continue to participate in searches and downloads.
- Cardigann download resolution and queue cookie scope tests stay green.
- Migration up/down is reversible; fixtures still build.

---

## 10. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| **SQLite** (ecto_sqlite3) | Migration is a simple boolean add + backfill — verify test migrator. |
| No live indexer network | Cardigann adapter tests are local; no Jackett/prowlarr network required. |
| LiveView admin tests | LiveViewTest only. |
| **Elixir `~> 1.20`** | **Not available** in this environment (Docker is 1.17). `mix test` **NOT run** for Mydia. |
| **AGPL-3.0** | Provenance notice. |

---

## 11. Later-fix audit (after merge `45b1be8`)

Searched `git log 45b1be8..origin/master -- <file>` after deepen. Later commits **do** touch these files, but none change the membership/enabled contract:

| SHA | Date | What | Relevance |
| --- | --- | --- | --- |
| `139edb5fc` | 2026-10-11 | `refactor(indexers): move config save and removal into CardigannLibrary` | **Extends** `CardigannLibrary` with `configure/2` and session invalidation on `remove`. `remove/1` still calls `set_membership(definition, false)` — the A3 contract is preserved. Not a fix to #1112 semantics. |
| `e9742d72f` | 2026-10-11 | `feat(indexers): detect dropped Cardigann sessions and mark needs_login` | Adds `"needs_login"` to `@health_statuses` on `cardigann_definition.ex`. Orthogonal to `in_library`/`enabled`. |
| `cc4b2b4d3`, `7fd0f1e9d`, `58ad62a6a`, … | later | indexers.ex refactors / telemetry / engine switcher | Touch `indexers.ex` and admin LiveView but do not change the membership filter semantics. |

`git log -S "in_library"` on `45b1be8..origin/master` timed out in this environment; the targeted file-log above is the evidence used. **No reference-bug fix to the #1112 contract was found.** The later `configure/2` work is additive.

---

## 12. Experiment log

| # | Experiment | Command / method | Result |
| --- | --- | --- | --- |
| E1 | Fetch `pull/1112.diff` | `curl` in WSL | **OK** — 1132 lines, 19 files. Matches API `changed_files: 19`. |
| E2 | API metadata | `GET /repos/getmydia/mydia/pulls/1112` | **OK** — `base.sha` `b928ffb3…`, head `14c90893…`, merge `45b1be8…`, 8 commits, 19 files, +477/−150. |
| E3 | Reconstruct merge first-parent | `git rev-parse 45b1be8^1` | **OK** — first parent == `23916b76…` (dossier SHA). API base `b928ffb3…` is a **different, earlier** commit (ancestor of `23916b76`). **Correction recorded.** |
| E4a | Patch apply at first-parent `23916b76` | `git apply --check && git apply` | **CLEAN / SUCCESS** (19 files, +477/−150). |
| E4b | Patch apply at API base `b928ffb3` | `git apply --check && git apply` (after `git clean -fd`) | **CLEAN / SUCCESS** — also applies. First attempt failed only because leftover untracked files from E4a were present; `git clean -fd` fixed it. |
| E5 | Later commits | `git log 45b1be8..origin/master -- <files>` | `139edb5fc` (CardigannLibrary refactor, additive), `e9742d72f` (needs_login status), many indexers.ex refactors. **No contract bugfix.** |
| E6 | `mix test` | Docker `elixir:1.17-otp-27` | **NOT RUN** — Elixir `~> 1.20` required. |
| E7 | Inventory vs short dossier | Count `diff --git` | **Matches** — 19 files; 8–10 substantive impl is fair. |

---

## 13. Challenge the reference

### Incomplete that compiles
Partial A (listing without search filter) compiles — `apply_cardigann_filters` simply never passes `:in_library`. Fails A2 / A5.

Partial B (toggle still hides) compiles — the LiveView render filter is wrong. Fails A1.

### Shortcut risks
- A solver could implement `in_library` but leave `enabled` as the sole membership flag in queries → A2 catches it.
- A solver could make Remove a hard delete → A3 catches it ("keeps its config").
- A solver could allow `enabled: true, in_library: false` by skipping the changeset guard → A5 catches it.

### Flaky risks
- Migration backfill test depends on the test migrator actually running `execute "UPDATE …"`. If the sandbox uses `mix ecto.migrate` vs manual schema load, this could diverge. Pin the migrator strategy in the fixture setup.
- LiveView tests are deterministic (render/click).

### Contract fairness
- A6 (migration backfill) is the easiest to get unfair if the test DB is built from `mix ecto.create + migrate` vs `structure.sql` load. State the migration expectation in the brief ("on upgrade, existing indexers must keep their current membership and enabled state") — already there.
- The two-concept language ("added" vs "enabled") is product language from the discussion; keep it visible.

---

## 14. Curator record

```yaml
case_id: mydia-1112-disable-indexers
project: getmydia/mydia
pr_url: https://github.com/getmydia/mydia/pull/1112
discussion_url: https://github.com/getmydia/mydia/discussions/1100
base_sha: 23916b76da3b6358a5fbedee12ceaf1700efa11e   # merge first-parent (reconstruction)
api_base_sha: b928ffb39f00385f56e56ddf794fe251cf9d461c  # PR open base (ancestor)
merge_sha: 45b1be8d7ae7d2925032234f10747902038a094f
head_sha: 14c908930ca6a908462f597087a426839127e8b5
merged_at: 2026-10-11T16:15:22Z
source_type: historical_merged_pr
task_kind: bounded_feature
family: status_flag_split_admin_ui_search_filters
brief_kind: clarified_implementation_brief
impl_files_substantive: 8-10
test_files: 9
total_files: 19
license: AGPL-3.0
elixir: "~> 1.20"
offline: true
db_required: true
db: sqlite (ecto_sqlite3)
patch_apply: clean_at_first_parent_and_api_base
mix_tests_run: false
mix_tests_blocked_reason: "Elixir ~> 1.20 required; Docker image is 1.17-otp-27"
later_commits_same_files:
  - sha: 139edb5fc
    note: "CardigannLibrary.configure/2 + session invalidate on remove; additive, preserves A3"
  - sha: e9742d72f
    note: "needs_login health status; orthogonal to in_library/enabled"
later_fix_audit: no_contract_bugfix
pr_body_empty: false
difficulty_hint: high
scope_risk: multi_consumer_consistency_trap
```

---

## 15. Next action

1. Prepare a Mydia runtime image with Elixir ~> 1.20 + SQLite; confirm `mix test` at base `23916b76` offline.
2. Freeze brief with the two user-facing concepts named (added vs enabled) and no internal symbols.
3. Controls: incomplete = listing-only without search filter (Partial A); integrity = enable-without-membership or Remove-wipes-config.
4. Qualify after (or with) Mydia #1119 once SQLite/deps are cached once per project.

---

## Grilling (2026-10-19)

### Minimum ticket
Better than #1119's brief — product language ("added to my library" vs "used in searches") is visible and internal names are hidden. Still slightly over-specified: the last sentence about the library browser (Added / Not added) can be shortened to "expose add/remove and enable/disable wherever indexers are managed". Keep the upgrade/backfill sentence; it is an essential product rule, not a hint.

### Named deterministic checks
A1–A8 are real and map to named upstream tests. Strong. Weak spot: A6 (migration backfill) is a migration-test concern that can silently not run if the test schema is loaded via structure dump instead of `mix ecto.migrate`. That is a grading trap, not a product trap — pin the migrator strategy in fixture setup and prove the migration test file actually executes. A8's "keeps the config warning on an added but disabled private indexer" is oddly specific; if it is the only A8 evidence it is thin. Add a plain "enabled indexer still participates in search" positive.

### Ambiguity / unfairness
- "On upgrade, existing indexers must keep their current membership and enabled state" is fair and visible. Good.
- The invariant "cannot be enabled without being in the library" is a product rule that solvers might implement as a soft UI disable instead of a changeset reject. Both are defensible unless the brief demands rejection. The brief does not demand it. Either state "enabling a non-member must be rejected, not silently ignored" or accept both and grade accordingly. Right now A5 will fail a reasonable soft-UI solution unfairly.
- Remove keeps config/credentials is clear. Do not grade exact flash text.
- Discussion #1100 is the source of the product decision; if any hidden check imports a later UI rename from `139edb5fc` (configure/2), that is out of scope. The later-commit audit correctly marks that additive — keep it out.

### Shortcuts + compiling incomplete
Partial A (listing without search filter) and Partial B (toggle still hides) are compiling and have named failures. Good. Under-weighted shortcut: implement `in_library` but leave search using `enabled` **or** `in_library` OR-ed (so disabled members still match). A2 must assert disabled members are absent from the enabled listing *and* from an actual search path, not just one query. Another shortcut: Remove does a soft-delete that keeps the row but filters it out of every list — A3 "keeps its config" must be verified by reading config after remove, not by absence from the page.

### Flakiness
Migration backfill test is the flake/divergence point (test migrator vs structure load). LiveView tests are deterministic. Cardigann adapter tests are local. Pin the migrator and this is low-flake.

### Preservation
Download-grab and queue-cookie tests are good witnesses. Still need a positive "ordinary search finds an enabled indexer" named test so a solver who filters everyone out of search cannot pass by making A2 vacuously true (nothing searched = nothing disabled searched).

### Env
**Same blocker as #1119.** Elixir `~> 1.20` never available; `mix test` never run. Dual-DB SQLite adapter mention is unverified. AGPL-3.0 provenance required.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. Later `CardigannLibrary.configure/2` (139edb5fc) is additive and must stay out of the reference tree and the brief.

### Verdict
**HOLD** — env never executed; A5 contract (reject vs soft-ignore) is under-specified for grading.

### Must-fix before qualification
1. Elixir ~> 1.20 image + full `mix test` green at base `23916b76` and base+patch, offline.
2. Decide and state in the brief: enabling a non-member is **rejected** (or explicitly accept soft-ignore and drop A5's hard reject). Do not leave it to hidden checks.
3. Strengthen A2 to cover an actual search path, not only the "enabled listing" query.
4. Add named positive search preservation ("enabled indexer is found").
5. Pin test migrator strategy so A6 actually executes.
