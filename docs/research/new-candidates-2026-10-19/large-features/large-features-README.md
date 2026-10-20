# Large features — 2026-10-19

Limit-testing **feature** candidates from real Elixir applications: **5–10 substantive implementation files preferred** (4–12 acceptable when coherent). This pass is intentionally picky — six strong large features rather than many mediocre ones.

**Method:** GitHub HTML PR pages + `pull/N.diff` + `raw.githubusercontent.com` + HTML commit pages for merge parents (REST API rate-limited). **Not verified:** compilation, test execution, offline dependency fetch, or runtime boot. No commits and no `cases/` bundles.

Guidance: [pr-selection-guidelines.md](../../pr-selection-guidelines.md) — larger coherent tasks are allowed when outcome and environment are tractable; file count is a signal not a quota; ticket must not name the fix; offline fixtures required. Prior app mining: [app-mining/](../app-mining/). This folder’s dossiers refine and expand the best large features (including ones first screened in app-mining) into the limit-testing template.

---

## Section: apps

### Summary table

| File | Project | PR | Feature | Impl files (approx) | Why limit-testing | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [large-feature-mydia-1.md](large-feature-mydia-1.md) | getmydia/mydia | [#1119](https://github.com/getmydia/mydia/pull/1119) | Per-show TV metadata provider fallback (TVDB/TMDB) + pin | 12–15 | One policy across matcher, pin, refresh, Fix Match, two modals; offline stub provider | discovered |
| [large-feature-mydia-2.md](large-feature-mydia-2.md) | getmydia/mydia | [#1112](https://github.com/getmydia/mydia/pull/1112) | Disable library indexers without removing them | 8–10 | Membership vs enabled split must hold in changesets, search filters, admin UI, migration | discovered |
| [large-feature-pinchflat-1.md](large-feature-pinchflat-1.md) | kieraneglin/pinchflat | [#640](https://github.com/kieraneglin/pinchflat/pull/640) | Per-source `cookie_behaviour` on every yt-dlp consumer | 7–8 | Policy must agree at download, slow/fast index, metadata; data migration | discovered |
| [large-feature-pinchflat-2.md](large-feature-pinchflat-2.md) | kieraneglin/pinchflat | [#610](https://github.com/kieraneglin/pinchflat/pull/610) | Persist and display download errors on media items | 8–10 | Pipeline failure state ↔ schema ↔ media show + source + history tables | discovered |
| [large-feature-beacon-1.md](large-feature-beacon-1.md) | BeaconCMS/beacon | [#687](https://github.com/BeaconCMS/beacon/pull/687) | `sitemap.xml` per site + `sitemap_index.xml` | 5–6 | Multi-site URL correctness across routes, controller, templates, scoped prefixes | discovered |
| [large-feature-craftplan-1.md](large-feature-craftplan-1.md) | puemos/craftplan | [#51](https://github.com/puemos/craftplan/pull/51) | Cancel unconsumed production batches | 5 | Domain cancel ↔ allocation release ↔ consumption guard ↔ LiveView lifecycle | discovered |

### Project / license / runtime holds (this pass)

| Project | License | Stack (historical) | Offline holds |
| --- | --- | --- | --- |
| mydia | AGPL-3.0 | Elixir `~> 1.20`, Phoenix 1.8, Ecto + SQLite, LiveView, Oban, Guardian | Stub metadata provider in-tree (`test/support/metadata_stub_provider.ex`); no live TVDB/TMDB |
| pinchflat | AGPL-3.0 | Elixir `~> 1.17`, Phoenix, Ecto + SQLite (`ecto_sqlite3`), Oban, Mox yt-dlp | yt-dlp mocks; **no YouTube**; verify SQLite migrations |
| beacon | MIT | Elixir `~> 1.14` (this era), Phoenix, Ecto, multi-site routing (ProxyEndpoint from #694) | Controller tests only; no crawler network |
| craftplan | AGPL-3.0 | Elixir `~> 1.20`, Ash 3 + Ash Postgres, Absinthe, LiveView | PostgreSQL; cache Ash/native deps; exclude object storage |

### Cross-candidate notes

- **Prefer mydia #1119 first** if only one large feature enters a pilot: clearest multi-subsystem policy, authentic FR #1117, and an offline stub already in the PR tests.
- **Mydia #1119 and #1112** are distinct families (metadata provider policy vs indexer status model) but share one app runtime — resolve SQLite/deps once.
- **Pinchflat #640 and #610** are distinct (cookie policy vs failure-state UI). #559 (settings sleep + throttle titles) was screened in app-mining as another 6–8 file feature; keep as reserve if a third Pinchflat slot exists.
- **Craftplan #51** is the best Ash app feature; pair runtime work with craftplan #53 (allergens) only after Ash is proven.
- **Beacon #687** depends on #694 (ProxyEndpoint) already in the starting tree at the recorded base — do not require solvers to re-implement multi-domain proxying.
- All AGPL/MIT notices must appear in case provenance.

### Explicitly not selected this pass (do not rediscover as “large features”)

| Lead | Why not |
| --- | --- |
| mydia #1111 (split ImportCandidates) | Pure refactor, “no behaviour change” — guidelines reject cleanup with no observable outcome. |
| mydia #1119 partial only in UI or only in matcher | That is the *incomplete control*, not a separate case. |
| plausible #5008 (multi team owners) | ~91 files — mega feature dump. |
| plausible #3828 (country shield) | ~32 files — too broad / mixed. |
| plausible #5381 (form submission events) | **JavaScript tracker only** — not Elixir application implementation. |
| plausible #4899 (saved segments API) | 5 impl files, coherent API — borderline “large”; keep as **reserve** if an API-family slot is wanted; not in Plausible’s original inventory (5939/5956/6300/6441/6449/6763). |
| teslamate recent closed PRs (58xx) | Mostly 1–3 file fixes, docs, deps, Rust/Nix; no 5–10 file Elixir feature found this pass. Existing teslamate candidates (5781, 5827, …) stay in app-mining as smaller features/bugs. |
| changelog.com #322/#358 | Mixed search/email/index work or asset noise; not clean 5–10 file product features. |
| operately Milestone V2 series (3270–3299) | Many small incremental PRs — combining them would violate “one coherent PR” rules. Operately #1069 remains the small subscription-dedup case. |
| livebook #3169 and earlier six cases | Already inventoried in multi-file / livebook audits; not re-mined here. |
| beacon #717 (JS hooks) | Coherent feature but heavy generated JS (`priv/static/beacon.js`, minified bundles) + thin PR body; **hold** as reserve if generated-asset cases are wanted later. |
| beacon #694 (ProxyEndpoint) | Infrastructure/multi-domain serving; prerequisite for #687 rather than the scored feature. |

### Recommended pilot order

1. **mydia #1119** (best limit-testing signal) + one of **beacon #687** (MIT, light) or **pinchflat #640** (mocked external CLI).
2. Second wave: mydia #1112 and pinchflat #610 once those runtimes are cached.
3. craftplan #51 only after Ash/Postgres qualification is proven with one smaller craftplan case if needed.

### Next actions (folder-level)

1. Per dossier: pin base SHA → cache deps → unchanged/reference/incomplete/integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes. None of those gates is done here.
2. Freeze product policies in each brief (especially pinchflat #640 merge-time cookie rule and mydia #1119 empty-vs-error fallback).
3. Keep license notices in provenance; do not open `cases/` bundles until qualification evidence exists.
4. If more large features are needed later, mine operately non-Milestone product PRs, changelog admin/feed features with clean Elixir-only diffs, and plausible reserves (#4899) — not another Pinchflat cookie/settings variant.

### What was not verified (this folder)

- Any `mix compile` / `mix test` / credo run on these bases.
- Offline Hex/git dependency availability and exact Elixir/OTP image compatibility.
- Whether upstream CI green at merge is reproducible here.
- Rate-limited REST metadata beyond HTML snapshots (2026-10-19).

HTML/diff/raw retrieval date: **2026-10-19**.

---

## Section: libraries

Limit-testing **feature** candidates from Elixir libraries/frameworks: **5–10 substantive implementation files**, coherent multi-module work with a clear public API and tests. Not mega-refactors, not deps, not docs-only. Skipped identities already deep-researched elsewhere (Ecto #4726/#4734/#4750, Phoenix #6840, Ash #3031, Cachex #407, Guardian #748, LiveView #4250/#4332, nimble_parsec #154, thousand_island 220/222/228, phoenix_pubsub 209/218, redix 351/356, …).

**Method:** GitHub HTML PR lists + `pull/N.diff` + `raw.githubusercontent.com` mix.exs/LICENSE + REST PR metadata for bodies (rate-limited). **Not verified:** compile, tests, offline deps, or runtime boot. No commits and no `cases/` bundles.

### Summary table

| File | Project | PR | Feature | Impl files | Why limit-testing | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [large-feature-absinthe-1.md](large-feature-absinthe-1.md) | absinthe-graphql/absinthe | [#1404](https://github.com/absinthe-graphql/absinthe/pull/1404) | Document descriptions on operations and fragments (GraphQL Sept 2025) | 6 | yecc grammar → Language AST → Blueprint → SDL render must agree | discovered |
| [large-feature-cachex-1.md](large-feature-cachex-1.md) | whitfin/cachex | [#341](https://github.com/whitfin/cachex/pull/341) | Named warmer processes + selective `Cachex.warm/2` | 8 | Spec/validator/incubator/services/warm-action naming policy | discovered |
| [large-feature-cachex-2.md](large-feature-cachex-2.md) | whitfin/cachex | [#306](https://github.com/whitfin/cachex/pull/306) | Scheduled LRW eviction policy | 5 | Shared LRW algorithm + Evented/Scheduled split + service start | discovered |
| [large-feature-broadway-1.md](large-feature-broadway-1.md) | elixir-broadway/broadway | [#344](https://github.com/elixir-broadway/broadway/pull/344) | Pluggable config storage (`:ets` / `:persistent_term`) | 5 | Behaviour + two stores + Topology lifecycle get/put/delete | discovered |
| [large-feature-ecto_sql-1.md](large-feature-ecto_sql-1.md) | elixir-ecto/ecto_sql | [#703](https://github.com/elixir-ecto/ecto_sql/pull/703) | MyXQL `insert_mode: :ignore_errors` (INSERT IGNORE) | 6 | Connection behaviour + SQL façade + MyXQL/Postgres/TDS adapters | discovered |

### Project / license / runtime holds (this pass)

| Project | License | Stack (historical) | Offline holds |
| --- | --- | --- | --- |
| absinthe | MIT | Elixir `~> 1.15`, yecc parser, ExUnit | No services; parser compile via Mix |
| cachex | MIT | Elixir `~> 1.5` (3.4–3.6 era), ETS, ExUnit | No services; #306 tests are timing-sensitive |
| broadway | Apache-2.0 | Elixir `~> 1.7`, OTP persistent_term/ETS | No services; storage tests mutate app env (`async: false`) |
| ecto_sql | Apache-2.0 | Elixir `~> 1.14`, adapter SQL builders | Unit SQL tests need no DB; integration upsert needs MySQL |

### Cross-candidate notes

- **Prefer Absinthe #1404 first** for a library pilot: freshest (2026), MIT, no services, 26 named tests, external GraphQL spec as the contract.
- **Cachex #341 and #306** are distinct families (warmer supervision vs limit eviction) on one runtime — resolve Cachex deps once if both enter a release.
- **Broadway #344** and **ecto_sql #703** add OTP-storage and SQL-adapter diversity; ecto_sql unit tests can run offline while integration stays optional.
- Keep Apache-2.0 notices for Broadway/ecto_sql in provenance; MIT for Absinthe/Cachex.

### Explicitly not selected this pass (do not rediscover as library “large features”)

| Lead | Why not |
| --- | --- |
| Absinthe #1377 `@defer`/`@stream` | **42 files / +8887** — mega incremental-delivery subsystem. Too large even for limit-testing; do not carve unofficial subsets. |
| Absinthe #1386 `@oneOf` | 4 impl files (below 5); excellent focused reserve for a GraphQL-spec family. |
| Absinthe #1176 schema declaration directives | 14 impl files — over the 5–10 window; mega schema-pipeline work. |
| Cachex #167 introduce warming | 7 impl and foundational, but **2018 / Elixir `~> 1.2`** — weak historical toolchain fit; prefer #341 which builds on warmers already in tree. |
| Cachex #171 streaming match queries | 9 impl but framed as refactor/Util removal; contract is ETS match API reshaping — needs a separate structural brief. |
| Cachex #353 customizable routers | 14 impl — over window; cluster/router rewrite. |
| Cachex #426 5.x API naturalization | 110 files — mega API rewrite. |
| Broadway #363 process labels | 5 impl but tiny per-file surface; thin named tests — reserve. |
| Bandit #707 chunked compression | 3 impl — under window (good focused reserve). |
| Oban #1400 snoozing | 4 impl — under window (good focused reserve). |
| Phoenix LiveView #4441 PubSub integration | 3 Elixir impl + tests — under window. |
| Phoenix LiveView #4336 diagnostics event | 15 JS files — over window and browser-heavy. |
| Ash #3012 signals | 33 files / +4958 — mega feature. |
| Guardian #748 runtime secrets | Already researched in auth-policy-candidates-2026-10-18. |
| Ecto_sql #748 BooleanExpr join ons | In the skip list (748). |
| Ecto #4750 splice params | In the skip list (4750). |
| ecto_sql #703 integration-only MySQL acceptance | Keep unit SQL as offline family; do not require live MySQL for admission. |

### Recommended pilot order

1. **Absinthe #1404** (spec-backed, service-free) + **Broadway #344** (OTP storage, light).
2. **Cachex #341** then **#306** if a second library runtime is wanted.
3. **ecto_sql #703** with unit-SQL acceptance; add MySQL integration only when a DB service is already proven.

### Next actions (folder-level)

1. Per dossier: pin base SHA → cache deps → unchanged/reference/incomplete/integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes. None of those gates is done here.
2. Freeze public API names in each brief (Absinthe descriptions scope; Cachex warmer `name` + `warm` `only`; Broadway `config_storage`; ecto_sql `insert_mode: :ignore_errors`).
3. Do not grade Cachex #306’s unsettled `enforce_bounds` symbol.
4. If more library large features are needed later: Absinthe #1386 (`@oneOf`, 4 files) and Bandit #707 (3 files) as focused reserves — not another Cachex API naturalization.

### What was not verified (this section)

- Any `mix compile` / `mix test` on these bases.
- Offline Hex availability and exact Elixir/OTP image fit (especially Cachex 2023–2024 and ecto_sql sibling `ecto` pin).
- Later follow-up commits to the same files after each merge.
- Integration DB behavior for ecto_sql #703 (unit SQL only).

HTML/diff/raw retrieval date: **2026-10-19**.

**Curation policy, 2026-10-20:** before implementing a researched candidate, follow [prepared fork sources](../../../prepared-fork-sources.md) and inspect existing fork branches. Runnable cases must pin prepared fork baselines; a research shortlist is not an admitted inventory. The [source audit](../../../../verification/prepared-forks-2026-10-20/README.md) records branch reuse and migration evidence.
