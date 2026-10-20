# Deep-dive dossier — Pinchflat #640 per-source cookie behaviour across yt-dlp consumers

**Case-prep status:** deep-inspected 2026-10-19/20 (API + full pull/N.diff + git clone + patch-apply + later-commit audit + **Docker mix test run**).
**Verdict:** strong large-feature candidate. Base-SHA question **resolved** (`59f8aa69` is the reconstruction parent; `b790e051` is its parent, not the base). Patch applies cleanly excluding the generated `erd.png`. Tests pass at base+patch. **Contract footgun confirmed:** later PR #641 (same day, 35 min after) changes `:when_needed` semantics — the ticket must freeze the merge-time rule.

---

## 1. Identity (resolved)

| Field | Value |
| --- | --- |
| Repo | [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat) |
| PR | [#640 [Enhancement] Add option for a source to only use cookies when needed](https://github.com/kieraneglin/pinchflat/pull/640) |
| Feature request | [#595](https://github.com/kieraneglin/pinchflat/issues/595) |
| Diff | https://github.com/kieraneglin/pinchflat/pull/640.diff (637 lines) |
| Author | kieraneglin (owner/maintainer) |
| PR body | Clear (cookie option; "when needed" only uses cookies for slow indexing; resolves #595) |
| Created / Merged | 2025-03-05T23:21:17Z / 2025-03-05T23:32:15Z |
| Head SHA | `e84b1dc66dfcc35f80038212ff7da828e07112d8` (`ke/different-cookie-behaviours`) |
| **Base SHA (squash parent)** | **`59f8aa69cdbc27625120fe85a236ff2166445562`** — confirmed: `git cat-file -p ac895944` shows `parent 59f8aa69…` |
| Alt SHA in short dossier | `b790e051330f085cf8b52b373d097adab7bc3e00` — **parent of `59f8aa69`**, i.e. one commit earlier. Not the reconstruction parent. |
| Merge commit | `ac895944a8d80c69f0da0f8846668f6f521866ef` — **squash merge** (single parent `59f8aa69`; no second parent) |
| Size | 5 commits, +243 / −61, **17 changed files** (API) — matches `pull/640.diff` (incl. `erd.png`) |
| License | **AGPL-3.0** |
| Elixir requirement at base | `~> 1.17` (from `mix.exs`; version `2025.2.20`) |

**Resolution of the short dossier's open question:** "re-verify which is the reconstruction parent" — **`59f8aa69`**. Pinchflat uses **squash merges**, so the squash commit's single parent is the reconstruction base. `b790e051` is `59f8aa69^` (a prior commit titled "Testing yt-dlp binary permissions (#634)").

---

## 2. Limit-testing story

Real product need (FR #595): cookies are required to *see* a private playlist (Watch Later) but must **not** be attached to every video download. The PR replaces a boolean `use_cookies` with a three-way policy `cookie_behaviour` (`:disabled | :when_needed | :all_operations`) and a single decision function that **every** yt-dlp consumer must use.

Coordination that is hard:

1. Schema + **data migration** mapping `use_cookies=true` → `all_operations` (and rollback).
2. One policy function used by download, slow indexing, fast indexing, metadata/thumbnail workers, and source-details UI lookups.
3. Source form labels for the three behaviours (and the source-details path that historically forced cookies).
4. Tests at **each** consumer boundary — a patch that fixes download but not metadata is incomplete.

This is not “ten copies of a string”: it is one policy with several call sites that must agree. File count (7–8 substantive) is a signal of that spread.

**Contract footgun to freeze at merge time:** at merge, `:when_needed` used cookies for **slow indexing only**. Later PR **#641** (merged 2025-03-05T16:41:07 -0800, i.e. ~35 minutes after #640) changes this to also retry downloads with cookies on cookie-related errors. The ticket must state the merge-time rule or hidden checks become unfair.

---

## 3. File inventory with roles (verified against `pull/640.diff`)

Counts: **17 paths** (incl. generated `erd.png` — ignore). Implementation = 8–9 substantive + 1 migration. Tests = 6. Matches short dossier.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/pinchflat/sources/source.ex` | Replace `:use_cookies` boolean with `Ecto.Enum` `:cookie_behaviour` (`[:disabled, :when_needed, :all_operations]`, default `:disabled`). |
| `lib/pinchflat/sources/sources.ex` | `use_cookies?(source, operation)` policy for `:indexing / :downloading / :metadata`; source-details changeset uses `:all_operations` only. |
| `priv/repo/migrations/20250304185528_add_cookie_behaviour_to_sources.exs` | Add column, map legacy true→`all_operations`, reverse for rollback, drop old column. |
| `lib/pinchflat/downloading/media_downloader.ex` | Download + downloadable-status use `:downloading`. |
| `lib/pinchflat/slow_indexing/slow_indexing_helpers.ex` | Indexing runner opts use `:indexing`. |
| `lib/pinchflat/fast_indexing/fast_indexing_helpers.ex` | Fast index metadata fetch uses `:metadata`. |
| `lib/pinchflat/metadata/metadata_file_helpers.ex` + `source_metadata_storage_worker.ex` | Thumbnail/source metadata use `:metadata`. |
| `lib/pinchflat_web/controllers/sources/source_html.ex` + `source_form.html.heex` | Friendly labels (`Disabled` / `When Needed` / `All Operations`); form field rename. |

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/pinchflat/sources_test.exs` | Policy table: `use_cookies?/2` per behaviour × operation. |
| `test/pinchflat/downloading/media_downloader_test.exs` | Download call sites honour the policy. |
| `test/pinchflat/slow_indexing/slow_indexing_helpers_test.exs` | Slow index attaches cookies for `:when_needed` and `:all_operations`, not `:disabled`. |
| `test/pinchflat/fast_indexing/fast_indexing_helpers_test.exs` | Fast index metadata does **not** attach cookies under `:when_needed`. |
| `test/pinchflat/metadata/metadata_file_helpers_test.exs` + `source_metadata_storage_worker_test.exs` | Metadata/thumbnail ops honour the policy. |

### Generated

| Path | Note |
| --- | --- |
| `priv/repo/erd.png` | Generated ER diagram — **do not count or require**. Blocks `git apply` as a binary hunk without full index; exclude it. |

---

## 4. Ticket / brief (draft clarified feature brief)

> Let a source choose when YouTube cookies are used: never, only when needed for indexing private collections, or for every operation. The choice must be honored consistently on slow indexing, fast indexing, downloads (including the download-ready pre-check), and metadata/thumbnail fetches. For “when needed”, use cookies on slow indexing only (not on downloads, fast indexing, or metadata). Existing sources that previously enabled cookies should behave as “use for all operations”. Expose the choice on the source form. Keep downloads working for sources that do not need cookies.

The three behaviour names/labels are product language and may appear. Do **not** name `use_cookies?/2`, migration filenames, or module paths.

**Critical freeze sentence (add to the brief):** *"For 'when needed', use cookies on slow indexing only"* — this is the merge-time rule. Do **not** import #641's retry-with-cookies behaviour.

---

## 5. Key implementation snippets (quoted from `pull/640.diff`)

### Policy function (`sources.ex`)

```elixir
def use_cookies?(source, operation) when operation in [:indexing, :downloading, :metadata] do
  case source.cookie_behaviour do
    :disabled -> false
    :all_operations -> true
    :when_needed -> operation == :indexing
  end
end
```

**This is the merge-time contract.** `:when_needed` → cookies **only** for `:indexing`.

### Schema (`source.ex`)

```elixir
field :cookie_behaviour, Ecto.Enum, values: [:disabled, :when_needed, :all_operations], default: :disabled
```

### Migration (reversible data map)

```elixir
def change do
  alter table(:sources) do
    add :cookie_behaviour, :string, null: false, default: "disabled"
  end

  execute(
    "UPDATE sources SET cookie_behaviour = 'all_operations' WHERE use_cookies = TRUE",
    "UPDATE sources SET use_cookies = TRUE WHERE cookie_behaviour = 'all_operations'"
  )

  alter table(:sources) do
    remove :use_cookies, :boolean, null: false, default: false
  end
end
```

### Download call site (`media_downloader.ex`)

```elixir
use_cookies = Sources.use_cookies?(item_with_preloads.source, :downloading)
runner_opts = [output_filepath: output_filepath, use_cookies: use_cookies]

case YtDlpMedia.get_downloadable_status(url, use_cookies: use_cookies) do
```

### Source-details path forces `:all_operations` only

```elixir
should_use_cookies = Ecto.Changeset.get_field(changeset, :cookie_behaviour) == :all_operations
```

### Form labels (`source_html.ex`)

```elixir
def friendly_cookie_behaviours do
  [
    {"Disabled", :disabled},
    {"When Needed", :when_needed},
    {"All Operations", :all_operations}
  ]
end
```

---

## 6. Named acceptance checks ↔ upstream tests

| ID | Observable obligation | Upstream test name(s) |
| --- | --- | --- |
| A1 | **Policy table:** each behaviour × operation yields the documented cookie flag. | `"returns true if the action is indexing and the source is set to :when_needed"`, `"returns false if the action is downloading and the source is set to :when_needed"`, `"returns true if the source has been set to use cookies"`, `"returns false if the source has not been set to use cookies"` |
| A2 | **Download:** `:when_needed` ⇒ download `use_cookies: false`; `:all_operations` ⇒ true; `:disabled` ⇒ false. | `"does not set use_cookies if the source uses cookies when needed"`, `"sets use_cookies if the source uses cookies"`, `"does not set use_cookies if the source does not use cookies"` |
| A3 | **Slow index:** `:when_needed` and `:all_operations` attach cookies on indexing; `:disabled` does not. | `"sets use_cookies if the source uses cookies when needed"` (slow_indexing), `"does not set use_cookies if the source uses cookies when needed"` |
| A4 | **Metadata/thumbnails:** `:when_needed` does **not** attach cookies on metadata/thumbnail ops. | `"does not set use_cookies if the source uses cookies when needed"` (metadata helpers + source_metadata_storage_worker) |
| A5 | **Migration:** legacy `use_cookies=true` ⇒ `:all_operations`; false ⇒ disabled; rollback restores boolean. | Reversible `execute` up/down (no dedicated test name in PR; curator should add one). |
| A6 | **Preservation:** `:disabled` sources still index/download without cookie files; sources that never needed cookies still work. | `"does not set use_cookies if the source does not use cookies"` across all consumer tests. |

---

## 7. Incomplete control (compiling partial)

**Partial A — enum + form + download call sites, but slow indexing still reading the old boolean (or always false).**

- A2 may pass; **A3** fails (private playlist indexing never gets cookies).
- Named failure: slow_indexing `"sets use_cookies if the source uses cookies when needed"`.

**Partial B — always pass `use_cookies: true` once any cookie behaviour is set.**

- **A2/A4** fail for `:when_needed`.

Both compile: the enum exists; the missed consumer just doesn't call `use_cookies?/2`.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Attach cookies for every operation whenever the field is non-nil (ignores `:when_needed` / `:disabled`).
- Break migration rollback or lose legacy true→all_operations mapping.
- Apply cookies to metadata/thumbnail under `:when_needed`.
- Change download-ready pre-check to ignore the policy.
- **Import #641's retry-with-cookies / `:error_recovery` behaviour** — that is a later feature, not this contract.

---

## 9. Preservation of existing behavior

- Existing cookie-on/off download tests rewritten to the new enum must still express old true/false behaviour.
- Sources with cookies disabled continue to index and download.
- Source create/details flows keep working (careful not to conflate sleep-interval UI skip from #559).

---

## 10. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| **yt-dlp mocked** | Existing `test/support/scripts/yt-dlp-mocks/`; **no YouTube**. |
| **SQLite** | `ecto_sqlite3`; data migration with `execute` up/down — verified in sandbox (tests passed). |
| Oban | Workers tested via existing helpers. |
| Freeze merge-time rule | Ticket states slow-index-only for `:when_needed`; do not import #641 retry-with-cookies. |
| **Elixir `~> 1.17`** | **Available** in Docker `elixir:1.17-otp-27`. |
| **AGPL-3.0** | Provenance notice. |

---

## 11. Later-fix audit (after merge `ac895944`)

**Critical finding — PR #641 is the contract footgun:**

| SHA | Date | What | Relevance |
| --- | --- | --- | --- |
| **`a97bb248e26f5305e68fce36ef1637feb28a2ca7` (#641)** | 2025-03-05 16:41:07 -0800 (**same day, ~35 min after #640**) | `[Enhancement] Retry a download using cookies if doing so might help` | **Changes the policy.** `use_cookies?/2` gains `:error_recovery` operation; `:when_needed` becomes `operation in [:indexing, :error_recovery]`. `media_downloader.ex` gains `maybe_retry_with_cookies/5` that retries with `force_use_cookies: true` when the error matches `"Sign in to confirm"` or `"This video is available to this channel's members"`. |
| `4554648` (#646) | later | Download rate limiting | Touches download pipeline; orthogonal to cookies. |
| Others (up to `67d8bd5`) | later | UI, Docker, sorting, filename ASCII | No further cookie-policy changes. |

**#641 `use_cookies?/2` after the fix:**

```elixir
def use_cookies?(source, operation) when operation in [:indexing, :downloading, :metadata, :error_recovery] do
  case source.cookie_behaviour do
    :disabled -> false
    :all_operations -> true
    :when_needed -> operation in [:indexing, :error_recovery]
  end
end
```

**Curator action:** the solver ticket and hidden checks must encode the **merge-time** rule (`:when_needed` → indexing only). A solver who discovers #641 in the repo history and implements retry-with-cookies would be solving a different task. State the freeze sentence explicitly.

---

## 12. Experiment log

| # | Experiment | Command / method | Result |
| --- | --- | --- | --- |
| E1 | Fetch `pull/640.diff` | `curl` in WSL | **OK** — 637 lines, 17 files. Matches API. |
| E2 | API metadata | `GET /repos/kieraneglin/pinchflat/pulls/640` | **OK** — base `59f8aa69…`, head `e84b1dc6…`, merge `ac895944…`, 5 commits, 17 files, +243/−61. |
| E3 | Reconstruct base | `git cat-file -p ac895944` (squash parent) | **OK** — single parent `59f8aa69…`. **`b790e051` is `59f8aa69^`**, not the base. Short dossier's open question resolved. |
| E4 | Patch apply at `59f8aa69` | `git apply --check` / `git apply` | **FAILED on `priv/repo/erd.png`** (binary hunk without full index). **CLEAN / SUCCESS with `--exclude=priv/repo/erd.png`** (15 files, +225/−61). All text hunks apply cleanly. |
| E5 | Patch apply at `b790e051` (alt) | `git apply` | Same erd.png failure; text hunks also clean. Not needed — use `59f8aa69`. |
| E6 | Later commits | `git log ac895944..origin/master -- <files>` after deepen | **`a97bb24` (#641)** changes `use_cookies?/2` and adds cookie-retry in `media_downloader.ex`. No other cookie-policy changes. |
| E7 | **`mix deps.get` + `mix compile` + `mix test` at base+patch** | Docker `elixir:1.17-otp-27`, `MIX_ENV=test`, one session | **RAN.** Compile: 122 files, OK (deprecation warnings only). Tests: `sources_test.exs` **90 tests, 0 failures**; `media_downloader_test.exs` **30 tests, 0 failures**; `slow_indexing_helpers_test.exs` **39 tests, 0 failures**. SQLite extension `sqlean` loads. Offline after `deps.get`. |
| E8 | Inventory vs short dossier | Count `diff --git` | **Matches** — 17 paths; 7–8 substantive is fair (excl. erd.png). |

---

## 13. Challenge the reference

### Incomplete that compiles
Partial A (download-only policy) compiles — slow indexing just keeps its own flag. Fails A3.

Partial B (always-true once set) compiles — `use_cookies?/2` returns true for any non-nil. Fails A2/A4.

### Shortcut risks
- A solver could map `:when_needed` to `operation != :metadata` (cookies on download too) → A2 catches it.
- A solver could skip the source-details `:all_operations`-only rule → source-details tests catch it.
- A solver could leave the old boolean in place and add the enum alongside it → migration A5 and the call-site tests catch it.

### Flaky risks
- Low. yt-dlp is mocked; tests are synchronous; SQLite sandbox is deterministic (90+30+39 passed in one run).
- The `execute` migration up/down is reversible; if the test migrator runs `change` in both directions, the reverse `execute` restores `use_cookies`. Pin the migrator strategy.

### Contract fairness
- The "when needed = slow indexing only" rule is stated in the **PR body** ("For now 'when needed' only uses cookies for slow indexing") and is in the brief. Do not hide it.
- A5 (migration rollback) has **no dedicated upstream test name** — curator must add one, or accept that a solver who breaks rollback still passes. Recommend adding a migration test as a named check.

---

## 14. Curator record

```yaml
case_id: pinchflat-640-cookie-behaviour
project: kieraneglin/pinchflat
pr_url: https://github.com/kieraneglin/pinchflat/pull/640
issue_url: https://github.com/kieraneglin/pinchflat/issues/595
base_sha: 59f8aa69cdbc27625120fe85a236ff2166445562   # squash parent (reconstruction)
alt_sha_not_base: b790e051330f085cf8b52b373d097adab7bc3e00  # parent of base
merge_sha: ac895944a8d80c69f0da0f8846668f6f521866ef  # squash merge, single parent
head_sha: e84b1dc66dfcc35f80038212ff7da828e07112d8
merged_at: 2025-03-05T23:32:15Z
source_type: historical_merged_pr
task_kind: bounded_feature
family: source_policy_propagated_to_yt_dlp_consumers
brief_kind: clarified_implementation_brief
impl_files_substantive: 7-8
test_files: 6
total_files: 17
generated_files: [priv/repo/erd.png]
license: AGPL-3.0
elixir: "~> 1.17"
offline: true
yt_dlp_mocked: true
db_required: true
db: sqlite (ecto_sqlite3)
patch_apply: clean_excluding_erd_png
mix_tests_run: true
mix_tests_summary: "sources 90/0, media_downloader 30/0, slow_indexing 39/0 at base+patch (elixir:1.17-otp-27 docker)"
later_commits_same_files:
  - sha: a97bb248e26f5305e68fce36ef1637feb28a2ca7
    pr: 641
    note: "SAME-DAY footgun: adds :error_recovery; :when_needed becomes indexing+error_recovery; cookie-retry on download errors. DO NOT import."
later_fix_audit: contract_changed_by_641_freeze_merge_time_rule
pr_body_empty: false
difficulty_hint: high
scope_risk: policy_spread_across_four_external_command_boundaries
```

---

## 15. Next action

1. Base SHA resolved: pin **`59f8aa69`**. Do not use `b790e051`.
2. Freeze the merge-time cookie rule in the brief ("when needed" = slow indexing only). Explicitly exclude #641 retry-with-cookies.
3. Incomplete = download-only; integrity = always-cookies or broken rollback. Add a named migration-rollback check (no upstream test name for A5).
4. Qualify after Pinchflat SQLite/Oban/mocks runtime is confirmed — **already exercised in Docker** (tests green at base+patch).

---

## Grilling (2026-10-19)

### Minimum ticket
The freeze sentence ("For 'when needed', use cookies on slow indexing only") is the **wrong product** now. LINEAGE-MERGE-POLICY and `combined-pinchflat-640-641.md` already decided: #640+#641 are one case; `:when_needed` = slow indexing **and** cookie-like download error recovery. Freezing merge-time #640-only semantics would reject a solver who implements the obvious recovery rule — exactly the unfairness the lineage policy exists to prevent. If this dossier is used alone, it is a **degraded** intermediate and should be the incomplete control, not the scored ticket. Scored ticket must be the combined brief from `combined-pinchflat-640-641.md`. This dossier's "do not import #641" instruction is now actively harmful if followed as the primary case.

### Named deterministic checks
A1–A6 are fine for #640-only. For the combined case, replace A3/A4 coverage with the combined A1–A6 matrix (always/never/when_needed × indexing/download/metadata + cookie-error retry + non-cookie-error no-retry + UI persist + defaults). The dossier correctly flags A5 (migration rollback) has **no upstream test name** — that is a real grading hole and must be a named curator check or rollback-breakers pass.

### Ambiguity / unfairness
- Under #640-only freeze: a solver who knows the product ("when needed" should also recover cookie failures) is penalized for being better. That is textbook unfair hidden constraint. Combined-lineage ticket fixes it.
- Under combined ticket: the cookie-like error strings ("Sign in to confirm…", members-only) are implementation-ish. The brief in `combined-pinchflat-640-641.md` already phrases this as "failure looks like a cookie/login problem (for example sign-in confirmation or members-only videos)" — keep that; do not freeze exact yt-dlp error substrings as the only matcher.
- "Existing sources that previously enabled cookies should behave as 'all operations'" is visible and fair.
- Source-details path forcing `:all_operations` only is a subtle rule. If graded, state it in the brief ("lookups that need private playlist visibility always send cookies"); if not graded, drop the check.

### Shortcuts + compiling incomplete
#640-only tree is the natural incomplete (fails A4 cookie-retry). Always-cookies and download-only are compiling. Under combined ticket, an additional incomplete is "retry every download failure with cookies" — A5 (unrelated failure: no cookie retry) must catch it. The dossier does not currently name that check; combined-pinchflat-640-641.md does (A5 there). Use the combined matrix.

### Flakiness
Tests are mocked and synchronous (90+30+39 green in Docker). Low flake. Keep yt-dlp mocks; never live YouTube. `execute` migration reverse is the only sharp edge — pin migrator.

### Preservation
Ordinary downloads without cookies, sources that never needed cookies, and legacy true→all_operations mapping are named-ish. Add a named "legacy use_cookies=true source still indexes and downloads with cookies after upgrade" check — right now migration A5 is half-tested.

### Env
**Best in this set.** Elixir 1.17 Docker available; `mix test` actually ran green at base+patch (90/0, 30/0, 39/0). Offline after deps.get. AGPL-3.0 notice still required. This env evidence does **not** extend to the combined tree — combined tree must be re-tested before freeze (the dossier already says so; do not skip it).

### Combined-lineage requirements
**REQUIRED.** This dossier depends on #640+#641. Rules:
1. Case ID should be `pinchflat-640-641` (or a new case version), not "only #640".
2. `provenance.json` lists both PRs and both applied commits (`ac89594…`, `a97bb24…`).
3. Ticket = combined brief (cookie-error recovery is visible product, not hidden).
4. Incomplete control = #640-only tree (indexing-only `:when_needed`).
5. Re-run `mix test` on the combined tree (A + #640 + #641 or post-#641 head) before qualification. E7 evidence is for #640-only.
6. Exclude generated `priv/repo/erd.png` from applies.

### Verdict
**READY-WITH-FIX** as a **combined** case; **REJECT as a standalone #640-only scored ticket** (unfair freeze of a 35-minute-later obvious hole).

### Must-fix before qualification
1. Adopt `combined-pinchflat-640-641.md` as the scored ticket and check matrix. Demote this dossier's freeze sentence to incomplete-control documentation.
2. Run `mix test` on the combined tree; record the result. Do not reuse E7.
3. Add named migration-rollback check and named legacy-true→all_operations preservation check.
4. Name the non-cookie-error no-retry check (combined A5) explicitly in protected checks.
5. Independent contract review of the combined brief's "cookie/login problem" phrasing (must not require exact error-substring matching).
