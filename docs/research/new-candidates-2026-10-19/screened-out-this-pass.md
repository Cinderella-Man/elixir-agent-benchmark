# Screened out or left unfiled — 2026-10-19 pass

These were looked at during discovery and **not** turned into per-case notes. Recorded so they are not silently forgotten or rediscovered as “new”.

| Source | Why no case file |
| --- | --- |
| Phoenix.PubSub [#210](https://github.com/phoenixframework/phoenix_pubsub/pull/210) `:group_by` | Valid feature (2 impl files) but adjacent to #209 on the same meta path. Keep as sibling reserve; do not count as independent coverage from #209 without a separate outcome. |
| Phoenix.HTML [#468](https://github.com/phoenixframework/phoenix_html/pull/468) structs as select values | 1 implementation file, +2/-1 — too thin alone for a flagship; usable focused reserve later. |
| Phoenix.HTML [#475](https://github.com/phoenixframework/phoenix_html/pull/475) | One-line arity follow-up to #474; folded into that lineage. |
| Redix [#350](https://github.com/whatyouhide/redix/pull/350) pool churn | Large manager rewrite; possible precursor/lineage for #351. Do not score both as separate tasks without a combined user outcome. |
| NimbleOptions [#149](https://github.com/dashbitco/nimble_options/pull/149) nil MFA | +1/-1 implementation — too thin; note only. |
| LiveDashboard [#495](https://github.com/phoenixframework/phoenix_live_dashboard/pull/495) app tree crash | 1-line fix. Good bug but not a multi-file task. |
| Surface [#775](https://github.com/surface-ui/surface/pull/775) force recompile on JS hook change | Single-file compile hook; contract and reproducibility of “recompile” need more work. |
| Bodyguard [#79](https://github.com/schrockwell/bodyguard/pull/79) default error runtime | 1 lib file + changelog; previously lightly screened in auth research. |
| Ash [#3039](https://github.com/ash-project/ash/pull/3039) forbidden relationships | 1-line impl + policy test — too thin as a flagship (Ash #3031 filed instead). |
| Thousand Island [#216](https://github.com/mtrudel/thousand_island/pull/216) | Refactor of connection start retries (1 file, net deletion). Needs explicit structural brief; skipped for clearer bug/feature PRs. |
| Timex / Bamboo / Quantum / Castore recent PRs | Mostly locale, CI, cert rotation, or dependency bumps — reject as mechanical/non-tasks per guidelines. |
| Supabase Realtime (sampled #2202, #2379, #2397, …) | Real product bugs exist, but mixed with infra/ops and multi-service setup (Postgres, tenants, regions). Not isolated a clean 2–5 file offline product task this pass. |
| Firezone PRs sampled | Dominated by Rust `connlib` work, not Elixir application tasks. |
| `thechangelog`, `beacon-cms`, `glimesh` | Repo names did not resolve via the API this pass (404/422). Not claimed screened. |
| Rate-limited 403s (Benchee, Sobelow, StreamData, Honeydew, …) | **Not screened.** Do not treat as empty. |

## Already excluded elsewhere (do not rediscover)

See [new-case-candidates-2026-10-18.md](../new-case-candidates-2026-10-18.md#do-not-rediscover-or-relabel-the-old-decisions) and `cases_rejected/` for Plausible 6300/6763/6441, older Ecto/Oban/Livebook holds, etc. This pass did not re-open those identities.
