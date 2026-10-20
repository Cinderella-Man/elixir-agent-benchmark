# Experiment log — large-feature deep-dives 2026-10-20

Honest record of commands and outcomes. WSL Ubuntu (git 2.53.0) + Docker (elixir images, postgres). Host has Elixir 1.20.4 but WSL path maps to Windows elixir without erl; all mix runs used Docker.

## Work directory

`/tmp/large-dd` in WSL (PR json/diff/patch + clones + apply trees).
Scripts: `docs/research/new-candidates-2026-10-19/_work/large-deepdive-2026-10-20/*.sh`

## PR fetch

| Case | API JSON | diff | patch | Notes |
| --- | --- | --- | --- | --- |
| BeaconCMS/beacon#687 | OK (22960 B) | 15879 B | 75324 B (25 commits) | API `commits: 36` ≠ patch series 25 |
| puemos/craftplan#51 | rate-limit 279 B | 12075 B | 12895 B (1 commit) | metadata recovered from clone |
| absinthe-graphql/absinthe#1404 | rate-limit 279 B | 21824 B | 23378 B (1 commit) | metadata recovered from clone |

GitHub unauthenticated API rate-limited after Beacon. Diff/patch downloads were fine.

## SHA verification (full clones)

### Beacon
- merge `1aa11357…` = squash, **1 parent** `86c9ffd2…`
- dossier base `78c0fef0…` is ancestor (1 commit: #723 ProxyEndpoint); NOT first parent
- head `3952b128…` NOT in default clone
- first-parent..merge: 15 files +235/-18

### Craftplan
- merge `46c0a6fa…` = squash, **1 parent** `ad9fb484…` = dossier base **YES**
- head `ff52fcab…` on `origin/feat/47-cancel-production-batch`, same diff as squash
- first-parent..merge: 8 files +157/-5

### Absinthe
- merge `c029a611…` = squash, **1 parent** `8fba7023…`
- dossier base `8e451950…` is ancestor (3 commits: #1409, #1419, release 1.10.0)
- head `65ce8ccf…` NOT in default clone
- first-parent..merge: 7 files +608/-8

## git apply results

| Case | Base | classic `git apply --check` | `git apply --3way` |
| --- | --- | --- | --- |
| Beacon | 86c9ffd (first parent) | **PASS** all 15 | **PASS** |
| Beacon | 78c0fef (claimed) | **FAIL** CHANGELOG.md | **FAIL** (UU CHANGELOG.md) |
| Craftplan | ad9fb48 | **PASS** all 8 | **PASS** |
| Absinthe | 8fba702 (first parent) | **PASS** all 7 | **PASS** |
| Absinthe | 8e45195 (claimed) | (not classic-tested) | **PASS** all 7 |

## mix test results

### Absinthe (`elixir:1.17-otp-27`, no services)
- base+patch `document_description_test.exs`: **26 tests, 0 failures**
- base+patch full: **1468 tests, 0 failures** (re-run) / **1468, 1 failure** (first run, InlineFunctionsTest)
- base full (no patch): **1442 tests, 0 failures**
- `inline_functions_test.exs` alone at base+patch: **3 tests, 1 failure** (flaky / seed, unrelated to descriptions)

### Craftplan (`elixir:1.20-otp-28`, postgres:16)
- `elixir:1.18` **refuses** (`~> 1.20` requirement) — honest env failure before 1.20 image
- base+patch `production_batching_test.exs`: **9 passed**
- base+patch `production_batch_live_actions_test.exs`: **15 passed**

### Beacon (`elixir:1.14-otp-25`, postgres:15)
- Without `mix esbuild.install` + `mix tailwind.install --no-assets`: Beacon.Boot `Beacon.LoaderError`, tests cannot run
- `mix ecto.create` alone: `couldn't be created: killed` (resolved by manual `CREATE DATABASE` + CLI installs)
- After setup: `sitemap_controller_test.exs` **2 tests, 0 failures**
- `media_library_controller_test.exs` + `install_test.exs`: **4 tests, 0 failures**

## Absinthe spec probes (base+patch)

- description before shorthand `{ … }`: **accepted** (spec §2.4 forbids) — untested by PR tests
- description before anonymous `query { … }`: **accepted** (spec allows)
- description before anonymous `mutation { … }` (spec Example № 4): **accepted**; `inspect(doc, pretty: true)` renders it
- `Language.Document` Inspect → `Language.Render` confirmed in source

## GraphQL spec fetch

https://spec.graphql.org/September2025/#sec-Descriptions — confirmed descriptions on operations and fragments; Example № 4 anonymous mutation with description; “Descriptions are not permitted on query shorthand.”

## Not done / residual

- No commits, no cases/ bundles
- Three-round qualification / blind model runs not started
- Full Beacon and Craftplan suites not run
- GitHub API PR bodies for craftplan/absinthe not fetched (rate limit)
