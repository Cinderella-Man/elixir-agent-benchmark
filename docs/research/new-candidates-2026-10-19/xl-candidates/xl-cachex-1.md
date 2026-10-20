# XL candidate — cachex #353 customizable routers for distributed caches

**Status:** discovered
**Source type:** historical merged PR (cluster routing refactor + feature)
**Project:** [whitfin/cachex](https://github.com/whitfin/cachex)
**PR:** [#353](https://github.com/whitfin/cachex/pull/353) — Refactor cluster based dispatch and enable customizable routers
**Author:** whitfin · **Merged:** 2024-08-25
**Source revisions:** merge `f66a6faa13873b9970a5a693147a05439614e7e6`
**Size:** +1056 / −466, **30 changed files** (14 substantive implementation)
**Task kind / family:** bounded feature + structural refactor / distributed cache routing
**Research date:** 2026-10-19
**License:** MIT (`package().licenses: ["MIT"]`)

---

## Why it is an XL LIMIT-TESTING case

Cachex v3 hard-coded jump-hash routing and a `:nodes` option. This PR introduces a **`Cachex.Router` behaviour** with four implementations (Local, Mod, Jump, Ring), moves the old router logic into a `Cachex.Services.Conductor` service, and reshapes node/cluster options across the public API. Consistency must hold across:

1. **`Cachex.Router`** — behaviour definition (`route/2`, `nodes/1`) and migration of old macro-based routing out.
2. **Four router modules** — `Local` (default, local-only), `Mod` (hash % len), `Jump` (jump consistent hash, v3-compatible), `Ring` (libring hash ring with dynamic node scaling).
3. **`Cachex.Services.Conductor`** — new service that owns cluster state and dispatches through the configured router.
4. **`Cachex.Options` / `Cachex.Spec` / `Validator`** — accept `:router` option; remove `:nodes` from the main API (nodes become a router option).
5. **`Cachex` public API** — `transaction/3`, `fetch/3` and remote calls route through the configured router.
6. **`Cachex.Actions.Transaction` / `Cachex.Policy.LRW.Evented`** — adapt to router-based dispatch.

14 implementation files: behaviour + 4 routers + conductor service + options/spec/validator + API + actions. One coherent product outcome (pluggable distributed routing).

## File inventory with roles

From `pull/353.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/cachex/router.ex` | `Cachex.Router` behaviour; remove old macro routing. |
| `lib/cachex/router/local.ex` | Default router — local node only. |
| `lib/cachex/router/mod.ex` | Basic `hash(key) % len(nodes)` router. |
| `lib/cachex/router/jump.ex` | Jump consistent hash (v3-compatible). |
| `lib/cachex/router/ring.ex` | Hash ring via `libring`; dynamic node scaling. |
| `lib/cachex/services/conductor.ex` | New service: cluster state + router dispatch. |
| `lib/cachex/services.ex` | Start conductor in the supervision tree. |
| `lib/cachex/options.ex` | `:router` option; remove `:nodes` from main API. |
| `lib/cachex/spec.ex` | Cache record gains cluster/router fields. |
| `lib/cachex/spec/validator.ex` | Validate `:router` option shape. |
| `lib/cachex.ex` | Public API routes through conductor/router. |
| `lib/cachex/actions/transaction.ex` | Transactions use router dispatch. |
| `lib/cachex/errors.ex` | Router-related error structs. |
| `lib/cachex/policy/lrw/evented.ex` | LRW policy adapts to router-based node view. |

**Counts:** 14 substantive implementation files. Tests + mix.exs + coveralls.json separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/cachex/router_test.exs` | Behaviour contract. |
| `test/cachex/router/local_test.exs` | Local router semantics. |
| `test/cachex/router/mod_test.exs` | Mod router distribution. |
| `test/cachex/router/jump_test.exs` | Jump hash consistency. |
| `test/cachex/router/ring_test.exs` | Ring router + dynamic nodes. |
| `test/cachex/options_test.exs` | `:router` option validation; `:nodes` removal. |
| `test/cachex/spec/validator_test.exs` | Spec validation for router. |
| `test/cachex/services_test.exs` | Conductor lifecycle. |
| `test/cachex/actions/transaction_test.exs` | Transaction routing. |
| `test/cachex/errors_test.exs` | Router error shapes. |
| `test/cachex/policy/lrw/evented_test.exs` | LRW with router. |
| `test/lib/cachex_case/helper.ex` | Test helper updates for router setup. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| `mix.exs` | Add `libring` dependency. |
| `coveralls.json` | Coverage config tweak. |
| `test/test_helper.exs` | Test bootstrap. |

## Draft clarified feature brief

> Distributed Cachex caches should support pluggable key-to-node routing. Define a router behaviour and provide four built-in routers: local-only (default), basic modulo hash, jump consistent hash (compatible with v3), and a hash ring that can scale with added/removed nodes. The `:router` option on `Cachex.start_link` selects the router; router-specific node lists are router options, not a top-level `:nodes` option. Remote dispatch (including transactions) must go through the configured router. Cluster state lives in a dedicated service.

Keep `Cachex.Router`, `Cachex.Router.Local/Mod/Jump/Ring`, and the `:router` option as the requested public API. Do **not** name `Cachex.Services.Conductor` or internal dispatch helpers.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Default is local:** starting a cache without `:router` uses local-only routing; no remote dispatch. |
| A2 | **Mod router:** keys distribute by `hash(key) % len(nodes)` across the configured node list. |
| A3 | **Jump router:** same key→node mapping as Cachex v3 jump hashing for a fixed node list. |
| A4 | **Ring router:** keys map via hash ring; adding/removing nodes remaps only a fraction of keys (not all). |
| A5 | **`:nodes` removed:** top-level `:nodes` is rejected or ignored; node lists are router options. |
| A6 | **Transactions route:** `Cachex.transaction/3` on a distributed cache dispatches through the configured router. |
| A7 | **Behaviour contract:** a custom module implementing the router behaviour can be passed as `:router` and receives `route/2` calls. |

## Incomplete control

**Compiling partial that misses one area:** implement the behaviour and Local/Jump routers but forget to wire `Cachex.Actions.Transaction` through the router.

- Router unit tests pass; **A6** fails (transactions bypass the router).
- Second partial: ship Ring without dynamic node scaling → **A4** fails on add/remove.

## Integrity / shortcut rejection

Reject patches that:

- Keep `:nodes` as a working top-level option (A5).
- Make all routers ignore their options and always use connected nodes.
- Break the existing LRW policy tests (preservation).
- Ship only the behaviour without the four named implementations.

## Preservation of existing behavior

- Single-node caches behave as before (Local is the default).
- Jump router preserves v3 hash mapping for existing clusters.
- Existing action tests (fetch, transaction, errors) remain green.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.7` at base (2024 era) | Cachex v4.0.0 milestone. |
| `libring` dependency | Hex package; must be available offline. |
| Tests | Pure ExUnit + ETS — no services. Some tests are timing-sensitive (LRW). |
| MIT | Provenance notice. |

Not verified here: compile/test/boot. Confirm `libring` is fetchable offline before qualification.

## Status: discovered

14-file distributed-routing feature with a clear behaviour contract, four named implementations, and measurable distribution/remapping outcomes. Strong OTP + clustering diversity pick.

## Next action

1. Pin base at merge parent of `f66a6faa13873b9970a5a693147a05439614e7e6` (2024-08).
2. Brief names `Cachex.Router` behaviour, four router modules, and `:router` option.
3. Incomplete = behaviour + Local/Jump without transaction wiring (A6 fails).
4. Acceptance offline: `mix test test/cachex/router/ test/cachex/options_test.exs`; LRW timing tests may need `async: false`.

## Provenance notes

- Closes issues #246 (dynamic nodes), #344 (jump→libring), #345 (cluster state abstraction).
- Breaking change (v4.0.0): `:nodes` removed from main API — the brief must state this explicitly so solvers do not preserve the old option.
- Previously noted in large-features as "14 impl — over window; cluster/router rewrite" — that is exactly the XL target.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Distributed Cachex caches should support pluggable key-to-node routing. Provide a router behaviour and four built-in routers: local-only (default), modulo hash, jump consistent hash (compatible with v3), and a hash ring that remaps only a fraction of keys when nodes are added or removed. Select the router with a `:router` start option; node lists are router options, not a top-level `:nodes` option. Remote dispatch, including transactions, must go through the configured router. Cluster state lives in a dedicated service.

Clarified brief / breaking-change feature. Product decisions already stated: default is Local, `:nodes` is removed, four named routers, transactions included, ring remaps fractionally. Two tightenings:

- "compatible with v3" needs an executable definition: "for a fixed node list, the jump router must map a given key to the same node the v3 jump hash did." Provide a golden mapping table in the checks (curator-authored), not a live v3 comparison.
- "remaps only a fraction of keys" is currently a wishlist. Make it a hard check: e.g. with nodes `[a,b,c]` → add `d`, at least one key stays put and at most some bound moves. Or replace with "adding a node does not rehash every key to a single node" — simpler and still blocks the always-rehash cheat. Do not leave "fraction" unquantified.

### 2. Deterministic checks

ExUnit + ETS. No network. **Fake:** a custom router module implementing the behaviour (test-local). **Do not** need multi-node distribution — `:nodes` is an explicit router option; tests pass a fake node list. Avoid `:erlang.multinode` setups.

| ID | Setup | Observable | Pass |
| --- | --- | --- | --- |
| `default-is-local` | `Cachex.start_link(:c)` with no `:router` | `Cachex.route` / fetch path | no remote dispatch; keys stay local |
| `mod-distributes-by-modulo` | `:router` = Mod, `nodes: [:a,:b,:c]`, known keys | `Router.route/2` | `hash(key) rem 3` mapping |
| `jump-golden-mapping` | Jump router, fixed `[:n1,:n2,:n3]`, curator table of 5–10 keys | `route/2` | matches table exactly |
| `ring-remap-partial` | Ring with `[a,b,c]`; compute routes for 20 keys; add `d`; recompute | route map | ≥1 key stable; not all keys moved to one node |
| `nodes-option-rejected` | `Cachex.start_link(:c, nodes: [:a])` | start result / options parse | `:nodes` is not accepted as a top-level cache option |
| `router-option-nodes` | Mod/Jump/Ring with `:nodes` **inside** the router tuple/opts | routes | uses the configured list, not connected nodes |
| `transaction-routes` | distributed cache + custom router recording calls | `Cachex.transaction/3` | custom `route/2` observed |
| `custom-router-conforms` | test module implementing the behaviour | `:router` = that module | init + route called; returns a node |
| `preservation-single-node` | existing action tests, no router | suite | green |
| `preservation-lrw` | existing LRW policy tests | suite | green (with `async: false` if needed) |

Without `nodes-option-rejected`, keeping `:nodes` as a silent alias passes. Without `custom-router-conforms`, shipping only the four built-ins passes A7. Without `transaction-routes`, transactions can bypass the router. Without `jump-golden-mapping`, a solver can invent any jump hash.

### 3. Ambiguity / unfairness

- **Hidden behaviour surface:** the actual `Cachex.Router` callbacks in the reference are `init/2`, `nodes/1`, `route/2`, **and** `spec/2`. The brief says "route/2 calls". If checks require a custom module to implement the full behaviour, that is an unstated API. Either name the callbacks as the requested behaviour surface or grade only "custom module can be selected and receives route/2".
- Validator quirk: reference checks `{:nodes, 1} in module.__info__(:functions)` for custom routers. Do **not** grade that internal validation shape; grade the observable route outcome.
- `:nodes` removal is a **breaking change**. The brief states it (good). Checks must accept "rejected" or "ignored" consistently — pick one and say it. "Rejected or ignored" in the dossier is ambiguous; prefer "not honoured as a top-level cache option" so both raise and ignore-and-stay-local are acceptable only if local is actually local. Cleanest: top-level `:nodes` is invalid and start fails validation.
- Ring "fraction remapped" bound is unstated (see above).
- Ring via `libring`: solvers may implement the ring themselves. That is fine — grade remap behaviour, not `libring` usage.
- "Cluster state lives in a dedicated service" is internal architecture. Do not assert on `Cachex.Services.Conductor` existing. Grade that routing works and `:router` is honoured.

### 4. Shortcuts

- Behaviour + Local/Jump only, no transaction wiring → fails `transaction-routes`. Correct incomplete.
- Ring without dynamic node scaling → fails `ring-remap-partial`.
- All routers ignore their options and use `Node.list()` / connected nodes → fails `router-option-nodes` and `jump-golden-mapping`.
- Keep `:nodes` working as before → fails `nodes-option-rejected`.
- Default is Mod/Jump instead of Local → fails `default-is-local` and may break single-node preservation.
- Custom `:router` accepted but never called (always Local) → fails `custom-router-conforms` / `transaction-routes`.
- Four modules with identical implementations → fails jump golden + mod modulo + ring remap.

### 5. Flakiness

Medium, contained. LRW policy tests are timing-sensitive (dossier already flags `async: false`). Router tests themselves are pure and deterministic. Do **not** grade "keys spread evenly" with statistical assertions — use exact modulo/golden tables. No real cluster, no epmd. `libring` is deterministic for a fixed node list.

### 6. Coverage mix

- Positive: default local, mod mapping, jump golden, ring remap, transaction routing, custom router.
- Negative: top-level `:nodes` not honoured; custom router not silently ignored.
- Preservation: single-node caches, LRW, existing actions.
- Mixed: one cache with a custom router + transactions + a key list that spans nodes, so a Local-only default leaks.

### 7. Environment

- MIT. Pure ExUnit + ETS. No services.
- **`libring` is a new Hex dep** — must be in the offline cache at the pinned 2024-era version. If the offline mirror lacks it, either vendor it or drop Ring from the graded surface and say so in the brief (that would shrink the case; prefer keeping it).
- Elixir `~> 1.7` at base is very old; confirm the runner image actually has a compatible OTP. Cachex 4.0 milestone era.
- **Nothing executed.** No apply, no compile.

### 8. XL-specific

14 impl files is **real coordination**: behaviour + four implementations + conductor + options/spec/validator + public API + transaction + LRW is one contract that must agree. The four routers are implementations of one interface — that is the coordination, not make-work. Possible split: (a) behaviour + Local/Jump + options (~8 files), (b) Ring + dynamic nodes + conductor (~5 files). That split is **tempting** but weakens the "one router contract" story; keep as one XL case if the environment holds. Outcome is one story (pluggable routing).

### 9. Verdict

**READY-WITH-FIX** — sharp behaviour contract and measurable distribution outcomes, but custom-router callback surface, `:nodes` reject policy, ring remap bound, and `libring` offline availability must be settled first.

### 10. Must-fix before qualification

1. Name the behaviour callbacks the brief requires (at minimum `route/2`; decide on `init/2`/`nodes/1`/`spec/2`).
2. Replace "fraction of keys" with a hard remap assertion.
3. State `:nodes` policy precisely (invalid at top level; allowed inside router options).
4. Bake a jump-hash golden mapping table (curator-authored from v3).
5. Confirm `libring` in the offline cache; pin base at merge parent of `f66a6faa…`.
6. Incomplete = behaviour + Local/Jump without transaction wiring. Integrity = ignore router options; keep `:nodes`; identical routers; default not Local.
7. LRW tests `async: false`; no statistical distribution assertions.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Hidden behaviour callbacks; libring offline; unquantified ring remap |
