# xl-beacon-578

**Status:** discovered
**Project:** BeaconCMS/beacon
**PR:** [#578 — Feature: add site-wide handle_info callbacks](https://github.com/BeaconCMS/beacon/pull/578)
**Issue:** (product request in PR body; complementary admin CRUD is out of tree)

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/BeaconCMS/beacon/pull/578 |
| Title | Feature: add site-wide handle_info callbacks |
| Source type | Historical merged PR (bounded CMS feature) |
| Merge style | **Squash** — one parent |
| Merge commit | `a46e29f9953951cae8bf91a999c37abf03252d5f` |
| Parent of merge (= base) | `fdf88f7d71d0d461c797e398136d8059d92002a6` |
| PR head SHA | `837458b946fcbc879310379eb641d6297e769ecf` (6 commits) |
| PR recorded base (lagged) | `7660dcaef6a2feaa8879a35878c11eac2e07d9d9` |
| Merged at | 2024-09-20T22:11:49Z |
| License | **MIT** |
| Verification | **Unverified** — PR body + `pull/578.diff` inspected; suite not executed |

**Identity note:** use the merge commit's parent `fdf88f7d…` as the historical base (it is the mainline tip at squash time; the PR API `base.sha` is older).

## Why it is a LIMIT-TEST

Beacon compiles site content into hot-loaded modules and mounts each page in a LiveView. Site-wide `handle_info/2` callbacks must be:

1. **Declared as content** (`Beacon.Content.InfoHandler` schema + `create_info_handler/1` etc.).
2. **Compiled into a per-site module** (`Beacon.Loader.InfoHandlers.build_ast/2`) and hot-reloaded when the record changes (`Loader` + `Worker` + `Boot`).
3. **Mounted into every page LiveView** (`PageLive`, `BeaconAssigns`, layout assigns) so `Kernel.send/2` to the page process invokes the user callback (flash, navigate, streams).
4. **Versioned** via `Migrations.V002` for existing sites.
5. **Kept out of page-only scope** — the ticket is site-wide; page-specific handlers are explicitly deferred.

The invariant: *a handler written through Content reaches the running page process without recompiling the host application*, and ordinary page message handling is not lost.

## File inventory (honest count)

**Implementation — 14 substantive:**

| File | Role |
| --- | --- |
| `lib/beacon/content/info_handler.ex` | **New** schema/changeset for site-wide handlers |
| `lib/beacon/content.ex` | CRUD API (`create_info_handler/1`, `change_info_handler/2`, …) |
| `lib/beacon/loader/info_handlers.ex` | **New** compile handlers into `*.InfoHandlers` module AST |
| `lib/beacon/loader.ex` | `fetch/reload_info_handlers_module`, `:content_updated` hook |
| `lib/beacon/loader/worker.ex` | GenServer call path for reload |
| `lib/beacon/loader/page.ex` | Page compile integrates handler module |
| `lib/beacon/boot.ex` | Startup compile/load |
| `lib/beacon/migrations/v002.ex` | Persist info_handler tables |
| `lib/beacon/web/beacon_assigns.ex` | Assigns expose handler module |
| `lib/beacon/web/live/page_live.ex` | Dispatch `handle_info` into site handlers |
| `lib/beacon/web/components/layouts/dynamic.html.heex` | Layout glue for assigns |
| `lib/beacon/web/components/layouts/app.html.heex` | Layout cleanup tied to assigns |
| `lib/errors.ex` | Error shapes for content API |
| `mix.exs` | Dep/module list touch |

**Tests — 5** (separate): `content_test.exs` (+140), `lifecycle/template_test.exs` (small), `page_live_test.exs` (+25), `test/support/fixtures.ex` (+26 fixture), `test_helper.exs` (+2).

**Generated:** none beyond migration source. No lockfile.

**Total files in diff:** 19 = 14 impl + 5 tests.

## Draft minimum ticket

> Let a Beacon site define `handle_info/2` callbacks that run on every page LiveView for that site, so `send/2` to a page can flash, navigate, or push streams. Creating or updating a site-wide handler must take effect on the running site without restarting the host app. Keep page-specific handlers out of scope.

## Named deterministic checks

1. **create-site-handler-persists** — `Content.create_info_handler/1` stores a valid handler for a site.
2. **compiled-module-exposes-callbacks** — `Loader.InfoHandlers` module for the site exports the configured `handle_info` clauses.
3. **page-dispatches-to-site-handler** — `PageLive` receiving a message invokes the site handler (process message → observable flash/assign).
4. **reload-on-content-update** — updating the handler reloads the module; subsequent page messages use the new clause (no app restart).
5. **invalid-handler-changeset** — bad source is rejected by the changeset (contract on Content).
6. **unrelated-page-messages-preserved** — normal LiveView messages still work (preservation).

## Incomplete that compiles (misses one subsystem)

Implement schema + `Content` CRUD + `InfoHandlers.build_ast` **but do not wire `PageLive` dispatch**. Compiles; content/compile tests pass; **page-dispatches-to-site-handler** fails.

Alternative incomplete: dispatch in `PageLive` against a module that is never reloaded → fail **reload-on-content-update**.

## Integrity shortcuts

- Unchanged tree fails **create-site-handler-persists** (no schema) and **page-dispatches-to-site-handler**.
- **reload-on-content-update** blocks compile-only-at-boot shortcuts.
- **unrelated-page-messages-preserved** blocks swallowing all `handle_info` messages.
- **invalid-handler-changeset** blocks “store any string and eval it later” without validation.

## Preservation

- Existing page lifecycle/template tests stay green.
- Page-specific `handle_info` is not required (explicit non-goal).
- Layouts continue to render for sites without handlers.

## Offline holds

| Hold | Notes |
| --- | --- |
| PostgreSQL | Beacon content/repo tests expect PG. |
| Network | None (no admin companion app in-tree). |
| Hot reload | Keep tests deterministic via `Loader` public APIs and process sync; avoid wall-clock sleeps. |
| MIT | Preserve license. |

## Cross-component contract

> `Content` is the source of truth; `Loader.InfoHandlers` is the only compiler; `PageLive` is the only dispatcher. Reload path (`Loader` → `Worker`) must invalidate the same module name `InfoHandlers.module_name/1` builds.

## Next action

Pin base `fdf88f7d…`; run `content_test` + `page_live_test` unchanged (fail), reference (pass), incomplete-without-page-dispatch (fail check 3 only). Confirm migration V002 applies on a pre-handler site fixture.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Let a Beacon site define `handle_info/2` callbacks that run on every page LiveView for that site, so `send/2` to a page can flash, navigate, or push streams. Creating or updating a site-wide handler must take effect on the running site without restarting the host app. Keep page-specific handlers out of scope.

Bounded CMS feature. Hot-reload and scope non-goal are explicit (good). Must add before fair:

- **How handlers are stored and invoked** is currently implied. The reference stores `msg` (a pattern) and `code` (a body) as source strings, compiles them into a per-site module, and requires the handler to return `{:noreply, socket}`. That return-shape rule and the "source strings" model are product decisions. Say one sentence: "a handler is a message pattern plus a callback body; the body must return `{:noreply, socket}`" — or accept any implementation and grade only the observable flash/navigate. The dossier's check 5 ("invalid source is rejected") is unfair without a stated validity rule.
- Do **not** require `Beacon.Content.InfoHandler`, `create_info_handler/1`, `msg`/`code` field names, or `Loader.InfoHandlers` unless the brief lists them as the requested Content API. Prefer: "expose Content functions to create/update site-wide handlers" and grade through those functions' observable effect on a page process. If you want the API names, list them like a refactor brief — they are the requested outcome.

### 2. Deterministic checks

ExUnit + Phoenix.ConnTest + LiveViewTest + **Postgres**. **Fakes:** none. Sync via `Beacon.Loader.reload_info_handlers_module/1` (already public and synchronous via `GenServer.call`) — **never sleep** on hot reload.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `create-handler-persists` | `Content.create_info_handler/1` (or brief-named API) | repo row / list | stored for the site |
| `compiled-module-exposes-clause` | after reload | compiled module (or behaviour) | configured clause is present |
| `page-dispatches-to-handler` | start page LiveView; `send(pid, msg)` | flash / assign / redirect | user callback runs |
| `reload-on-content-update` | update handler; `reload_info_handlers_module`; send again | same | **new** clause runs; no host restart |
| `invalid-handler-rejected` | bad source (per stated rule) | changeset | `{:error, changeset}` |
| `unrelated-messages-preserved` | send a message with no handler | PageLive | no crash / old warning path or defined skip; ordinary LiveView messages still work |
| `no-handler-site-renders` | site with zero handlers | page render | layout still renders |
| `migration-v002-on-existing-site` | site fixture without handler table content | migrate | applies cleanly |
| `preservation-page-lifecycle` | existing page/template tests | suite | green |

Without `reload-on-content-update`, boot-only compile passes. Without `unrelated-messages-preserved`, a catch-all that swallows every message passes. Without `invalid-handler-rejected` **and** a stated validity rule, this check is a lottery.

### 3. Ambiguity / unfairness

- **Validity rule for source is unstated.** Reference validates via `do_validate_template` (compiles as Elixir with imports `Phoenix.LiveView` and vars `socket` + msg). That is a hidden contract: what syntax is allowed, what imports, what error. Either state "the handler body is Elixir evaluated with `socket` bound, same as other Beacon content templates" (pointing at existing content validation is then fair) or grade only "clearly broken source is rejected".
- **Return shape** `{:noreply, socket}` — reference raises `Beacon.Web.ServerError` on other returns. Hidden exception module. Grade "bad return does not silently succeed" loosely, or state the required return in the brief.
- **`msg` as a pattern string** (`Code.string_to_quoted!`) vs a match spec vs a function is an implementation choice. Do not grade the string encoding.
- Page-specific handlers are out of scope — good. Do not fail a solver who also adds them if site-wide still works; do not require them.
- `mix.exs` / `lib/errors.ex` / layout glue are thin. Do not grade them by path.
- Event handlers (`EventHandler`) already exist in the tree and are the visible analogue. Fair game for investigation; do not require solvers to copy that exact module layout.

### 4. Shortcuts

- Schema + Content CRUD + compiler, **no PageLive dispatch** → fails `page-dispatches-to-handler`. Correct incomplete.
- Dispatch against a module that is never reloaded → fails `reload-on-content-update`.
- Catch-all `handle_info` that ignores unknown messages by returning `{:noreply, socket}` always → may pass dispatch but fail `unrelated-messages-preserved` if that check expects the old warning/no-op path. Be careful: returning `{:noreply, socket}` for unknown messages is a **reasonable alternative**. Accept it if ordinary messages still work. Do not require the old `Logger.warning`.
- Eval any stored string at runtime with no validation → fails `invalid-handler-rejected` only if validation is stated.
- Compile handlers only at Boot → fails reload check.
- Dispatch to handlers but drop flash/navigate assigns (return `{:noreply, socket}` with no effect) → fails `page-dispatches-to-handler` if the check asserts the flash/assign, not just "no crash". **Assert the effect** (flash text or assign change).
- Migration not applied → fails migration check / content insert.

### 5. Flakiness

Medium if reload is async. Use `Loader.reload_info_handlers_module/1` (synchronous) after Content writes. Do not wait on `:content_updated` broadcasts with `assert_receive` timeouts as the only sync — or if you do, also call the public reload. PageLive tests must start the site boot path consistently. No wall-clock sleeps. `Task.Supervisor.async` in Boot is parallel — tests should not depend on Boot order; call reload APIs directly.

### 6. Coverage mix

- Positive: create, compile, dispatch, reload, migration.
- Negative: invalid source rejected (if rule stated); missing handler does not break the page.
- Preservation: existing page lifecycle/template tests; sites without handlers.
- Mixed: one site with two handlers (msg A and msg B) so a single-clause compiler fails; update one clause and prove only that clause changed.

### 7. Environment

- MIT. **PostgreSQL** required. No network. No admin companion app in-tree.
- Hot reload must be deterministic via Loader public APIs.
- **Nothing executed.** No apply, no compile, no migration run.
- Beacon test suite is heavy (many sites). Keep the graded surface to `content_test` + `page_live_test` + migration check.

### 8. XL-specific

14 impl files is **mostly real** for a hot-reload CMS feature: schema → Content API → compiler → loader/worker/boot → migration → assigns → PageLive dispatch is one pipeline, and the invariant "handler written through Content reaches the running page" is exactly the cross-component relationship. Thin edges: `mix.exs`, `lib/errors.ex`, two layout templates. Honest core ~10. Possible split: (a) Content schema + compile (~5 files), (b) PageLive dispatch + reload (~5 files). **Do not split** — (a) alone is a dead feature, (b) alone has nothing to dispatch. Outcome is one story. This is a legitimate XL case if the validity/return policies are stated.

### 9. Verdict

**READY-WITH-FIX** — coherent hot-reload story with a real cross-process invariant and an existing EventHandlers analogue to investigate; blocked on stating the source-validity and return-shape rules and on naming-or-not the Content API.

### 10. Must-fix before qualification

1. State handler model in the ticket: pattern + body; body returns `{:noreply, socket}`; validated as Beacon template source (or equivalent).
2. Decide Content API naming: list `create_info_handler` etc. as requested surface, or grade only observable page effects.
3. Do not grade `InfoHandler` struct fields, `Loader.InfoHandlers`, `Beacon.Web.ServerError`, or layout files.
4. Sync reload via `Loader.reload_info_handlers_module/1`. No sleeps.
5. Incomplete = schema+CRUD+compile without PageLive dispatch. Integrity = no reload; catch-all swallow (accepted only if ordinary messages still work); eval without validation; boot-only compile.
6. Mixed two-handler + update-one fixture. PG. Pin base `fdf88f7d…`. Graded surface = content + page_live + migration.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Unstated source-validity / return-shape; Content API name-pinning |
