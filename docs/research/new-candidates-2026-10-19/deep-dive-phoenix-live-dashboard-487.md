# Deep-dive dossier — phoenixframework/phoenix_live_dashboard PR #487 nested app process tree

**Status:** screened (discovery complete; no qualification executed)  
**Research date:** 2026-10-19  
**Dossier kind:** case-creation pack (everything needed to freeze a case, no bundle written)

---

## 1. Identity

| Field | Value |
| --- | --- |
| Project | [phoenixframework/phoenix_live_dashboard](https://github.com/phoenixframework/phoenix_live_dashboard) |
| PR | [#487 — Add a nested list view of application processes](https://github.com/phoenixframework/phoenix_live_dashboard/pull/487) |
| Author | `nathanl` (Nathan Long) |
| Head branch | `nathanl:list_view` (force-pushed `5a8df8d` → `8f7b6ab`) |
| Feature commit | `8f7b6ab91aff8998ee522ba3a628c1ec795c3614` |
| **Base SHA** | `4468d1344412c81aacb89a39684296856c87cffc` |
| **Merge SHA** | `ae6ed8927cb2fa73bff07943ca2261e357b6b3e5` |
| Merged | 2026-05-07 into `main` by `chrismccord` (4 checks passed) |
| Review | `mcrumm` left review comments on navigation components; “this is pretty awesome! I think I am okay with adding another application tree view, but I have a question about the navigation components.” After force-push: “I love it! … we should probably get some input from someone like @SteffenDE before we merge.” |
| Reactions | 13 👍 + 1 ❤️ (user demand evidence) |
| Demo | `process.list.mp4` screen recording attached in PR body |

**PR body (verbatim):**

> Add a compact nested list view of the processes for an application. Each level of nesting can be expanded or collapsed and the list can be searched.

**URLs**
- https://github.com/phoenixframework/phoenix_live_dashboard/pull/487
- Diff used: `https://github.com/phoenixframework/phoenix_live_dashboard/pull/487.diff`
- Raw sources at merge SHA via `raw.githubusercontent.com`

**Related mention in PR thread:** nathanl linked `elixir-ecto/postgrex#764` (“Set process labels”) — process labels improve list readability but are a **different** repo/PR. Not combined here.

**Sibling PRs (NOT this case):** short research note previously flagged #495 (crash fix, 1-line) and #491 (custom info module) as different tasks. Confirmed out of scope for this dossier.

---

## 2. Shortest ticket / brief (product decisions stated)

### Recommended solver-visible brief (clarified implementation brief)

> On an application’s info page in LiveDashboard, the existing tree view is hard to scan for large supervision trees. Add a **list view** of that application’s processes as a compact nested list, and let the user switch between the existing tree view and the new list view.
>
> Requirements:
> 1. A view switcher with two modes: the existing tree (default) and a new list.
> 2. The list is nested to match the supervision structure: supervisors contain their children, indented one level per depth. Each row shows the node type (master / ancestor / supervisor / worker / link) and the process name or pid.
> 3. Rows with children can be expanded or collapsed individually. Provide “Expand all” and “Collapse all” actions. The list starts fully expanded.
> 4. A search box filters the list. A row matches if its **name/pid** or its **type** contains the query (case-insensitive). Non-matching rows are hidden, but ancestors of a matching row stay visible so the hierarchy remains readable. Matching rows are highlighted.
> 5. Clicking a process name still opens the same process info the tree view opens.
> 6. The tree view and the rest of the applications page keep working.

### Product decisions that must be visible (do not hide in tests)

| Decision | Why |
| --- | --- |
| Two modes via a switcher; tree stays default | Reviewer asked about navigation; PR chose `view_mode` nav. Solvers could otherwise replace the tree. |
| Filter keeps ancestors of matches | Not obvious; flattening vs. keeping parents is a real product choice (see §5 incomplete A). |
| Filter matches **type** as well as name | Reference does `String.contains?(type, downcased)`. |
| Expanded by default | Reference starts `collapsed: MapSet.new()`. |
| Row type labels (master/ancestor/supervisor/worker/link) | Comes from `SystemInfo` node tags; visible in reference HTML as `process-list-type--*`. |
| Click name → same `show_info` action as tree | Cross-view consistency. |

**Task kind / family:** bounded feature / observability UI (LiveDashboard).  
**Ticket style:** clarified implementation brief (PR body is short and does not state filter/ancestor semantics).

---

## 3. Implementation roles + key code quotes

### Files and roles

| File | Role | Count class |
| --- | --- | --- |
| `lib/phoenix/live_dashboard/info/app_info_component.ex` | View-mode nav, recursive list component, collapse/filter state and events | **1 substantive implementation file** |
| `assets/css/app/components/_app_info.scss` | Presentation: toolbar, list indent guides, type badges, match highlight | stylesheet (presentation — count separately) |
| `test/phoenix/live_dashboard/pages/applications_page_test.exs` | 3 new LiveViewTest cases + `app_info_path/2` helper | tests |
| `CHANGELOG.md` | `* Add a compact nested list view for application supervision trees` under `## Unreleased` | docs |

**Do not inflate implementation count with the SCSS** unless the brief requires the visual layout (indent guides, badges, match highlight). Logic is one file.

### Structural relationship that must stay correct

```
SystemInfo.fetch_app_tree(node, app)
  → {root_value, children}   # node_value = {type, pid, name_or_[]}
  → ReingoldTilford.build(...)          # existing tree SVG (preserve)
  → list_tree = [{root_value, children}] # wrap for list mode (new)
  → filter_tree/2                        # recursive; keeps ancestors
  → recursive .list_tree HEEx            # nested <ul class="process-list">
  → collapsed :: MapSet of pid strings   # expand/collapse
  → view_mode from page.params["view_mode"]  # "list" → :list else :tree
```

The list and the tree **must consume the same `raw_tree`**, so both views describe the same processes.

### Key code quotes (from merge diff)

**View switcher + list vs tree (render):**

```elixir
<PageBuilder.live_nav_bar
  id="app-info-nav"
  page={@page}
  nav_param="view_mode"
  extra_params={["info"]}
>
  <:item name="tree" label="Tree"></:item>
  <:item name="list" label="List"></:item>
</PageBuilder.live_nav_bar>

<%= if @view_mode == :tree do %>
  <svg ... id="tree" class="tree"> ... </svg>   # existing SVG tree
<% else %>
  <div class="app-info-actions">
    <form phx-change="filter" phx-submit="filter" phx-target={@myself} class="app-info-filter">
      <input type="search" name="filter" class="app-info-filter-input"
             value={@filter} placeholder="Search" phx-debounce="150" />
    </form>
    <button class="app-info-action-btn" phx-click="expand_all" phx-target={@myself}>Expand all</button>
    <button class="app-info-action-btn" phx-click="collapse_all" phx-target={@myself}>Collapse all</button>
  </div>
  <div class="app-info-list">
    <.list_tree nodes={@filtered_tree} collapsed={@collapsed} myself={@myself} filter={@filter} />
  </div>
<% end %>
```

**Recursive list component + collapse gate:**

```elixir
defp list_tree(assigns) do
  ~H"""
  <ul class="process-list">
    <li :for={{node_value, children} <- @nodes} class="process-list-item">
      <div class={"process-list-row" <>
            if(node_matches?(node_value, @filter), do: " process-list-match", else: "")}>
        <%= if children != [] do %>
          <span class="process-list-toggle" phx-click="toggle_collapse"
                phx-value-pid={encode_pid_string(node_value)} phx-target={@myself}>
            <%= if MapSet.member?(@collapsed, encode_pid_string(node_value)), do: "▸", else: "▾" %>
          </span>
        <% else %>
          <span class="process-list-toggle-placeholder"></span>
        <% end %>
        <span class={"process-list-type process-list-type--#{node_type(node_value)}"}>
          <%= node_type(node_value) %>
        </span>
        <span class="process-list-name" phx-click="show_info"
              phx-value-info={node_encoded_pid(node_value)} phx-page-loading>
          <%= node_label(node_value) %>
        </span>
      </div>
      <%= unless children == [] or MapSet.member?(@collapsed, encode_pid_string(node_value)) do %>
        <.list_tree nodes={children} collapsed={@collapsed} myself={@myself} filter={@filter} />
      <% end %>
    </li>
  </ul>
  """
end
```

**Filter keeps ancestors (the subtle product rule):**

```elixir
defp filter_tree(nodes, filter) when filter in ["", nil], do: nodes

defp filter_tree(nodes, filter) do
  downcased = String.downcase(filter)

  Enum.reduce(nodes, [], fn {node_value, children}, acc ->
    filtered_children = filter_tree(children, filter)
    label = node_label(node_value) |> to_string() |> String.downcase()
    type = node_type(node_value) |> to_string()

    if String.contains?(label, downcased) or String.contains?(type, downcased) or
         filtered_children != [] do
      [{node_value, filtered_children} | acc]
    else
      acc
    end
  end)
  |> Enum.reverse()
end
```

**Collapse state:**

```elixir
def handle_event("toggle_collapse", %{"pid" => pid_string}, socket) do
  collapsed = socket.assigns.collapsed
  collapsed =
    if MapSet.member?(collapsed, pid_string),
      do: MapSet.delete(collapsed, pid_string),
      else: MapSet.put(collapsed, pid_string)
  {:noreply, assign(socket, collapsed: collapsed)}
end

def handle_event("expand_all", _, socket),
  do: {:noreply, assign(socket, collapsed: MapSet.new())}

def handle_event("collapse_all", _, socket) do
  all_supervisors = collect_supervisor_pids(socket.assigns.raw_tree)
  {:noreply, assign(socket, collapsed: all_supervisors)}
end
```

**Node typing / labeling (pre-existing helpers, extended):**

```elixir
defp node_type({type, _, _}), do: type
# types from SystemInfo: :master | :ancestor | :supervisor | :worker | :link
defp node_label({_, pid, []}), do: pid |> :erlang.pid_to_list() |> List.to_string()
defp node_label({_, _, name}), do: inspect(name)
```

### Tree data shape (from `SystemInfo.app_tree_callback/1`)

```
fetch_app_tree(node, app)
  → :error | {root_node, children}

root_node:  {:master, master_pid, []}  or  wrapped with {:ancestor, pid, []}
children:   [{ {:supervisor|:worker|:link|:ancestor|:master, pid, name_or_[]}, grandchildren }]
```

Built via `:application_controller.get_master/1`, `:supervisor.which_children/1`, and link-walking (`links_tree`). The list view **must** reflect this live structure — not a hardcoded dump.

---

## 4. Named acceptance assertions ↔ visible requirements

Upstream tests added in #487 (verbatim):

```elixir
test "list view renders when view_mode=list" do
  {:ok, live, _} = live(build_conn(), app_info_path(:kernel, view_mode: "list"))
  rendered = render(live)
  assert rendered =~ "process-list"
  assert rendered =~ ":rex"
  assert rendered =~ ":standard_error"
  assert rendered =~ "supervisor"
end

test "list view filter narrows results and highlights matches" do
  {:ok, live, _} = live(build_conn(), app_info_path(:kernel, view_mode: "list"))
  rendered = render(live)
  assert rendered =~ ":rex"
  assert rendered =~ ":standard_error"

  rendered =
    live
    |> element(".app-info-filter")
    |> render_change(%{"filter" => "rex"})

  assert rendered =~ ":rex"
  refute rendered =~ ":standard_error"
  assert rendered =~ "process-list-match"
end

test "list view expand all and collapse all" do
  {:ok, live, _} = live(build_conn(), app_info_path(:kernel, view_mode: "list"))
  rendered = render(live)
  # Tree is expanded by default, so we see nested processes
  assert rendered =~ ":rex"

  # Collapse all hides children
  rendered =
    live
    |> element("button", "Collapse all")
    |> render_click()

  refute rendered =~ ":rex"

  # Expand all shows them again
  rendered =
    live
    |> element("button", "Expand all")
    |> render_click()

  assert rendered =~ ":rex"
end

defp app_info_path(app, params) do
  query =
    [{"info", "App<#{app}>"} | Enum.map(params, fn {k, v} -> {to_string(k), v} end)]
    |> URI.encode_query()

  "/dashboard/applications?#{query}"
end
```

Preservation test (pre-existing, must stay green):

```elixir
test "shows the application supervision tree" do
  {:ok, live, _} = live(build_conn(), applications_path(50, "", :version, :asc))
  rendered = live |> element("#app-kernel") |> render_click()
  assert rendered =~ ":rex"
  assert rendered =~ ":standard_error"
end
```

### Assertion map

| Named assertion | Visible requirement | Discriminates |
| --- | --- | --- |
| `B1 list renders (view_mode=list)` | List mode reachable via param; `process-list` markup; real kernel processes `:rex`, `:standard_error`; type badge text `supervisor` | Flat dump without types; list mode missing; hardcoded tree |
| `B2 filter narrows` | Query `"rex"` keeps `:rex`, drops `:standard_error`, adds `process-list-match` | No-op filter; filter that hides all; no highlight |
| `B3 collapse all hides children` | Collapse-all ⇒ nested `:rex` gone | CSS-only toggle; collapse that doesn't re-render |
| `B4 expand all restores children` | Expand-all ⇒ `:rex` back | One-way collapse |
| `B5 tree view still works` (preservation) | Existing SVG tree path unchanged | Replacing tree instead of adding list mode |
| `B6 rest of applications page` (preservation) | Search/limit/status tests in same file still pass | Page-wide regression |
| `B7 default is tree` *(proposed)* | `view_mode` absent ⇒ tree SVG present, list absent | List replaces tree as default |
| `B8 ancestors kept on filter` *(proposed)* | Filter matching a grandchild still shows its supervisors | Flattened filter (incomplete A) |
| `B9 type filter` *(proposed)* | `filter=worker` keeps workers | Name-only filter |
| `B10 show_info still wired` *(proposed)* | Click `.process-list-name` triggers same info as tree | Dead click handler |

**Acceptance boundary:** LiveViewTest at the applications page (`live/2`, `element/2`, `render_click`, `render_change`). Prefer presence/absence of process names, type labels, and `process-list-match` class over exact HTML snapshots.

---

## 5. Compiling incomplete + expected named failure

### Plausible incomplete A — nested render, but filter flattens / drops ancestors

- Compiles. `B2` may still pass (it only checks `:rex` present / `:standard_error` absent). **Fails `B8`.**
- Named failure: `filter keeps ancestors of matches`.
- This is the highest-value extra assertion; upstream tests do **not** cover it.

### Plausible incomplete B — expand/collapse only toggles CSS class, no assign change

- Compiles. `B3`/`B4` fail because `render_click` output would still contain `:rex` (children not actually removed from the HEEx tree).
- Named failure: `collapse_all hides nested processes`.

### Plausible incomplete C — list is a flat dump of all processes

- Compiles. `B1` may pass if type badges and names appear. Fails `B8` and a proposed nesting assertion (indent/`process-list` nested `<ul>` presence, or parent-child relationship).
- Named failure: `list is nested by supervision structure`.

### Plausible incomplete D — search matches labels only, not type

- Compiles. Fails `B9`.
- Named failure: `filter matches process type`.

### Plausible incomplete E — add list mode but break/rename tree mode

- Compiles. Fails `B5`/`B7`.
- Named failure: `tree view preserved`.

---

## 6. Integrity / bypass control

| Bypass | Control |
| --- | --- |
| Hardcoded static tree for `:kernel` | `B1` can be gamed if only `:kernel` is tested. Add a second app (e.g. `:stdlib` or `:elixir`) or assert against `SystemInfo.fetch_app_tree` truth in the fixture. |
| Render names in a flat `<div>` list with the string `process-list` | `B3`/`B4` require collapse to change rendered children; `B8` requires hierarchy. |
| Filter returns all rows always | `B2` `refute rendered =~ ":standard_error"`. |
| Filter returns only exact matches, no ancestors | `B8`. |
| Collapse-all sets `collapsed` but render ignores it | `B3`. |
| Mutate existing tests | Preservation `B5`/`B6` + full `mix test`. |

**Positive preservation examples:** existing applications-page tests (limit, search, not-started status, tree supervision) plus `B5`. Do not let a patch that disables the tree or the page table pass.

---

## 7. Preservation checks

1. `test "shows the application supervision tree"` — tree click still shows `:rex` / `:standard_error`.
2. `test "shows applications with limit"` — table row cap unchanged.
3. `test "search"` — page-level app search unchanged.
4. `test "not started applications have different status in table"` — `Application.load/start/stop` status classes unchanged.
5. `menu_link/2` still returns `{:ok, "Applications"}`.
6. Tree SVG branch still renders when `view_mode` is absent or `"tree"`.

---

## 8. Runtime / offline / services — **can applications page tests run without a browser?**

### Answer: **Yes. No browser required.**

The new tests use **`Phoenix.LiveViewTest` only**:

```elixir
defmodule Phoenix.LiveDashboard.ApplicationsPageTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint Phoenix.LiveDashboardTest.Endpoint
```

They call `live(build_conn(), path)`, `render(live)`, `element/2 |> render_click()`, `element/2 |> render_change/1`. There is **no** Wallaby/Hound/playwright/Chromium dependency in this test file or in `mix.exs`.

### Full test environment (from `test/test_helper.exs` at merge SHA)

| Piece | Required for applications-page tests? | Notes |
| --- | --- | --- |
| ExUnit + `exclude: :integration` | yes | `ExUnit.start(exclude: :integration)` |
| `Phoenix.LiveDashboardTest.Endpoint` + PubSub (PG2) | **yes** | Started in test_helper |
| Router with `live_dashboard "/dashboard"` | **yes** | Path `/dashboard/applications?...` |
| Ecto Postgres repo (`storage_up`) | no for these tests | test_helper *attempts* `Ecto.Adapters.Postgres.storage_up/1` at boot |
| Ecto MySQL repo | no | same |
| Ecto SQLite repo | no | same |
| `os_mon` started, `ssh` stopped/unloaded | **yes** (env) | test_helper does `Application.stop(:ssh)` / `ensure_all_started(:os_mon)` |
| Node / npm / assets build | no for ExUnit | `setup` alias runs `npm install` for dev assets; **not** needed for LiveViewTest HTML assertions |
| Browser / Chromium | **no** | — |
| Network | no | — |

**Caveat (mark honestly):** `test_helper.exs` unconditionally configures and `storage_up`s three Ecto repos. `mix.exs` lists `ecto_sqlite3` as `only: [:dev, :test]` and Postgres/MySQL extras as `optional: true`. If optional DB adapters are absent, test_helper may warn or fail *before* any test runs — that is a **setup** failure, not an applications-page failure. For a case, either (a) provide the optional deps + local PG/MySQL/SQLite as upstream CI does, or (b) stub/skip the repo setup in a curated test_helper. Confirm in qualification which path the prepared image uses. **Not verified by an actual `mix test` in this research pass.**

### Historical `mix.exs` (at merge SHA `ae6ed89`)

```
app: :phoenix_live_dashboard
version: "0.8.7"
elixir: "~> 1.12"
deps: mime, phoenix_live_view "~> 0.19 or ~> 1.0", telemetry_metrics,
      optional ecto extras; test: floki, stream_data, ecto_sqlite3, jason
extra_applications(:test): [:ssh, :os_mon, :runtime_tools, :logger]
aliases.setup: ["deps.get", "cmd --cd assets npm install"]
```

### Runtime summary

| Item | Value |
| --- | --- |
| Browser? | **Not required** for LiveViewTest acceptance. Set `runtime.browser: false`. |
| DB? | Not used by these tests; test_helper boot touches optional Ecto repos. |
| Services | In-BEAM only: Endpoint + PubSub + `os_mon`. |
| Offline | Yes after `mix deps.get` (and optional `npm install` only if building assets). |
| Async | `async: true` — safe; tests use live `:kernel` processes (read-only). |

**If a browser case is desired** (`runtime.browser: true`) that is a **separate, heavier contract** (pinned Chromium, `runtime: true` tests). Prefer ExUnit LiveView tests first — the upstream suite is already there.

---

## 9. License / provenance

| Item | Value |
| --- | --- |
| License | **MIT** (`LICENSE.md` at merge SHA) |
| Copyright | `Copyright (c) 2019 Michael Crumm, Chris McCord, José Valim` (Alex Castaño listed in mix maintainers) |
| `mix.exs` package | `licenses: ["MIT"]` |
| Author | Nathan Long (community contributor), merged by Chris McCord |
| Reviewers | Michael Crumm (navigation question → force-push), SteffenDE sought but merge done by chrismccord |
| Demo evidence | `process.list.mp4` in PR; 13 👍 reactions |
| Exposure | Fully public. |

---

## 10. Reference challenges

### 10.1 Later commits to the same files after merge — **CRITICAL FINDING**

Queried GitHub commit history per path (HTML commits pages; REST API rate-limited part of the pass).

| Path | Later commits after merge `ae6ed89` | What changed |
| --- | --- | --- |
| `lib/phoenix/live_dashboard/info/app_info_component.ex` | **None.** Latest commit is `8f7b6ab` (2026-03-13, this PR). | Feature logic untouched after merge. |
| `assets/css/app/components/_app_info.scss` | **None.** Latest is `8f7b6ab`. | Styles untouched after merge. |
| `test/phoenix/live_dashboard/pages/applications_page_test.exs` | **One:** `6ef6963e44bdd7ae18b0d470a090d1beca344f31` — *“Release v0.9.0”* (2026-08-12, SteffenDE). | **Unrelated assertion only** (see below). |

**The v0.9.0 test delta (full, relevant hunk):**

```diff
     assert rendered =~
-             ~s|tr phx-click="show_info" phx-value-info="App&lt;ssh&gt;" phx-page-loading="phx-page-loading" id="app-ssh">|
+             ~s|tr phx-click="show_info" phx-value-info="App&lt;ssh&gt;" phx-page-loading="" id="app-ssh">|
```

This is in `test "not started applications have different status in table"` — **not** one of the three list-view tests. Cause: LiveView changed how boolean-ish `phx-page-loading` is serialized (`phx-page-loading="phx-page-loading"` → `phx-page-loading=""`). **Not a bug in the nested list feature.**

**Implication for case design:**
- No upstream “reference bug” trail on the feature files — the implementation was stable from merge to research date.
- The only later test edit is **HTML-serialization brittleness** in a *pre-existing* test. This is the clearest evidence that **exact HTML snapshots in this suite go stale across LiveView versions**. Curated assertions must avoid raw attribute serialization; use names, class names, and structural markers (as the three list-view tests already largely do).

### 10.2 Flaky / environment-sensitive UI assertions

| Risk | Detail | Mitigation |
| --- | --- | --- |
| Live process tree shape | Tests assert `:rex` and `:standard_error` under `:kernel`. True on OTP’s kernel app; if a future OTP renames/moves them, tests break. | Pin OTP in the prepared image; record OTP version in freeze. |
| `phx-page-loading` serialization | Demonstrated by the v0.9.0 fix. | Never assert raw boolean-attr serialization. |
| Collapse-all / expand-all button text | `element("button", "Collapse all")` matches on text. Locale/CSS `::before` glyphs (`▸`/`▾`) are separate nodes — fine — but text matching is brittle if labels change. | Keep labels in the brief if scored. |
| Match highlight class | `process-list-match` is a class name — OK as a structural marker, not a snapshot. | Keep. |
| `async: true` + live `:kernel` | Read-only inspection; no mutation of kernel. Collapse state is per-LiveView-process. | OK. |
| Debounce 150ms | `phx-debounce="150"` on the filter input. `render_change` in LiveViewTest **bypasses** debounce (server receives the event). No sleep needed. | Do not add sleeps. |
| Filter test `refute :standard_error` | Assumes `:standard_error` does not contain `"rex"` (true) and is present before filter (true for `:kernel`). | Keep `:kernel`; document OTP pin. |

### 10.3 Search/expand semantics underspecified in PR body

PR body says only “expanded or collapsed and the list can be searched.” It does **not** state ancestor retention, type matching, default-expanded, or highlight. Those are reference behaviors. **They must be in the brief if scored** (§2). Otherwise accept defensible alternatives and soften `B8`/`B9`.

### 10.4 CSS as a scored deliverable?

Indent guides, type badges, and match highlight live in SCSS. LiveViewTest does **not** apply CSS, so visual layout cannot be graded at the LiveViewTest boundary. Either:
- (a) score only structure/markup/events (recommended), or
- (b) add a browser case for visuals (heavier; not recommended first).

### 10.5 Modal / nav_bar interaction

The component renders inside a modal; the diff adds SCSS overrides for `.nav.nav-pills` spacing “for use inside a modal.” Reviewer’s only technical question was about navigation components. If a case requires the switcher to work inside the modal with `extra_params={["info"]}` preserved, say so in the brief — otherwise a solver may put the switcher in the wrong place and still pass structural tests.

---

## 11. Curator record (fields from `docs/pr-selection-guidelines.md`)

```markdown
Source type / project / source revisions / PR or original request:
  historical PR; phoenixframework/phoenix_live_dashboard;
  base 4468d1344412c81aacb89a39684296856c87cffc → merge ae6ed8927cb2fa73bff07943ca2261e357b6b3e5
  (feature commit 8f7b6ab91aff8998ee522ba3a628c1ec795c3614).
  Request: PR body + demo video + 13 👍 reviewer/user demand.

Status: screened
Case version / release inventory / public or withheld exposure:
  none yet; would be v1; public

Task kind / family / maintenance report or clarified brief:
  bounded feature / observability UI (LiveDashboard applications info) /
  clarified implementation brief (PR body underspecifies filter semantics)

Full solver-visible ticket and appended instructions:
  see §2. Do not repeat requirement text in grading.requirements[].text
  (schema-v2 appends those to the prompt). Keep assertion mapping here.

Implementation files and each file's role:
  lib/phoenix/live_dashboard/info/app_info_component.ex
    — view_mode nav, recursive list_tree/1, collapse/filter assigns+events
  (1 substantive implementation file)

Test / documentation / generated / mechanical files (separate counts):
  assets/css/app/components/_app_info.scss — presentation only (not counted
    as implementation unless visuals are scored)
  test/.../applications_page_test.exs — 3 tests + 1 helper (tests)
  CHANGELOG.md — 1 line (docs)
  no generated/mechanical files

Cross-component behavior to verify:
  - list and tree share SystemInfo.fetch_app_tree structure
  - collapse state (MapSet of pid strings) gates recursive child render
  - filter recursion preserves ancestors and highlights matches
  - show_info click path shared with tree view
  - view_mode URL param round-trips through live_nav_bar

Visible source for each scored obligation:
  B1–B4 from upstream tests (will become curated named assertions)
  B5–B6 from pre-existing tests in the same file
  B8/B9/B10 from §2 brief (must be stated there if scored)

Starting-state and reference-test evidence (inspected vs executed):
  inspected: full #487 diff, PR body/thread, applications_page_test.exs at
    merge, test_helper.exs, mix.exs, LICENSE.md, SystemInfo.app_tree_callback,
    commit histories of 3 touched paths, v0.9.0 test delta
  executed: NOT executed in this research pass (no mix run)

Plausible partial solution and expected named failure:
  incomplete A: filter flattens / drops ancestors → fails "filter keeps
    ancestors of matches" (B8)
  incomplete B: CSS-only collapse → fails B3/B4
  incomplete C: flat dump → fails B8 + nesting assertion
  incomplete D: name-only filter → fails B9
  incomplete E: tree broken/replaced → fails B5/B7

Preservation and alternative-solution risks:
  - exact HTML snapshots go stale (v0.9.0 phx-page-loading evidence)
  - :kernel process names are OTP-version-sensitive → pin OTP
  - CSS/visuals ungradeable at LiveViewTest boundary
  - alternative list markup is fine if structure/events match; do not
    require class names unless the brief names them

Runtime / offline services / license evidence and unknowns:
  ExUnit + Phoenix.LiveViewTest + ConnTest; Endpoint+PubSub in test_helper;
  os_mon in test; NO browser required. Optional Ecto repo boot in
  test_helper may need PG/MySQL/SQLite or a curated helper stub.
  MIT LICENSE.md (Crumm/McCord/Valim 2019).
  Unknown: whether prepared image will run upstream test_helper as-is
    (Ecto storage_up side effects) — resolve in qualification.

Three-round named control outcomes and frozen-input evidence:
  none yet (research pass only)

Blind model/settings policy and all attempt IDs (including failures/retries):
  none yet

Independent contract review / passing-patch reviews / unresolved findings:
  none yet. Unresolved: ancestor-retention and type-match must be in the
  brief or softened in grading; Ecto boot in test_helper; whether
  view_mode switcher location (modal nav) is scored.

Coverage added / related or duplicate tasks:
  LiveDashboard / observability UI — different product surface from
  Livebook/Plausible/Phoenix.PubSub tasks already in inventory.
  Sibling PRs #495 (crash fix) and #491 (custom info module) are different
  tasks; not combined.

Admission or exclusion reason / conditions for reconsideration:
  provisional pending: freeze §2 brief (ancestor + type-match rules),
  decide markup-vs-visual scoring, resolve test_helper Ecto boot, pin OTP,
  write named assertions B1–B6 (+B8/B9), then qualify 3 rounds + 2 blinds.

Next action:
  Keep as the strongest user-visible LiveDashboard feature in this pass.
  Grade at LiveViewTest boundary (no browser). Add B8 (ancestor retention)
  as a named assertion — upstream does not cover it. Pin OTP and settle
  test_helper Ecto boot during fixture prep.
```

---

## 12. Next action

1. **Freeze §2 brief** — especially: ancestors kept on filter, type-match, expanded-by-default, tree preserved as default.
2. **Fixture prep:** pin Elixir `~> 1.12` / OTP (record exact versions); decide upstream `test_helper.exs` vs a curated helper that skips optional Ecto `storage_up`.
3. **Named assertions B1–B6 + B8 + B9.** Avoid raw HTML attribute serialization (v0.9.0 lesson).
4. **Score at LiveViewTest only** (`runtime.browser: false`). Do not grade SCSS.
5. **Three qualification rounds + two blind successes** before admission.

**Recommendation:** **admit as the LiveDashboard / observability-UI diversity case** once the brief states filter semantics and the test_helper/Ecto boot is settled. One substantive logic file + LiveViewTest acceptance with no browser is tractable. Highest-value gap to close: **ancestor-preserving filter** (incomplete A) is invisible in upstream tests.
