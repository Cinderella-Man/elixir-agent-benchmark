# App-repo PR mining — 2026-10-19

Discovery/screening notes for **real Elixir application** repositories (not libraries). Goal: SWE-bench-style case candidates — 2–5 substantive implementation files, authentic user problem, offline-capable holds documented. Skips chores, deps, CI, docs-only, and perf-only changes.

**Method (shared):** GitHub REST API was rate-limited on this host (unauthenticated). Discovery used GitHub **HTML** closed-PR listings (embedded JSON), `pull/N.diff`, `raw.githubusercontent.com` at base revisions, and HTML commit pages for merge parents. **Not verified:** compilation, test execution, offline dependency fetch, or runtime boot for any candidate. No commits and no `cases/` bundles were produced.

Guidance: [pr-selection-guidelines.md](../../pr-selection-guidelines.md). Prior shortlist: [application-shortlist-2026-10-19.md](../application-shortlist-2026-10-19.md).

This file is a **shared index**. Parallel mining passes append their own project sections. Candidate dossiers are one file per PR: `app-candidate-<project>-<pr>.md`.

---

## Index of candidate files in this folder

| Project | Files |
| --- | --- |
| Beacon CMS | `app-candidate-beacon-{672,681,729,760}.md` |
| Changelog.com | `app-candidate-changelog.com-{339,559,562}.md` |
| **Craftplan** | `app-candidate-craftplan-{51,53}.md` |
| Mydia | `app-candidate-mydia-{1083,1105,1127,1150,1168}.md` |
| **NervesHub** | `app-candidate-nerves_hub_web-3153.md` |
| Pinchflat | `app-candidate-pinchflat-{485,535,542,559,610,640}.md` |
| TeslaMate | `app-candidate-teslamate-{5781,5782,5820,5823,5827}.md` |
| **Vutuv** | `app-candidate-vutuv-2373.md` |
| Logflare | none selected this pass (see section below) |

---

## Section: craftplan, logflare, vutuv, nerves_hub_web

Projects assigned in this pass: [puemos/craftplan](https://github.com/puemos/craftplan), [Logflare/logflare](https://github.com/Logflare/logflare), [wintermeyer/vutuv](https://github.com/wintermeyer/vutuv), [nerves-hub/nerves_hub_web](https://github.com/nerves-hub/nerves_hub_web).

| Project | License | Stack (base `mix.exs`) | Selected | Notes |
| --- | --- | --- | --- | --- |
| craftplan | AGPL-3.0 | Elixir `~> 1.20`; Ash 3 + Ash Postgres + Ash auth + Absinthe + LiveView | **#53, #51** | Strong domain work (catalog BOM, production batches). Ash is heavy but local. |
| logflare | Apache-2.0 | Phoenix, Ecto, Oban, BigQuery/ClickHouse paths | none selected | See “Screened out” below. |
| vutuv | MIT | Elixir `~> 1.20`; Phoenix 1.8, LiveView, Ecto, Req | **#2373** | Lightest runtime; multi-surface consistency task. |
| nerves_hub_web | Apache-2.0 | Elixir `~> 1.20.0`; Phoenix, Ecto + `ecto_ch`, Oban | **#3153** (if feasible) | Multi-service hold (PG + ClickHouse + TLS device endpoint). |

### Selected candidates (4)

| File | Project | PR | Kind | Impl files | Why selected |
| --- | --- | --- | --- | --- | --- |
| [app-candidate-craftplan-53.md](app-candidate-craftplan-53.md) | craftplan | [#53](https://github.com/puemos/craftplan/pull/53) | bug fix | 2 | Allergens omit nested subassembly materials while labels/rollups include them; issue #49; mixed nested/shared/cycle tests. |
| [app-candidate-craftplan-51.md](app-candidate-craftplan-51.md) | craftplan | [#51](https://github.com/puemos/craftplan/pull/51) | bounded feature | 5 | “Canceled” filter state with no cancel action (issue #47); domain action + allocation release + LiveView controls. |
| [app-candidate-vutuv-2373.md](app-candidate-vutuv-2373.md) | vutuv | [#2373](https://github.com/wintermeyer/vutuv/pull/2373) | bug fix / policy | 6* | Logged-out visitors lose same-named expired credentials; profile + CV + agent docs must agree. MIT. |
| [app-candidate-nerves_hub_web-3153.md](app-candidate-nerves_hub_web-3153.md) | nerves_hub_web | [#3153](https://github.com/nerves-hub/nerves_hub_web/pull/3153) | bug fix | 3 | Soft-deleted connected device stays in deployment group and keeps orchestrator/socket work. |

\*vutuv #2373 is one visibility policy across six presentation paths — slightly above the 2–5 preference but coherent; do not split into fake separate tasks.

### Cross-candidate notes (this section)

- **Prefer craftplan #51** if only one craftplan case enters the corpus (bounded feature, clearest user request, domain + UI). **#53** is the better *bug-fix* companion (calculation ↔ rollup ↔ label).
- **Do not count both craftplan PRs as independent “project coverage”** — same app, same Ash/Postgres fixture work. Resolve the Ash runtime once, then qualify both.
- **vutuv #2373** is the diversity pick (MIT, plain Ecto/LiveView, multi-surface). Its PR body discloses AI-written text; record as exposure metadata, not automatic exclusion.
- **nerves_hub #3153** is the strongest NervesHub lead but is gated on ClickHouse + HTTPS device-socket fixture. Defer rather than mock the disconnect boundary if the socket cannot run offline.
- All AGPL/Apache/MIT notices must appear in case provenance.

### Screened out this section (do not rediscover)

| PR / lead | Why not selected |
| --- | --- |
| Logflare #4169 (OTP reports to user sources), #4162 (`sources_backends` rows), #4154, #4117 | **1 implementation file** each. Real bugs but below the coordinated multi-file preference; keep as focused reserves if a one-file slot exists. |
| Logflare #4113 (SourceSup / interceptor deadlock) | **17+ paths** spanning backends, gRPC, channels, telemetry — too broad and mixed-refactor for a single task. |
| Logflare #4118 (VictoriaMetrics/PromQL) | New backend feature with external-system shape; not offline-clean without more fixture work. |
| craftplan #35 (privilege escalation on registration) | Good security fix (2 impl files) but second-tier vs #51/#53; test-support refactor also in diff. Reserve. |
| craftplan #43 (product/recipe deletion) | Involves migrations + Ash resource snapshots + VERSION bump — generated/DDL-heavy. Reserve. |
| craftplan #22/#23/#24 (nutrition), #22 XLSX import | Feature sprawl or external format. |
| craftplan #27/#26 (perf) | Perf-only — excluded by guidelines. |
| craftplan #34/#33/#25/#17 (CI, deploy, Elixir upgrade, dep vulns) | Chore/infra — excluded. |
| vutuv #2372 (expired certs stay visible) | Same family as #2373 (predecessor); do not pair as two cases. |
| vutuv #2371, #2368, #2365, #2361, #2360, … | Smaller UI/spam/feed fixes; mostly 1–2 files or policy text. |
| nerves_hub #3148/#3149/#3150 (Teams/Slack) | External chat integrations. |
| nerves_hub #3146 (expired CA on register) | Focused reserve; narrower than #3153. |

### Runtime holds (this section)

| Project | Holds to resolve before qualification |
| --- | --- |
| craftplan | PostgreSQL; Ash 3 + native `bcrypt_elixir`/`picosat_elixir`; cache `mix.lock` offline; **exclude** SeaweedFS/MinIO storage integration from the selected tests. Heroicons git sparse dep must be cached. |
| vutuv | PostgreSQL (test alias migrates); LiveViewTest/lazy_html; keep Req/link-verification offline; confirm assets/Node need. |
| nerves_hub_web | PostgreSQL **and** ClickHouse (`CLICKHOUSE_URL`); HTTPS `DeviceEndpoint` with client certs on a fixed test port; Oban; **git dep** `opentelemetry_oban` (branch) must be cached. |
| logflare | (not selected) BigQuery/ClickHouse paths and Playwright would be the main holds. |

### Next actions (this section)

1. Pick the **pilot pair**: one craftplan candidate (#51 or #53) + vutuv #2373 (light runtime) or nerves_hub #3153 (if multi-service fixture is ready).
2. Per candidate: pin base SHA → cache deps → unchanged/reference/incomplete/integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes. None of those gates is done here.
3. Keep license notices and PR-body tooling disclosures in provenance.
4. Do not open a `cases/` bundle until qualification evidence exists.

### What was not verified (this section)

- Any `mix` compile/test/credo run on these bases.
- Offline Hex/git dependency availability.
- Exact Elixir/OTP image compatibility (craftplan/vutuv `~> 1.20`; nerves_hub `~> 1.20.0`).
- Whether upstream CI green at merge is reproducible here.
- Rate-limited REST metadata (stars, full issue timelines beyond HTML snippets).

HTML/diff/raw retrieval date: **2026-10-19**.

---

## Other sections

Other project sections (Beacon, Changelog.com, Mydia, Pinchflat, TeslaMate) live in their own `app-candidate-*.md` dossiers in this folder. If those passes append summary sections here, keep them **below** this heading and do not edit the craftplan/logflare/vutuv/nerves_hub section above without re-reading those dossiers.

---

## Section: teslamate-org/teslamate + kieraneglin/pinchflat

Focus projects for this pass. Per-PR dossiers: `app-candidate-teslamate-*.md`, `app-candidate-pinchflat-*.md`. REST was rate-limited; evidence is HTML PR pages + `pull/N.diff`/`pull/N.patch` + raw `mix.exs`/LICENSE. Base SHA ≈ parent of first PR commit; merge SHA from “merged commit” link — **re-verify before reconstruction**.

### Shortlist (11)

| File | Project | PR | Kind | Impl files | Why it is here | Status |
| --- | --- | --- | --- | --- | --- | --- |
| [app-candidate-teslamate-5781.md](app-candidate-teslamate-5781.md) | TeslaMate | [#5781](https://github.com/teslamate-org/teslamate/pull/5781) | bug_fix | 4–5 | Token refresh safety + sign-in LiveView error classification / single-flight | discovered — draft next |
| [app-candidate-teslamate-5823.md](app-candidate-teslamate-5823.md) | TeslaMate | [#5823](https://github.com/teslamate-org/teslamate/pull/5823) | bug_fix | 1 | Geofence form updates vs drive/charge re-assignment | discovered — focused repair |
| [app-candidate-teslamate-5820.md](app-candidate-teslamate-5820.md) | TeslaMate | [#5820](https://github.com/teslamate-org/teslamate/pull/5820) | bug_fix | 1 | Re-assignment SQL used wrong latitude (bbox vs radius) | discovered — sibling of 5823 |
| [app-candidate-teslamate-5782.md](app-candidate-teslamate-5782.md) | TeslaMate | [#5782](https://github.com/teslamate-org/teslamate/pull/5782) | bug_fix | 3 | Fail-closed token/userinfo redaction in errors and logs | discovered — reserve |
| [app-candidate-teslamate-5827.md](app-candidate-teslamate-5827.md) | TeslaMate | [#5827](https://github.com/teslamate-org/teslamate/pull/5827) | bug_fix | 4+ | Shared VIN/car-title labeling across LiveViews | discovered — UI reserve |
| [app-candidate-pinchflat-485.md](app-candidate-pinchflat-485.md) | Pinchflat | [#485](https://github.com/kieraneglin/pinchflat/pull/485) | bug_fix | 3 | Livestream download readiness vs Oban retry | discovered — draft next |
| [app-candidate-pinchflat-640.md](app-candidate-pinchflat-640.md) | Pinchflat | [#640](https://github.com/kieraneglin/pinchflat/pull/640) | feature | 7–8 | `cookie_behaviour` policy on every yt-dlp consumer | discovered — draft next |
| [app-candidate-pinchflat-610.md](app-candidate-pinchflat-610.md) | Pinchflat | [#610](https://github.com/kieraneglin/pinchflat/pull/610) | feature | 8–10 | Persist `last_error` + show on media/source/history UI | discovered — draft next |
| [app-candidate-pinchflat-559.md](app-candidate-pinchflat-559.md) | Pinchflat | [#559](https://github.com/kieraneglin/pinchflat/pull/559) | feature | 6–8 | Settings sleep flags + throttle junk-title rejection + bot-check non-retry | discovered — freeze 0=off |
| [app-candidate-pinchflat-535.md](app-candidate-pinchflat-535.md) | Pinchflat | [#535](https://github.com/kieraneglin/pinchflat/pull/535) | bug_fix | 5–6 | OPML route token + basic auth plugs / router / UI | discovered — security family |
| [app-candidate-pinchflat-542.md](app-candidate-pinchflat-542.md) | Pinchflat | [#542](https://github.com/kieraneglin/pinchflat/pull/542) | feature | 3 | SponsorBlock mark-as-chapters through profile + option builder | discovered — focused reserve |

### Project notes (this section)

| Project | License | Stack | Holds |
| --- | --- | --- | --- |
| TeslaMate | AGPL-3.0-or-later | Elixir `~> 1.19`, PostgreSQL + `earthdistance`, LiveView | Postgres extension in runner image; toolchain 1.19; **no live Tesla API** (tests mock) |
| Pinchflat | AGPL-3.0 | Elixir `~> 1.17`, SQLite (`ecto_sqlite3`), Oban, Mox yt-dlp | SQLite+Oban+Mox bootstrap **unverified** vs runner’s PG/CH adapters; **no live YouTube** |

### Cross-candidate notes (this section)

- Prefer **Pinchflat #485** and **TeslaMate #5781** first (clearest multi-component bugs, mockable).
- **Pinchflat #640** needs the merge-time rule frozen in the brief: “when needed” uses cookies for **slow indexing only** (later PRs change this).
- **#5823 / #5820** are one geofence-assignment family — do not count as independent coverage without saying so.
- **#559** has a contract footgun: validation `greater_than: 0` vs UI “0 = disable”. State 0=off in the ticket.
- AGPL both projects — keep notices in provenance. TeslaMate #5823 PR body is Claude-assisted (exposure metadata).

### Screened out this section (do not rediscover)

| PR / lead | Why not selected |
| --- | --- |
| TeslaMate dependabot / CI / Nix / docs / style / rust WIP | Not product implementation. |
| TeslaMate #5847 (`import_runs.car_id` type) | Migration-only. |
| TeslaMate #5804 (version module) | Multi-call-site consolidation; weaker observable behavior. |
| TeslaMate #5785 (geocoder address ranks) | One Elixir file + Grafana JSON; reserve. |
| Pinchflat #838/#822/#697/#513/#507 | Spelling / CSS / tiny UI. |
| Pinchflat #609/#618/#581/#570 | 1–2 file focused fixes; reserves only. |
| Pinchflat #540 (indexing overhaul) | Performance-leaning / large. |
| Pinchflat #606/#641/#646 | Promising but not fully mined this pass. |

### Next actions (this section)

1. Confirm TeslaMate `earthdistance` and Pinchflat SQLite/Oban/Mox in the runner.
2. Draft Pinchflat #485 and TeslaMate #5781 cases (ticket + named checks only).
3. Then #640, #5823, #610/#559/#535 as runtime allows.
4. No `cases/` bundles until qualification gates pass.

## Section: app-mining-changelog-beacon-mydia-2026-10-19

Projects: [thechangelog/changelog.com](https://github.com/thechangelog/changelog.com), [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon), [getmydia/mydia](https://github.com/getmydia/mydia).
Method: GitHub HTML PR lists (embedded JSON), `pull/N.diff`, `pull/N.patch`, raw LICENSE/mix.exs, issue pages. API was rate-limited. **Not verified:** compile/test execution.

### Selected candidates (12)

| Project | PR | Title | Status | Impl | Notes |
| --- | --- | --- | --- | --- | --- |
| changelog.com | [#559](https://github.com/thechangelog/changelog.com/pull/559) | Make episode publish idempotent | discovered | 5 | Canonical news item + queue-once + rollback side effects. Strong upstream tests. |
| changelog.com | [#339](https://github.com/thechangelog/changelog.com/pull/339) | First time commentor validation | discovered | 6–7 | Moderation + notify branching + admin email. 2020 toolchain risk. |
| changelog.com | [#562](https://github.com/thechangelog/changelog.com/pull/562) | Isolate release preparation from Oban workers | discovered | 2 | OTP supervision flag + deploy hook; fresh-VM tests. |
| beacon | [#681](https://github.com/BeaconCMS/beacon/pull/681) | fix: page variant flashing | discovered | 7 | Plug → template metadata → assigns → PageLive. Issue #327. Curator checks needed. |
| beacon | [#672](https://github.com/BeaconCMS/beacon/pull/672) | Page warming | discovered | 3 | Config + Boot + Content query. Issue #666. |
| beacon | [#760](https://github.com/BeaconCMS/beacon/pull/760) | Add lifecycle stage `:after_unpublish_page` | discovered | 3 | Config + Lifecycle.Page + Content GenServer. |
| beacon | [#729](https://github.com/BeaconCMS/beacon/pull/729) | fix: crash recovery | discovered | 4 | Beacon before Endpoint; runtime endpoint config. Ordering check to author. |
| mydia | [#1105](https://github.com/getmydia/mydia/pull/1105) | Require permission and respect account restrictions for library bulk actions | discovered | 5 | Authz across LiveView events + BulkWrites/Deletion scope. |
| mydia | [#1150](https://github.com/getmydia/mydia/pull/1150) | fix(jobs): stop metadata refresh jobs snoozing forever | discovered | 4 | Oban 2.24 snooze/attempt rollback; StartupJitter + 2 workers + migration. |
| mydia | [#1083](https://github.com/getmydia/mydia/pull/1083) | fix(watch-sync): sync watched state across every Jellyfin copy | discovered | 4 | Mapping uniqueness + engine fold + reconciler. Issue #1079. |
| mydia | [#1127](https://github.com/getmydia/mydia/pull/1127) | fix(watch-sync): import watches on copies mapped after they were played | discovered | 4 | Cursor/marker semantics follow-up to #1083. Issue #1097. |
| mydia | [#1168](https://github.com/getmydia/mydia/pull/1168) | fix(jobs): return float averages … on PostgreSQL | discovered | 1 | Focused one-file dual-DB bug; needs Postgres to discriminate. |

### Screened out this section (do not rediscover)

| PR / lead | Why not selected |
| --- | --- |
| changelog.com #345 | Oban delayed notify **and** author edit window (two capabilities); 15 commits + lockfile noise. Hold. |
| changelog.com #563 | Migration + tests only. Reject as thin. |
| changelog.com #322 | Algolia cloud dependency. Hold. |
| changelog.com #439 | One controller file. Reject (focused reserve). |
| changelog.com #232/#327/#510 | Huge asset diffs / redesign. |
| beacon #713 | Multi-node media (`:node` in UploadMetadata) — multi-node fixture hold. |
| beacon #684 | Coherent but 2 impl files; focused reserve. |
| beacon #717/#694/#687 | Generator/static-asset heavy. |
| beacon #646 | Single file. |
| mydia #1123 | Calendar + admin form-controls family (phx-change outside form); hold with mixed refactor. |
| mydia #1119/#1112/#1109 | Large features; Cardigann/metadata runtime risk. |
| mydia #1111 | Refactor without tests. |
| mydia #1081/#1077 | S3-compatible storage — cloud. |

### Project notes (this section)

| Project | License | Runtime |
| --- | --- | --- |
| changelog.com | Custom (content © Changelog Media LLC; code MIT-style permission) | Elixir `~> 1.18` at 2026 PRs; PostgreSQL; avoid S3/R2/Algolia/Honeycomb paths. |
| BeaconCMS/beacon | MIT (DockYard) | Elixir `~> 1.14`; PostgreSQL; mix-task generators in tree. |
| getmydia/mydia | AGPL-3.0 | Elixir `~> 1.20`; SQLite local / PostgreSQL CI; Oban; fakes for Jellyfin in tests — keep external media out of scored checks. |

### Next actions (this section)

1. Pin base SHAs (parent of first PR commit; confirm merge-base) listed in each dossier.
2. Prefer pilot trio: changelog.com #559, beacon #681 or #672, mydia #1105 (authz) or #1150 (Oban).
3. mydia #1083 and #1127 are the same engine files — qualify one at a time; keep both (distinct defects).
4. Author missing acceptance checks for beacon #681/#729 before freeze.
5. No `cases/` bundles until qualification evidence exists.

### What was not verified (this section)

- Any `mix` compile/test run; offline Hex availability; exact OTP image fit for 2020 changelog.com PRs (#339).
- Dual-DB migration behavior for mydia (#1083/#1168) on both SQLite and PostgreSQL.
- Parent SHAs are parent-of-first-commit from commit HTML, not confirmed merge-bases.

**Curation policy, 2026-10-20:** before implementing a researched candidate, follow [prepared fork sources](../../../prepared-fork-sources.md) and inspect existing fork branches. Runnable cases must pin prepared fork baselines; a research shortlist is not an admitted inventory. The [source audit](../../../../verification/prepared-forks-2026-10-20/README.md) records branch reuse and migration evidence.
