# Large feature — Broadway #344 pluggable configuration storage

**Status:** discovered
**Source type:** historical merged PR (addresses #342)
**Project:** [elixir-broadway/broadway](https://github.com/elixir-broadway/broadway)
**PR:** [#344](https://github.com/elixir-broadway/broadway/pull/344) — feat: refactor persistent term usage to behaviour
**Author:** Ziinc · **Merged:** 2024-11-29
**Source revisions:** base `8d29ca4e4d8e05eede10608a336ad70215d4886d` → head `f370304c533fca35cbc225856c3a1764e00bd834` → merge `1151db21d51433b592b55421cd9689d8c81ca339`
**Size:** +250 / −15, **6 changed files**
**Task kind / family:** bounded feature / OTP config store behind a behaviour
**Research date:** 2026-10-19
**License:** Apache-2.0 (`package().licenses: ["Apache-2.0"]`)

---

## Why it is a LIMIT-TESTING case

Broadway stores `%Broadway.Topology{}` in `:persistent_term`. Many dynamically named Broadway servers cause global GC / unbounded persistent_term growth. The PR introduces a **public configuration-storage choice** (`config Broadway, config_storage: :ets | :persistent_term | module`) with a small behaviour and two implementations. Consistency must hold across:

1. **`Broadway.ConfigStorage` behaviour** — `setup/0` (optional), `list/0`, `put/2`, `get/1`, `delete/1`; `get_module/0` / `get_options/0` readers.
2. **`Broadway.ConfigStorage.Ets`** — named or custom-named ETS table; setup/put/get/delete/list.
3. **`Broadway.ConfigStorage.PersistentTerm`** — default; OTP 21.3+ check moves here.
4. **`Broadway.Topology`** — start writes through the store; `config/1` reads through it; terminate deletes by name; optional `setup/0`.
5. **`Broadway` docs** — public app config keys and migration note.

Five implementation files, clear product API in the PR body and moduledoc. A partial that implements ETS but leaves topology on persistent_term is the natural incomplete.

## File inventory with roles

From `pull/344.diff`.

### Implementation (substantive)

| Path | Role |
| --- | --- |
| `lib/broadway/config_storage.ex` | Behaviour + module/option resolution. |
| `lib/broadway/config_storage/ets.ex` | ETS implementation (`:broadway_co` default table, `table_name` opt). |
| `lib/broadway/config_storage/persistent_term.ex` | Default implementation (previous behavior). |
| `lib/broadway/topology.ex` | All config get/put/delete go through `ConfigStorage`. |
| `lib/broadway.ex` | Documents `:config_storage` / `:config_storage_opts`. |

**Counts:** 5 substantive implementation files. New test module.

### Tests (contract-describing)

| Path | Contract covered |
| --- | --- |
| `test/broadway/config_storage_test.exs` | ETS default options and custom `table_name` (`"ets default options"`, `"ets custom name"`). |

### Mechanical / docs

| Path | Note |
| --- | --- |
| (docs in `lib/broadway.ex`) | Public config documentation — part of the feature contract. |

## Draft clarified feature brief

> Broadway must be able to store running topology configuration in ETS instead of `:persistent_term`, selected with application config (`config_storage: :ets` or `:persistent_term`, plus storage options such as a custom ETS table name). Starting and stopping Broadway servers must create and remove configuration in the chosen store so many dynamic Broadway names do not accumulate global persistent_term data. Default behavior stays persistent_term. Existing Broadway pipelines must keep resolving their configuration the same way.

Keep the public config keys `config_storage` and `config_storage_opts` in the brief if graded. Do **not** name `Broadway.ConfigStorage.Ets` unless the brief treats the behaviour as requested public API (PR ships it as `@moduledoc false` — prefer grading observable config + lifecycle).

## Named acceptance checks

| ID | Observable obligation |
| --- | --- |
| A1 | **ETS store lifecycle:** with `config_storage: :ets`, put/get/list/delete behave (`"ets default options"`). |
| A2 | **Custom table:** `config_storage_opts: [table_name: :my_table]` uses that table (`"ets custom name"`). |
| A3 | **Topology start/stop:** starting a named Broadway with ETS storage registers config; terminate removes it (no leak). |
| A4 | **Default preserved:** omitting config still uses persistent_term (OTP check / previous tests). |
| A5 | **Resolution:** unknown/malformed storage config does not silently corrupt the default path. |
| A6 | **Preservation:** ordinary Broadway producer/batcher tests still pass with the default store. |

## Incomplete control

**Compiling partial that misses one area:** implement `ConfigStorage` + ETS module and tests, but leave `Broadway.Topology` still calling `:persistent_term` directly.

- A1/A2 pass (unit-level ETS); **A3** fails (topology never uses the store).
- Second partial: wire topology reads but not `terminate` deletes → leak assertion fails after stop.

## Integrity / shortcut rejection

Reject patches that:

- Make ETS the silent default (A4).
- Leave persistent_term entries after terminate when ETS is selected (or vice versa).
- Require OTP 21.3+ check only in the default path in a way that ETS setups crash on missing `setup/0`.
- Change pipeline message processing under the guise of storage.

## Preservation of existing behavior

- Default `:persistent_term` path is unchanged for existing apps.
- `Broadway` public pipeline API (producers, batchers, acknowledgers) untouched.
- Full Broadway suite remains the preservation net; storage tests are additive.

## Runtime / offline holds

| Hold | Notes |
| --- | --- |
| Elixir `~> 1.7` at base | Broadway `1.1.0`. |
| Services | None. |
| `async: false` on storage tests | App env mutation — run storage tests in isolation or accept ExUnit’s serial module. |
| Apache-2.0 | Provenance notice. |

Not verified here: compile/test/boot. Upstream suite may need a specific Elixir/OTP pairing from CI.

## Status: discovered

Clean five-file feature with a real product motivation (dynamic Broadway names / GC). Good OTP-adjacent diversity.

## Next action

1. Pin base `8d29ca4e4d8e05eede10608a336ad70215d4886d`.
2. Brief freezes `config_storage: :ets | :persistent_term` and custom table option as public.
3. Incomplete = ETS module without topology wiring.
4. Acceptance: `test/broadway/config_storage_test.exs` + a small start/stop leak check + default preservation.
