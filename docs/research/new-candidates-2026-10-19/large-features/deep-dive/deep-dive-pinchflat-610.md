# Deep-dive dossier — Pinchflat #610 persist and display download errors on media items

**Case-prep status:** deep-inspected 2026-10-19/20 (API + full pull/N.diff + git clone + patch-apply + later-commit audit + **Docker mix test run**).
**Verdict:** strong large-feature candidate. Identity SHAs confirmed (squash-merge parent = reconstruction base). Patch applies cleanly excluding `erd.png`. Tests pass at base+patch. Clean later-fix window on the `last_error` contract (the only later commits to `media_downloader.ex` are #640/#641 cookie work, orthogonal).

---

## 1. Identity (confirmed)

| Field | Value |
| --- | --- |
| Repo | [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat) |
| PR | [#610 [Enhancement] Record and display errors related to downloading](https://github.com/kieraneglin/pinchflat/pull/610) |
| Feature request | [#602](https://github.com/kieraneglin/pinchflat/issues/602) |
| Diff | https://github.com/kieraneglin/pinchflat/pull/610.diff (669 lines) |
| Author | kieraneglin (owner/maintainer) |
| PR body | Clear (errors saved to media item table and shown in-app; resolves #602; screenshot attached) |
| Created / Merged | 2025-02-11T22:44:49Z / 2025-02-12T18:17:24Z |
| Head SHA | `57ee87b3e4ae4395085fab31e1e01084931ef074` (`ke/record-download-failure-reason`) |
| **Base SHA (squash parent)** | **`fe5c00dbeff0adcc3f35ec9639c47a8f8b3338c4`** — confirmed: `git cat-file -p e7adc9d6` shows `parent fe5c00db…` |
| Merge commit | `e7adc9d68f40ad75819e00e26542fb3b6b24e0d1` — **squash merge** (single parent `fe5c00db`) |
| Size | 7 commits, +298 / −70, **15 changed files** (API) — matches `pull/610.diff` (incl. `erd.png`) |
| License | **AGPL-3.0** |
| Elixir requirement at base | `~> 1.17` (from `mix.exs`; version `2025.1.27`) |

**Dossier SHA check:** short dossier's base `fe5c00db…` and merge `e7adc9d6…` are **correct**. Pinchflat squash-merges, so the squash parent is the reconstruction base. No correction needed.

---

## 2. Limit-testing story

Users cannot tell *why* a download failed (FR #602). The feature adds durable `last_error` on media items, writes it on failure, clears it on success, and surfaces it on the media show page **and** in the source and history tables (with a tooltip). The limit-testing work is **pipeline state ↔ persistence ↔ several read surfaces**:

1. Download pipeline (including non-binary error terms) must stringify and store a readable reason.
2. Worker error handling must stay aligned with retry vs non-retry behaviour (not swallowed by the new field).
3. Successful download must **clear** a previous error (no stale red text).
4. Three UI surfaces (media show, source media table, history table) must render the error when present and **not crash / not show a section** when nil.
5. Table queries/preloads must actually select `:last_error` or the tooltip is empty.

A partial that persists the error but never renders it, or renders only on media show, is a plausible incomplete. File count (~8–12 impl) reflects persistence + utils + a tooltip component + three surfaces — not mechanical copies.

---

## 3. File inventory with roles (verified against `pull/610.diff`)

Counts: **15 paths** (incl. generated `erd.png` — ignore). Implementation = 11–12 substantive + 1 migration. Tests = 2. Matches short dossier's "~8–10" as a conservative count (UI wiring files are thin).

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `priv/repo/migrations/20250210201413_add_last_error_to_media_item.exs` | Add `last_error` string column. |
| `lib/pinchflat/media/media_item.ex` | Schema field `last_error` + allowed fields + typespec. |
| `lib/pinchflat/downloading/media_downloader.ex` | Set `last_error` on error paths; clear on success; wrap non-binary messages. |
| `lib/pinchflat/downloading/media_download_worker.ex` | Align worker error handling with persisted error (retry vs non-retry unchanged). |
| `lib/pinchflat/utils/string_utils.ex` | `wrap_string/1` for inspect vs binary. |
| `lib/pinchflat_web/components/custom_components/text_components.ex` | Tooltip component. |
| `lib/pinchflat_web/components/custom_components/button_components.ex` | Button component tweak (tooltip trigger). |
| `lib/pinchflat_web/controllers/media_items/media_item_html/show.html.heex` | Show last_error section (omitted when nil). |
| `lib/pinchflat_web/controllers/pages/page_html/history_table_live.ex` | Tooltip on failed rows. |
| `lib/pinchflat_web/controllers/sources/source_html/media_item_table_live.ex` | Tooltip + preloads/select include `:last_error`. |
| `lib/pinchflat_web/controllers/sources/source_html/show.html.heex` | UI wiring. |
| `lib/pinchflat_web/controllers/media_profiles/media_profile_html/show.html.heex` | UI wiring. |

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/pinchflat/downloading/media_downloader_test.exs` | Stores error on failure; clears on success; recovered and unrecoverable paths. |
| `test/pinchflat/utils/string_utils_test.exs` | Non-binary stringification. |

Upstream UI tests are thin; the curator should add LiveView/HTML checks at the real boundary (A4/A5).

### Generated

| Path | Note |
| --- | --- |
| `priv/repo/erd.png` | Generated — **ignore**. Blocks `git apply` as binary hunk; exclude it. |

---

## 4. Ticket / brief (draft clarified feature brief)

> When a download fails I cannot tell why. Save the failure reason on the media item and show it in the app: on the media item page and in the source and history tables. Clear the saved reason when a later download succeeds. Successful items must not show a stale error. Non-binary error terms should still store a readable string. Keep existing retry/recover behaviour.

Do **not** name `last_error`, `wrap_string/1`, tooltip modules, or file paths in the solver ticket.

---

## 5. Key implementation snippets (quoted from `pull/610.diff`)

### Persist on error / clear on success (`media_downloader.ex`)

```elixir
# Returns {:ok, %MediaItem{}}
Media.update_media_item(media_item, %{last_error: nil})

{:error, error_atom, message} ->
  Media.update_media_item(media_item, %{last_error: StringUtils.wrap_string(message)})
  {:error, error_atom, message}

{:recovered, media_item, message} ->
  {:ok, updated_media_item} = Media.update_media_item(media_item, %{last_error: StringUtils.wrap_string(message)})
  {:recovered, updated_media_item, message}
```

### Non-binary stringification (`string_utils.ex`)

```elixir
@doc """
...error messages whose types can vary.

Returns binary()
"""
def wrap_string(message) when is_binary(message), do: message
def wrap_string(message), do: "#{inspect(message)}"
```

### Schema (`media_item.ex`)

```elixir
field :last_error, :string
```

(added to both the `@type t` fieldspec and the schema `field` list, plus the castable/allowed fields)

---

## 6. Named acceptance checks ↔ upstream tests

| ID | Observable obligation | Upstream test name(s) |
| --- | --- | --- |
| A1 | **Store on failure:** failed download ⇒ media item has a non-empty readable error string. | `"sets the last_error to the error message on failure"` |
| A2 | **Clear on success:** fixture with old error; successful download ⇒ reason is cleared/nil. | `"sets the last_error to nil on success"` |
| A3 | **Both failure kinds:** recoverable and unrecoverable failures both persist a reason. | `"sets the last_error appropriately when recovered"`, `"sets the last_error appropriately when unrecoverable"`, `"returns an unrecoverable tuple if recovery fails"` |
| A4 | **Media show:** page includes the error text when present; omits the section when nil. | *No upstream test name* — **curator must add** LiveView/HTML assertion. |
| A5 | **Tables:** source media table and history table can show the reason (tooltip data present; no crash when nil). | *No upstream test name* — **curator must add** LiveView assertion (preloads/select include the field). |
| A6 | **Preservation:** successful download still updates metadata/filepath; retry/recover behaviour unchanged. | Existing downloader success/metadata tests (stay green). |

String-utils tests: `"returns strings as-is"`, `"returns other values as inspected strings"`.

---

## 7. Incomplete control (compiling partial)

**Partial A — persist `last_error` in the downloader/schema but never render it** (or render only on media show, not tables).

- A1 may pass; **A4/A5** fail.
- Named failure: curator-added LiveView assertion on the source media table / history table tooltip.

**Partial B — store error but also store it on success / never clear.**

- **A2** fails: `"sets the last_error to nil on success"`.

Both compile: the field and the update calls exist; the missed part is a template or a clear-path.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Set the error on successful downloads (stale errors).
- Block download completion solely because of the new field.
- Show empty tooltip/section when the field is nil (must omit or stay inert).
- Change retry classification as a side effect of persisting the message.

---

## 9. Preservation of existing behavior

- Existing downloader success/metadata tests stay green (verified: 29/29 and 30/30 in Docker).
- Media items with no error render without a new empty section.
- Worker retry vs non-retry paths unchanged.

---

## 10. Runtime / offline holds

| Hold | Notes |
| --- | --- |
| **yt-dlp mocked** | No YouTube. |
| **SQLite** | `ecto_sqlite3`; `add_last_error` applies in test DB (verified — tests ran). |
| Floki / LiveViewTest | UI checks at HTML/LiveView level (Floki is a test dep). |
| **Elixir `~> 1.17`** | **Available** in Docker `elixir:1.17-otp-27`. |
| **AGPL-3.0** | Provenance notice. |

---

## 11. Later-fix audit (after merge `e7adc9d6`)

Searched `git log e7adc9d6..origin/master -- <file>` after deepen:

| File | Later commits |
| --- | --- |
| `lib/pinchflat/downloading/media_download_worker.ex` | **none** |
| `lib/pinchflat/media/media_item.ex` | **none** (`last_error` introduced only by #610 itself; `git log -S "last_error"` shows no later renames) |
| `lib/pinchflat/utils/string_utils.ex` | **none** |
| `lib/pinchflat/downloading/media_downloader.ex` | `ac89594` (#640 cookie_behaviour) and `a97bb24` (#641 cookie-retry) — **orthogonal** to `last_error`; they change cookie policy, not the error field. |

**Clean window on the `last_error` contract.** No reference-bug evidence. The #640/#641 work is the sibling feature family and does not fix or break the error-persistence semantics.

The 26 commits after #610 are: cookie work (#640/#641), rate limiting (#646), filename ASCII (#660), healthcheck logging, dependency updates, sorting, docs, Docker, UI tabs. None touch `last_error` rendering or persistence.

---

## 12. Experiment log

| # | Experiment | Command / method | Result |
| --- | --- | --- | --- |
| E1 | Fetch `pull/610.diff` | `curl` in WSL | **OK** — 669 lines, 15 files. Matches API. |
| E2 | API metadata | `GET /repos/kieraneglin/pinchflat/pulls/610` | **OK** — base `fe5c00db…`, head `57ee87b3…`, merge `e7adc9d6…`, 7 commits, 15 files, +298/−70. |
| E3 | Reconstruct base | `git cat-file -p e7adc9d6` (squash parent) | **OK** — single parent `fe5c00db…`. Short dossier SHA is correct. |
| E4 | Patch apply at `fe5c00db` | `git apply --check` / `git apply` | **FAILED on `priv/repo/erd.png`** (binary). **CLEAN / SUCCESS with `--exclude=priv/repo/erd.png`** (13 files, +289/−70). All text hunks apply cleanly. |
| E5 | Later commits | `git log e7adc9d6..origin/master -- <files>` after deepen | `last_error` files clean. Only #640/#641 touch `media_downloader.ex` (cookie work, orthogonal). |
| E6 | **`mix deps.get` + `mix compile` + `mix test` at base+patch** | Docker `elixir:1.17-otp-27`, `MIX_ENV=test`, one session | **RAN.** Compile: 122 files, OK. Tests: `string_utils_test.exs` **8 tests, 0 failures**; `media_downloader_test.exs` **29 tests, 0 failures**. SQLite `sqlean` extension loads. Offline after `deps.get`. |
| E7 | Inventory vs short dossier | Count `diff --git` | **Matches** — 15 paths; "~8–10 impl" is a conservative split (11–12 if counting all UI wiring). |

---

## 13. Challenge the reference

### Incomplete that compiles
Partial A (persist-only) compiles — the UI templates simply never read the field. Fails A4/A5 (curator-added checks).

Partial B (never-clear) compiles — the success path keeps the old value. Fails A2: `"sets the last_error to nil on success"`.

### Shortcut risks
- A solver could store `inspect(message)` always (even for binaries) → `"returns strings as-is"` catches it.
- A solver could render an empty tooltip/section when nil → A5's "no crash when nil / omit section" catches it (curator check).
- A solver could change retry classification while persisting → A6 preservation tests catch it.

### Flaky risks
- Low. yt-dlp mocked; 8+29 tests passed deterministically in Docker.
- UI assertions (A4/A5) are not upstream — curator must add them carefully so they don't depend on exact tooltip markup. Prefer "page contains error string" / "page does not contain error section when nil" over pixel/HTML-structure equality.

### Contract fairness
- A4/A5 have **no upstream test names** — the reference patch implements them but does not test them at the LiveView boundary. The curator **must add** named checks or the incomplete (persist-only) will pass. This is the main grading gap.
- The brief already states the three surfaces ("on the media item page and in the source and history tables"), so the obligation is visible.

---

## 14. Curator record

```yaml
case_id: pinchflat-610-download-errors
project: kieraneglin/pinchflat
pr_url: https://github.com/kieraneglin/pinchflat/pull/610
issue_url: https://github.com/kieraneglin/pinchflat/issues/602
base_sha: fe5c00dbeff0adcc3f35ec9639c47a8f8b3338c4   # squash parent (reconstruction)
merge_sha: e7adc9d68f40ad75819e00e26542fb3b6b24e0d1  # squash merge, single parent
head_sha: 57ee87b3e4ae4395085fab31e1e01084931ef074
merged_at: 2025-02-12T18:17:24Z
source_type: historical_merged_pr
task_kind: bounded_feature
family: failure_state_persistence_multi_surface_ui
brief_kind: clarified_implementation_brief
impl_files_substantive: 11-12
test_files: 2
total_files: 15
generated_files: [priv/repo/erd.png]
license: AGPL-3.0
elixir: "~> 1.17"
offline: true
yt_dlp_mocked: true
db_required: true
db: sqlite (ecto_sqlite3)
patch_apply: clean_excluding_erd_png
mix_tests_run: true
mix_tests_summary: "string_utils 8/0, media_downloader 29/0 at base+patch (elixir:1.17-otp-27 docker)"
later_commits_same_files: []   # last_error contract clean; #640/#641 on media_downloader are cookie-orthogonal
later_fix_audit: clean_window_on_last_error_contract
pr_body_empty: false
grading_gap: "A4/A5 have no upstream test names; curator must add LiveView/HTML checks"
difficulty_hint: medium-high
scope_risk: persistence_plus_three_ui_surfaces
```

---

## 15. Next action

1. Pin base `fe5c00db` (confirmed squash parent).
2. Draft brief without naming the column; prefer LiveView/HTML assertions over pixel tests.
3. **Add curator LiveView checks for A4/A5** (media show + source table + history table; omit when nil) — this is the grading gap.
4. Incomplete = persist-only; integrity = never-clear / show-when-nil.
5. Qualify after Pinchflat runtime is confirmed — **already exercised in Docker** (tests green at base+patch).

---

## Grilling (2026-10-19)

### Minimum ticket
Short and good. "Save the failure reason on the media item and show it in the app: on the media item page and in the source and history tables. Clear when a later download succeeds." That is the right length. One fix: "Non-binary error terms should still store a readable string" is a detail that leaks implementation. Replace with "the saved reason must always be human-readable" or drop it and grade readability as an integrity check. Keep "Keep existing retry/recover behaviour."

### Named deterministic checks
A1–A3 have real upstream test names. **A4 and A5 have none.** This is the grading gap the dossier itself flags — and it is not a small one. Without curator LiveView/HTML checks, the persist-only incomplete **passes the whole suite**. That is disqualifying until fixed. A4/A5 must become named checks with explicit assertions: page contains error text when present; page/table omits the error affordance when nil; source media table and history table both show it (not just media show). Prefer string-presence / section-absence over tooltip markup equality.

### Ambiguity / unfairness
- "Show it in the app … on the media item page and in the source and history tables" is visible. Fair. Do not require a specific tooltip component or icon.
- "Readable string" for non-binary terms: if hidden checks require `inspect/1` specifically, that is unfair. Accept `inspect` or any non-empty printable string that is not `"nil"` / `""`.
- Clear-on-success is stated. Good.
- Exact placement of the error on the show page (section header text) must not be byte-graded.

### Shortcuts + compiling incomplete
Persist-only (Partial A) and never-clear (Partial B) are compiling with named failures — **except A4/A5 have no names yet**. Additional shortcuts: store the error but render it only on media show (tables empty) — dies only if A5 exists; show a permanent "Failed" badge with no message — A4 must require the message text. Integrity should also reject patches that set `last_error` on success or that block download completion.

### Flakiness
8+29 tests green in Docker; yt-dlp mocked. Low flake. UI checks must use LiveViewTest/Floki render, not screenshots or sleeps. Tooltip hover is **not** testable deterministically in LiveViewTest — grade that the table row exposes the error (assign, title attribute, or visible text), not that a tooltip opens.

### Preservation
Downloader success/metadata tests are good. Add named "successful download after a failure leaves no error visible" at the **UI** boundary, not only the field-nil unit test — otherwise a solver can clear the field but leave a stale UI section.

### Env
**Solid.** Elixir 1.17 Docker, `mix test` ran green at base+patch (8/0 + 29/0), SQLite works, offline after deps.get. AGPL-3.0 provenance still needed. This is qualification-ready from an env standpoint once A4/A5 exist.

### Combined-lineage requirements
Not a #640+#641 case. `last_error` window is clean; #640/#641 on `media_downloader.ex` are cookie-orthogonal — do not merge them into this case. Sibling feature family only.

### Verdict
**READY-WITH-FIX** — env is proven; grading gap A4/A5 is the one hard blocker.

### Must-fix before qualification
1. Author named LiveView/HTML checks for A4 (media show) and A5 (source media table + history table), including nil-omission. Until these exist, the persist-only incomplete passes — do not freeze.
2. Add named UI-boundary "cleared on success" check.
3. Soften "non-binary → readable string" in the brief so hidden checks do not require `inspect/1` specifically.
4. Specify that tooltip-hover is not the graded affordance (presence of the reason on the row/page is).
5. Three qualification rounds + two blind successes after the above.
