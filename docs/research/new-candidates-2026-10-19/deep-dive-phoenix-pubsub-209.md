# Deep-dive case prep — Phoenix.PubSub PR #209 (default dispatcher)
### With folded short note on PR #210 (`:group_by`)

**Research date:** 2026-10-19
**Sole-source status:** This file is the case-creation source of truth for #209 (and the #210 note). Companion short note: `phoenix-pubsub-209-default-dispatcher.md` (earlier screening pass).
**Evidence method:** GitHub HTML PR pages, `https://github.com/phoenixframework/phoenix_pubsub/pull/209.diff`, local full clone at `https://github.com/phoenixframework/phoenix_pubsub.git` (HEAD `79d97f0bb040b4e77a04efbe5b140d81faba7a39`), `raw.githubusercontent.com` at pinned SHAs. GitHub REST API was rate-limited during research (core remaining=0); anything only available via API is marked **unverified**.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Project | [phoenixframework/phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub) |
| PR | [#209 — Add configurable default dispatcher](https://github.com/phoenixframework/phoenix_pubsub/pull/209) |
| Author | `twinn` (Tony Winn \<hi@tonywinn.me\>) |
| Merged by | `josevalim` |
| State | MERGED |
| Opened | 2026-04-15 (first timeline comment Apr 15, 2026) |
| Merged | **2026-04-17T18:02:28Z** (committer date 2026-04-17 20:02:27 +0200) |
| Base SHA | `0b63dce1765de0cb3f57f6c7e5cc6b4fc9ef0d98` |
| Head SHA | `f5b05218ddb75660e074c4dca3235b5fde33107f` |
| Merge / squash SHA | **`228b82ec2cd1eae6f933e9a723fea82228476fd4`** (verified in local clone; commit title `Add configurable default dispatcher (#209)`) |
| PR body | Present (full text quoted below) |
| Linked issues | **None declared** in body or timeline. Not closing any issue. |
| Review comments | 0 review comments (API `review_comments: 0`). One issue comment from `josevalim` on 2026-04-17 with **no visible text body** (reactions only) — content **unverified** beyond that. Merge was direct (josevalim merged 1 commit). |
| Release | Shipped in **v2.3.0** (2026-08-25) per CHANGELOG “Enhancements: Add configurable default dispatcher” |

### PR body (verbatim summary)

> ## Summary
> Adds a `:dispatcher` option to `child_spec`/`start_link` that sets the default dispatcher module for all broadcast functions. Defaults to `Phoenix.PubSub` (preserving existing behavior). Can be overridden per-call by passing a dispatcher to `broadcast/4` and friends.
>
> ```elixir
> {Phoenix.PubSub, name: :my_pubsub, dispatcher: MyApp.Dispatcher}
> ```
>
> ## Motivation
> The custom dispatching feature is powerful, but in practice it's difficult to use as a default for an application. The current options are:
> 1. Pass the dispatcher explicitly on every `broadcast` call
> 2. Create a wrapper module that injects the dispatcher
>
> Both add boilerplate for what is conceptually a per-PubSub configuration. The wrapper approach is particularly fragile. Any code that calls `Phoenix.PubSub.broadcast/3` directly instead of going through the wrapper bypasses the custom dispatcher entirely. In a growing codebase with multiple contributors, this is easy to miss.
>
> The use case I ran into was filtering broadcasts in test environments, scoping delivery so that concurrent async tests sharing a topic don't leak messages to each other. A configurable default makes this a one-line change at startup rather than a module-level abstraction that every callsite must remember to use.
>
> ## Implementation
> The internal meta `:pubsub` tuple is extended from `{adapter, name}` to `{adapter, name, dispatcher}`. Single `Registry.meta` lookup per broadcast call, same as before. No additional lookups.
>
> ## Changes
> - `Phoenix.PubSub.Supervisor` accepts `:dispatcher` option, stores it in the meta tuple
> - All broadcast functions default dispatcher to `nil`, read the configured default from the meta tuple, and fall back to it when no explicit dispatcher is passed
> - 6 new tests covering default dispatcher, per-call override, and all broadcast variants

**API contract note:** The PR body **declares `:dispatcher` as the product API** (option name and example). If the solver ticket names a public option, use `:dispatcher`. Do not invent another name.

---

## 2. User-visible outcome + draft ticket

### Outcome
An application can set one default broadcast dispatcher per PubSub instance at startup. Every ordinary broadcast entry point uses it. A dispatcher passed on an individual call still wins. With no `:dispatcher` option, behavior is unchanged (`Phoenix.PubSub` remains the dispatcher).

### Draft ticket / feature brief (shortest sufficient)

> Custom dispatching today only works if every call site remembers to pass a dispatcher (or wraps `Phoenix.PubSub`, which is easy to bypass). Let me configure a default dispatcher for a PubSub at startup so ordinary broadcasts use it automatically. An explicit dispatcher on a single call must still override that default. When nothing is configured, keep today’s delivery behavior.
>
> Wire it as a `:dispatcher` option on `Phoenix.PubSub` child spec / `start_link`, defaulting to `Phoenix.PubSub`.

(Optional one-line scope if graded: “All broadcast entry points must honor the configured default, including the raising (`!`) variants and `direct_broadcast`.”)

---

## 3. File list (actual diff) and roles

Diff source: `https://github.com/phoenixframework/phoenix_pubsub/pull/209.diff`
Squash commit stat: `lib/phoenix/pubsub.ex | 37 ++++++++++--------`, `lib/phoenix/pubsub/supervisor.ex | 4 +-`, `test/phoenix/pubsub_test.exs | 82 +++++++++++++++++++++++++++++++++++++++-` — 3 files, 106 insertions, 17 deletions.

| File | Status | +/− | Role |
| --- | --- | --- | --- |
| `lib/phoenix/pubsub/supervisor.ex` | modified | +4/−1 | Accept `:dispatcher`, store 3-tuple in Registry meta |
| `lib/phoenix/pubsub.ex` | modified | +37/−17 | All broadcast entry points read configured default when explicit dispatcher is `nil` |
| `test/phoenix/pubsub_test.exs` | modified | +82/−1 | 6 named tests under `describe "default dispatcher"` |

**Counts:** 2 substantive implementation files, 1 test file. No docs/CHANGELOG/mix.exs changes in this PR.

### 3.1 `lib/phoenix/pubsub/supervisor.ex` — store the option

Before (`0b63dce`):

```elixir
registry = [
  meta: [pubsub: {adapter, adapter_name}],
  partitions: partitions,
  keys: :duplicate,
  name: name
]
```

After (`228b82e`):

```elixir
dispatcher = Keyword.get(opts, :dispatcher, Phoenix.PubSub)

registry = [
  meta: [pubsub: {adapter, adapter_name, dispatcher}],
  partitions: partitions,
  keys: :duplicate,
  name: name
]
```

Role: one-line option intake + meta-tuple shape change. Default is `Phoenix.PubSub` when option omitted.

### 3.2 `lib/phoenix/pubsub.ex` — honor the default on every entry point

Recurring pattern (example `broadcast/4`):

```elixir
# BEFORE
def broadcast(pubsub, topic, message, dispatcher \\ __MODULE__)
    when is_atom(pubsub) and is_binary(topic) and is_atom(dispatcher) do
  {:ok, {adapter, name}} = Registry.meta(pubsub, :pubsub)
  ...
end

# AFTER
def broadcast(pubsub, topic, message, dispatcher \\ nil)
    when is_atom(pubsub) and is_binary(topic) and is_atom(dispatcher) do
  {:ok, {adapter, name, default_dispatcher}} = Registry.meta(pubsub, :pubsub)
  dispatcher = dispatcher || default_dispatcher

  with :ok <- adapter.broadcast(name, topic, message, dispatcher) do
    dispatch(pubsub, :none, topic, message, dispatcher)
  end
end
```

Entry points changed (all of them — this is the cross-file invariant):

| Function | Change |
| --- | --- |
| `broadcast/3,4` | default arg `\\ nil`; resolve `dispatcher \|\| default_dispatcher` |
| `broadcast_from/4,5` | same |
| `local_broadcast/3,4` | now also does `Registry.meta` lookup; `dispatch(..., dispatcher \|\| default_dispatcher)` |
| `local_broadcast_from/4,5` | same |
| `direct_broadcast/4,5` | `adapter.direct_broadcast(..., dispatcher \|\| default_dispatcher)` |
| `broadcast!/3,4` | default arg `\\ nil`, delegates |
| `broadcast_from!/4,5` | default arg `\\ nil`, delegates |
| `direct_broadcast!/4,5` | default arg `\\ nil`, delegates |
| `node_name/1` | meta pattern updated to 3-tuple `{:ok, {adapter, name, _dispatcher}}` (must compile) |

`local_broadcast` after:

```elixir
def local_broadcast(pubsub, topic, message, dispatcher \\ nil)
    when is_atom(pubsub) and is_binary(topic) and is_atom(dispatcher) do
  {:ok, {_adapter, _name, default_dispatcher}} = Registry.meta(pubsub, :pubsub)
  dispatch(pubsub, :none, topic, message, dispatcher || default_dispatcher)
end
```

### 3.3 `test/phoenix/pubsub_test.exs` — 6 new tests

Test dispatcher used in the PR:

```elixir
defmodule TestDispatcher do
  def dispatch(entries, :none, message) do
    for {pid, _} <- entries do
      send(pid, {:custom_dispatched, message})
    end
    :ok
  end

  def dispatch(entries, from, message) do
    for {pid, _} <- entries, pid != from do
      send(pid, {:custom_dispatched, message})
    end
    :ok
  end
end
```

Named tests added under `describe "default dispatcher"`:

1. `defaults to Phoenix.PubSub when no dispatcher configured`
2. `uses configured dispatcher for broadcast/3`
3. `uses configured dispatcher for local_broadcast/3`
4. `uses configured dispatcher for broadcast_from/4`
5. `explicit dispatcher overrides the configured default`
6. `bang variants use configured dispatcher`

(Upstream counts these as “6 new tests”. `direct_broadcast` is **not** unit-tested in the PR tests — only via the bang variant chain. Acceptance design below should still name a direct-broadcast obligation if the ticket claims “all broadcast functions”.)

---

## 4. Exact acceptance checks (named assertions)

Map each check to the requirement it scores. All single-node, offline.

| # | Named assertion | Requirement |
| --- | --- | --- |
| A1 | `test_accept_default_dispatcher_broadcast` | Start `{Phoenix.PubSub, name: name, dispatcher: RecordingDispatcher}`; `subscribe` + `broadcast/3`; assert subscriber receives `{:custom_dispatched, msg}` and **not** the bare `msg`. |
| A2 | `test_accept_default_dispatcher_local_broadcast` | Same with `local_broadcast/3`. |
| A3 | `test_accept_default_dispatcher_broadcast_from` | Same with `broadcast_from/4` from a third-party pid (not the subscriber). |
| A4 | `test_accept_bang_variants_use_default` | `broadcast!/3` (and optionally `broadcast_from!`, `direct_broadcast!`) deliver via configured dispatcher. |
| A5 | `test_accept_no_option_preserves_default_delivery` | PubSub **without** `:dispatcher`; `broadcast/3` delivers the bare message (`assert_receive :hello`). Preservation. |
| A6 | `test_accept_explicit_dispatcher_overrides_default` | PubSub with `dispatcher: TestDispatcher`; call `broadcast(..., Phoenix.PubSub)` (or another explicit module); assert bare delivery, **not** custom. Per-call override wins. |
| A7 | `test_accept_direct_broadcast_uses_default` | `direct_broadcast/4` (or `direct_broadcast!`) without explicit dispatcher uses configured default. (In the PR this is only covered indirectly; if the ticket says “all broadcast functions”, score it.) |
| A8 | `test_accept_node_name_still_works` | `Phoenix.PubSub.node_name/1` still returns a node name after the meta-tuple change (regression for the 3-tuple pattern update). |

**Integrity/bypass controls (must fail a cheating solution):**

| # | Named control | What it rejects |
| --- | --- | --- |
| C1 | `test_ctrl_explicit_arg_not_swallowed` | Solution that makes configured default **always win** over an explicit per-call dispatcher → A6 fails / this control asserts override still works. |
| C2 | `test_ctrl_all_entry_points_honor_default` | Solution that wires only `broadcast/3` and leaves `local_broadcast` / `broadcast_from` / bang / `direct_broadcast` on hardcoded `Phoenix.PubSub` → A2/A3/A4/A7 fail. |
| C3 | `test_ctrl_meta_tuple_consistent` | Solution that stores dispatcher in supervisor but reads 2-tuple meta in `node_name/1` or one reader → compile error or A8 fails. |
| C4 | `test_ctrl_no_option_no_regress` | Solution that changes default delivery shape/payload when option omitted → A5 fails. |

**Preservation checks (must not break — run full existing suite or at least these):**

- Existing `test/phoenix/pubsub_test.exs` child_spec name-required test.
- Existing `test/shared/pubsub_test.exs` adapter suite (uses the shared PubSub started in `test_helper.exs`) — default delivery unchanged.
- `test/phoenix/distributed_pubsub_test.exs` if cluster is available (`:clustered` tag); **optional offline** — see Runtime.
- Tracker tests do not depend on the meta tuple shape directly (they call public API) but will catch broken `broadcast` if run.

---

## 5. Plausible incomplete solution (compiling partial) + expected named failure

**Partial P1 — one entry point missed.** Wire `:dispatcher` in supervisor and in `broadcast/4` only; leave `local_broadcast`, `broadcast_from`, bang variants, or `direct_broadcast` on `dispatcher \\ __MODULE__` / hardcoded module. Compiles and may even pass a naive smoke test.

- Expected named failures: `test_accept_default_dispatcher_local_broadcast` and/or `test_accept_default_dispatcher_broadcast_from` and/or `test_accept_bang_variants_use_default` and/or `test_accept_direct_broadcast_uses_default`.

**Partial P2 — default always wins.** Implement lookup but resolve `default_dispatcher` first (ignore explicit arg when configured). Compiles.

- Expected named failure: `test_accept_explicit_dispatcher_overrides_default` (A6).

**Partial P3 — meta tuple half-migrated.** Supervisor writes 3-tuple but `node_name/1` still matches 2-tuple → `MatchError` at runtime, or compile warning if written with a pin. If they match 2-tuple in one place only, A8 or any call through that path fails.

- Expected named failure: `test_accept_node_name_still_works` (A8) or MatchError in tests.

**Do not use as incomplete:** “forgets tests” — tests are not the scored product surface here.

---

## 6. Reference-challenge findings (FUTURE commits after merge)

Fetched via full clone `git log` on the touched paths after merge `228b82e` (2026-04-17).

### Commits that later touched `lib/phoenix/pubsub.ex` / `lib/phoenix/pubsub/supervisor.ex`

| Commit | Date | Title | Relation to #209 |
| --- | --- | --- | --- |
| `c1ae9f7` | 2026-04-30 | Add `:group_by` option to choose Registry sharding strategy (**#210**) | Extends **same files** and the same meta-tuple path. Not a bugfix of #209. See folded note §9. |
| `0d813c5` | 2026-09-11 author / 2026-10-06 committer | provide a new mechanism for custom message sending (**#218**) | **Deprecates custom dispatchers** (the feature #209 made configurable). Adds `# TODO: remove in 3.0` next to the `:dispatcher` option in supervisor. |
| `be1aa34` | 2026-10-06 | add note about reserved metadata shape and re-add guards | Guards/docs for #218 senders; touches broadcast guards. Not a #209 bugfix. |
| `76f64f9` | 2026-10-07 | Merge PR **#219** Followups for senders | Further sender API; deprecates dispatcher-arg broadcasts via `@doc deprecated`. |
| `cf2c8a0` | 2026-10-08 | Add finalize to sender behaviour (**#220**) | Sender lifecycle only. |

### Verdict for #209 as a case

- **No later commit is a bugfix of the #209 default-dispatcher logic itself.** The 3-tuple meta and `dispatcher || default` pattern were not “repaired”; they were later **superseded/deprecated** by the sender feature in v2.4.0.
- **Reference-challenge / hold H209-1 (product supersession, not a bug):** After v2.4.0, custom dispatchers and the `:dispatcher` child option are deprecated in favor of `Phoenix.PubSub.Sender`. CHANGELOG 2.4.0 migration guide step 3 explicitly says “Remove … the `:dispatcher` option from your PubSub child specification”. Supervisor keeps the option with `# TODO: remove in 3.0`.
  - **Case impact:** Still valid as a historical feature task at base `0b63dce` (pre-supersession). Do **not** grade post-2.4 deprecation behavior. Do **not** combine with the sender feature.
  - If a solver “helpfully” removes `:dispatcher` or rewrites to senders, that is **out of scope** and should fail preservation (A5/A6 still require dispatcher semantics).
- **Hold H209-2 (unclear contract, minor):** PR body says “All broadcast functions default dispatcher to `nil`” but PR tests never call `direct_broadcast/4` without an explicit dispatcher. Upstream behavior does honor the default there (diff is clear). If the ticket says “all broadcast entry points”, include A7; if the ticket is scoped to the 6 upstream tests, A7 is optional extra. **Decide before freezing hidden checks.**
- **Hold H209-3 (over-constrained risk, low):** TestDispatcher’s `dispatch/3` callback signature is `{entries, from, message}` matching `Registry.dispatch`’s `{dispatcher, :dispatch, [from, message]}`. Hidden tests must use that same dispatcher contract (already public via “Custom dispatching” docs at base). Do not require extra callbacks.
- **Flaky risk:** Low. All upstream tests are `async: true` single-node ExUnit with unique PubSub names (`:"ps_default_#{:erlang.unique_integer([:positive])}"`). No sleeps, no cluster.
- **No post-merge “fix bug in default dispatcher” commit exists** in the log through HEAD `79d97f0` (2026-10-08). Confirmed via `git log -- lib/phoenix/pubsub.ex` and `-- lib/phoenix/pubsub/supervisor.ex`.

---

## 7. Runtime / offline / license

| Item | Evidence |
| --- | --- |
| Elixir requirement at base `0b63dce` | `elixir: "~> 1.13"` in `mix.exs` (`Phoenix.PubSub.Mixfile`, `@version "2.2.0"`). Same at merge. |
| OTP | Supervisor raises unless `:persistent_term` (OTP 21.3+). Historical CI at base: Elixir `1.13.4 / 1.16.3 / 1.18.4 / 1.19.4` + `main-otp-28` against OTP `25.3 / 26.2 / 27.3 / 28.1 / maint-28`. Lint on 1.19.4. |
| Deps | Only `{:ex_doc, ">= 0.0.0", only: :docs}`. No runtime deps. `mix deps.get` offline after hex cache or with `--no-deps-check` if only compiling. |
| Database / external services | **None.** Pure OTP + Registry + PG2 adapter. |
| Offline single-node | **Yes.** `test/phoenix/pubsub_test.exs` is `use ExUnit.Case, async: true` with **no** `:clustered` tag. `test_helper.exs` starts one local PubSub (`name: Phoenix.PubSubTest, pool_size: 4`) and only spawns cluster nodes `unless :clustered in exclude`. |
| Cluster / peer | `Phoenix.PubSub.Cluster.spawn/1` uses `:peer.start` + `epmd -daemon` (see `test/support/cluster.ex`). Distributed tests are tagged `:clustered` via `Phoenix.PubSub.NodeCase`. CI runs `epmd -daemon` then `mix test`. |
| Offline command for acceptance | `mix test --exclude clustered` (or `mix test test/phoenix/pubsub_test.exs`) — no network, no DB. |
| License | **MIT**, `LICENSE.md`: “Copyright (c) 2014 Chris McCord”. `mix.exs` `package.licenses: ["MIT"]`. |
| Provenance | Public GitHub PR by external contributor, merged by José Valim. Not synthetic. |

---

## 8. Curator record (template from `docs/pr-selection-guidelines.md`)

```markdown
Source type / project / source revisions / PR or original request:
  historical PR | phoenixframework/phoenix_pubsub |
  base 0b63dce1765de0cb3f57f6c7e5cc6b4fc9ef0d98 → merge 228b82ec2cd1eae6f933e9a723fea82228476fd4 |
  https://github.com/phoenixframework/phoenix_pubsub/pull/209

Status: discovered (deep-dive complete 2026-10-19; ready for provisional pending fixture build)

Case version / release inventory / public or withheld exposure:
  case v0 (to assign) | not yet in any release inventory | public historical PR
  (feature shipped upstream in v2.3.0; later deprecated in v2.4.0 — do not grade deprecation)

Task kind / family / maintenance report or clarified brief:
  feature / OTP PubSub configuration (per-instance default dispatcher)
  brief: see §2 draft ticket

Full solver-visible ticket and appended instructions:
  see §2; name option `:dispatcher` only if treated as requested public interface (PR body does)

Implementation files and each file's role:
  lib/phoenix/pubsub/supervisor.ex — accept/store :dispatcher in Registry meta (3-tuple)
  lib/phoenix/pubsub.ex — all broadcast entry points use configured default when explicit is nil
  (quoted snippets §3)

Test / documentation / generated / mechanical files (separate counts):
  tests: test/phoenix/pubsub_test.exs (+82/−1, 6 named tests)
  docs/generated/mechanical: none in this PR

Cross-component behavior to verify:
  start_link option → Registry meta → every public broadcast entry point;
  explicit per-call dispatcher still wins; default remains Phoenix.PubSub when omitted;
  node_name/1 still works after meta-tuple change

Visible source for each scored obligation:
  A1–A8 map to PR body “Changes” bullets and upstream test names (§4)

Starting-state and reference-test evidence (inspected vs executed):
  Inspected: full .diff, squash commit 228b82e, base tree at 0b63dce (mix.exs, LICENSE,
  test_helper, supervisor, pubsub.ex), future git log through HEAD 79d97f0.
  Executed: NOT executed (no mix test run in this research pass) — unverified runtime.

Plausible partial solution and expected named failure:
  P1 missed entry point → test_accept_default_dispatcher_local_broadcast (or from/bang/direct)
  P2 default always wins → test_accept_explicit_dispatcher_overrides_default
  P3 half-migrated meta tuple → test_accept_node_name_still_works

Preservation and alternative-solution risks:
  Must preserve default delivery with no option (A5), explicit override (A6), existing shared
  adapter suite, child_spec name error. Alternative: store default elsewhere than meta tuple —
  acceptable if all acceptance checks pass and no extra runtime cost claimed.

Runtime / offline services / license evidence and unknowns:
  Elixir ~> 1.13 (mix.exs at base); CI matrix 1.13.4–1.19.4 / OTP 25.3–28.1;
  offline single-node OK (`mix test --exclude clustered`); MIT (LICENSE.md);
  unknown: josevalim issue-comment body on PR (empty/reactions only); API-only fields unverified.

Three-round named control outcomes and frozen-input evidence:
  (not run — case not built yet)

Blind model/settings policy and all attempt IDs (including failures/retries):
  (not run)

Independent contract review / passing-patch reviews / unresolved findings:
  H209-1 product supersession by senders (v2.4.0) — do not grade deprecation;
  H209-2 direct_broadcast coverage gap in upstream tests vs “all functions” wording;
  H209-3 dispatcher callback shape is Registry.dispatch’s dispatch/3 — do not invent extras.

Coverage added / related or duplicate tasks:
  OTP PubSub configuration; distinct from Phoenix web cases and from #218 senders.
  Related (do not bundle): #210 :group_by (see §9), #206 unsubscribe_match (already on base).

Admission or exclusion reason / conditions for reconsideration:
  Candidate: coherent 2-file feature, clear public API from PR body, offline tests, strong
  incomplete controls. Condition: freeze whether A7 (direct_broadcast) is scored; freeze
  ticket wording on naming `:dispatcher`.

Next action:
  Pin runtime to Elixir 1.15+/OTP 26+ (or match CI 1.18/27) in the case image; write ticket
  from §2; implement acceptance A1–A6 (+A7 if scored) and controls C1–C4; do not include
  #210 or #218 senders in the same case.
```

---

## 9. Folded short note — PR #210 (`:group_by`)

**Why folded:** Single option + small supervisor helper + tests (3 files, +71/−1). Thin as a standalone case. Same files/meta path as #209. Task allowed folding.

| Field | Value |
| --- | --- |
| PR | [#210 — Add configurable :group_by option for the underlying Registry](https://github.com/phoenixframework/phoenix_pubsub/pull/210) |
| Author | `studzien` (Rafał Studnicki) |
| Base | `228b82e` (i.e. **stacked on #209**) |
| Merge | **`c1ae9f72ebb400a0beb99c18399f03bf7dd7ad81`** (2026-04-30) |
| PR body | Present: “Adds a `:group_by` option to `Phoenix.PubSub`, forwarded to the underlying Registry. Defaults to `:pid` (no behavior change). Accepts `:key` or pid.” Merge commit message adds: maps `:pid` → `keys: :duplicate`, `:key` → `keys: {:duplicate, :key}` (Elixir 1.19+, refs elixir-lang/elixir#14654); invalid values raise `ArgumentError` at supervisor start; “Refs: #198”. |
| Files | `lib/phoenix/pubsub.ex` (+8 docs), `lib/phoenix/pubsub/supervisor.ex` (+11/−1), `test/phoenix/pubsub_test.exs` (+53) |

Key code:

```elixir
defp registry_keys(:pid), do: :duplicate
defp registry_keys(:key), do: {:duplicate, :key}

defp registry_keys(other) do
  raise ArgumentError,
        "invalid :group_by option (got #{inspect(other)}), must be :pid or :key"
end
```

**Contract holds if ever turned into its own case:**

- `:key` requires **Elixir 1.19+** (`{:duplicate, :key}`). Upstream tests gate the `:key` test with `if Version.match?(System.version(), ">= 1.19.0")`. A case that scores `:key` **must pin Elixir ≥ 1.19** or the test is vacuous.
- Duplicate subscribe on same topic still delivers **once per subscription** in both modes (upstream asserts two `assert_receive :hello`).
- Invalid `:group_by` raises `ArgumentError` at **start_supervised** (supervisor init), message includes `invalid :group_by option` and the got value.
- **Do not bundle** with #209: different author, different requirement (Registry sharding vs default dispatcher), and #210’s tests sit after #209’s in the same file — bundling would make attribution and incomplete-controls ambiguous.

**If a future curator wants a standalone #210 case:** reuse runtime pin Elixir 1.19+/OTP 28, acceptance = default `:pid` double-delivery, explicit `:pid`, `:key` (guarded), invalid raises; incomplete = only implement `:pid` mapping or accept `:key` without requiring 1.19; preservation = `:group_by` omitted behaves exactly as before (including `:duplicate` keys).

---

## 10. Next action (for #209 case)

1. Freeze scope: #209 **only** (no #210, no senders).
2. Write solver ticket from §2 with `:dispatcher` as the named public option (upstream product API).
3. Build acceptance A1–A6 and decide A7/A8; controls C1–C4.
4. Pin image to Elixir ~> 1.13-compatible toolchain actually used in CI at base (recommend 1.18.4 / OTP 27.3 for safety).
5. Offline: `mix test --exclude clustered` or targeted `test/phoenix/pubsub_test.exs`.
6. Record H209-1 (supersession) in the case’s reference-challenge notes so graders do not reward sender-based rewrites.
