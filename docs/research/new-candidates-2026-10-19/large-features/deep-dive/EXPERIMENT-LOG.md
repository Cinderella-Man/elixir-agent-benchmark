# Experiment log — large-feature deep-dives (2026-10-19/20)

Honest record of what was executed vs inspected. Toolchain: WSL git 2.53 for clone/apply; **Windows Elixir 1.20.4 / OTP 29** for `mix` (WSL had no native Elixir; `sudo` password required for apt). MySQL integration via Docker `mysql:8.0`.

Artifacts: `../_work/experiments/` (diffs, JSON extracts, shell scripts, snapshotted trees under `trees/`).

## Matrix

| Case | Clone | `git apply` at base | Applied == claimed head/merge | `mix` acceptance | `mix` broader | Later commits on files |
| --- | --- | --- | --- | --- | --- | --- |
| cachex #341 | OK | **clean** | == PR head `3f62838` | 15 passed (warm+options) | **200 passed** full | 82; warmer fix #403 out of scope |
| cachex #306 | OK | **clean** | 9/9 feature files match head; 3 mechanical residual | 7 passed (scheduled+evented+policy) | 196/197 (InspectTest env) | many; `:batch_size`→`:buffer` later |
| broadway #344 | OK | **clean** | == PR head `f370304` | 2 passed (config_storage_test) | 106/107 without storage test; **31/129 with it** (test isolation bug) | #345, #349 follow-up fixes |
| ecto_sql #703 | OK | **clean** | == merge `af90644` (exact) | 142 unit MyXQL + 303 pg/tds + 2 named insert_mode | Integration upsert_all **7/7** on MySQL; full integration 422/433 | `:ignore_errors`→`:ignore` rename next day |

## SHA corrections (summary)

| Case | Correction |
| --- | --- |
| cachex #341 | “merge” `e700e96` is last of **3 linear landings**, not a 2-parent merge. PR head `3f62838` still exists. |
| cachex #306 | Claimed base `fc4f2a0` is **not** merge-base (`8c55685`) and **not** ancestor of head. Still applies. Landing `7b4062b` is single-parent. Final commit **flips default to Scheduled**. |
| broadway #344 | Head `f370304` exists via `pull/344/head`. Merge is squash onto main **after #343** (`format_discarded` residual is not #344). |
| ecto_sql #703 | Squash parent == claimed base. Intermediate HTML SHAs `8c7955d`/`cb3f237` are dead (force-push). |

## Lineage (cachex #306 ↔ #341) — do not double-count blindly

- Shared file: **only** `lib/cachex/services.ex`.
- #306 (2023-01) = policy-server supervision; #341 (2024-03) = hook/warmer linking.
- #306 is an **ancestor** of #341 (base of #341 already contains #306).
- Two product outcomes (eviction vs warmer names). Keep as two cases only with a corpus lineage note.

## ecto_sql #703 grading boundary (requested split)

| Layer | Command | DB? | Passed here |
| --- | --- | --- | --- |
| L1 unit SQL | `mix test test/ecto/adapters/myxql_test.exs` (+ pg/tds) | **No** | 142 + 303 + 2 named |
| L2 MySQL integration | `ECTO_ADAPTER=myxql mix test integration_test/myxql/upsert_all_test.exs` | **Yes** | 7/7 including all three `insert_mode` tests |

Score A1/A2/A5 offline; A3/A4 service-gated. Do not mock away L2.

## Honest gaps / not run

- No WSL-native Elixir (could not `apt install` without sudo password). All `mix` runs are Windows Elixir 1.20.4 / OTP 29 — **newer** than project floors (1.5–1.14). Results should be re-checked on era toolchain before freezing, but all four compiled and their acceptance tests passed.
- cachex #306 full suite: `InspectTest` failure on OTP 29 memory shapes (unrelated to PR).
- broadway full suite with storage test in same VM: 98 failures from **reference test isolation** (`put_env(..., nil)`), not from the feature.
- ecto_sql full integration: 11 unrelated failures outside `upsert_all_test`.
- Cachex #306 apply at true merge-base `8c55685` not re-run (claimed base applied clean).
- No three-round qualification, no blind model runs (out of scope for this deep-dive pass).
- No commits made; no `cases/` bundles written.

## Commands (canonical)

```bash
# clone + apply (pattern)
git clone https://github.com/<org>/<repo>.git <name>
cd <name> && git checkout <base_sha>
git apply --check /path/to/pr.diff && git apply /path/to/pr.diff
git add -A && git diff --cached <pr_head_or_merge> --stat

# mix (Windows PowerShell)
$env:Path = "C:\Program Files\Elixir\bin;C:\Program Files\Erlang OTP\bin;" + $env:Path
$env:MIX_ENV = "test"
mix deps.get && mix test <files>

# ecto_sql MySQL integration
docker run -d --name elx-mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -e MYSQL_DATABASE=ecto_test -p 3306:3306 mysql:8.0
$env:ECTO_ADAPTER = "myxql"; $env:MYSQL_URL = "root@127.0.0.1"
mix test integration_test/myxql/upsert_all_test.exs --trace
```
