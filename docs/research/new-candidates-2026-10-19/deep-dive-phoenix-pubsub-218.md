# Deep-dive case prep — Phoenix.PubSub PR #218 (message senders)
### Lineage includes #219 (followups) and #220 (finalize)

**Research date:** 2026-10-19
**Sole-source status:** This file is the case-creation source of truth for the sender feature lineage (#218 core + follow-ups). Companion short note: `phoenix-pubsub-218-message-senders.md`.
**Evidence method:** GitHub HTML PR pages for #218/#219/#220, `https://github.com/phoenixframework/phoenix_pubsub/pull/218.diff` (also 219.diff, 220.diff), local full clone of `phoenixframework/phoenix_pubsub` (HEAD `79d97f0bb040b4e77a04efbe5b140d81faba7a39`) including `git fetch origin pull/218/head` for pre-squash commits. GitHub REST API was rate-limited (core remaining=0); API-only fields marked **unverified**.

---

## 1. Identity

### 1.1 Core PR #218

| Field | Value |
| --- | --- |
| Project | [phoenixframework/phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub) |
| PR | [#218 — Message senders](https://github.com/phoenixframework/phoenix_pubsub/pull/218) |
| Author | `SteffenDE` (Steffen Deusch \<steffen@deusch.me\>) |
| Merged by | `SteffenDE` |
| State | MERGED |
| Branch | `sd-sender` → `main` |
| PR opened | comment dated Sep 11, 2026 |
| PR merged | **Oct 6, 2026** (committer date `2026-10-06 17:13:59 +0200` on the squash commit) |
| Base SHA | `01cf8ed2d71f9f7798314fe79a766214131238ad` (Release v2.3.0) |
| **Squash / merge SHA** | **`0d813c5a463ad6c0749885cab8b1d89bd66d804b`** — title `provide a new mechanism for custom message sending`, body “deprecates custom dispatchers”. Author date 2026-09-11 12:05:49 +0200. |
| Earlier research note SHA `391d814f55ce09e5ab1f43e1e447c552a3e65908` | **NOT FOUND** in the clone (`fatal: bad object`). Do not use. Treat as **unverified/erroneous**. Use `0d813c5a463ad6c0749885cab8b1d89bd66d804b`. |
| PR body | **EMPTY** (“No description provided.”) |
| Commits on PR head (pre-squash) | 6: `bda91e1` provide a new mechanism…, `01ff82d` fixes, `b6f3892` apply suggestions from code review, `05b60a6` Use cons to store sender information, `4872a71` Remove uneeded deprecation clause, `3128ce1` only deprecate in docs for now |
| Linked issues | None closing. **Referenced by / related:** [phoenix_live_view#4441 PubSub integration for LiveViews and LiveComponents](https://github.com/phoenixframework/phoenix_live_view/pull/4441) (Merged); [#217 Add tagged subscriptions](https://github.com/phoenixframework/phoenix_pubsub/pull/217) (Closed — not the same feature). |
| Review | `josevalim` reviewed Sep 13 (threads on `lib/phoenix/pubsub.ex`, `lib/phoenix/pubsub/pg2.ex` — thread bodies not rendered in scrape, **unverified**), Sep 15 (thread on `test/support/remote_dispatcher.ex`). **Approved Sep 15** with visible comment (below). |
| Other participants | `edgurgel` (contributor) comments around Oct 7–8 that led to #220. |
| Release | **v2.4.0** (2026-10-07) — “Add `Phoenix.PubSub.Sender` as a successor for custom dispatchers”. Then **v2.4.1** (2026-10-08) adds `finalize/1`. |

**josevalim approval comment (verbatim, Sep 15, 2026):**

> Looks good to me! Let's make sure Phoenix v1.8 can run this without runtime warnings and it is good to go!

**Squash commit file stat (`0d813c5`):**

```
lib/phoenix/pubsub.ex                    | 183 ++++++++++++++++++++++++++++---
lib/phoenix/pubsub/sender.ex             |  35 ++++++  (NEW)
lib/phoenix/pubsub/supervisor.ex         |   2 +
test/phoenix/distributed_pubsub_test.exs |  27 +++++
test/phoenix/pubsub_test.exs             | 142 ++++++++++++++++++++++++++++++++
test/support/node_case.ex                |  13 +++
test/support/remote_dispatcher.ex        |  24 ++++  (NEW)
7 files changed, 408 insertions(+), 18 deletions(-)
```

### 1.2 Follow-up PR #219 — Followups for senders

| Field | Value |
| --- | --- |
| PR | [#219 — Followups for senders](https://github.com/phoenixframework/phoenix_pubsub/pull/219) |
| Author / merger | `SteffenDE` |
| Branch | `sd-sender-2` |
| Body | **EMPTY** (“No description provided.”) |
| Merged | **Oct 7, 2026** |
| Merge SHA | **`76f64f9d4c4c4057c5b45c08197c7b6182d4ed5e`** (single-parent squash-style commit titled “Merge pull request #219 from phoenixframework/sd-sender-2”) |
| Commits | `9864417` Followups for senders, `b792e62` use `@doc deprecated` |
| Review | `josevalim` reviewed Oct 6, approved Oct 7. 12 checks passed on merge. |
| File stat of merge | `CHANGELOG.md` +34, `lib/phoenix/pubsub.ex` ±86, `lib/phoenix/pubsub/sender.ex` +21/−?, `test/phoenix/pubsub_test.exs` +70 — 4 files, +166/−45 |

**SteffenDE’s contract research comment (Oct 6, 2026) — critical for metadata shape:**

> I let Codex query the GitHub API for Elixir code using PubSub metadata and it did not find anyone using lists, so I think that change is fine. Another option would be to restrict sender metadata to be a tuple, then [:foo] would not be ambiguous.
>
> | Project | Subscription metadata |
> | Phoenix (`channel/server.ex` L443–444) | `{:fastlane, ...}` tuple |
> | Livebook (`session.ex` L3233) | `{encoder, receiver_pid}` tuple |
> | Spawn (`actors/actor/pubsub.ex` L41–47) | Map |
> | Oban’s Phoenix notifier | `__MODULE__` atom |

Note: PR timeline also shows `SteffenDE force-pushed the main branch from 6fb1edc to be1aa34` and force-pushed `sd-sender-2` `4fc12cd → 9864417` on Oct 6. `be1aa34` is on `main` as parent of the #219 merge — see §6 reference bugs.

### 1.3 Follow-up PR #220 — Add finalize to sender behaviour

| Field | Value |
| --- | --- |
| PR | [#220 — Add finalize to sender behaviour](https://github.com/phoenixframework/phoenix_pubsub/pull/220) |
| Author | `josevalim` |
| Merger | `SteffenDE` |
| Branch | `jv-sender-finalize` |
| Merged | **Oct 8, 2026** |
| Merge / squash SHA | **`cf2c8a08fef846a27a89c4beb07aa4a365616aa8`** (2 commits: `b90f671` Add finalize…, then “Make it optional”) |
| File stat | `lib/phoenix/pubsub.ex` +26/−10, `lib/phoenix/pubsub/sender.ex` +15, `test/phoenix/pubsub_test.exs` +20 — 3 files, +51/−10 |

**PR body (verbatim):**

> cc @edgurgel
> We can make this an optional callback OR we retire 2.4.0 and launch as 2.4.1 OR we launch 2.5.0. Thoughts?

**Discussion (all Oct 8, 2026):**

- `edgurgel`: “I was thinking about an optional callback but happy with whatever you prefer!”
- `edgurgel` approved: “I think this could be an optional callback but this way works as well!”
- `SteffenDE`: “I'm thinking optional + 2.4.1 is what I'd do!”
- `josevalim`: “I was kind hoping to avoid the optional check because we most likely need to traverse the map at the end anyway and that would help us eliminate one additional branch but i guess the performance is negligible either way.”
- Outcome: commit “Make it optional” → `@optional_callbacks finalize: 1` + `function_exported?(module, :finalize, 1)`. Shipped as **v2.4.1**.

---

## 2. User-visible outcome + draft ticket

### Outcome
A subscriber can pass `sender: {MySender, meta}` to `Phoenix.PubSub.subscribe/3`. Local deliveries to that subscription go through `MySender.send/4` instead of a bare `send/2`, with an optional per-module accumulator (`state`) and optional `finalize/1` after the partition finishes. Plain subscribers are unchanged. Custom dispatchers still work but are deprecated (docs). `unsubscribe_sender/3` removes sender subscriptions selectively (from #219).

### Draft ticket — THREE lineages. Pick ONE before any hidden check.

#### Option L1 — Core only (#218 squash `0d813c5`, plus mandatory `be1aa34` guard fix — see §6)

> Let me plug a custom message sender into a PubSub the way I can plug a dispatcher, but at subscribe time. When I subscribe with `sender: {Module, meta}`, deliveries to that subscription should call `Module.send/4` with `(pid, meta, message, state)` instead of a plain send, so I can transform or tag messages and cache serialized payloads across subscribers via `state`. Ordinary subscriptions with no sender must keep receiving the bare message. Sender metadata must not collide with existing `:metadata` list-shaped values.
>
> (If finalize is out of scope, stop here.)

#### Option L2 — Core + #219 followups (unsubscribe_sender + doc deprecations)

> …plus: let me remove only my matching sender subscriptions with `unsubscribe_sender/3`, and mark custom-dispatcher broadcast APIs as deprecated in docs without breaking them.

#### Option L3 — Full v2.4.1 surface (#218 + #219 + #220)

> …plus: after all deliveries in a registry partition, call an **optional** `finalize/1` once per sender module that was invoked, with that module’s final accumulated state. Return value ignored. Modules that do not implement `finalize/1` must not error.

**Recommendation:** **L1 + explicit finalize** is the richest still-coherent feature; **L1 without finalize** is the smallest that matches “message senders” as first shipped. Do **not** mix “optional callback” acceptance with “required callback” hidden checks (the #220 thread is exactly this fork). Freeze one lineage.

**API surface to freeze (exact):**

| Surface | Signature / shape |
| --- | --- |
| Subscribe opt | `subscribe(pubsub, topic, sender: {module, meta})` where `is_atom(module)` |
| Stored registry meta | **`[module \| meta]`** improper/cons list — NOT `{module, meta}` tuple (changed in `05b60a6`) |
| Behaviour | `@callback send(pid :: pid(), meta :: term(), message :: term(), state :: term()) :: term()` |
| Optional finalize (L3) | `@callback finalize(state :: term()) :: term()` + `@optional_callbacks finalize: 1` |
| Acc semantics | First call in a partition for that module gets `state = nil`; return value is passed to the next subscriber **of the same module in the same partition**. Reset per broadcast, per partition, per module. Different metadata same module **share** the accumulator. |
| Deprecated metadata | `:metadata` in shape `[mod \| _]` **raises**; other `:metadata` still works |
| Unsubscribe (L2) | `unsubscribe_sender(pubsub, topic, {module, metadata})` → `unsubscribe_match(pubsub, topic, [module \| metadata])` with same pattern-match rules |

---

## 3. Implementation files and roles (with real snippets)

### 3.1 `lib/phoenix/pubsub/sender.ex` (NEW) — behaviour

Final form (after #220):

```elixir
defmodule Phoenix.PubSub.Sender do
  @moduledoc """
  Defines a custom message sender.
  ...
  """

  @callback send(pid :: pid(), meta :: term(), message :: term(), state :: term()) :: term()

  @doc """
  Finalizes a sender's accumulated state after dispatch completes in a Registry partition.
  This callback is optional. Its return value is ignored.
  """
  @callback finalize(state :: term()) :: term()

  @optional_callbacks finalize: 1
end
```

Core-only form (`0d813c5`) has only `send/4` and no `finalize`.

### 3.2 `lib/phoenix/pubsub.ex` — subscribe storage + dispatch

**subscribe/3 (after #218, cons-list storage):**

```elixir
meta =
  case opts[:sender] do
    {mod, term} when is_atom(mod) ->
      [mod | term]

    _ ->
      # TODO: Deprecate me
      case opts[:metadata] do
        [mod | _] when is_atom(mod) ->
          raise "passing metadata in the shape of [module | term] to subscribe is unsupported"

        other ->
          other
      end
  end

case Registry.register(pubsub, topic, meta) do
  {:ok, _} -> :ok
  {:error, _} = error -> error
end
```

**dispatch/3 (core #218; finalize added in #220):**

```elixir
def dispatch(entries, :none, message) do
  states =
    for {pid, metadata} <- entries, reduce: %{} do
      acc ->
        dispatch_with_optional_sender(pid, metadata, message, acc)
    end

  Enum.each(states, &finalize_sender/1)   # (220; #218 just returned :ok)
end

def dispatch(entries, from, message) do
  states =
    for {pid, metadata} <- entries, pid != from, reduce: %{} do
      acc ->
        dispatch_with_optional_sender(pid, metadata, message, acc)
    end

  Enum.each(states, &finalize_sender/1)
end

defp dispatch_with_optional_sender(pid, [module | meta], message, acc) when is_atom(module) do
  state = Map.get(acc, module, nil)
  new_state = module.send(pid, meta, message, state)
  Map.put(acc, module, new_state)
end

defp dispatch_with_optional_sender(pid, _metadata, message, acc) do
  send(pid, message)
  acc
end

defp finalize_sender({module, state}) do
  if function_exported?(module, :finalize, 1), do: module.finalize(state)
end
```

**API split (important for preservation):** #218 **splits** each broadcast into `/3` (no dispatcher) and `/4` (explicit dispatcher) clauses instead of `dispatcher \\ nil` defaults. Example:

```elixir
def broadcast(pubsub, topic, message)
    when is_atom(pubsub) and is_binary(topic) do
  {:ok, {adapter, name, dispatcher}} = Registry.meta(pubsub, :pubsub)
  with :ok <- adapter.broadcast(name, topic, message, dispatcher) do
    dispatch(pubsub, :none, topic, message, dispatcher)
  end
end

def broadcast(pubsub, topic, message, dispatcher) do
  {:ok, {adapter, name, default_dispatcher}} = Registry.meta(pubsub, :pubsub)
  dispatcher = dispatcher || default_dispatcher
  ...
end
```

Same split for `broadcast_from`, `local_broadcast`, `local_broadcast_from`, `direct_broadcast`, and the three `!` variants. Docs on dispatcher-arity clauses say custom dispatchers are deprecated (later `@doc deprecated` in #219).

**unsubscribe_sender/3 (from #219):**

```elixir
def unsubscribe_sender(pubsub, topic, {module, metadata})
    when is_atom(pubsub) and is_binary(topic) and is_atom(module) do
  unsubscribe_match(pubsub, topic, [module | metadata])
end
```

### 3.3 `lib/phoenix/pubsub/supervisor.ex` — tiny change

```elixir
# TODO: remove in 3.0
dispatcher = Keyword.get(opts, :dispatcher, Phoenix.PubSub)
```

(Comment added in #218 next to the #209 option. No sender option at the PubSub child level — senders are per-subscription.)

### 3.4 Test / support files

| File | Role |
| --- | --- |
| `test/phoenix/pubsub_test.exs` | `describe ":sender"` — TestSender/OtherSender, invoke instead of plain send, once per subscription, state accumulation within partition, state isolation across partitions, coexist with plain subscribers, `broadcast_from` skips sender, `local_broadcast`, unsubscribe; (219) `unsubscribe_sender` cases; (220) finalize once with accumulated state |
| `test/phoenix/distributed_pubsub_test.exs` | `custom dispatcher travels to remote nodes`, `:sender is honoured for remote subscribers` (cluster) |
| `test/support/node_case.ex` | `spy_on_pubsub_with_sender/5` |
| `test/support/remote_dispatcher.ex` | NEW: `Phoenix.PubSub.RemoteDispatcher` + `Phoenix.PubSub.RemoteSender` for multi-node assertions |

Upstream test names worth mirroring (single-node):

- `invokes the sender instead of a plain send`
- `delivers exactly once per subscription`
- `plain subscribers are delivered exactly once`
- `state accumulates across subscriptions within a registry partition`
- `state does not carry across registry partitions`
- `senders and plain subscribers coexist on one topic`
- `broadcast_from/4 skips the sending process`
- `local_broadcast/3 invokes the sender`
- `unsubscribe removes the sender subscription`
- (220) `broadcast invokes optional finalization once with the accumulated state`
- (219) `unsubscribe_sender removes only the caller's matching sender subscriptions`, `unsubscribe_sender matches metadata patterns`, `unsubscribe_sender with no match leaves subscriptions active`

---

## 4. Exact acceptance checks (named assertions)

Single-node first. Cluster only if the brief claims remote delivery.

### Core (L1)

| # | Named assertion | Requirement |
| --- | --- | --- |
| A1 | `test_accept_sender_instead_of_plain_send` | `subscribe(..., sender: {TestSender, meta})`; `broadcast/3`; assert `TestSender` delivered tagged message; **refute** bare `message`. |
| A2 | `test_accept_plain_subscriber_unchanged` | No sender → `assert_receive message`; payload/shape identical to today. |
| A3 | `test_accept_sender_and_plain_coexist` | Mixed subscribers on one topic: each gets its own path exactly once. |
| A4 | `test_accept_state_accumulates_within_partition` | `registry_size: 1`; three sender subs; states observed `nil`, then prior return values (e.g. `[nil,1,2]`). |
| A5 | `test_accept_state_isolated_across_partitions` | `pool_size: 2, registry_size: 2`; multiple `nil`s (one per partition that has a sender). |
| A6 | `test_accept_broadcast_from_skips_caller` | Sender sub of caller is skipped (`refute_received`). |
| A7 | `test_accept_local_broadcast_invokes_sender` | `local_broadcast/3` also honors sender. |
| A8 | `test_accept_unsubscribe_removes_sender_sub` | After `unsubscribe/2`, no sender delivery. |
| A9 | `test_accept_metadata_list_shape_raises` | `subscribe(..., metadata: [SomeMod \| _])` raises the reserved-shape error (contract from `be1aa34` / #219). |
| A10 | `test_accept_sender_metadata_tuple_input` | `sender: {Mod, meta}` with various `meta` (atom, tuple) works — input is `{mod, meta}`; storage is `[mod \| meta]`. |

### If L3 (finalize)

| # | Named assertion | Requirement |
| --- | --- | --- |
| A11 | `test_accept_finalize_optional_once` | Sender with `finalize/1` called **once** per partition with final state; other modules untouched; plain subs unaffected. |
| A12 | `test_accept_finalize_absent_ok` | Sender **without** `finalize/1` does not error (`function_exported?` path). |

### If L2 (unsubscribe_sender)

| # | Named assertion | Requirement |
| --- | --- | --- |
| A13 | `test_accept_unsubscribe_sender_selective` | Removes only caller’s matching `{mod, meta}`; other topics / other modules / other meta remain. |
| A14 | `test_accept_unsubscribe_sender_pattern_meta` | `{TestSender, {:custom, :_}}` pattern matching like `unsubscribe_match`. |

### Integrity / bypass controls

| # | Named control | Rejects |
| --- | --- | --- |
| C1 | `test_ctrl_sender_not_ignored` | “Sender” that always falls back to `send(pid, message)` (never calls `module.send/4`) → A1 fails. |
| C2 | `test_ctrl_no_double_delivery` | Sender path that also plain-sends → double message; A1/A3 refute bare/extra. |
| C3 | `test_ctrl_default_payload_unchanged` | Sender feature that changes plain-subscriber message shape → A2 fails. |
| C4 | `test_ctrl_cons_list_contract` | Solution that stores senders as `{mod, meta}` tuples and matches tuples in dispatch: if hidden tests subscribe via `sender: {Mod, meta}` and expect `Mod.send/4`, a tuple-only implementation that forgets the cons encoding may still pass IF dispatch matches the same encoding — **so encode the contract in the brief or test only through the public `sender:` option**. Do **not** require the internal storage shape unless the ticket says so. (See §6 H218-2.) |
| C5 | `test_ctrl_from_skip` | Sender dispatch that does not skip `from` on `broadcast_from` → A6 fails. |
| C6 | `test_ctrl_finalize_once` (L3) | Finalize called per subscriber instead of once per module per partition → A11 fails. |

### Preservation checks

- All existing tests at base `01cf8ed`: especially `test/shared/pubsub_test.exs` adapter suite, `test/phoenix/pubsub_test.exs` pre-existing tests, tracker tests.
- Custom dispatcher arity still works (cluster test `custom dispatcher travels to remote nodes` if cluster on; at least local `broadcast(..., RemoteDispatcher)` style call must not crash).
- `:metadata` option still works for non-list shapes (Phoenix fastlane tuple, Livebook tuple, maps, bare atoms — per SteffenDE’s survey in #219).
- `unsubscribe_match/3` still works.
- `Phoenix.PubSub.Supervisor` still accepts `:dispatcher` (deprecated but present).

---

## 5. Plausible incomplete solutions (compiling partial) + expected named failure

**P1 — behaviour + broadcast/3 only.** Implement `sender.ex`, store meta, wire `broadcast/3` path; leave `local_broadcast` / `broadcast_from` / bangs / `direct_broadcast` on old `for {pid, _} <- entries, do: send(pid, message)`.

- Expected failure: `test_accept_local_broadcast_invokes_sender` or `test_accept_broadcast_from_skips_caller`.

**P2 — tuple vs cons mismatch.** Store `sender: {Mod, meta}` as `{Mod, meta}` in Registry but dispatch matches `[module | meta]`. Compiles. Sender silently falls through to plain `send`.

- Expected failure: `test_accept_sender_instead_of_plain_send` (receives bare message; `refute_received :hello` fails). **This is the realistic partial — upstream itself switched mid-PR (`05b60a6`).**

**P3 — sender ignored when metadata missing.** Match only `{module, meta}` and require meta; plain `sender: {Mod, :atom}` breaks.

- Expected failure: any test with atomic meta.

**P4 (L3) — finalize required.** Implement `finalize/1` as mandatory `@callback` without `@optional_callbacks` / without `function_exported?`. Senders without finalize crash.

- Expected failure: `test_accept_finalize_absent_ok`. **This is exactly the #220 product fork — do not require both “optional” and “always call”.**

**P5 (L2) — unsubscribe_sender drops all subs.** Use `unsubscribe/2` instead of `unsubscribe_match` on `[module | metadata]`.

- Expected failure: `test_accept_unsubscribe_sender_selective`.

---

## 6. Reference-challenge findings (FUTURE commits / holds)

### 6.1 Post-#218 commits touching the same files (after squash `0d813c5`)

From `git log` on `lib/phoenix/pubsub.ex`, `lib/phoenix/pubsub/sender.ex`, `lib/phoenix/pubsub/supervisor.ex` after `01cf8ed`:

| Commit | Date | Title | Nature |
| --- | --- | --- | --- |
| **`be1aa34`** | 2026-10-06 | **add note about reserved metadata shape and re-add guards** | **POST-MERGE FIX on main** — see H218-1 |
| `76f64f9` | 2026-10-07 | Merge PR #219 Followups for senders | Feature follow-up (unsubscribe_sender, @doc deprecated, CHANGELOG migration) |
| `43688f7` | 2026-10-08 | Update docs | Docs only |
| `cf2c8a0` | 2026-10-08 | Add finalize to sender behaviour (#220) | Feature follow-up (optional finalize) |
| `904731e` / `79d97f0` | 2026-10-08 | Release v2.4.1 / update changelog | Release |

### H218-1 — REFERENCE BUG: dropped guards, fixed in `be1aa34` (HOLD)

`0d813c5` / PR #218 **removed** the `when is_atom(dispatcher)` guard from `broadcast/4` (and related dispatcher-arity heads) when splitting clauses:

```diff
   @spec broadcast(t, topic, message, dispatcher) :: :ok | {:error, term}
-  def broadcast(pubsub, topic, message, dispatcher \\ nil)
-      when is_atom(pubsub) and is_binary(topic) and is_atom(dispatcher) do
+  def broadcast(pubsub, topic, message, dispatcher) do
```

`be1aa34` (on main **after** the squash, **before** #219 merge) re-adds:

```diff
-  def broadcast(pubsub, topic, message, dispatcher) do
+  def broadcast(pubsub, topic, message, dispatcher)
+      when is_atom(pubsub) and is_binary(topic) and is_atom(dispatcher) do
```

and documents that `:metadata` in `[atom | term]` shape is reserved/raises.

**Case impact:**

1. **Do not score “guards on broadcast/4” as required** if the reference patch is the raw #218 squash — the reference itself lacked them until `be1aa34`.
2. Either (a) use `0d813c5` + `be1aa34` as the reference repair (two-commit window), or (b) omit guard checks from acceptance.
3. A plausible incomplete that “only adds senders and drops dispatcher guards” is **historically authentic** (it is what merged) — do not treat it as a pure invention.

### H218-2 — Unclear contract: storage shape

Upstream changed sender storage from `{mod, term}` to `[mod | term]` mid-PR (`05b60a6 Use cons to store sender information`) so that the reserved metadata shape `[mod | _]` is unambiguous. Public API is `sender: {mod, meta}`. **Hidden tests must go through `subscribe(..., sender: ...)`**, not through Registry.lookup shape, unless the ticket specifies the cons encoding. SteffenDE’s comment explicitly considered “restrict sender metadata to be a tuple” as an alternative — that alternative was **not** shipped.

### H218-3 — Lineage freeze (do not score three cases)

#218 + #219 + #220 are one feature-then-correction lineage in three days (Oct 6–8 committer dates; authoring Sep 11–Oct 8). Count as **one** case with one frozen surface (L1/L2/L3). Do not mint three benchmarks.

### H218-4 — Optional vs required finalize

#220 thread: optional callback was chosen (v2.4.1). `function_exported?/3` + `@optional_callbacks finalize: 1`. If L3, acceptance **must** allow senders without `finalize/1`. Requiring finalize would fail the reference.

### H218-5 — Deprecation is docs-only in the merged core

`3128ce1 only deprecate in docs for now` **removed** `@deprecated` attributes from the core PR. #219 later added `@doc deprecated`. Phoenix v1.8 “without runtime warnings” was josevalim’s merge condition. **Do not require `@deprecated` module attributes** on the core-only lineage. Do not fail a solver that only updates docs.

### H218-6 — Over-constrained test risk: state accumulation

State is **per sender module, per registry partition, per broadcast**. Tests that assume global serialization cache across partitions would be wrong. Upstream tests pin this with `registry_size: 1` vs `registry_size: 2`. Flaky risk if hidden tests assume a single partition when `pool_size`/`registry_size` default to schedulers/4. **Always pin `registry_size: 1` or assert per-partition semantics.**

### H218-7 — Multi-node / flaky

Distributed tests need `epmd` + `:peer` + four nodes (`node1`–`node4@127.0.0.1`). Not required for L1 single-node acceptance. If included, runner must support `:peer` offline on loopback. Mark **runner unverified** for peer.

### H218-8 — Empty PR bodies

#218 and #219 bodies are empty. Ticket must be reconstructed from diffs + comments (this dossier). Independent contract review is mandatory before hidden checks.

---

## 7. Runtime / offline / license

| Item | Evidence |
| --- | --- |
| Elixir at base `01cf8ed` | `elixir: "~> 1.13"`, `@version "2.3.0"` in `mix.exs` |
| Elixir at merge window | Still `~> 1.13`. CI at base: 1.13.4/OTP 25.3, 1.16.3/26.2, 1.18.4/27.3, 1.19.4/28.1 (lint), `main-otp-28`. After #218, main added 1.20.4/OTP 29 (`5b81eae`, `1527c10`) — not required for the feature. |
| Deps | Only `ex_doc` for docs. No runtime deps. |
| Offline single-node | **Yes** for core sender tests (`test/phoenix/pubsub_test.exs`, `async: true`, no `:clustered` tag). `mix test test/phoenix/pubsub_test.exs` or `mix test --exclude clustered`. |
| Cluster | `Phoenix.PubSub.Cluster` uses `:peer.start` + `epmd -daemon`. Distributed sender tests are `@moduletag :clustered`. |
| Services | None (no DB, no network beyond loopback epmd if clustered). |
| License | MIT, Copyright (c) 2014 Chris McCord. |
| Provenance | Phoenix team (SteffenDE, josevalim, edgurgel). Authentic upstream. |

---

## 8. Curator record (template from `docs/pr-selection-guidelines.md`)

```markdown
Source type / project / source revisions / PR or original request:
  historical PR lineage | phoenixframework/phoenix_pubsub |
  base 01cf8ed2d71f9f7798314fe79a766214131238ad
  core squash 0d813c5a463ad6c0749885cab8b1d89bd66d804b
  guard fix be1aa34079061439ae3a879682a05b5592df4ded
  #219 76f64f9d4c4c4057c5b45c08197c7b6182d4ed5e
  #220 cf2c8a08fef846a27a89c4beb07aa4a365616aa8
  | https://github.com/phoenixframework/phoenix_pubsub/pull/218
    (plus #219, #220)

Status: discovered (deep-dive complete 2026-10-19)
  HOLD pending lineage freeze (L1 vs L2 vs L3) and H218-1 guard scoring decision

Case version / release inventory / public or withheld exposure:
  case v0 (to assign) | not yet inventoried | public historical PRs
  (shipped upstream v2.4.0 / v2.4.1)

Task kind / family / maintenance report or clarified brief:
  feature / PubSub sender behaviour (subscribe-time custom delivery + state)
  brief: §2 Option L1 / L2 / L3 — pick one

Full solver-visible ticket and appended instructions:
  from §2 after lineage freeze; public API is subscribe sender: {mod, meta},
  Sender.send/4, (L3) optional finalize/1, (L2) unsubscribe_sender/3

Implementation files and each file's role:
  lib/phoenix/pubsub/sender.ex (new behaviour)
  lib/phoenix/pubsub.ex (subscribe meta encoding + dispatch_with_optional_sender
    + API arity split + unsubscribe_sender + finalize_sender)
  lib/phoenix/pubsub/supervisor.ex (TODO comment only)
  quoted §3

Test / documentation / generated / mechanical files (separate counts):
  tests: pubsub_test.exs describe ":sender", distributed_pubsub_test.exs (cluster),
    node_case.ex helper, remote_dispatcher.ex support
  docs: CHANGELOG migration guide (#219); sender.ex moduledoc
  generated/mechanical: none

Cross-component behavior to verify:
  subscribe opt → Registry meta → dispatch on local and (if scored) remote;
  plain vs sender coexistence; broadcast_from skip; state per module/partition;
  optional finalize; metadata reserved shape raises

Visible source for each scored obligation:
  A1–A14 map to upstream test names in §3.4 / §4; PR body empty — obligations
  come from diffs + josevalim/edgurgel/SteffenDE comments quoted in §1

Starting-state and reference-test evidence (inspected vs executed):
  Inspected: .diff 218/219/220, pre-squash PR head commits, be1aa34 full diff,
  mix.exs/LICENSE/test_helper/CI at base and HEAD, CHANGELOG 2.4.0/2.4.1,
  PR HTML conversations for 218/219/220.
  Executed: NOT executed (no mix test in this research pass) — unverified runtime.

Plausible partial solution and expected named failure:
  P1 wire only broadcast/3 → test_accept_local_broadcast_invokes_sender
  P2 tuple vs cons storage → test_accept_sender_instead_of_plain_send
  P3 require meta → tests with atomic meta
  P4 finalize required → test_accept_finalize_absent_ok
  P5 unsubscribe_sender unselective → test_accept_unsubscribe_sender_selective

Preservation and alternative-solution risks:
  plain delivery byte-stable; :metadata non-list shapes keep working (Phoenix
  fastlane, Livebook, maps, atoms); custom dispatcher arity still callable;
  unsubscribe_match still works; :dispatcher option still accepted.
  Alt solutions: different internal meta encoding OK if public sender: works.

Runtime / offline services / license evidence and unknowns:
  Elixir ~> 1.13; offline single-node OK; cluster optional via :peer+epmd;
  MIT LICENSE.md; unknown: josevalim inline review threads on pg2.ex / remote_dispatcher.ex
  (bodies not scraped); peer runner support unverified.

Three-round named control outcomes and frozen-input evidence:
  (not run — case not built yet)

Blind model/settings policy and all attempt IDs (including failures/retries):
  (not run)

Independent contract review / passing-patch reviews / unresolved findings:
  H218-1 reference bug (guards) — HOLD
  H218-2 storage shape must not be over-specified in hidden tests
  H218-3 freeze L1/L2/L3 as one case
  H218-4 finalize optional (do not require)
  H218-5 deprecation docs-only on core
  H218-6 pin registry_size in state tests
  H218-7 cluster optional
  H218-8 empty bodies → brief reconstructed

Coverage added / related or duplicate tasks:
  OTP messaging extension points / behaviour callbacks.
  Distinct from #209 default dispatcher (do not bundle; #218 deprecates it).
  Related upstream consumer: phoenix_live_view#4441.

Admission or exclusion reason / conditions for reconsideration:
  Strong authentic multi-file feature with review lineage. Conditions before
  admission: (1) freeze L1/L2/L3; (2) resolve H218-1 scoring of guards;
  (3) independent contract review of ticket wording (bodies empty).

Next action:
  Freeze L1+optional-finalize (or L1 only); write brief naming sender: {mod, meta}
  and Sender.send/4 (+ optional finalize if L3); build A1–A10 (+A11–12) and C1–C6;
  decide guard policy per H218-1; single-node offline acceptance; do not score
  distributed delivery unless runner has :peer.
```

---

## 9. Next action

1. **Freeze lineage** (recommend **L1 + optional finalize** as one coherent “message senders” case, matching v2.4.1 capability, or **L1 only** if smaller is better). Document the choice in the case brief.
2. **Resolve H218-1:** either fold `be1aa34` into the reference repair or drop guard assertions.
3. Write the solver ticket from §2 (public API only: `sender: {module, meta}`, `Phoenix.PubSub.Sender.send/4`, optional `finalize/1` if L3).
4. Implement acceptance A1–A10 (A11–A12 if L3) and controls C1–C6; pin `registry_size` in state tests.
5. Runtime pin: Elixir 1.18+/OTP 27+ (compatible with `~> 1.13`); offline `mix test test/phoenix/pubsub_test.exs --exclude clustered`.
6. Do **not** create separate cases for #219 or #220. Do **not** bundle with #209.
