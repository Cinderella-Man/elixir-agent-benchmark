# New candidate cases — 2026-10-19

Discovery-only research notes. One file per candidate. **No case bundles, imports, builds, tests, model runs or commits** were performed. Status values are research dispositions, not admissions.

Selection basis: [PR selection guidelines](../../pr-selection-guidelines.md), [case admission](../../case-admission.md), and the exclusion register already recorded in `docs/research/*` and `cases_rejected/`. Existing screened PRs (Ecto/Plug/Phoenix/Oban/Livebook/Plausible/Operately/LiveBeats/Accent/Guardian/Finch/ExDoc/Cachex/Swoosh/…) were **not rediscovered**.

## Index

| File | Project | PR | Kind | Impl files | Why it is here | Status |
| --- | --- | --- | --- | --- | --- | --- |
| [phoenix-pubsub-209-default-dispatcher.md](phoenix-pubsub-209-default-dispatcher.md) | Phoenix.PubSub | [#209](https://github.com/phoenixframework/phoenix_pubsub/pull/209) | feature | 2 | Per-PubSub default dispatcher must stay consistent across every broadcast API | discovered — draft next |
| [phoenix-pubsub-218-message-senders.md](phoenix-pubsub-218-message-senders.md) | Phoenix.PubSub | [#218](https://github.com/phoenixframework/phoenix_pubsub/pull/218) (+ #219, #220) | feature | 3 | New sender behaviour spans public API, behaviour module and supervisor wiring | discovered — draft next |
| [thousand-island-228-peername-cache.md](thousand-island-228-peername-cache.md) | Thousand Island | [#228](https://github.com/mtrudel/thousand_island/pull/228) | bug_fix | 2 | Socket metadata must survive client disconnect between handler start and later reads | discovered — draft next |
| [thousand-island-220-socket-ownership.md](thousand-island-220-socket-ownership.md) | Thousand Island | [#220](https://github.com/mtrudel/thousand_island/pull/220) | bug_fix | 3 | Accept path, transport contract and handler lifecycle must agree on ownership-transfer failure | discovered — draft next |
| [thousand-island-222-telemetry-exception.md](thousand-island-222-telemetry-exception.md) | Thousand Island | [#222](https://github.com/mtrudel/thousand_island/pull/222) | bug_fix | 2 | Handler exceptions must emit the documented telemetry exception span and re-raise unchanged | discovered — focused reserve |
| [redix-351-least-busy-routing.md](redix-351-least-busy-routing.md) | Redix | [#351](https://github.com/whatyouhide/redix/pull/351) | feature | 3 | Cluster pool routing and manager lookup must stay consistent under mixed slot maps | discovered — draft next |
| [redix-356-sentinel-socket-leak.md](redix-356-sentinel-socket-leak.md) | Redix | [#356](https://github.com/whatyouhide/redix/pull/356) | bug_fix | 1 | Sentinel path must close sockets on role/ROLE failure before trying the next sentinel | discovered — focused reserve |
| [nimble-parsec-154-choice-fallback.md](nimble-parsec-154-choice-fallback.md) | NimbleParsec | [#154](https://github.com/dashbitco/nimble_parsec/pull/154) | bug_fix | 1 | Traversal errors must honor choice fallback like other unbound combinators | discovered — focused reserve |
| [ash-3031-calculation-arguments.md](ash-3031-calculation-arguments.md) | Ash | [#3031](https://github.com/ash-project/ash/pull/3031) | bug_fix | 5 | Calculation argument validation must run once and keep literal/expression distinctions | discovered — larger coherent task |
| [phoenix-html-474-json-escape.md](phoenix-html-474-json-escape.md) | Phoenix.HTML | [#474](https://github.com/phoenixframework/phoenix_html/pull/474) (+ #475) | feature | 1 | Public JSON-in-HTML escaping helper with a follow-up arity/API correction | discovered — focused reserve |
| [phoenix-live-dashboard-487-app-process-tree.md](phoenix-live-dashboard-487-app-process-tree.md) | Phoenix.LiveDashboard | [#487](https://github.com/phoenixframework/phoenix_live_dashboard/pull/487) | feature | 1 (+ CSS) | Application process inspection UI: nested tree, expand/collapse, search | discovered — browser/UI reserve |

## Coverage this pass adds

| Family | Candidates |
| --- | --- |
| OTP / PubSub messaging | Phoenix.PubSub #209, #218 |
| Socket / connection lifecycle | Thousand Island #228, #220, #222 |
| Redis cluster / connection management | Redix #351, #356 |
| Parser compiler | NimbleParsec #154 |
| Query / calculation framework | Ash #3031 |
| HTML safety / form-adjacent API | Phoenix.HTML #474 |
| Observability UI | LiveDashboard #487 |

None of these projects appears in the 2026-10-15/18 research shortlists as a prepared or held candidate identity. Bodyguard #79 and Surface #775 were scanned and left out (too thin / single-file compile hook without a clear multi-file contract).

## What is still missing before any of these can enter `cases/`

Same gate as always, and **none of it was done in this pass**:

1. Exact first-parent source reconstruction and patch application check.
2. Independent contract review (requirements-first, then assertions).
3. Plausible incomplete + integrity controls.
4. Three fresh qualification rounds with matching named outcomes.
5. Two reviewed blind strong-model successes under frozen inputs.

## Search coverage / limits

- GitHub REST search + `pulls/{n}/files` + PR metadata + raw `mix.exs`/license fetches.
- Rate limits hit some repos (403/422); those projects are **not** claimed fully screened.
- No issue discussions beyond PR bodies were opened for every row; holds say so when body is empty.
- Application-side scan this pass: Supabase Realtime looked busy but its PRs mix infra/ops with product work; left out until a clean 2–5 file product task is isolated. `thechangelog`, `beacon-cms`, `glimesh` repo names did not resolve in this pass.

## Suggested next drafting order

1. **Thousand Island #228** or **#220** — small, offline, ordinary ExUnit, clear observable failure.
2. **Phoenix.PubSub #209** — clean feature with preservation default, no services.
3. **Redix #356** then **#351** — grows from focused repair to coordinated cluster task.
4. **NimbleParsec #154** — different reasoning (compiler/routing), tiny surface.
5. **Ash #3031** — only if a larger coordinated framework task is wanted.

## Later pass — more library candidates

Additional library candidates mined the same day live in [`more-candidates/more-candidates-README.md`](more-candidates/more-candidates-README.md) (ecto_sql #758 / #741, absinthe `@oneOf` lineage #1386+#1438+#1439, broadway #369, bandit #705). That index owns the rows; this README does not duplicate them.
