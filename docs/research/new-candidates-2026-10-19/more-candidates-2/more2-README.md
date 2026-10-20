# More2 candidates — 2026-10-19 (second-pass PR mining)

Second-pass SWE-bench candidate dossiers written under `more-candidates-2/`. Two complementary batches landed in this folder: an **application** pass (trusted apps) and a **library/framework** pass. No commits and no `cases/` bundles.

**Method (both batches):** GitHub HTML PR pages + `pull/N.diff` + merge-commit pages + raw `mix.exs`/`LICENSE` sidecars (REST API rate-limited on some repos). **Not verified:** full `mix compile` / `mix test`, offline Hex cache, or runtime boot.

**Guidance:** [pr-selection-guidelines.md](../../pr-selection-guidelines.md), [LINEAGE-MERGE-POLICY.md](../large-features/LINEAGE-MERGE-POLICY.md). Combined lineages allowed when a follow-up is an obvious improvement; ticket = final behavior.

---

# Section A — Library / framework batch

Elixir library and framework PRs, skipping identities already filed in `more-candidates/`, `large-features/`, or `docs/research/`. **Five** new strong cases: three coordinated 2–5 file tasks, **one 5–10 file feature**, and two obvious lineages.

**Skip list honored:** ecto 4750/4726/4734/4697, plug 1269, phoenix 6840/6762, oban 1400/1199/1509, absinthe 1404/1377/1386/1438/1439/1290, cachex 341/306/407/411/403, broadway 344/369/289, ecto_sql 703/699/741/758/748, pubsub 209/218/210/220, TI 228/220/222/216, redix 351/356/350, nimble_parsec 154, ash 3031/3039, phoenix_html 474/475/468, live_dashboard 487/495, guardian 748, bandit 705/671/673/688/695/707, live_view 4250/4332, tesla 939, mint 514/496, req 337, finch 391.

## A. Summary table

| File | Project | PR(s) | Kind | Impl files | Why strong | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [more2-ecto_sql-738-753-760.md](more2-ecto_sql-738-753-760.md) | elixir-ecto/ecto_sql | [#738](https://github.com/elixir-ecto/ecto_sql/pull/738) + [#753](https://github.com/elixir-ecto/ecto_sql/pull/753) + [#760](https://github.com/elixir-ecto/ecto_sql/pull/760) | bug_fix (lineage) | 3 | SQL operator precedence for `not`/`in`/`is_nil` as operands — coordinated across Postgres, MyXQL, TDS | discovered |
| [more2-thousand_island-206-208-209.md](more2-thousand_island-206-208-209.md) | mtrudel/thousand_island | [#206](https://github.com/mtrudel/thousand_island/pull/206) + [#208](https://github.com/mtrudel/thousand_island/pull/208) + [#209](https://github.com/mtrudel/thousand_island/pull/209) | bug_fix (lineage) | 4 | Acceptor-loop resilience: fd exhaustion, transient accept errors, handler start failure | discovered |
| [more2-phoenix-6871.md](more2-phoenix-6871.md) | phoenixframework/phoenix | [#6871](https://github.com/phoenixframework/phoenix/pull/6871) | feature | 2 | `:max_channels_per_transport` on `socket/3` — endpoint → transport → join limit, both websocket and longpoll | discovered |
| [more2-ueberauth-217.md](more2-ueberauth-217.md) | ueberauth/ueberauth | [#217](https://github.com/ueberauth/ueberauth/pull/217) | feature (security) | 1+dep | Sign+verify OAuth state nonce cookie; CSRF rejection before provider; new project | discovered |
| [more2-thousand_island-211.md](more2-thousand_island-211.md) | mtrudel/thousand_island | [#211](https://github.com/mtrudel/thousand_island/pull/211) | feature | **7** | `handshake_timeout` server option + optional `Transport.handshake/2` across config, socket, SSL, TCP | discovered |

Mix: two lineage bugs (3–4 impl each), two coordinated 2–5 features, one **5–10 file feature** (TI #211, 7 impl). Two Thousand Island files cover **different subsystems** (acceptor loop vs handshake/config) and are independent families.

## A. Identity SHAs (squash merges; pin first parent as base)

| Case | Merge commit | Notes |
| --- | --- | --- |
| ecto_sql-738 | `04191cba289b76da5575b3516bc676ec9bae3419` | First of the precedence lineage |
| ecto_sql-753 | `23857635127b8e94031847dd7522923e48b80150` | Postgres `in`/`is_nil` left-operand fix |
| ecto_sql-760 | `254792d0fb4dc02757a07428127eada77591cf72` | `in` as operand; apply after 738+753 |
| TI-206 | `14de02fc6e86b79b1837e8cc6d66b2944c275301` | emfile/enfile back-off |
| TI-208 | `0453daf2ec954abe1c5ac59ea4b73eec6af26826` | transient accept(2) errors |
| TI-209 | `8c3199730cbf85faff75bf69996873d50fd1e68b` | handler start failure; apply after 206+208 |
| phoenix-6871 | `3fc1fb16c2fb7b4c37ee6e6f85a8f8fbbda5905e` | 1 commit |
| ueberauth-217 | `b02dc2d8b72754665f4b90b87d9362e49a18f6b2` | 1 commit; Plug floor `~> 1.10` |
| TI-211 | `a2858bbe3d5196c75028fccade983fd8486321ba` | 7-commit PR, squash-merged; independent of 206–209 |

All listed merges are **squash (1 parent)**. Reconstruct at the merge's first parent and apply `pull/N.diff` (or apply the lineage diffs in the order shown).

## A. Lineage decisions

| Lineage | Action | Intermediate = incomplete control |
| --- | --- | --- |
| ecto_sql #738 → #753 → #760 | **One case.** Ticket describes final precedence behaviour across the three adapters. | #738-only, or #738+#753 without #760 |
| TI #206 → #208 → #209 | **One case.** Same author, same day, same acceptor loop. Ticket describes surviving all three recoverable classes. | #206-only, or #206+#208 without #209 |
| TI #211 vs #206–209 | **Keep separate.** Handshake bound (config/transport) is not acceptor-loop resilience. | n/a |
| phoenix #6871 | No lineage needed. | websocket-only wiring |
| ueberauth #217 | No follow-up PR. | sign-only without verify |

## A. Cross-candidate notes

- **Two Thousand Island cases share a project and runtime (MIT, Elixir `~> 1.13`) but not a subsystem.** Resolve runtime once; tasks are independent. Do not staple them into one case.
- **ecto_sql precedence lineage is the flagship coordinated bug**: three adapters must agree on parenthesization; tests assert generated SQL strings (no live DB). Distinct from filed ecto_sql 703 (insert_mode), 741 (read-only tx), 758 (migration callbacks).
- **phoenix-6871** is a public-option plumbing task (endpoint macro → transport config → channel join enforcement). Avoid over-concentrating on URL validation (already filed as 6840/LiveView 4250 family).
- **ueberauth-217 is a new project** (MIT, Elixir `~> 1.14`, pure Plug/ExUnit). Adds OAuth/CSRF security family. Guardian 748 is skip-listed and a different project.
- TI-211's optional `handshake/2` callback is a real extension point; the legacy `handshake/1`-only fallback is a named obligation (do not grade private dispatch style).

## A. Explicitly looked at and not filed (library pass)

| Lead | Why not a case file here |
| --- | --- |
| ash #3012 (introduce signals) | Authentic feature but **~25 implementation files** — mega feature dump; over the 5–10 window. Revisit only with a carved subset brief. |
| redix #345 (multi-node pool clusters) | Solid cluster work, but only **2 impl files** (`cluster.ex`, `manager.ex`) + docs/tests; #346/#347/#348 are follow-ups. Coherent reserve if a Redix cluster slot opens. |
| phoenix_live_view #4441 (PubSub integration) | 3 impl (`live_view.ex`, `channel.ex`, `pubsub.ex`) — good coordinated feature; held to keep the batch at five and prefer a new project (ueberauth). Reserve. |
| phoenix_live_view #4449/#4452/#4454/#4468 (uploads) | Mostly JS/TS + e2e specs; needs Node/browser grading adapter. Defer for execution support. |
| guardian #745 (reject non-numeric JWT time claims) | Good 2-file coordinated bug (`jwt/verify.ex` + `verify.ex`); focused reserve if a second auth slot opens. |
| phoenix_pubsub #197+#198 (pool sizing) | Related but #197 is a migration option and #198 is Registry pool split — product choices need a clarified brief. Defer. |
| absinthe #1416 (PartitionSupervisor for subscriptions) | 2 impl files; thin. Skip-list already covers the oneOf/description family. |
| ecto #4801 (keep interpolated `true` filters) | 1 impl + 1 test; subtle `add_filter` logic but thin for this batch's multi-file bar. Focused reserve. |
| ecto #4790 (`exists?` + combinations) | 1 impl + 1 test. Focused reserve. |
| ecto_sql #750 (migrator version bookkeeping) | 1 impl + 1 test. Focused reserve. |
| ash #3027/#3028 (bulk before_action / after_batch notifications) | 1 impl each; good bugs but thin. #3028's notification-pairing helper is a nice focused reserve. |
| cachex #432 / #419 / #402 | Skip-adjacent cachex work already covered; no new 2–5 flagship. |
| bandit / oban / broadway / gen_stage | REST search rate-limited or 422 this pass; revisit with authenticated API if a slot opens. |

## A. Next actions (library batch)

1. Per dossier: pin the listed base SHA → apply `pull/N.diff` in lineage order → unchanged / reference / plausible-incomplete / integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes.
2. **ecto_sql lineage**: grade generated SQL (or precedence-equivalent), not private helper names; use "#738 only" as the incomplete control.
3. **TI acceptor lineage**: `FlakyTransport` / `FailInitHandler` harness is in the upstream tests; keep sleep-based tests as behavior checks, not timing scores.
4. **TI-211**: freeze `:handshake_timeout`, optional `handshake/2`, and `:timeout` error reason from the brief; legacy-transport fallback is the incomplete control.
5. **phoenix-6871**: exercise both websocket and longpoll; keep the compile-time `ArgumentError` for invalid values visible in the brief.
6. **ueberauth-217**: rejection must happen **before** the provider callback; pin Plug `~> 1.10`. Keep MIT notice in provenance.
7. Apache-2.0 (ecto_sql) and MIT (TI, phoenix, ueberauth) notices in provenance.

---

# Section B — Application batch (trusted apps)

Application-level dossiers in this same folder (parallel pass). Each file is self-contained; this section indexes them only.

| File | Project | PR(s) | Kind | Why strong | Status |
| --- | --- | --- | --- | --- | --- |
| [more2-beacon-1.md](more2-beacon-1.md) | BeaconCMS/beacon | [#774](https://github.com/BeaconCMS/beacon/pull/774) + [#775](https://github.com/BeaconCMS/beacon/pull/775) | feature (lineage) | Media library URL helpers + provider API; #775 stacked on #774 | screened |
| [more2-changelog-201.md](more2-changelog-201.md) | thechangelog/changelog.com | [#201](https://github.com/thechangelog/changelog.com/pull/201) | feature | JSON Feed endpoint for news (fixes #196); query + routing + serialization | discovered |
| [more2-craftplan-1.md](more2-craftplan-1.md) | puemos/craftplan | [#43](https://github.com/puemos/craftplan/pull/43) | bug_fix | Product deletion cascade + recipe removal (fixes #41); 13 files | screened |
| [more2-craftplan-2.md](more2-craftplan-2.md) | puemos/craftplan | [#52](https://github.com/puemos/craftplan/pull/52) | bug_fix | Batch-sheet scientific notation optional (fixes #48); 8 files | screened |
| [more2-nerves_hub_web-1.md](more2-nerves_hub_web-1.md) | nerves-hub/nerves_hub_web | [#3117](https://github.com/nerves-hub/nerves_hub_web/pull/3117) | feature (large) | Organization webhooks for device events; 52 files — Slack follow-ups explicitly not merged | screened |
| [more2-pinchflat-356.md](more2-pinchflat-356.md) | kieraneglen/pinchflat | [#356](https://github.com/kieraneglen/pinchflat/pull/356) | feature | Min/max media duration filters on sources; schema + query + form | discovered |
| [more2-pinchflat-46-74.md](more2-pinchflat-46-74.md) | kieraneglen/pinchflat | [#46](https://github.com/kieraneglen/pinchflat/pull/46) + [#74](https://github.com/kieraneglen/pinchflat/pull/74) | feature (lineage) | Audio-only downloads; #74 completes #46's incomplete audio path | discovered |
| [more2-pinchflat-540.md](more2-pinchflat-540.md) | kieraneglen/pinchflat | [#540](https://github.com/kieraneglen/pinchflat/pull/540) | feature (5–10) | Overhaul indexing (force + download archive); slow-indexing workers + yt-dlp collection | discovered |
| [more2-teslamate-3943.md](more2-teslamate-3943.md) | teslamate-org/teslamate | [#3943](https://github.com/teslamate-org/teslamate/pull/3943) | bug_fix | Honor Retry-After on HTTP 429; 3 coordinated files (API → scheduler) | discovered |
| [more2-vutuv-1.md](more2-vutuv-1.md) | wintermeyer/vutuv | [#2368](https://github.com/wintermeyer/vutuv/pull/2368) | feature (security) | Link spam: signup trap, nofollow, auto-freeze; 33 files | screened |

App-batch identity SHAs, lineage notes, and next actions live in each dossier. Notable: **nerves_hub_web #3117 is a large feature (52 files)** whose Slack follow-ups (#3119–#3123) are stacked on it but are a **new channel**, not a hole in the webhook contract — keep #3117 alone per LINEAGE-MERGE-POLICY. **pinchflat #46+#74** and **beacon #774+#775** are explicit lineage merges.

### B1. Identity SHAs — teslamate / pinchflat / changelog.com (verified squash parents)

| Case | Merge commit | Parent to pin as base | Notes |
| --- | --- | --- | --- |
| teslamate-3943 | `b900a98d08c227c0ffe780cae807a0f239284965` | **`f34c0876e80171cc4f41b78ad26d6f0652339491`** | 1 parent; PR API base was older — use squash parent; exclude `.gitignore` |
| pinchflat-356 | `af8235c6b326d5901a242282c8ea327167e0c633` | `8e9f02c8078bdba882830df0b54c2efee46e535a` | 1 parent; exclude `priv/repo/erd.png` |
| pinchflat-46-74 | #46 `fc52f16475ef9962c9f4cee834b0d261053ef206` / #74 `7e4f1a8412ee492fcb9b992f76b8b0bab97f8d85` | **`8cc36928f1e45c727f62b21dd2acda2624553954`** (before either) | reference = #74 tree; incomplete = #46 tree |
| changelog-201 | `1d7a8eba21c7c622cfcf22458c5a9c7b43bb5547` | **`4f53b9da20b9a5bad57eac62d1d586919308bcd5`** | 1 parent; PR API base was older |
| pinchflat-540 | `9185f075ca3dc9fe37721b9d3f4a6188183007d8` | `09d1653f4b8d506b4dc9f03c1e8daf01ee0b6fa5` | 1 parent; optional 5–10 slot |

**Identity rule:** pin the squash commit’s sole parent from the commit page, not the PR API `base` when they disagree (teslamate-3943, changelog-201).

Skip list honored for this sub-batch: teslamate 5781/5782/5820/5823/5827/5847; pinchflat 485/535/542/559/610/640/641/646/802/836/838; changelog.com 339/559/562. Notable reserves not filed here: teslamate #3940/#3962/#3813 (thinner/separate stories), pinchflat #144/#383/#176/#660 (same profile→options family as 356/46-74), changelog #378/#417/#322 (larger).

---

## Evidence artifacts (`_work/`)

| Pattern | Contents |
| --- | --- |
| `*.diff` | Raw `pull/N.diff` for every filed and screened lead (library + app) |
| `*.html` | PR HTML pages (titles, authors, merge SHAs) |
| `commit-*.html` | Merge-commit pages for filed identities |
| `*-mix.exs`, `*-LICENSE*` | Raw sidecars for Elixir/license requirements |

## What was not verified (both batches)

- `mix compile` / `mix test` at any base.
- Offline dependency availability and exact Elixir/OTP image fit.
- Whether upstream CI green at merge is reproducible here.
- Full parent graphs beyond the squash/merge parent shown on each commit page (2026-10-19).
- REST API metadata for bandit/oban/broadway (rate-limited/422); those library leads are not filed.

HTML/diff/commit retrieval date: **2026-10-19**.
