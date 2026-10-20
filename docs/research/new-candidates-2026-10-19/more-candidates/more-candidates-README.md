# More candidates — 2026-10-19 (trusted apps, new PRs)

Additional SWE-bench candidates from projects we already trust. **Four** new strong cases (quality over per-project quotas). This README indexes the **trusted-apps batch only** (teslamate / pinchflat / changelog / beacon / mydia). Sibling `more-*.md` files in this folder may cover other project sets; they are not summarized here. None of these PR numbers appear in `app-mining/`, `large-features/`, or `large-features/deep-dive/` (those already cover teslamate 5781/5782/5820/5823/5827, pinchflat 485/535/542/559/610/640/641, changelog 339/559/562, beacon 672/681/687/729/760, mydia 1083/1105/1112/1119/1127/1150/1168).

**Method:** GitHub HTML PR pages + `pull/N.diff` + commit pages for first-parent / squash parents (REST API rate-limited). **Not verified:** full `mix compile` / `mix test`, offline Hex cache, or runtime boot. No commits and no `cases/` bundles.

**Guidance:** [pr-selection-guidelines.md](../../pr-selection-guidelines.md), [LINEAGE-MERGE-POLICY.md](../large-features/LINEAGE-MERGE-POLICY.md). Combined lineages allowed when a follow-up is an obvious improvement; ticket = final behavior. None of these four required a lineage merge (see notes).

---

## Summary table

| File | Project | PR | Kind | Impl files | Why strong | Status |
| --- | --- | --- | --- | ---: | --- | --- |
| [more-beacon-713.md](more-beacon-713.md) | BeaconCMS/beacon | [#713](https://github.com/BeaconCMS/beacon/pull/713) | bug_fix | 5+1 fixture | Multi-node media upload ownership: metadata.node + `:erpc` reads must agree across library, processors, loader | discovered |
| [more-mydia-1095.md](more-mydia-1095.md) | getmydia/mydia | [#1095](https://github.com/getmydia/mydia/pull/1095) | bug_fix | 3 | Copy succeeds when SMB/NFS refuses chmod; one helper must back organizer, trash, and storage entry | discovered |
| [more-pinchflat-646.md](more-pinchflat-646.md) | kieraneglin/pinchflat | [#646](https://github.com/kieraneglin/pinchflat/pull/646) | feature | 4+1 migration | Optional download throughput limit: schema/form/runner policy; upstream named CLI checks | discovered |
| [more-beacon-727.md](more-beacon-727.md) | BeaconCMS/beacon | [#727](https://github.com/BeaconCMS/beacon/pull/727) | bug_fix | 4 | Content-encoding negotiation for runtime CSS/JS (br > gzip > raw) across ETS + controller | discovered |

Mix: three coordinated 2–5 file bugs/features and one slightly larger coordinated asset-pipeline bug (6 files including fixture). No 5–10 file “large feature” was added this pass — the only such lead (mydia S3 #1077+#1081) is 120+/60+ files and belongs to a mega-feature screen, not this batch.

## Identity SHAs (verified first-parent / squash)

| Case | Merge commit | Parent to pin as base | Merge style |
| --- | --- | --- | --- |
| beacon-713 | `cc0ca8e9c6e28326cc0feacceea2081adfcae3de` | `9db90ad9e9f871e9d74626fe5152af70af58e567` | squash (1 parent) |
| mydia-1095 | `60ed46b3c03689e3df61222568b872e38af6fbb1` | **`e8b45af9b0441ec8600a8113e2c74a080566578e` (first parent)** | **merge (2 parents)**; PR head `6b33cd06fe24826d069c0f51932c3e344d817b60` |
| pinchflat-646 | `4554648ba7facfc8ed7cdff0ed1689052044d42f` | `0fbf810cb672c588e019e8acd86cd07cc3bb2d94` | squash (1 parent); exclude `priv/repo/erd.png` |
| beacon-727 | `6e69859a7f9d20263055f78f020c5cc1daf8ab12` | `8ce6717d86bce85248ee86ad691f9029411b7d87` | squash (1 parent) |

## Cross-candidate notes

- **Two Beacon cases (#713, #727) share a project but not a subsystem** (media library ownership vs asset encoding). Runtime (Elixir/Phoenix/Ecto, MIT) can be resolved once; tasks are independent families.
- **mydia-1095 is a merge commit** — always pin first-parent `e8b45af9…`, never the merge tip, when building the starting tree.
- **pinchflat-646** is a third Pinchflat family alongside cookie policy (640+641) and download errors (610): bandwidth policy. Do not fold into the cookie lineage.
- **beacon-727 vs #716** (retry CSS load): parallel fixes in the same pipeline; policy says do **not** staple them. If #716 is selected later, note shared files only.

## Explicitly looked at and not filed (do not rediscover as “new”)

| Lead | Why not a case file here |
| --- | --- |
| mydia #1077 + #1081 (S3 read + write path) | Authentic and combinable, but **120 + 67 files** — mega feature dump; over the 5–10 window even for limit-testing. Revisit only with a carved, reviewable subset brief. |
| changelog #570 (PlusPlus chapters when `audio_chapters` empty) | Rich tests, **closed without merge** (`mergedTime: null`, `mergeCommitSha: null`). Head commit `c0aff54…` exists but provenance is not a merged PR — defer until a merged identity or a reconstruction brief is approved. |
| changelog #563 (unique episode-backed news identities) | **Merged** (`39d0178…`), but implementation is one uniqueness migration + two test files — too thin as a 2–5 file flagship. Focused reserve if a data-integrity slot is wanted. |
| changelog #560 (data-backed meta podcast hosts) | 1 impl file (`podcast.ex`) + tests — focused reserve, not multi-file. |
| changelog #543 (Fly.io region resilience) | Infra/docs (`INFRASTRUCTURE.md`, `justfile`) — not an application task. |
| teslamate #5862 (MQTT never publish smaller odometer) | 1 impl file + 1 test — good focused bug; thin for this batch’s multi-file bar. |
| teslamate #5821 (VIN label in settings) | Same outcome family as **already filed** #5827 (VIN labels on other screens). Sibling only; do not score independently without a combined VIN-labeling case. |
| pinchflat #540 (forced indexing / download archive) | 5 impl + tests (~10 paths) — solid **reserve** large-ish feature if a second Pinchflat feature slot opens; not filed here to keep the batch at four. |
| pinchflat #606 (multiple YouTube API keys) | 3 files, settings-flag style — overlaps the “settings → yt-dlp” family with #646; prefer #646 (clearer named CLI checks). |
| pinchflat #581 / #609 / #618 | 1 impl + 1 test each — focused reserves (indexing, members-only retry, shorts detection). |
| beacon #716 (retry CSS asset loading) | 4 impl, **no tests in PR**; parallel to #727, not an obvious follow-up. Reserve. |
| beacon #700 (`robots.txt` per site) | Lineage-adjacent to **already filed** #687 sitemap; URL placement redesigns (#740/#746/#749) stay separate per LINEAGE-MERGE-POLICY. |

## Recommended next actions (folder)

1. Per dossier: pin the listed base SHA → `pull/N.diff` (strip `erd.png` / optional `dev.exs`) → unchanged / reference / plausible-incomplete / integrity controls → three fresh qualification rounds → independent contract review → two blind strong-model successes.
2. **mydia-1095** needs a refused-chmod stub (or a real FUSE/SMB mount) before checks 4–5 are fair.
3. **beacon-713** needs a two-node or `:erpc` double harness; the PR ships fixture updates but no multi-node test file.
4. **pinchflat-646**: keep `erd.png` out of graded diffs; do not grade option-order beyond the sleep-interval adjacency already in tests.
5. **beacon-727**: decide whether `dev.exs` stays mechanical; assert header/body pairs, not compressed-byte equality.
6. Keep AGPL (mydia, pinchflat) and MIT (beacon) notices in provenance. No `cases/` bundles until qualification evidence exists.

## What was not verified

- `mix compile` / `mix test` at any of the four bases.
- Offline dependency availability and exact Elixir/OTP image fit.
- Whether upstream CI green at merge is reproducible here.
- Full parent graphs beyond the squash/merge parent shown on each commit page (2026-10-19).

HTML/diff/commit retrieval date: **2026-10-19**.
