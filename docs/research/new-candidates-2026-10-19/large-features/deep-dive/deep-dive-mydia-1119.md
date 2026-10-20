# Deep-dive dossier — Mydia #1119 per-show TV metadata provider fallback + pin

**Case-prep status:** deep-inspected 2026-10-19/20 (API + full pull/N.diff + git clone + patch-apply + later-commit audit + Docker mix for pinchflat sibling; mydia mix not run — Elixir ~> 1.20 unavailable).
**Verdict:** strong large-feature candidate. Identity SHAs confirmed. Patch applies cleanly at the merge first-parent. No later fix to the policy files (clean window). Limit-testing across five subsystems.

---

## 1. Identity (corrected)

| Field | Value |
| --- | --- |
| Repo | [getmydia/mydia](https://github.com/getmydia/mydia) |
| PR | [#1119 feat: fall back to the other TV metadata provider (TVDB/TMDB) per show](https://github.com/getmydia/mydia/pull/1119) |
| Issue | [#1117](https://github.com/getmydia/mydia/issues/1117) — Fallback metadata providers for TV shows |
| Diff | https://github.com/getmydia/mydia/pull/1119.diff (2650 lines) |
| Author | arsfeld (owner/maintainer) |
| PR body | Substantial (closes #1117; documents pin rule, fallback-on-empty only, no-fallback-on-error, unattended hold, UI toggles, fileless-show exception) |
| Created / Merged | 2026-10-12T01:10:09Z / 2026-10-12T01:58:31Z |
| Head SHA | `8057d437da8dc2f15ebb7a320b9944a9c9dd7897` (`worktree-tv-metadata-provider-fallback`) |
| **Base SHA (merge first-parent)** | **`071360c6c765b4db02337943dd8d9ba6eee47bd6`** — confirmed: `git rev-parse 8902237^1` == `071360c6` |
| Merge commit | `890223727f0701eef9a6ad006e88e30f417fdfa6` (parents = `071360c6` + `8057d437`) |
| Size | 14 commits, +1493 / −522, **30 changed files** (API) — matches `pull/1119.diff` file count |
| License | **AGPL-3.0** (GNU Affero GPL v3 at base; `mydia-LICENSE` in `_work/`) |
| Elixir requirement at base | `~> 1.20` (from `mix.exs` line 54) |

**Dossier SHA check:** short dossier's base `071360c6…` and merge `8902237…` are **correct**. No correction needed.

---

## 2. Limit-testing story (why it stresses multi-subsystem coordination)

One user-facing capability forces a policy rule to stay consistent across **five subsystems**:

1. **Per-show pin state** (`media_items.metadata_source_pinned`) and who sets/clears it (`ProviderSwitch.pin_for/2`).
2. **Importer fallback** (`MetadataMatcher`): search the other provider only on empty results, never on relay errors; hold cross-provider unattended matches for review; still auto-import new episodes of an already-pinned local show.
3. **Refresh/re-identify decision**: pinned shows refetch their own provider; unpinned shows re-identify against the library provider.
4. **Fix Match**: default search provider is the show's stored provider when pinned; switching providers goes through the existing episode-safe switch.
5. **Import “Change match” and Fix Match modals**: TVDB/TMDB toggle only for TV searches; non-library results carry a badge; a fileless show has no library provider so a Fix Match switch does not pin.

A solver who implements only the fallback search, or only the pin boolean, or only one of the two modals, will compile and still fail named checks in another subsystem.

---

## 3. File inventory with roles (verified against `pull/1119.diff`)

Counts: **30 files total**. Implementation ≈ 18 substantive paths + 1 migration + 1 domain README (docs). Tests = 10. This is **above** the guidelines' preferred 2–5, but the short dossier correctly argues the UI files are thin wiring of one policy at each boundary — not ten copies of a string.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/mydia/media/media_item.ex` | Schema field `metadata_source_pinned` (boolean, default false) + typespec + cast. |
| `priv/repo/migrations/20261011231535_add_metadata_source_pinned_to_media_items.exs` | Plain boolean add; up/down for both SQLite adapters. |
| `lib/mydia/media/provider_switch.ex` | `pin_for/2`, `library_provider/1`, `provider_refresh_decision/1` (`:refetch` vs `{:reidentify, …}`). |
| `lib/mydia/media/fix_match.ex` | `provider_for/1` defaults to stored provider for pinned shows; `search/6`, `adopt/6` honour provider override. |
| `lib/mydia/library/metadata_matcher.ex` | `search_external_tv_show_with_fallback/3` — fallback to the other provider on **empty primary result only**. |
| `lib/mydia/library/candidate_promotion.ex` | Promotion stamps the pin when it creates a show on the non-library provider. |
| `lib/mydia/library/match_scoring.ex` | Shared scoring helpers (title/year/popularity) used by both providers. |
| `lib/mydia/library/file_ingest.ex` | Ingest path; `cross_provider_tv?/2` holds unattended cross-provider matches. |
| `lib/mydia/metadata/tv_provider.ex` | Provider parse/label/`other/1`/`for_library` helpers. |
| `lib/mydia_web/live/import_media_live/match_search.ex` | Import “Change match” search state: provider toggle, async search. |
| `lib/mydia_web/live/import_media_live/match_search_modal.ex` | Modal UI: TVDB/TMDB toggle (TV only), badges for non-library results. |
| `lib/mydia_web/live/import_media_live/components.ex` + `index.ex` + `index.html.heex` | Import surface wiring for fallback group warning / toggle. |
| `lib/mydia_web/live/media_live/show.ex` + `show.html.heex` + `show/fix_match_events.ex` + `show/fix_match_modal.ex` + `show/modals.ex` | Fix Match surface: pinned-provider badge, provider toggle, episode-safe switch. |

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/mydia/library/metadata_matcher_fallback_test.exs` | Empty primary → other provider; **relay error does not fallback**; both empty → no match; no provider → no fallback. |
| `test/mydia/media/provider_pin_test.exs` | Pin on create/switch to non-library provider; clear when switched back; unpinned re-identified; pinned re-fetched in place. |
| `test/mydia/media/fix_match_test.exs` | Pinned show searches its own provider; unpinned searches library provider; switch pins / un-pins; movies ignore provider override. |
| `test/mydia/library/candidate_promotion_test.exs` | Cross-provider confident match stays candidate (held for review); local-show match exempt; promotion stamps pin. |
| `test/mydia_web/live/import_media_provider_toggle_test.exs` | Toggle present for TV only; picking TMDB result stamps TMDB; non-library result dropped when tagged wrong. |
| `test/mydia_web/live/media_live/fix_match_test.exs` + `show/fix_match_events_test.exs` | Fix Match toggle/pin UI contract. |
| `test/mydia/library/batch_matcher_test.exs`, `file_ingest_test.exs` | Supporting matcher/ingest behaviour. |
| `test/support/metadata_stub_provider.ex` | **Offline stub provider** — no live TVDB/TMDB required. |

### Generated / docs

| Path | Note |
| --- | --- |
| `lib/mydia/media/README.md` | Domain rules documentation (useful visible source for the brief; not graded as implementation). |

---

## 4. Ticket / brief (draft clarified feature brief)

> A TV show that one metadata provider does not carry should still be matchable when the other provider has it. When the library’s provider returns no match for a show, search the other provider once and use that result. A relay/availability error on the first provider must not trigger the fallback. Once a show lives on the provider its library does not use, keep it on that provider for refresh and Fix Match; switching it back to the library’s provider clears that pin. Under unattended import, a cross-provider TV match is held for review (except new episodes of an already-stored show). Expose a TVDB/TMDB toggle in the import “Change match” and Fix Match UIs for TV searches only. Movies and IMDb are out of scope. Keep existing same-provider matching and unattended import working.

Public names that **are** the product (keep visible): TVDB/TMDB labels, the idea of a per-show pinned provider. Do **not** name `metadata_source_pinned`, `ProviderSwitch`, `pin_for/2`, or file paths in the solver ticket.

---

## 5. Key implementation snippets (quoted from `pull/1119.diff`)

### Fallback-on-empty only (`metadata_matcher.ex`)

```elixir
# A show the library's provider does not carry may still be on the other
# one. Only a clean "nothing found" falls through: a relay error stays an
# error, so an outage on one provider cannot quietly re-match a library onto
# the other. The result keeps its own `provider_type`, and
# `Mydia.Library.FileIngest` refuses to auto-promote a match whose provider
# differs from the library's, so this only ever produces a suggestion.
defp search_external_tv_show_with_fallback(parsed, config, opts) do
  with {:error, :no_matches_found} <- search_external_tv_show(parsed, config, opts),
       other when not is_nil(other) <- TvProvider.other(Keyword.get(opts, :provider)) do
    Logger.debug("No match on library provider, trying the other one",
      title: parsed.title,
      provider: other
    )
    search_external_tv_show(parsed, config, Keyword.put(opts, :provider, other))
  else
    nil -> {:error, :no_matches_found}
    result -> result
  end
end
```

### Pin rule (`provider_switch.ex`)

```elixir
@spec pin_for(atom(), atom() | nil) :: boolean()
def pin_for(provider, library_provider) when library_provider in [:tvdb, :tmdb],
  do: provider != library_provider

def pin_for(_provider, _library_provider), do: false
```

### Refresh honours pin (`provider_switch.ex`)

```elixir
# A pinned show was put on its provider on purpose. Re-identifying it onto
# the library's provider would undo that choice, and for a show the library's
# provider does not carry it would open an empty picker.
def provider_refresh_decision(%MediaItem{
      type: "tv_show",
      metadata_source_pinned: true,
      metadata_source: source
    })
    when source in [:tvdb, :tmdb],
    do: :refetch
```

### Fix Match provider default (`fix_match.ex`)

```elixir
@spec provider_for(MediaItem.t()) :: :tmdb | :tvdb
def provider_for(%MediaItem{type: "movie"}), do: :tmdb

def provider_for(%MediaItem{type: "tv_show", metadata_source_pinned: true} = item),
  do: stored_provider(item)

def provider_for(%MediaItem{id: nil} = item), do: stored_provider(item)
```

### Unattended guard (`file_ingest.ex`)

```elixir
# A show found on the provider its library does not use (MetadataMatcher's
# fallback) waits for a person whatever its score: the library's provider
# may list it under another title, and accepting it pins the show to the
# other provider. A match against a show already in the library is exempt,
# since the operator already accepted that show, pinned or not.
defp cross_provider_tv?(_candidate, %{from_local_db: true}), do: false
```

---

## 6. Named acceptance checks ↔ upstream tests

| ID | Observable obligation | Upstream test name(s) |
| --- | --- | --- |
| A1 | **Fallback-on-empty:** primary provider returns no TV match, secondary has one → import/match uses the secondary result. | `"TVDB empty, TMDB hit: a TMDB match"` |
| A2 | **No-fallback-on-error:** primary relay error → error surfaces; secondary is **not** searched. | `"a TVDB error is returned without trying TMDB"` |
| A3 | **Pin stamp:** show created/switched onto the non-library provider is pinned; switching back clears the pin. | `"a TMDB match in a #{library_provider} library creates a show with pinned=#{pinned?}"`, `"switching onto the non-library provider pins the show"`, `"switching back onto the library provider clears the pin"` |
| A4 | **Refresh honours pin:** pinned show refetches its own provider; unpinned re-identifies. | `"a pinned TMDB show in a TVDB library is re-fetched in place"`, `"an unpinned TMDB show in a TVDB library is re-identified"` |
| A5 | **Fix Match provider default:** pinned show searches its stored provider; unpinned searches the library provider. | `"a pinned show searches its own provider, not the library's"`, `"an unpinned show searches the library's provider"` |
| A6 | **Unattended guard:** cross-provider TV match is held for review; match against existing local show is **not** held. | `"a confident TMDB match in a TVDB library stays a candidate"`, `"a cross-provider match from the local database is not held for review"` |
| A7 | **UI toggles:** import Change-match and Fix Match show a TVDB/TMDB toggle for TV only; picking a non-library result switches+pins; fileless show's Fix Match switch does not pin. | `"a show offers the toggle, a movie does not"`, `"picking a TMDB result switches and pins the show"`, `"a movies library's match modal has no provider toggle"` |
| A8 | **Preservation:** same-provider matches still import unattended; library-wide provider migration still moves **unpinned** shows; movies unchanged. | `"the guard does not touch a same-provider match"`, `"a movie ignores the provider override"` |

Additional upstream tests: `"no provider given: no fallback"`, `"both empty: still no match"`, `"pins only when the provider differs from a known library provider"`, `"a result on the other provider sharing the current id stays pickable"`, `"the matching result on the current provider is disabled"`, `"a result tagged with the other provider is dropped"`.

---

## 7. Incomplete control (compiling partial)

**Partial A — importer fallback + pin field + migration, but `provider_refresh_decision` still re-identifies every show** (or Fix Match always searches the library provider).

- A1 may pass; **A4/A5** fail (pinned show is re-identified / searched on the wrong provider).
- Named failure: `"a pinned TMDB show in a TVDB library is re-fetched in place"`.

**Partial B — implement fallback but always fallback even on relay errors.**

- **A2** fails: `"a TVDB error is returned without trying TMDB"`.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Fall back on **any** primary failure (including relay/timeout errors) — that is the outage re-match bug the issue cares about.
- Set the pin for movies, or for shows already on the library provider.
- Drop the unattended-review guard for cross-provider matches (auto-import a foreign-provider show).
- Disable Fix Match or Change-match entirely as a way to avoid the toggle contract.
- Hard-code “TMDB only” or “TVDB only” instead of honouring library provider.

---

## 9. Preservation of existing behavior

- Same-provider TV matching, scoring (`match_scoring.ex`), and unattended import of ordinary matches.
- Movie matching and import (no provider toggle, no pin).
- Library-wide provider change migrates unpinned shows as before.
- Existing Fix Match episode-safety when switching providers.

---

## 10. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| **SQLite** (ecto_sqlite3) | Migration is a plain boolean add — verify test sandbox applies it on both adapters if dual-DB is in play. |
| **No live TVDB/TMDB** | **Already solved in-tree:** `test/support/metadata_stub_provider.ex` + Bypass-style tests in `metadata_matcher_fallback_test.exs`. Offline holds look favorable. |
| LiveView tests | Standard Phoenix LiveViewTest; no browser required for A1–A8. |
| Oban / Guardian | Present in app; matching/UI tests should not need live workers if jobs are invoked directly. |
| **Elixir `~> 1.20`** | **Not available in this environment** (Docker image is `elixir:1.17-otp-27`). `mix test` at base+patch was **NOT run** for Mydia. |
| **AGPL-3.0** | Record notice in provenance. |

---

## 11. Later-fix audit (after merge `8902237`)

Searched `git log 8902237..origin/master -- <file>` after `git fetch --deepen=100` for every key policy file:

| File | Later commits |
| --- | --- |
| `lib/mydia/library/metadata_matcher.ex` | **none** |
| `lib/mydia/media/provider_switch.ex` | **none** |
| `lib/mydia/media/fix_match.ex` | **none** |
| `lib/mydia/media/media_item.ex` | **none** |
| `lib/mydia/library/candidate_promotion.ex` | **none** |
| `lib/mydia/library/file_ingest.ex` | **none** |

**Clean window.** The ~40 commits after #1119 on master are player/shelves/assistant UI work (Liquid Glass, shelf feedback, plugins) — none touch the metadata provider policy. No reference-bug evidence.

---

## 12. Experiment log

| # | Experiment | Command / method | Result |
| --- | --- | --- | --- |
| E1 | Fetch `pull/1119.diff` | `curl -sL https://github.com/getmydia/mydia/pull/1119.diff` in WSL | **OK** — 2650 lines, 30 files. Inventory matches short dossier (12–15 substantive impl + 10 tests + README + migration). |
| E2 | API metadata | `GET /repos/getmydia/mydia/pulls/1119` | **OK** — base_sha `071360c6…`, head `8057d437…`, merge `8902237…`, 14 commits, 30 files, +1493/−522. |
| E3 | Reconstruct merge first-parent | `git rev-parse 8902237^1` after shallow clone + fetch | **OK** — first parent == `071360c6…` == API base_sha. Dossier SHA is correct. |
| E4 | Patch apply at base | `git apply --check && git apply` at `071360c6` | **CLEAN / SUCCESS** (30 files, +1493/−522). |
| E5 | Later commits on policy files | `git log 8902237..origin/master -- <policy files>` after deepen | **None** — clean window. |
| E6 | `mix deps.get` / `mix test` at base+patch | Docker `elixir:1.17-otp-27` | **NOT RUN** — Mydia requires Elixir `~> 1.20`; only 1.17 available. Static verification + patch-apply only. |
| E7 | File inventory vs short dossier | Manual count of `diff --git` lines | **Matches** — 30 total; dossier's “12–15 substantive” is a fair split of thin UI wiring vs policy code. |

---

## 13. Challenge the reference

### Incomplete that compiles
Partial A (fallback + pin field + migration, but refresh still re-identifies) compiles cleanly — `provider_refresh_decision` already has a fall-through clause for unpinned shows. Fails A4/A5 with named test `"a pinned TMDB show in a TVDB library is re-fetched in place"`.

Partial B (fallback on any error) compiles; fails A2 with `"a TVDB error is returned without trying TMDB"`.

### Shortcut risks
- A solver could set `metadata_source_pinned: true` unconditionally on create → A3's "pins only when the provider differs from a known library provider" catches it.
- A solver could skip the unattended hold and auto-promote cross-provider matches → A6 catches it.
- Hard-coding TMDB as fallback target instead of `TvProvider.other/1` → A3's library-provider matrix catches it.

### Flaky risks
- LiveView toggle tests are async UI; use LiveViewTest render/click (deterministic) not sleeps.
- The stub provider is synchronous; no network timing. Low flake risk.

### Contract fairness
- A2 (no-fallback-on-error) is the easiest to get unfair: a solver who treats `{:error, :timeout}` as "no matches" would fail. The PR body states the rule explicitly and the test name is unambiguous.
- A6's "held for review regardless of confidence" is stated in the PR body and README; do not hide it.

---

## 14. Curator record

```yaml
case_id: mydia-1119-provider-fallback-pin
project: getmydia/mydia
pr_url: https://github.com/getmydia/mydia/pull/1119
issue_url: https://github.com/getmydia/mydia/issues/1117
base_sha: 071360c6c765b4db02337943dd8d9ba6eee47bd6
merge_sha: 890223727f0701eef9a6ad006e88e30f417fdfa6
head_sha: 8057d437da8dc2f15ebb7a320b9944a9c9dd7897
merged_at: 2026-10-12T01:58:31Z
source_type: historical_merged_pr
task_kind: bounded_feature
family: multi_provider_metadata_matching_pin_policy_ui
brief_kind: clarified_implementation_brief
impl_files_substantive: 12-15
test_files: 10
total_files: 30
license: AGPL-3.0
elixir: "~> 1.20"
offline: true
stub_provider: true
db_required: true
db: sqlite (ecto_sqlite3)
patch_apply: clean_at_base
mix_tests_run: false
mix_tests_blocked_reason: "Elixir ~> 1.20 required; Docker image is 1.17-otp-27"
later_commits_same_files: []
later_fix_audit: clean_window
pr_body_empty: false
difficulty_hint: high
scope_risk: large_file_count_but_single_policy
```

---

## 15. Next action

1. Prepare a Mydia runtime image with Elixir ~> 1.20 + SQLite; confirm `mix test` at base `071360c6` with the stub provider and no network.
2. Freeze the brief above (keep product policies visible; no internal names).
3. Build unchanged / reference / incomplete (refresh-pin miss) / integrity (fallback-on-error) controls; run three qualification rounds.
4. Independent contract review focusing on A2 (error vs empty) and A6 (unattended guard) — those are the easiest to get unfair.

---

## Grilling (2026-10-19)

### Minimum ticket
The draft brief is a five-clause product essay, not a shortest-sufficient ticket. Too much policy is being stated as "here is the design" rather than left to investigation. Keep: "A TV show missing from my library's metadata provider should still match on the other provider; empty results fall through, relay errors do not. Once a show lives on the non-library provider, keep it there for refresh and Fix Match; switching back clears that pin. Cross-provider unattended matches wait for review (except new episodes of an already-stored show). Add a TVDB/TMDB toggle for TV searches only. Keep same-provider matching working." Cut the rest to curation notes. The brief as written answers half the investigation before the solver opens the repo.

### Named deterministic checks
A1–A8 map to real upstream tests and are nameable. Good. But A7 has three distinct obligations glued into one ID (toggle visibility / pick-and-pin / fileless-show no-pin). Split into A7a/A7b/A7c before qualification or a solver who nails two of three looks partial for the wrong reason. A2 ("relay error is not fallback") is the highest-value discriminating check; keep it explicit and do not collapse it into A1.

### Ambiguity / unfairness
- "Relay/availability error" vs "empty result" is the unfairness hot spot. If hidden checks treat `{:error, :timeout}` or `{:error, :rate_limited}` as "no match", solvers who correctly separate them will fail. The brief must say errors never trigger fallback, period — already almost there, but "relay/availability" is soft language. Use "any error other than an empty result set".
- "Held for review regardless of confidence" is a product policy that is easy to reverse-engineer only from the PR body. It is in the brief — good — but a solver can reasonably auto-promote high-confidence cross-provider matches. If the hidden check rejects that, the brief is the contract and is fair; do not also require the exact hold reason string.
- "Fileless show's Fix Match switch does not pin" is an edge case that appears only in implementation. If it is scored, state it in the brief. If it is not, drop it from A7.
- Movies/IMDb "out of scope" is fine but "keep existing movie matching working" must be a named preservation check, not vibes.

### Shortcuts + compiling incomplete
Partial A (fallback+pin field, refresh still re-identifies) and Partial B (fallback on any error) are real compiling incompletes with named failures. Good. Additional shortcut the dossier under-weights: a solver can pin on create unconditionally for TV shows and still pass A3 if the test matrix only covers "created on non-library provider". The negative ("pins only when provider differs") is listed in additional tests — make it a **named** integrity check, not a footnote. Another shortcut: implement fallback search but never surface the foreign-provider result in the Change-match UI — A1 unit may pass while the user-facing flow is broken; A7 must be graded at LiveView boundary, not only unit.

### Flakiness
Stub provider is synchronous; LiveViewTest clicks are deterministic. Real flake risk is Oban job invocation if any check accidentally enqueues instead of calling the matcher directly. Mandate: acceptance checks invoke the matcher/refresh functions directly or await Oban with a bounded drain; never `Process.sleep`. Low flake overall once that is pinned.

### Preservation
A8 covers same-provider import and unpinned migration. Add one mixed-population check: a library with one pinned foreign-provider show and one ordinary same-provider show — both refresh correctly in one pass. "Movies unchanged" is listed but not named; add a named movie preservation test or a solver can break movies and still pass.

### Env
**This is the blocker.** Elixir `~> 1.20` is required and was never available; `mix test` was never run. SQLite adapter + stub provider look favorable on paper, but "looks favorable" is not execution. No deps.get, no compile, no test evidence at base or base+patch. AGPL-3.0 notice must land in provenance before any bundle.

### Combined-lineage requirements
Not a #640+#641 / #1386+#1438+#1439 case. No lineage merge required. Later commits audited clean on policy files — do not fold post-#1119 player/shelf work into this case.

### Verdict
**HOLD** — env never executed. Do not schedule qualification on static confidence.

### Must-fix before qualification
1. Provide Elixir ~> 1.20 + SQLite image; run full `mix test` at base `071360c6` and at base+patch. Both must be green offline with the stub provider and zero network.
2. Split A7 into three named checks; promote "pins only when provider differs" and a named movie preservation test out of the footnotes.
3. Tighten the brief's error-vs-empty sentence to "any error other than an empty result set never triggers fallback".
4. Add the mixed pinned+unpinned population preservation check.
5. Independent contract review focused on A2 and A6 before any blind attempts.
