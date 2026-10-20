# Large feature — Cachex #341 named warmer processes

**Status:** discovered
**Source type:** historical merged PR (fixes #334)
**Project:** [whitfin/cachex](https://github.com/whitfin/cachex)
**PR:** [#341](https://github.com/whitfin/cachex/pull/341) — Allow warmers to be have named processes
**Author:** whitfin · **Merged:** 2024-03-24
**Source revisions:** base `b22cb1ffcd0763f011f1ed3868b8589147050052` → head `3f6283852e3cbdd335431f90f36fd2ea725bef34` → merge `e700e966da6017337318bea205058144c9d5d332`
**Size:** +127 / −87, **10 changed files**
**Task kind / family:** bounded feature / cache warmer supervision + selective warm
**Research date:** 2026-10-19
**License:** MIT (`package().licenses: ["MIT"]`)

---

## Why it is a LIMIT-TESTING case

Warmers already exist in the starting tree. The feature adds a **public `name` on the warmer record** so a warmer GenServer can be named (atom) or left to its pid, and **selective `Cachex.warm/2` filtering** via `only`. Consistency must hold across:

1. **Spec record** — `:warmer` gains `name: GenServer.server()` (default nil).
2. **Validator** — name must be nil, atom, or pid; module must still implement `Cachex.Warmer`.
3. **Incubator** — child spec uses `[name: val]` only when name is set.
4. **Informant / Steward / Services** — shared linking/supervision logic pulled up so named and unnamed warmers both work.
5. **Warm action** — `Cachex.warm/2` can filter by module or name (`only`).
6. **Public API docs** — `Cachex.warm/2` and warmer struct options.

Eight implementation files, coherent OTP ownership. A partial that names the process but breaks warm filtering (or vice versa) is plausible and compiles.

## File inventory with roles

From `pull/341.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/cachex/spec.ex` | `:warmer` record gains `name` (type + default). |
| `lib/cachex/spec/validator.ex` | Validate name is `nil` / atom / pid alongside Warmer behaviour checks. |
| `lib/cachex/services/incubator.ex` | Start warmer with `name:` only when provided. |
| `lib/cachex/services/informant.ex` | Common linking logic moved toward `Cachex.Services`. |
| `lib/cachex/services/steward.ex` | Same shared linking for warmers. |
| `lib/cachex/services.ex` | Shared parent-link helpers used by incubator/informant/steward. |
| `lib/cachex/actions/warm.ex` | `only` filtering by module/name. |
| `lib/cachex.ex` | Public `Cachex.warm/2` option surface. |

**Counts:** 8 substantive implementation files. Tests separate.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/cachex/actions/warm_test.exs` | Warm with/without `only`; named vs unnamed warmers. |
| `test/cachex/options_test.exs` | Option/record parsing including warmer `name`. |

### Mechanical / docs

| Path | Note |
| --- | --- |
| (none material) | PR body is the product description. |

## Draft clarified feature brief

> Let a cache warmer register under an optional process name so multiple warmers can be supervised and addressed without colliding on the module atom. When a name is given, warmers start under that name; when it is omitted, keep today’s unnamed/pid behavior. `Cachex.warm/2` should be able to warm only selected warmers by module or name. Invalid warmer names must fail validation. Keep existing warmer modules and full-cache warm working.

Keep `Cachex.warm/2` and the warmer `name` option visible if graded. Do **not** name `Incubator`, `Informant`, or the record internals.

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **Named start:** warmer with `name: :my_warmer` is reachable as that name after cache start. |
| A2 | **Unnamed preserved:** warmer with `name: nil` still starts (pid/module as today). |
| A3 | **Validation:** non-atom/non-pid names are rejected (upstream warmer validation tests). |
| A4 | **Selective warm:** `Cachex.warm(cache, only: ModuleOrName)` warms only that warmer (upstream `warm_test` `only` cases). |
| A5 | **Full warm:** `Cachex.warm/2` without `only` still warms every warmer. |
| A6 | **Preservation:** ordinary puts/gets, hooks, and non-warmer caches unchanged. |

## Incomplete control

**Compiling partial that misses one area:** add `name` to the `:warmer` record and incubator start options, but leave `Cachex.warm/2` without `only` filtering.

- A1–A3 pass; **A4** fails (selective warm).
- Second partial: `only` filter but incubator always passes `name: module` → **A2**/collision behavior fails for unnamed multi-instance warmers.

## Integrity / shortcut rejection

Reject patches that:

- Require every warmer to be named (breaks existing modules).
- Make `only` ignore the filter and always warm everything.
- Break `Cachex.Warmer` behaviour checks (`interval/0`, `execute/1`).
- Register two warmers under the same forced name and crash the cache on start.

## Preservation of existing behavior

- Existing warmer modules without `name` keep working (issue #334 is an addition, not a break).
- Hook/informant behavior for non-warmer hooks is unchanged (shared-link refactor must not drop hook linking).
- `Cachex.warm/2` with no options remains “warm all”.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.5` at base | Cachex `3.6.0` mix.exs. |
| Services | None. ETS cache + ExUnit. |
| Depends on existing warmer feature | Starting tree already has `Cachex.Warmer`; this PR does not introduce warming from scratch. |
| MIT | Provenance notice. |

Not verified here: compile/test/boot.

## Status: discovered

Eight-file OTP/service coordination around one public option. Strong library limit-test next to Absinthe grammar work.

## Next action

1. Pin base `b22cb1ffcd0763f011f1ed3868b8589147050052`.
2. Brief names warmer `name` + `Cachex.warm/2` `only` filter as requested public API.
3. Incomplete = named start without selective warm.
4. Acceptance: `test/cachex/actions/warm_test.exs` + options/validator tests.
