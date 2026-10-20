# app-candidate-changelog.com-562

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/thechangelog/changelog.com/pull/562 |
| Title | Isolate release preparation from Oban workers |
| Project | thechangelog/changelog.com |
| Source type | Historical merged PR (OTP supervision / release-task isolation) |
| PR head SHA | `cdeff84f84a2c87a3806df3712526938b32baeb0` (1 commit) |
| Parent of first commit (likely base) | `8aaa784595fd98430245ccfffd91f232cc30910c` |
| Merged at | 2026-09-07T20:28:11Z |
| License | Custom: content/design © Changelog Media LLC; code under MIT-style permission |
| Elixir | `~> 1.18` |
| Verification | **Unverified** — full diff inspected; tests not executed |

## Why it is a case

Release hooks (`mix changelog.static.upload`, `mix ecto.migrate`) boot the app with production config. That started Oban consumers/plugins/leadership on a temporary release machine, so release preparation could acquire background work.

What must stay consistent:

- Supervisor children: Oban is present and running in normal app start, absent when `CHANGELOG_RELEASE_TASK=1`.
- Repo/Endpoint/app_cache still start in release-task mode (release needs deps, not workers).
- Telemetry/Oban reporter attach only when Oban workers are active.
- `docker/scripts/on.deploy` exports the release-task flag and runs upload then migrate in order with fail-fast.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/changelog/application.ex` | Conditional Oban child + telemetry attach based on `CHANGELOG_RELEASE_TASK` |
| `docker/scripts/on.deploy` | Export flag; ordered `static.upload` then `ecto.migrate`; fail-fast |

Tests (separate): `test/changelog/release_task_test.exs` (fresh VM startup matrix + stubbed release hook).

## Draft ticket

> Our deploy release hook starts the whole application, so Oban workers can pick up jobs while we are only trying to upload static files and migrate. Make release preparation boot the app without background workers, while normal application start still runs Oban. Fix it.

## Named acceptance checks

1. **release-mode-no-oban** — with `CHANGELOG_RELEASE_TASK=1`, `Changelog.Supervisor` children do not include Oban; `Oban.whereis` is not a pid; Repo/Endpoint/app_cache are up.
2. **normal-mode-has-oban** — without the flag (and with flag unset or `0`), Oban is supervised and running.
3. **hook-sets-flag-and-order** — `on.deploy` exports `CHANGELOG_RELEASE_TASK=1` and runs static upload then migrate.
4. **hook-fail-fast** — upload failure prevents migration; migration failure fails the hook.

## Incomplete + integrity control

- **Incomplete:** gate only telemetry attach (or only the Oban child) but still start Oban under the flag. Fail **release-mode-no-oban**.
- **Integrity:** unchanged tree fails **release-mode-no-oban**; reference passes 1–4. **normal-mode-has-oban** prevents “delete Oban entirely.”

## Preservation

- Normal boot still runs Oban with production queues.
- IEx shell still avoids default Oban telemetry logger (existing behavior).
- Release hook still requires `OP_SERVICE_ACCOUNT_TOKEN` and preserves fail-fast semantics.

## Runtime / offline holds

- PostgreSQL required for `ensure_all_started` in tests.
- `on.deploy` tests stub `fnox` and can run offline (no 1Password).
- Static upload targets storage in real deploys — **not** exercised by the named checks (good).
- Fresh-VM tests spawn `elixir -S mix run` — needs local Elixir/OTP matching the pin.

## Status

**discovered** — small, coherent OTP isolation with named startup matrix tests already in the PR. Shell half is deploy glue but is part of the visible contract.

## Next action

Execute `release_task_test.exs` at base/head; confirm `elixir` subprocess tests work in the Pi runner image.
