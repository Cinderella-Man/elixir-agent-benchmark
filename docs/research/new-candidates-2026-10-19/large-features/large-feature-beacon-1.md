# Large feature — Beacon #687 sitemap.xml per site and sitemap_index.xml

**Status:** discovered
**Source type:** historical merged PR (resolves issue #169; depends on #694 ProxyEndpoint)
**Project:** [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon) — CMS on Phoenix LiveView
**PR:** [#687](https://github.com/BeaconCMS/beacon/pull/687)
**Issue:** [#169](https://github.com/BeaconCMS/beacon/issues/169) — Generate `sitemap.xml`
**Author:** APB9785 · **Created:** 2024-12-04 · **Merged/closed:** 2025-02-03
**Source revisions:** base (merge first parent) `78c0fef0f88a4b83a397533e0ad35224dbb246a9` → merge `1aa11357746073f0f9e321e1cdf2ba1e62a51682` (head `3952b1287cde487cff7c4767d856aca13e8b847a`, 36 commits)
**Task kind / family:** bounded feature / multi-site routing + controller + XML templates
**Research date:** 2026-10-19
**License:** MIT

---

## Why it is a LIMIT-TESTING case

Clear user-visible capability: **Beacon generates `sitemap.xml` per site and a `sitemap_index.xml`** (issue #169). The feature sits on multi-site routing (the PR depends on #694 `Beacon.ProxyEndpoint` for multiple domains) and must stay consistent across:

1. **Router / loader routes** — expose sitemap URLs in the right site-scoped prefix (`beacon_sitemap_url`, `beacon_page_url` helpers).
2. **Controller** — `SitemapController` `index` (sitemap_index) and `show` (per-site sitemap) actions keyed by `conn.assigns.site`.
3. **XML builders/templates** — `sitemap.xml.eex`, `sitemap_index.xml.eex`, and `Beacon.Web.SitemapXML` must emit valid, site-correct URLs (not a single hardcoded host).
4. **Install / generator tests** — `install_test` and test routers/endpoints (`endpoint_b`, scoped prefixes) show that sites with different prefixes still get correct sitemap links.

Coordination is hard because the same URL-correctness rule appears in helper functions, controller assigns, and template output; a partial that adds a controller but wrong site prefixes is plausible. Five implementation files, MIT license, tests at the controller boundary — a clean limit-testing feature without external services.

## File inventory with roles

From `pull/687.diff` (15 paths).

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/beacon/loader/routes.ex` | Route loading / site-scoped route helpers. |
| `lib/beacon/router.ex` | Router macros / `beacon_sitemap_url`, `beacon_page_url` helpers. |
| `lib/beacon/web/controllers/sitemap_controller.ex` | `call/2` for `:index` and `:show`; site assign. |
| `lib/beacon/web/sitemap/sitemap.xml.eex` | Per-site sitemap template. |
| `lib/beacon/web/sitemap/sitemap_index.xml.eex` | Sitemap index template. |
| `lib/beacon/web/sitemap_xml.ex` | XML construction / URL assembly. |

**Counts:** 5–6 substantive implementation files (routes, router helpers, controller, two templates, XML module). Tests and test-support separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/beacon_web/controllers/sitemap_controller_test.exs` | `index` and `show` actions; page URL correctness via routes. |
| `test/mix/tasks/install_test.exs` | Install/router generation still works. |
| `test/beacon_web/controllers/media_library_controller_test.exs` | Regression around related web controllers. |
| `test/support/endpoint_b.ex`, `test/support/routers.ex`, `config/test.exs`, `test/test_helper.exs` | Multi-site / scoped-prefix fixtures. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| `CHANGELOG.md` | Documentation — do not count as implementation. |
| `.formatter.exs` | Formatting config only. |

## Draft clarified feature brief

> Beacon should generate a `sitemap.xml` for each site and a `sitemap_index.xml` that points at them. URLs in the sitemap must use the correct site host and path prefix (including sites mounted under a scoped prefix). Expose the sitemap at the site’s web routes so crawlers can fetch it. Keep existing page rendering and media routes working.

The public product names `sitemap.xml` and `sitemap_index.xml` stay in the ticket. Do **not** name `SitemapController`, `SitemapXML`, template filenames, or helper functions.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Per-site sitemap:** GET site’s sitemap returns XML with that site’s page URLs (correct host/prefix). |
| A2 | **Sitemap index:** `sitemap_index.xml` lists per-site sitemap URLs. |
| A3 | **Scoped prefix:** a site under a path prefix emits prefixed URLs, not root-only. |
| A4 | **Multi-site isolation:** two sites do not leak each other’s pages into the wrong sitemap. |
| A5 | **Valid XML:** well-formed sitemap elements (loc at minimum) — not HTML error pages. |
| A6 | **Preservation:** existing page routes, media library controller, and install task still work. |

## Incomplete control

**Compiling partial that misses one subsystem:** add `SitemapController` + templates but hardcode a single host/root prefix (ignore `beacon_page_url` / scoped prefix).

- A1 may pass for the default site; **A3/A4** fail (wrong URLs under prefix or cross-site leak).
- Second partial: generate `sitemap.xml` but omit `sitemap_index.xml` → **A2** fails.

## Integrity / shortcut rejection

Reject patches that:

- Emit empty sitemaps or placeholder URLs.
- Collapse all sites into one sitemap or one index entry.
- Break existing router helpers (`beacon_page_url`) used by page rendering.
- Return HTML instead of XML.

## Preservation of existing behavior

- Existing page loading/rendering and media library controller tests stay green.
- Install/mix task tests still pass.
- Sites without extra pages still get a valid (possibly small) sitemap.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| No external crawlers/network | Controller tests only. |
| PostgreSQL | Standard Beacon/Ecto test setup. |
| Elixir `~> 1.14` at this era | Pin toolchain to the historical floor. |
| Depends on #694 multi-domain | Starting revision already has ProxyEndpoint if reconstructed at merge parent; do not require re-implementing #694. |
| MIT | Provenance notice. |

Not verified here: compile/test/boot.

## Status: discovered

Clean 5-file feature with multi-site URL consistency. Good diversity pick (MIT, CMS routing/XML) next to Mydia/Pinchflat media apps.

## Next action

1. Pin base `78c0fef0f88a4b83a397533e0ad35224dbb246a9` (includes #694).
2. Brief stays about sitemap files + correct per-site URLs; no internal names.
3. Incomplete = hardcoded host/prefix; integrity = empty/cross-site leak.
4. Qualify with multi-site test fixtures already in `test/support/`.
