# Real Elixir application shortlist — 2026-10-19

Discovery-only. Goal: **whole open-source applications** (products people use), not libraries, not tutorials, not junk. These are **new sources** to shortlist for future case research — not admitted cases.

Screening rules used:
- Public GitHub, real product purpose (not a demo/tutorial dump).
- Open license (MIT / Apache / AGPL / BSD). Skipped crypto-shape and torrent-indexing projects.
- Prefer **active** repos (pushed in 2025–2026) and Phoenix/LiveView/Ecto/Oban stacks the runner can prepare.
- Skip names already researched as apps (Plausible, Livebook, Operately, LiveBeats, Accent, Mobilizon, Linkhut, Algora TV, ExVenture).

GitHub API is rate-limited without a token; activity/license stars below are from 2026-10-19 snapshots. Treat stars as popularity only, not admission evidence.

---

## Tier A — shortlist for case discovery (active products)

| App | Repo | ★ | License | Last push | What it is | Stack (from mix.exs) | Why it belongs on the list | Main risks / unknowns |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| **TeslaMate** | [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate) | 9142 | AGPL-3.0 | 2026-10-19 | Self-hosted Tesla vehicle data logger (drives, charging, maps, stats) | Not confirmed at root `mix.exs` (app may live in subdir); historically Phoenix + PostgreSQL + Grafana sidecar | Large real product, strong data/visualization workflows, very active | AGPL (record in provenance); multi-service (Postgres + optional Grafana); Tesla API is external — fixtures must be offline/synthetic |
| **Pinchflat** | [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat) | 5409 | AGPL-3.0 | 2025-12-16 | YouTube media manager (download, dedupe, organize) | Elixir `~> 1.17`; Phoenix, LiveView, Ecto+**SQLite**, Oban, Floki | Clear media-library workflows; SQLite keeps prep lighter than PG-only apps | YouTube/network in real use — needs offline fixtures; AGPL; ~1 year since last push |
| **Changelog.com** | [thechangelog/changelog.com](https://github.com/thechangelog/changelog.com) | 2772 | custom/NOASSERTION | 2026-09-22 | Podcast publishing platform (site, feeds, admin) | Elixir `~> 1.18`; Phoenix, LiveView, Ecto+SQL, Oban, Waffle (uploads), scrivener | Real content product with auth, media, feeds, admin | License is **non-standard** — must read carefully; media/uploads; large codebase |
| **Beacon CMS** | [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon) | 1262 | MIT | 2026-09-28 | CMS built on Phoenix LiveView | Elixir `~> 1.14–1.15`; Phoenix, Ecto, LiveView-adjacent, Floki, Req | CMS workflows (pages, layouts, content) fit LiveView/Ecto coverage | Version floor older; is it a library *for* apps or a shippable app? (product-shaped either way) |
| **Craftplan** | [puemos/craftplan](https://github.com/puemos/craftplan) | 1153 | AGPL-3.0 | 2026-10-08 | Self-hosted artisanal D2C micro-business management | Elixir `~> 1.20`; **Ash** + Ash PG + Ash auth + Absinthe + Phoenix LiveView | Domain-rich (catalog, orders, auth) and modern stack; good Ash coverage | Ash is heavy; AGPL; fairly new — confirm test/fixture maturity |
| **Logflare** | [Logflare/logflare](https://github.com/Logflare/logflare) | 1006 | Apache-2.0 | 2026-10-19 | Centralized structured logging / log search | Elixir `~> 1.4` (old floor — modern deps still present); Phoenix, LiveView, Ecto, Oban, Tesla, Playwright tests | Ops/product app, active today; interesting ingest/query workflows | Very old `elixir:` requirement string vs modern deps — pin carefully; BigQuery backend in real product (offline fixture work); Playwright in tree |
| **ServiceRadar** | [carverauto/serviceradar](https://github.com/carverauto/serviceradar) | 920 | Apache-2.0 | 2026-10-19 | Open-source network management / monitoring / ITOM | Root `mix.exs` not found (monorepo?) | Network/monitoring domain not yet in inventory | Confirm Elixir app path vs other languages; service topology may be heavy |
| **Mydia** | [getmydia/mydia](https://github.com/getmydia/mydia) | 798 | AGPL-3.0 | 2026-10-18 | Personal media companion | Elixir `~> 1.20`; Phoenix, LiveView, Ecto+**SQLite**, Oban, Guardian, Absinthe | Active, LiveView + GraphQL + auth; media domain | AGPL; external media sources need offline stand-ins |
| **vutuv** | [wintermeyer/vutuv](https://github.com/wintermeyer/vutuv) | 355 | MIT | 2026-10-19 | Social network (profiles, connections) | Elixir `~> 1.20`; Phoenix, LiveView, Ecto, Req | MIT, active **today**, classic social workflows | Smaller star count; confirm product surface depth |
| **NervesHub** | [nerves-hub/nerves_hub_web](https://github.com/nerves-hub/nerves_hub_web) | 273 | Apache-2.0 | 2026-10-18 | IoT / Nerves device fleet management | Elixir `~> 1.20`; Phoenix, LiveView, Ecto, Oban, ClickHouse (`ecto_ch`) | Distinct domain (devices, firmware, health); ClickHouse already known to the runner | Multi-service (PG + ClickHouse); IoT auth/tenancy complexity |
| **TymeSlot** | [Tymeslot/tymeslot](https://github.com/Tymeslot/tymeslot) | 233 | (check LICENSE) | (recent per search) | Open-source meeting scheduling | Elixir `~> 1.20`; Phoenix, LiveView, Oban, Ecto | Scheduling/booking family missing from inventory | Smaller project; verify license + activity + tests |

### Suggested discovery order (for *case PR mining*, not admission)

1. **TeslaMate** or **Pinchflat** — big real products, media/data workflows.
2. **Changelog.com** or **Beacon CMS** — content/publishing; Phoenix/Ecto depth.
3. **Mydia** or **vutuv** — modern LiveView apps; smaller and faster to prepare.
4. **Craftplan** — only if Ash coverage is wanted (pairs with already-filed Ash #3031).
5. **NervesHub** — later; service topology is heavier.

---

## Tier B — real apps, weaker for *this* pass (stale / archived / thin)

| App | Repo | ★ | Status | Note |
| --- | --- | ---: | --- | --- |
| Papercups | [papercups-io/papercups](https://github.com/papercups-io/papercups) | 6116 | last push 2024-02 | Chat product, MIT — but stale; prefer live repos for historical PR mining |
| Midarr | [midarrlabs/midarr-server](https://github.com/midarrlabs/midarr-server) | 1405 | 2026-03 | Media server; check how much is Elixir vs client |
| Uneebee | [zoonk/uneebee](https://github.com/zoonk/uneebee) | 1342 | **archived** | Courses platform, AGPL — skip or treat as historical only |
| Firestorm | [firestormforum/firestorm](https://github.com/firestormforum/firestorm) | 969 | 2023-09 | Forum + Elm frontend — frontend coupling |
| Avia | [aviacommerce/avia](https://github.com/aviacommerce/avia) | 537 | 2023-08 | E-commerce framework (more framework than product) |
| Cog | [operable/cog](https://github.com/operable/cog) | 920 | 2021 | Chatops — dead |
| Rauversion | [rauversion/rauversion-phx](https://github.com/rauversion/rauversion-phx) | 362 | 2024-01 | Music industry; AGPL; stale |
| Shlinked | [cbh123/shlinked](https://github.com/cbh123/shlinked) | 387 | satirical social | Fun but small/odd product; AGPL |

---

## Deliberately not shortlisted

| Candidate | Why not |
| --- | --- |
| `sergiotapia/magnetissimo` | Torrent-site indexer — legal/ethics risk for a public benchmark corpus |
| `anoma/anoma` | Crypto/blockchain “reference implementation” — outside product scope; risk of hype/scam-adjacent surface |
| `openai/symphony` | Agent/infra product from OpenAI; not a classic end-user Elixir app for this corpus |
| `dwyl/phoenix-chat-example`, `schneidmaster/socializer`, `wojtekmach/acme_bank` | Tutorials / example umbrellas, not production products |
| `securityelixir/potion_shop` | Intentionally vulnerable teaching app |
| Libraries (Tesla, Mint, Cachex, Timex, …) | Already covered in library/framework research; user asked for whole applications |

---

## Already covered (do not re-shortlist as new apps)

From earlier research: Plausible, Livebook, Operately, LiveBeats, Accent, Mobilizon, Linkhut, Algora TV, ExVenture.

Libraries/frameworks already deeply researched (Ecto, Phoenix, Plug, Oban, Absinthe, Broadway, Bandit, Finch, Mint, Req, Credo, ExDoc, Cachex, Swoosh, Guardian, Ash, …) stay in their own reports.

---

## What “shortlist” means here

These are **sources worth mining for 2–5 file PR cases**, following `docs/pr-selection-guidelines.md`. Next step per app (when you pick one):

1. Read LICENSE + historical Mix/CI at a candidate PR’s base.
2. Enumerate merged PRs with real product outcomes (not chores).
3. Screen for offline fixtures (no live Tesla/YouTube/BigQuery).
4. Then deep-dive specific PRs like the PubSub/Redix set.

**No PRs were inspected in this pass** — this file is the app-level shortlist only.

## Verification limits

- GitHub unauthenticated API rate limits hit some `mix.exs` fetches (TeslaMate, ServiceRadar).
- Stars/push dates are a snapshot, not a health guarantee.
- “Not a scam” = real org/repo/product shape + open license + no crypto/torrent red flags — not a security audit.
