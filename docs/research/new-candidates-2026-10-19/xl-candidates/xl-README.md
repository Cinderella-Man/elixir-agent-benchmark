# XL candidates — 2026-10-19

Limit-testing **XL** candidates: **10–20 substantive implementation files** (tests counted separately), one coherent product outcome, multi-module coordination. This folder holds both **libraries** (prior pass) and **real Elixir applications** (this pass). Fills the gap between large-features (5–10 files) and mega-rewrite rejects (50+).

**Method:** GitHub PR list HTML (embedded JSON) + `pull/N.diff` + pull API for identity SHAs + PR bodies for issue links. **Not verified:** compilation, test execution, offline dependency fetch, or runtime boot. No commits and no `cases/` bundles.

Guidance: [pr-selection-guidelines.md](../../pr-selection-guidelines.md) — larger coherent tasks are allowed when outcome and environment are tractable; file count is a signal not a quota; ticket must not name the fix. Lineage policy: [large-features/LINEAGE-MERGE-POLICY.md](../large-features/LINEAGE-MERGE-POLICY.md). Prior work: [large-features/](../large-features/), [app-mining/](../app-mining/), [more-candidates/](../more-candidates/), [more-candidates-2/](../more-candidates-2/).

---

## Summary table

### Applications (this pass)

| File | Project | PR | Feature | Impl files | Why limit-testing | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [xl-pinchflat-282.md](xl-pinchflat-282.md) | kieraneglin/pinchflat | [#282](https://github.com/kieraneglin/pinchflat/pull/282) | YouTube API for fast indexing (opt-in, RSS fallback) | 13 | Behaviour + 2 providers + helper fallback + setting/migration + settings/source UI | discovered |
| [xl-mydia-1072.md](xl-mydia-1072.md) | getmydia/mydia | [#1072](https://github.com/getmydia/mydia/pull/1072) | Stream links for external players | 10 | Token mint/verify + authz re-check per request + shared Range helper + LiveView rows/modal + JS | discovered |
| [xl-beacon-578.md](xl-beacon-578.md) | BeaconCMS/beacon | [#578](https://github.com/BeaconCMS/beacon/pull/578) | Site-wide `handle_info` callbacks | 14 | Content schema → compile module → hot reload → PageLive dispatch | discovered |
| [xl-livebook-2608.md](xl-livebook-2608.md) | livebook-dev/livebook | [#2608](https://github.com/livebook-dev/livebook/pull/2608) | Proxy requests to the runtime | 10 | Behaviour across Attached/Embedded/Standalone + Session + ProxyPlug | discovered |

### Libraries (prior pass in this folder)

| File | Project | PR | Feature | Impl files | Why limit-testing | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [xl-absinthe-1.md](xl-absinthe-1.md) | absinthe-graphql/absinthe | [#1176](https://github.com/absinthe-graphql/absinthe/pull/1176) | Schema declaration directives (SDL + macro) | 14 | Blueprint → phases → notation → SDL render → persistent_term → introspection | discovered |
| [xl-cachex-1.md](xl-cachex-1.md) | whitfin/cachex | [#353](https://github.com/whitfin/cachex/pull/353) | Pluggable cluster routers | 14 | Behaviour + 4 routers + conductor + options/validator + actions | discovered |
| [xl-oban-1.md](xl-oban-1.md) | oban-bg/oban | [#347](https://github.com/oban-bg/oban/pull/347) | Ecto dynamic repositories | 10 | `Oban.Repo` facade + every DB-touching component | discovered |

## Project / license / runtime holds

| Project | License | Stack (historical) | Offline holds |
| --- | --- | --- | --- |
| pinchflat | AGPL-3.0 | Elixir/Phoenix/PG (2024 base) | PostgreSQL; mock YouTube HTTP (no live API) |
| mydia | AGPL-3.0 | Elixir ~> 1.20, Phoenix, SQLite/PG | One pinned DB adapter; no external player |
| beacon | MIT | Elixir/Phoenix/PG (2024 base) | PostgreSQL; deterministic Loader sync |
| livebook | Apache-2.0 | Elixir/Phoenix (2024 base) | No services (NoopRuntime); mix.lock dep line OK |
| absinthe | MIT | Elixir ~> 1.15 (2022) | None; yecc/Mix compile |
| cachex | MIT | Elixir ~> 1.7 (2024) | Cache `libring` offline |
| oban | Apache-2.0 | Elixir ~1.10 / OTP ~23 (2020) | PostgreSQL; verify old toolchain image |

## Cross-candidate notes

- **Application pilot order:** pinchflat #282 (spec-like fallback contract + issue #280) → mydia #1072 (authz + range) → beacon #578 (hot-reload) → livebook #2608 (runtime behaviour).
- **Library pilot order (unchanged):** Absinthe #1176 → Cachex #353 → Oban #347.
- Squash identity: parent of the merge commit is the historical base (pinchflat/beacon/livebook match; beacon PR API base lags — use merge parent). mydia #1072 is a **true merge**: first parent `423921b9…` is mainline base.
- Every dossier has a **compiling incomplete** that misses exactly one subsystem and named positive+negative checks.

## Explicitly not selected as XL applications (do not rediscover)

| Lead | Why not XL / disposition |
| --- | --- |
| teslamate #5543 MQTT HA discovery | ~7–8 impl + docs/nix — under the 10–20 impl window (large-feature reserve). MQTT broker is an offline hold. |
| teslamate #5065 dark mode | Theme/CSS-heavy; impl coherence weak for XL. |
| teslamate Grafana bump PRs (#4721, #4756, …) | Generated dashboard/deps noise. |
| vutuv #1759 @-mentions | ~8 Elixir + 2 JS + CSS + 4 gettext noise files; good feature but mechanical inflation — **reserve** if a JS-heavy XL slot is wanted. |
| vutuv #2215 / #2218 / #2225 fediverse | Fediverse delivery/offline external servers — defer for network holds. |
| livebook #2897 / #2906 / #2921 | Teams/org-status coupling; 2906 logout is thin. Defer with edition policy. |
| livebook #2936 Python cells | 24 files — over ceiling / runtime images. |
| livebook #2167 / #2309 | Previously deferred (21 / 17 paths, no ready contract). |
| changelog #322 transcript search | Algolia network dependency; ~8 impl. |
| changelog #201 / #339 / #559 / #562 | Already filed in app-mining. |
| nerves #431 remote IEx | Older (2020) UI/console; 15 files but weak offline oracle. |
| nerves #2822 deployment group notes | 13 files, mostly notes CRUD — borderline. |
| nerves 3117 | HOLD mega 52-file; only refile if a coherent 10–20 subset + written combined outcome is carved. |
| pinchflat #108 media streaming | 16 files but UUID migration + boot tasks mixed; overlaps mydia streaming family. |
| pinchflat #116 cookie auth | 12 files, config/Dockerfile heavy (7–8 real impl). |
| pinchflat #277 / #330 / #399 / #487 / #510 / #589 | Under-window or mixed housekeeping. |
| pinchflat 640/641/610/540/356/46/74/646/485/535/542/559 | Already filed — skip. |
| mydia 1119/1112/1083/1105/1095/1127/1150/1168 | Already filed — skip. |
| mydia 1047/1052/1053/1055/1067/1077/1081/1084/1086/1115/1116/1118/1121/1183/1185/1195 | MEGA (50–389 files) — reject as XL. |
| mydia 1045/1048/1064/1098/1113/1114/1119/1182/1184/1190/1194 | BIG (>20) or already filed. |
| beacon 687/713/727/774/775/681/672 | Already filed — skip. |
| beacon #740 always generate endpoints | 23 files — over ceiling. |
| craftplan 51/53/46/55/43/52 | Already filed; #40/#55 are mega traceability. |
| vutuv 2368/2373/2365 | Already filed — skip. |

## Recommended pilot order (XL)

1. **pinchflat #282** — clean issue link (#280), fallback contract, MIT-sized tests, AGPL app with PG.
2. **mydia #1072** — security-sensitive per-request authz; true merge identity documented.
3. **beacon #578** — CMS hot-reload path; MIT.
4. **livebook #2608** — interface-per-runtime; service-free.
5. Libraries: Absinthe #1176 → Cachex #353 → Oban #347.

## Next actions (folder-level)

1. Per dossier: pin base SHA → cache deps → unchanged/reference/incomplete/integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes. None of those gates is done here.
2. Do not grade exact error text (uniform 404 wording in mydia is product policy, not string match).
3. Keep AGPL/MIT/Apache-2.0 notices in provenance; do not open `cases/` bundles until qualification evidence exists.
4. Revisit vutuv #1759 and teslamate #5543 only if an additional JS-heavy or MQTT-slot case is requested.

## What was not verified (this folder)

- Any `mix compile` / `mix test` on these bases.
- Offline Hex availability and Elixir/OTP image compatibility.
- Whether upstream CI green at merge is reproducible here.
- Later follow-up commits touching the same files after each merge.
- Full text of linked issues (#280, #2090) beyond PR summaries.

HTML/diff/API retrieval date: **2026-10-19**. Diff files and PR JSON snapshots under [`_work/`](_work/).

**Curation policy, 2026-10-20:** before implementing a researched candidate, follow [prepared fork sources](../../../prepared-fork-sources.md) and inspect existing fork branches. Runnable cases must pin prepared fork baselines; a research shortlist is not an admitted inventory. The [source audit](../../../../verification/prepared-forks-2026-10-20/README.md) records branch reuse and migration evidence.
