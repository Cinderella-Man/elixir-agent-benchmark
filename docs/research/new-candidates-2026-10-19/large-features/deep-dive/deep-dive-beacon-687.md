# Deep-dive dossier — Beacon #687 sitemap.xml per site and sitemap_index.xml

**Case-prep status:** deep-inspected + experiments 2026-10-20 (API + full clone + apply + mix test).  
**Verdict:** viable candidate. **Correct reconstruction base is merge first-parent `86c9ffd2…`, not the dossier's `78c0fef0…`.** Patch applies cleanly at first-parent. Sitemap tests execute green at base+patch (needs esbuild/tailwind/Postgres).

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon) |
| PR | [#687 Beacon generates `sitemap.xml` per site and a `sitemap_index.xml`](https://github.com/BeaconCMS/beacon/pull/687) |
| Issue | [#169 Generate `sitemap.xml`](https://github.com/BeaconCMS/beacon/issues/169) |
| Diff / Patch | `pull/687.diff` (15 879 B), `pull/687.patch` (75 324 B) |
| Author | APB9785 (Andrew Berrien) |
| PR body | `## Resolves #169` / `Depends on #694` (36 chars) |
| Created / Merged | 2024-12-04T21:59:05Z / 2025-02-03T17:56:36Z |
| Branch | `apb/sitemap` (head `3952b1287cde487cff7c4767d856aca13e8b847a`) |
| API base SHA (PR open) | `86c9ffd2c46558313725fa7ffddbf72bd926b2b3` |
| **Merge commit (squash)** | `1aa11357746073f0f9e321e1cdf2ba1e62a51682` |
| **Merge first parent = correct base** | `86c9ffd2c46558313725fa7ffddbf72bd926b2b3` |
| Dossier claimed base | `78c0fef0f88a4b83a397533e0ad35224dbb246a9` (**wrong** — see §3) |
| Size (first-parent..merge) | **15 files, +235 / −18** |
| License | MIT |
| Elixir at base | `~> 1.14` (`mix.exs` `@version "0.3.3"`) |

PR body says the feature **depends on #694 `Beacon.ProxyEndpoint`**. The merge first-parent already contains the ProxyEndpoint mix-tasks work (#723 is `78c0fef`; #717 JS Hooks is `86c9ffd`).

---

## 2. Shortest ticket / brief (solver-visible)

> Beacon should generate a `sitemap.xml` for each site and a `sitemap_index.xml` that points at them. URLs in the sitemap must use the correct site host and path prefix (including sites mounted under a scoped prefix). Expose the sitemap at the site’s web routes so crawlers can fetch it. Keep existing page rendering and media routes working.

Keep visible: `sitemap.xml`, `sitemap_index.xml`, multi-site / scoped-prefix URL correctness.  
Do **not** name `SitemapController`, `SitemapXML`, `beacon_sitemap_url`, template filenames.

---

## 3. Source revisions — experiment log (SHAs)

Full clone of `BeaconCMS/beacon` (WSL Ubuntu, git 2.53.0):

```
git clone https://github.com/BeaconCMS/beacon.git
git log -1 --format='%H %P %s' 1aa11357746073f0f9e321e1cdf2ba1e62a51682
```

| Claim | Experiment result |
| --- | --- |
| Merge commit exists | YES `1aa11357746073f0f9e321e1cdf2ba1e62a51682` |
| Subject | `Beacon generates `sitemap.xml` per site and a `sitemap_index.xml` (#687)` |
| **Parents** | **only one:** `86c9ffd2c46558313725fa7ffddbf72bd926b2b3` — **squash merge, no second parent** |
| Dossier "base (merge first parent) `78c0fef0…`" | **FALSE.** `78c0fef` is a *different* commit (`mix tasks to setup ProxyEndpoint and create new Endpoints (#723)`, 2025-01-31). It is an **ancestor** of `86c9ffd` by exactly 1 commit (`86c9ffd` = `Add support for user-defined JS Hooks (#717)`). |
| Head `3952b128…` | **NOT FOUND** in main clone (PR branch `apb/sitemap` not in default clone; GitHub may still hold `refs/pull/687/head`). |
| API `commits: 36` vs patch series | `pull/687.patch` contains **25** commits (`[PATCH 01/25]`…`[PATCH 25/25]`). Discrepancy: API count 36 ≠ patch series 25. Use the **squash diff** (`pull/687.diff`) as the reference patch. |

**Correct reconstruction base: `86c9ffd2c46558313725fa7ffddbf72bd926b2b3`** (merge first parent / API base_sha).

---

## 4. File roles + inventory (from `pull/687.diff` + `git diff --name-status` first-parent..merge)

### Implementation (6 substantive)

| Path | Role |
| --- | --- |
| `lib/beacon/web/controllers/sitemap_controller.ex` | **New.** `call(conn, :index)` renders sitemap index from all running sites; `call(conn, :show)` renders per-site sitemap from published pages. Uses `Beacon.Loader.fetch_routes_module/1` + `Beacon.apply_mfa` for `beacon_sitemap_url` / `beacon_page_url`. |
| `lib/beacon/web/sitemap_xml.ex` | **New.** `embed_templates "sitemap/*.xml"` view module. |
| `lib/beacon/web/sitemap/sitemap.xml.eex` | **New.** `<urlset>` with `<loc>` + `<lastmod>` per page. |
| `lib/beacon/web/sitemap/sitemap_index.xml.eex` | **New.** `<sitemapindex>` listing per-site sitemap URLs. |
| `lib/beacon/router.ex` | Adds `beacon_site` route `get "/sitemap.xml" … as: :beacon_sitemap`; new `beacon_sitemap_index/1` macro; site-scoped URL helpers. |
| `lib/beacon/loader/routes.ex` | Generates `beacon_sitemap_url/1` and `beacon_page_url/2` on the per-site routes module. |

### Tests / test-support (contract)

| Path | Contract |
| --- | --- |
| `test/beacon_web/controllers/sitemap_controller_test.exs` | **New, 60 lines, 2 tests:** `test "index"` asserts exact multi-site index XML (5 sites incl. scoped prefixes + `site_b.com`); `test "show"` asserts per-site `urlset` with `beacon_page_url` and ISO8601 `lastmod`. |
| `test/support/endpoint_b.ex`, `test/support/routers.ex`, `config/test.exs`, `test/test_helper.exs` | Multi-site fixtures (`:my_site`, scoped `/nested/media`, `/nested/site`, `/other`, host `site_b.com`). |
| `test/beacon_web/controllers/media_library_controller_test.exs` | Preservation (6 deletions — related cleanup). |
| `test/mix/tasks/install_test.exs` | Install/router generation preservation. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| `CHANGELOG.md` | Docs entry only. |
| `.formatter.exs` | Formatting config. |

---

## 5. Cross-component behavior to verify

The same URL-correctness rule must hold in three places:

1. **Routes module helpers** (`beacon_sitemap_url/1`, `beacon_page_url/2`) — produce site-correct host + scoped prefix.
2. **Controller assigns** — `:index` collects sitemap URLs for *all* running sites; `:show` scopes pages to `conn.assigns.site`.
3. **Templates** — emit well-formed sitemap XML (`loc` / `lastmod`, `sitemapindex`).

A partial that adds a controller but hardcodes one host/root prefix compiles and may pass a single-site check, but fails scoped-prefix / multi-site isolation.

---

## 6. Named acceptance assertions ↔ requirements

From `test/beacon_web/controllers/sitemap_controller_test.exs` (usable as named acceptance):

| Assertion (test name / claim) | Requirement |
| --- | --- |
| `test "index"` | `sitemap_index.xml` lists **all** sites’ sitemap URLs with correct host/prefix (`/nested/media/sitemap.xml`, `/nested/site/sitemap.xml`, `/other/sitemap.xml`, `/sitemap.xml`, `http://site_b.com:4000/sitemap.xml`). |
| `test "show"` | Per-site `sitemap.xml` emits `<urlset>` with that site’s page `loc` (via routes helper) and ISO8601 `lastmod`; `content_type` is XML UTF-8. |

Implicit obligations (from fixture setup + product brief): scoped-prefix sites get prefixed URLs; two sites do not leak pages into each other’s sitemap; sites with no extra pages still get a valid (possibly small) sitemap.

---

## 7. Compiling incomplete + named failure

**Incomplete A — controller + templates, but hardcoded host / root prefix** (ignore `beacon_page_url` / scoped prefix):

- `test "show"` may still pass if the fixture site is root-mounted and the helper is used for `loc`.
- **Fails** `test "index"`: expected index contains `/nested/media/sitemap.xml`, `/nested/site/sitemap.xml`, `/other/sitemap.xml`, `site_b.com` — a single hardcoded root host produces the wrong list.

**Incomplete B — `sitemap.xml` only, no `sitemap_index.xml`:**

- **Fails** `test "index"` (route missing or empty).

**Named failure for A/B:** `test "index"` in `test/beacon_web/controllers/sitemap_controller_test.exs`.

---

## 8. Integrity / shortcut rejection

Reject patches that:

- Emit empty sitemaps or placeholder URLs.
- Collapse all sites into one sitemap or one index entry (breaks `test "index"` exact XML).
- Break `beacon_page_url` used by page rendering (media/page tests fail).
- Return HTML instead of XML (`response_content_type(conn, :xml)`).

---

## 9. Experiments — `git apply` of `pull/687.diff`

Shallow clone + `git apply` at each candidate base (WSL, git 2.53.0):

| Base | Classic `git apply --check` | `git apply --3way` | Verdict |
| --- | --- | --- | --- |
| **First parent `86c9ffd2…`** | **exit 0, all 15 paths cleanly** | **exit 0** | **Use this base** |
| Dossier claimed `78c0fef0…` | **exit 1** — `CHANGELOG.md` context mismatch (first-parent has JS Hooks changelog lines the patch expects) | exit 1, `UU CHANGELOG.md` conflict; other 14 paths applied via 3way fallback | Do not use as reconstruction base |

Exact commands (WSL):

```bash
git clone --depth 1 https://github.com/BeaconCMS/beacon.git classic-beacon
cd classic-beacon
git fetch --depth 1 origin 86c9ffd2c46558313725fa7ffddbf72bd926b2b3
git checkout 86c9ffd2c46558313725fa7ffddbf72bd926b2b3
git apply --verbose --check /tmp/large-dd/BeaconCMS_beacon-687.diff   # exit 0
git apply --verbose /tmp/large-dd/BeaconCMS_beacon-687.diff           # exit 0
```

---

## 10. Experiments — `mix test` at base+patch

Environment: Docker `elixir:1.14-otp-25` (matches `~> 1.14`), `postgres:15` on `localhost:5432`, `DATABASE_URL=postgres://postgres:postgres@localhost:5432/beacon_test`.

**Setup required (runtime hold):**

```bash
mix deps.get
mix compile
mix esbuild.install          # required — Beacon.Boot loads runtime JS
mix tailwind.install --no-assets  # required — Beacon.Boot loads runtime CSS
mix ecto.migrate             # or mix ecto.create + migrate
```

Without esbuild/tailwind binaries, Beacon.Boot dies with `Beacon.LoaderError` (`esbuild binary not found` / `tailwind-cli binary not found`) and tests never run. Earlier `mix ecto.create` alone reported `The database … couldn't be created: killed` — resolved by creating the DB manually and installing the two CLIs.

**Results at `86c9ffd` + patch:**

| Command | Result |
| --- | --- |
| `mix test test/beacon_web/controllers/sitemap_controller_test.exs` | **2 tests, 0 failures** |
| `mix test test/beacon_web/controllers/media_library_controller_test.exs test/mix/tasks/install_test.exs` | **4 tests, 0 failures** |

Not run here: full Beacon suite (large). Targeted acceptance + preservation boundary is green.

---

## 11. Later commits on the same files (reference-bug / drift scan)

From full clone, `git log 1aa1135..HEAD -- <sitemap paths>`:

| SHA / PR | Date | What | Relevance to a reconstructed case |
| --- | --- | --- | --- |
| `c243a49` #740 | 2025-02-04 | `feat: always generate site endpoints` — rewrites routes loader, sitemap controller, sitemap_index template, test fixtures (endpoints module). | **Touches sitemap controller + index template + routes.** Starting from first-parent, the #687 tests are the era-correct contract; do not back-port #740. |
| `0f0817f` #743 | 2025-02-05 | `chore: use host in tests` — test host expectations. | Test-only drift. |
| `c951d31` #746 | 2025-02-10 | `chore: move sitemap_index.xml and robots.txt to top-level host` — **moves sitemap_index/robots off site prefixes** into `ProxyEndpoint`; large sitemap test rewrite. | **Reference-bug family:** multi-site URL placement was redesigned one week after merge. Do not grade #687 against post-#746 behavior. |
| `98ed94e` #749 | 2025-02-11 | `fix(robots.txt): use proxy endpoint url to build sitemap_index url` — **fixes sitemap_index URL construction** via proxy endpoint. | Explicit follow-up fix to sitemap URL building. |
| `9dbfa20` #700 | (before/around) | `Beacon generates robots.txt per site` — sibling feature. | Related coverage, not a fix. |
| `e721fac` | 2026-04-13 | `Add comprehensive SEO system…` — large later feature touching sitemap controller/templates. | Far future; ignore for case. |

**Implication:** reconstruct at `86c9ffd` + #687 diff only. Later commits (#746/#749) *change* the URL-placement contract; using a later base would make the #687 tests fail and over-constrain solvers.

---

## 12. Preservation

Must keep working (executed):

- `test/beacon_web/controllers/media_library_controller_test.exs` — 2–3 tests green.
- `test/mix/tasks/install_test.exs` — green.
- Existing page routes (not re-run here; `beacon_page_url` is shared with sitemap `loc`).

---

## 13. Runtime / offline

| Hold | Evidence |
| --- | --- |
| PostgreSQL 15 | Executed in Docker. |
| Elixir `~> 1.14` | `elixir:1.14-otp-25` compiled + tested. |
| **esbuild + tailwind standalone CLIs** | **Required** (`mix esbuild.install`, `mix tailwind.install --no-assets`). Not optional — Beacon.Boot blocks tests otherwise. |
| MIT | `LICENSE` at base. |
| No external crawlers | Controller tests only. |

---

## 14. Curator record (guidelines checklist)

```
Source type / project / source revisions / PR:
  historical merged PR (squash) / BeaconCMS/beacon
  base 86c9ffd2c46558313725fa7ffddbf72bd926b2b3
  merge 1aa11357746073f0f9e321e1cdf2ba1e62a51682
Status: discovered → deep-inspected (not yet screened/admitted)
Case version / inventory / exposure: n/a (no bundle)
Task kind / family: bounded feature / multi-site routing + controller + XML
Ticket kind: clarified implementation brief (above)
Implementation files: 6 (controller, view, 2 templates, router, routes loader)
Tests / docs / mechanical: 3 test files + 4 test-support + CHANGELOG + formatter
Cross-component behavior: routes helpers ↔ controller assigns ↔ XML templates
Visible source for each scored obligation: sitemap_controller_test.exs (index/show)
Starting-state / reference evidence:
  unchanged: base alone has no sitemap_controller_test (new file)
  reference: 2 sitemap tests + 4 preservation tests executed green at base+patch
Plausible partial: hardcoded host/prefix → fails test "index"
Preservation risks: beacon_page_url shared with page rendering; media + install tests
Runtime: Postgres + esbuild + tailwind + Elixir 1.14 (executed)
Three-round controls: NOT run (discovery stage)
Blind model policy: not started
Contract review: brief hides internal names; #746/#749 later redesign is out of scope
Coverage: CMS routing/XML multi-site — distinct from Mydia/Pinchflat media apps
Admission reason / reconsideration: good diversity; pin first-parent base
Next action: screen with incomplete control (hardcoded prefix) against test "index"
```

---

## 15. Verdict for case creation

| Criterion | Assessment |
| --- | --- |
| Authentic coherent work | Yes — issue #169, user-visible sitemap files. |
| Coordinated implementation | Yes — 6 files, URL rule must agree across helper/controller/template. |
| Visible contract | Yes — exact XML assertions in controller test. |
| Observable success | Yes — executed green; incomplete A/B have named failures. |
| Reproducible environment | Yes, with **esbuild + tailwind + Postgres** holds. |
| Provenance | MIT; squash-merge SHA corrected. |

**Keep.** Correct the dossier base SHA to `86c9ffd2…` before any bundle work.

---

## Scope note (2026-10-19 lineage policy)

#687 alone is a fair sitemap case. Later #740/#746/#749 redesign URL placement � **do not auto-merge** unless the brief clearly wants that layout (that would be a second product decision). Prefer freeze-at-#687 with first-parent base 86c9ffd2�, or a new combined case version if we want the redesign as the stated outcome.

---

## Grilling (2026-10-19)

### Minimum ticket
The brief is acceptable: `sitemap.xml`, `sitemap_index.xml`, multi-site / scoped-prefix URL correctness, exposed at the site's web routes. Good. Two tightenings: (1) "Keep existing page rendering and media routes working" is the right preservation sentence — keep it. (2) "URLs must use the correct site host and path prefix (including sites mounted under a scoped prefix)" is doing real work; do not cut it. Do not expand the brief to #746/#749 top-level-host placement — that is a later product redesign.

### Named deterministic checks
Only two tests exist (`test "index"`, `test "show"`). That is thin for a 6-file feature. `test "index"` is the real discriminator (multi-site + scoped prefixes + second host). `test "show"` can pass with a hardcoded host if the fixture site is root-mounted — the dossier admits this. **Add at least:** (a) `show` for a scoped-prefix site asserting the `loc` prefix; (b) site isolation — site A's pages do not appear in site B's sitemap; (c) empty/minimal site still returns a valid sitemap document (not a 500 or empty body). Without (a)/(b) the hardcoded-host incomplete may slip through.

### Ambiguity / unfairness
- "Expose the sitemap at the site's web routes" is slightly vague about whether `sitemap_index.xml` is site-scoped or host-scoped. At #687 it is site-scoped (later #746 moved it). The brief must freeze **#687 placement** explicitly or a solver who does the later, arguably better layout fails. State: "a `sitemap_index.xml` on each site's routes that points at that site's sitemap and any sibling sites' sitemaps" — or whatever #687 actually does — and say later top-level-host placement is out of scope.
- Exact XML whitespace / attribute order must not be byte-graded. Grade structure + `loc`/`lastmod` presence + content-type.
- "Depends on #694 ProxyEndpoint" is environment noise if the base already contains it (it does at `86c9ffd2`). Do not put #694 in the solver ticket.

### Shortcuts + compiling incomplete
Hardcoded host/root-prefix incomplete is real and dies on `test "index"`. Sitemap-only (no index) dies on `test "index"`. Under-weighted shortcuts: (1) emit `lastmod` as now() for every page — acceptable unless the check requires actual page timestamps; (2) list sites from config instead of running sites — may pass fixtures but is fragile; (3) collapse multi-site into one sitemap — dies on `test "index"` exact XML. Add the site-isolation check so (3) cannot pass by accident of fixture setup.

### Flakiness
Controller tests are deterministic. Real flake risk is **setup**, not assertion: Beacon.Boot requires esbuild + tailwind CLIs or tests never run (`Beacon.LoaderError`). A flaky/slow `mix esbuild.install` is an env failure, not a graded failure — separate it in the runner. Postgres must be up before `mix test`. Do not mix setup failures with test-body failures.

### Preservation
Media library + install tests were run (4 tests green) but the full suite was not. `beacon_page_url` is shared with page rendering — at least one named page-render test must stay in the preservation set or a solver can break page URLs while sitemap tests stay green. Run those before freeze.

### Env
Elixir `~> 1.14` (1.14-otp-25 Docker works). Postgres 15 required. **esbuild + tailwind standalone CLIs are mandatory, not optional** — any runner image without them will produce setup failures that look like case failures. MIT license — easy provenance. Targeted tests green at base+patch; full suite unrun.

### Combined-lineage requirements
**Do not auto-merge #740/#746/#749.** LINEAGE-MERGE-POLICY is explicit: later URL-placement redesign is a separate product decision. Freeze at #687 + first-parent `86c9ffd2`. If someone wants the later layout, that is a **new** combined case version with its own brief — not a silent upgrade of this one. The dossier's scope note already says this; keep it binding.

### Verdict
**READY-WITH-FIX** — base SHA correction is done, tests execute, but named-check coverage is too thin and #687 vs #746 placement must be frozen in the brief.

### Must-fix before qualification
1. Freeze #687 site-scoped placement in the brief; explicitly exclude #746/#749 top-level-host layout.
2. Add named checks: scoped-prefix `show`, site isolation, minimal-site valid sitemap. Do not rely on `test "index"` alone.
3. Add at least one named page-render preservation test (`beacon_page_url` shared path).
4. Runner image must preinstall esbuild + tailwind CLIs; record setup-vs-body failure split.
5. Re-run targeted + preservation tests on the **frozen** tree (not a mixed later checkout) before three qualification rounds.
