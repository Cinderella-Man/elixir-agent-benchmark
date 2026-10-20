# More2 candidate — beacon PRs #774+#775 (media library URL helpers + provider API)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR **lineage** (combined under LINEAGE-MERGE-POLICY: #775 is stacked on #774 and completes the same media-API story)
**Project:** [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR A URL | https://github.com/BeaconCMS/beacon/pull/774 |
| PR A title | feat(media library): add media_{path/url} utility functions |
| PR B URL | https://github.com/BeaconCMS/beacon/pull/775 |
| PR B title | chore: improve media library API |
| Author | **leandrocp** (maintainer) |
| PR A merge (squash) | `f75e878c10b24916a149b57764654ada4aeb9b39` (1 parent `e862412a9fd6c89bed593b5d5dfb0883a78c8487`) |
| **PR A base (parent of squash A)** | `e862412a9fd6c89bed593b5d5dfb0883a78c8487` |
| PR B merge (squash) | `1fdd517443aed63cd00e82b5c540d1ffc11e789c` (1 parent `f75e878c…`) |
| **PR B parent = PR A squash** | `f75e878c…` — lineage stacking **verified** on commit API |
| Combined reference | tree at `1fdd5174…` (= A then B) |
| Incomplete control | tree at `f75e878c…` (= A only) |
| Diffs | https://github.com/BeaconCMS/beacon/pull/774.diff , `.../pull/775.diff` |
| Scale | A: 1 file +38/−4; B: 4 files +103/−44 (combined 4 paths) |

License: **MIT**. Mix: Elixir, Phoenix. No services beyond optional S3 provider (not required for unit checks).

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> Callers who need a media asset URL have to dig through provider tuples by hand. Give the media library first-class helpers to resolve an asset’s public URL (first registered provider, or a named provider), to list all provider URLs, and to go from a site + file name straight to a path/URL without loading the asset query yourself. Keep multi-provider assets working and keep returning nil/empty for unknown assets or providers. Fix it.

Do **not** name `url_for/1`, `url_for/2`, `url_for_asset/2`, `media_path/2`, `media_url/2`, `get_url_for`, or file paths. Those names are the **requested public API outcome** and may appear if the brief is written as a bounded feature; the maintenance-report shape above leaves naming open and only requires the capabilities.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/beacon/media_library.ex` | Public helpers: `media_path/2`, `media_url/2` (A); `url_for/1`, `url_for/2`, `urls_for/1`, `url_for_asset/2` (B). |
| `lib/beacon/media_library/provider.ex` | Provider behaviour/contract tightened so URL resolution is not raw-tuple matching. |
| `lib/beacon/media_library/provider/s3.ex` | S3 provider aligned to the new contract. |

**Cross-component behavior:** MediaLibrary facade ↔ Provider behaviour ↔ concrete providers. A helper that only works for the default repo provider breaks multi-URL assets; `url_for/1` must return the **first registered** provider’s URL (documented), not an arbitrary one.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (1) | `test/beacon/media_library_test.exs` (extends in B) |

**Implementation count:** **3** files (library + provider behaviour + s3). Slightly under the 2–5 preference; keep as a **focused multi-file API** diversity pick (MIT, clean lineage, small incomplete matrix).

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| M1 | `url_for(asset)` returns the URL of the first registered provider. |
| M2 | `url_for(asset, "repo")` / named provider returns that provider’s URL; unknown provider → nil. |
| M3 | `urls_for(asset)` lists every provider URL for multi-provider assets. |
| M4 | `url_for_asset(site, file_name)` resolves without the caller querying assets manually; missing file behaves as documented (nil/empty). |
| M5 | `media_path/2` and `media_url/2` return the site-relative path / absolute URL for a file name. |
| M6 | Unknown asset / non-asset argument → nil, no crash. |
| M7 | Preservation: existing upload/display flows and S3 provider URL generation unchanged. |

Upstream tests cover M1–M2 (and part of M4). M3, M5–M7 need curator witnesses (especially multi-provider fixture and non-asset args).

---

## 5. Incomplete / integrity controls

**Natural incomplete (lineage intermediate):** tree at `f75e878c…` (PR A only) — `media_path`/`media_url` exist, but `url_for*` and provider contract work are missing. M1–M3 fail.

**Second incomplete (compiling on A):** add `url_for/1` only, leave `url_for/2` and `url_for_asset` missing — M2/M4 fail.

**Third incomplete:** helpers hardcode the default provider and ignore the provider key — M2/M3 fail on multi-provider assets.

**Integrity:** standard `System.halt(0)` early-exit; require executed `media_library_test` results, not only compile.

---

## 6. Preservation

- Existing asset upload, `__beacon_media__` serving, and hashed asset paths.
- S3 provider still produces URLs when configured (not required in offline tests).
- Multi-provider registration order preserved (first = `url_for/1` result).
- Mixed population: single-provider asset, multi-provider asset, missing file, non-asset argument.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| Services | None required (S3 provider can be stubbed / not exercised). |
| Deps | `ExBrotli` etc. only if asset pipeline tests are pulled in — prefer media_library unit tests. |
| Browser | Not required. |

**Not verified:** compilation, green base suite, offline dep cache. Small API case; verify parents as recorded above before freeze.

---

## 8. Status / next action

**Status:** screened — clean **stacked lineage** (#774 then #775) and a coherent media-API outcome. Ticket states the final helpers; intermediate #774-only tree is the natural incomplete control. Small file count, low runtime risk (MIT).

**Next action:** pin base `e862412a…` for the full combined reference at `1fdd5174…`; prove fixture with `media_library_test`; author M1–M7; incomplete = A-only tree. Attribute **both** PRs in provenance. Optional note: #782 customizable asset delete callbacks is a **later** media feature — out of scope here.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Callers who need a media asset URL have to dig through provider tuples by hand. Give the media library first-class helpers to resolve an asset’s public URL (the first registered provider, or a named provider), to list every provider URL for an asset, and to go from a site + file name straight to the asset’s URL without loading the asset query yourself. Keep multi-provider assets working and keep returning nil for unknown assets or providers.

Clarified brief. Capabilities only — no function names.

**CRITICAL hidden-requirement / reference contradiction:** the draft ticket and check M5 require `media_path/2` and `media_url/2` (site-relative **path** + absolute URL). Diff evidence for #775 shows those functions (added in #774) are **deleted** and replaced by `url_for_asset/2` (URL only). The combined reference tree at `1fdd5174…` has **no** `media_path`/`media_url`. Per LINEAGE-MERGE-POLICY the ticket must describe the **final** behaviour — so drop "path" from the ticket and drop M5 as written. As drafted, the ticket demands an outcome the reference does not implement: a correct solver who keeps `media_path`/`media_url` from #774 would pass M5 while diverging from the reference; a solver who follows the final design would fail M5. Unfair either way.

Rewritten ticket above already omits path helpers. If you truly want path helpers scored, they must be in the reference (extend beyond upstream final) and then this is no longer a pure lineage freeze.

### 2. Deterministic checks

ExUnit, `media_library_test.exs` style. Fake providers as test modules (existing fixture). No S3, no network.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `url_for first-registered` | Asset with 2+ providers, known registration order | `url_for(asset)` | returns the **first** registered provider’s URL |
| `url_for named-provider` | Same asset; `url_for(asset, "repo")`; `url_for(asset, "unknown")` | same | named provider’s URL; nil for unknown |
| `urls_for all-providers` | Multi-provider asset | `urls_for(asset)` | every provider URL, no nils |
| `url_for_asset site-and-filename` | Site with uploaded `image.png`; site with missing file | `url_for_asset(site, name)` | URL for known file; nil for missing |
| `url_for non-asset-safe` | `url_for(:noop)`, `url_for(nil)`, `url_for(asset, :noop)` | same | nil, no crash |
| `preservation upload-and-serve` | Existing upload / `__beacon_media__` flows | asset URL + serving | unchanged (M7) |

Fake provider: yes — register two stub providers (repo-like + custom key) in the site config fixture. Do not require S3.

### 3. Ambiguity / unfairness

- "first registered provider" is a real ordering policy — the ticket states it. Good. Checks must build the fixture with a known registration order.
- Function names (`url_for/1`, `url_for/2`, `urls_for/1`, `url_for_asset/2`, `media_path/2`) are the **requested public API outcome** if the brief is written as a bounded feature ("add these helpers"), or open if written as a capability brief. The draft acknowledges both shapes and then scores names anyway. Pick one: capability brief (grade behaviours via whatever names appear in the public `MediaLibrary` module — hard) **or** API brief that lists the helper names (fair game, they are the outcome). Given upstream is an API cleanup, listing the helper names is the honest choice; otherwise do not require exact names in checks.
- Nil vs empty for `urls_for` of unknown: reference rejects nils and returns a list. Ticket says "nil/empty" — pick one per function (`url_for*` → nil; `urls_for` → `[]`).
- Whether `url_for/1` should return nil or raise on a providers-empty asset: reference returns nil via `get_url_for(nil, _)`. Grade nil.

### 4. Shortcuts

- Natural incomplete = tree at `f75e878c…` (A only): `media_path`/`media_url` exist, `url_for*` / `url_for_asset` missing. Fails M1–M4. **But** if M5 still requires `media_path`, this incomplete would **pass** M5 — another reason to kill M5.
- `url_for/1` only; no named-provider or `url_for_asset`. Fails M2/M4.
- Helpers hardcode the default provider and ignore `provider_key`. Fails M2/M3 on multi-provider assets.
- `urls_for` returns raw tuples or includes nils. Fails M3.
- Crash on unknown provider instead of nil. Fails M2/M6.

### 5. Flakiness / nondeterminism

Low. Pure helpers over a struct. Provider registration order must be fixed in the fixture (config list order). No clocks, no async.

### 6. Coverage mix

- Positive: first-provider URL; named-provider URL; all URLs; site+filename resolution.
- Negative: unknown provider; unknown file; non-asset arg.
- Preservation: upload/display and default provider URL generation.
- Mixed population: single-provider asset vs multi-provider asset in one test so a default-provider hardcode fails.

### 7. Environment risk

- **MIT.** No services (S3 stubbed / untested). Phoenix/Elixir; `ExBrotli` only if asset-pipeline tests get pulled in — stay in `media_library_test`.
- Small (3 impl files) — below the 2–5 preference; acceptable as a focused API diversity pick per guidelines.
- **Not verified:** compilation, green base suite, offline dep cache. Lineage stacking (#775 parent = #774 squash) is verified — good.

### 8. Verdict

**READY-WITH-FIX** — clean stacked lineage and low runtime risk, but the draft ticket/checks contradict the final reference (`media_path`/`media_url` removed in #775). Mandatory rewrite before any qualification.

### 9. Must-fix list

1. **Rewrite ticket + kill M5** to match the final tree: URL helpers only (`url_for/1`, `url_for/2`, `urls_for/1`, `url_for_asset/2` — or capability wording with behavioural checks). Do not score `media_path`/`media_url` against a reference that deletes them.
2. Decide name-pinning: either list the public helper names as the requested API, or grade only behaviours.
3. State per-function nil/empty policy.
4. Incomplete = A-only tree (`f75e878c…`); it must fail url_for* checks once M5 is gone.
5. Multi-provider fixture with known registration order; preservation witness for upload/serve.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Ticket/M5 contradict final reference (media_path removed) |
