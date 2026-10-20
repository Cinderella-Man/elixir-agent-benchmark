# More2 candidate — nerves_hub_web PR #3117 (organization webhooks for device events) — large feature

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (large coherent feature; integrations surface)
**Project:** [nerves-hub/nerves_hub_web](https://github.com/nerves-hub/nerves_hub_web)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/nerves-hub/nerves_hub_web/pull/3117 |
| Title | Add webhooks for device events |
| Author | **joshk** (collaborator); body credits Claude Code tooling (exposure metadata) |
| Merged | 2026-10-15 (squash) |
| Merge commit SHA | `f199fa59dec1ac35c4a909f0b4440fb2c9561f1c` |
| **Base SHA (parent of squash)** | `198660eea4a0a5759d38d31142cdc9e2695ac921` |
| Squash parents | **1 parent** — squash verified via API commit object |
| Diff | https://github.com/nerves-hub/nerves_hub_web/pull/3117.diff |
| Commits in PR | 3 (branch commits; freeze the squash) |
| Scale | **52 files, +5286 / −9** |

**Lineage note (do not merge):** #3119 *Connect Slack workspaces*, #3120 *Post device notifications to Slack*, #3122/#3123 Slack commands are **stacked on this squash** (verified: #3119 parent = `f199fa59…`). Per [LINEAGE-MERGE-POLICY](../large-features/LINEAGE-MERGE-POLICY.md) “PR A is fine; PR B is an unrelated later feature” — Slack is a **new channel**, not a hole in the webhook contract. Keep #3117 alone. If a Slack large-feature is filed later, freeze it at the end of that stack and reference #3117 as already in-tree at its base.

License: **Apache-2.0**. Mix: Elixir `~> 1.20.0`, Phoenix, Ecto, Oban. Runtime gates from app-mining still apply (PG + possible ClickHouse + offline dep cache).

---

## 2. Ticket (shortest sufficient, clarified implementation brief)

> Organizations need to hear about device connects, health changes, and firmware updates in their own systems without polling our API. Add organization webhooks: a webhook targets an HTTP endpoint, carries the listed device events, and can be limited to chosen products (default: every product in the organization, including new ones). Deliveries must be signed so receivers can verify them, retried without flooding error trackers, and skipped briefly after failures so one dead endpoint cannot fill the shared queue. Turn off a webhook that fails too long or answers gone. Webhooks must not be usable to reach private network addresses unless an operator explicitly allows it, and managing them must require the organization manage role. Expose setup in the org UI and the API. Do not change device update behavior itself.

Do **not** name `Webhooks.Cache`, `Delivery.Adapter`, `Standard Webhooks`, `WEBHOOKS_ALLOW_PRIVATE_DESTINATIONS`, `product_webhooks`, or file paths. Signature scheme and SSRF policy can be stated as outcomes (“verifiable signatures”, “refuse private destinations”) without naming the library or config key.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/nerves_hub/webhooks.ex`, `webhooks/webhook.ex`, `webhooks/events.ex`, `webhooks/payloads.ex` | Domain: webhook resource, event catalog, payload shapes. |
| `lib/nerves_hub/webhooks/cache.ex` | Per-product ETS cache of subscribed webhooks; org-level invalidation across nodes. |
| `lib/nerves_hub/webhooks/delivery.ex`, `delivery/adapter.ex`, `destination.ex`, `signature.ex` | Delivery: destination checks (SSRF), one-shot Mint connection pinned to the checked address, Standard Webhooks signature, no redirects. |
| `lib/nerves_hub/workers/deliver_webhook.ex` | Oban job on `webhooks` queue; snooze retries; 30s failure skip; 24h / 410 auto-disable. |
| `lib/nerves_hub/devices/{connections,health,health_evaluation,metrics,update_history,updates}.ex`, `extensions/{health,metrics}.ex`, `firmware_updates.ex`, `events/device_events.ex` | Emit device events at the real state transitions (connect/disconnect, health, metrics, firmware scheduled/progress/finished/validated). |
| `lib/nerves_hub_web/live/org/integrations.ex` + `.heex` | Org Integrations page (create/edit/regenerate/disable). |
| `lib/nerves_hub_web/controllers/api/webhook_*.ex`, `api_spec.ex`, `helpers/authorization.ex`, `router.ex`, `components/navigation.ex` | REST API + permissions (`webhook:create/update/delete`) + nav. |
| `lib/nerves_hub/audit_logs/**`, `product_notifications.ex` | Audit entries (host only, not URL/secret) and product notify on disable. |
| `config/*`, `docs/webhooks.md`, `docs/runtime_configuration.md` | Feature flag `WEBHOOKS_ALLOW_PRIVATE_DESTINATIONS`, receiver docs. |
| `priv/repo/migrations/20261013094217_*`, `20261013214512_*` | Create webhooks tables (second migration renames `product_webhooks` rather than copying). |

**Cross-component behavior:** event emission ↔ product/org subscription cache ↔ signed delivery ↔ SSRF destination policy ↔ permissions. A webhook that is created but never receives `device.firmware_update.finished` from `UpdateHistory.record/3` fails the core story; a cache that is not invalidated on org webhook change delivers stale subscriptions.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (11) | `webhooks_test`, `webhooks/{delivery/adapter,destination,raised_events,signature}_test`, `workers/deliver_webhook_test`, `web_live/org/integrations_test`, `api/webhook_controller_test` |
| Migrations (2) | create + rename (mechanical DDL; rename preserves ids) |
| Docs (2) | `docs/webhooks.md`, `docs/runtime_configuration.md` |
| Config (5) | `config/{config,dev,runtime,test}.exs` + spell/AGENTS noise |

**Implementation count:** **~25** code paths (domain + delivery + emitters + UI + API). This is the **large feature** candidate of the pass. Migrations/docs/config are mechanical relative to the product outcome.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| W1 | Org can create a webhook for a public HTTP endpoint; API and UI both work. |
| W2 | Device connect/disconnect (including stale sweep disconnect) produces a delivered event. |
| W3 | Health report and health status change (with reasons / previous status) produce events. |
| W4 | Firmware update scheduled / progress (throttled) / finished / validated produce events from the real update history path. |
| W5 | Product filter: only listed products’ events are sent; default is all products including ones added later; other org’s product name is refused. |
| W6 | Signature header verifies against the documented scheme / reference vector. |
| W7 | Delivery retries without emitting `{:error,_}` to Sentry-style trackers (snoozes); crash in our code still raises. |
| W8 | After a failure, deliveries for that webhook skip briefly; long failure or 410 disables the webhook; disable notifies previously covered products. |
| W9 | SSRF: literal private address refused on save; hostname resolved at delivery and refused if any address is private; request goes to the **checked** address; redirects are not followed (3xx = failure). |
| W10 | Permissions: manage role required to create/update/delete and (API) read; view-only cannot see URL/secret; audit logs name host only. |
| W11 | Preservation: devices without webhooks still update; non-webhook device behavior unchanged; at most 20 webhooks per org. |

Upstream tests cover W1–W11 in unit/controller form. Prefer focused `webhooks_test` + `raised_events_test` + `deliver_webhook_test` + `signature_test` + `destination_test` over the full suite.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** domain + API create webhooks and enqueue deliveries, but `UpdateHistory` never raises `.finished` — W4 fails (the outcome every outcome already passes through).

**Second incomplete:** deliveries work but signature is a custom HMAC not matching the documented scheme — W6 fails.

**Third incomplete:** SSRF check on save only, delivery uses DNS-fresh address / follows redirects — W9 fails.

**Fourth incomplete:** cache never invalidated on webhook change — W5 stale-delivery fails after edit.

**Integrity:** standard `System.halt(0)` early-exit; require executed webhook + signature + destination tests.

---

## 6. Preservation

- Device updates, penalty box (already-filed #3153/#3154/#3156), and firmware flows unchanged.
- Org without webhooks: no extra delivery load (one ETS miss per product).
- Existing audit log shape for non-webhook actions.
- Mixed population: subscribed/unsubscribed products, healthy/failing endpoint, view-only vs manage member.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required. |
| ClickHouse | Confirm focused webhook tests can run PG-only. |
| Oban | App supervision may start Oban — offline-safe if deps cached. |
| Git dep | `opentelemetry_oban` branch dep must be cached offline. |
| External HTTP | Destination tests must use local/loopback or stubs; **never** require real internet. |
| TLS device socket | Not required for these checks. |

**Not verified:** compilation, green base suite, offline dep cache. Prefer focusing webhook tests rather than full suite. Exposure: body credits Claude Code (record, not exclude).

---

## 8. Status / next action

**Status:** screened — **large feature** for this pass (one coherent integrations capability: signed device-event webhooks). Complements (does not duplicate) already-filed device/penalty cases. Slack stack stays out of this ticket.

**Next action:** pin base `198660ee…` → apply `pull/3117.diff` → map W1–W11 → incomplete = missing `UpdateHistory` emit / wrong signature / SSRF hole. Apache-2.0; attribute **only** #3117 in provenance. Pair after a PG(+Oban) fixture is proven on a smaller nerves_hub case (#3153 family).

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Organizations need to hear about device connects, health changes, and firmware updates in their own systems without polling our API. Add organization webhooks: a webhook targets an HTTP endpoint, carries those device events, and can be limited to chosen products (default: every product in the organization, including new ones). Deliveries must be signed with the Standard Webhooks scheme so receivers can verify them, retried without flooding error trackers, and skipped briefly after failures so one dead endpoint cannot fill the shared queue. Turn off a webhook that fails for a day or answers 410. Webhooks must not reach private network addresses unless an operator explicitly allows it, and managing them must require the organization manage role. Expose setup in the org UI and the API. Do not change device update behavior itself.

Clarified brief, long but one capability. Product decisions that **must** be in the ticket because the repo cannot settle them: Standard Webhooks (named — it is the external contract, not the fix), product-filter default including future products, private-address refusal with operator override, manage-role requirement, disable thresholds.

**Hidden requirements flagged (many):**
- Draft said "signed so receivers can verify them" — that admits any HMAC. Reference is **Standard Webhooks** (`webhook-id` / `webhook-timestamp` / `webhook-signature`, `v1,` + base64 HMAC-SHA256 of `"<id>.<timestamp>.<body>"`, `whsec_` secrets). `signature_test` has reference vectors. Without naming Standard Webhooks the ticket is unfair; with it, the ticket is honest. Do the latter.
- Numeric policies absent from the draft: retry window ~2.5h via snooze, 30s skip after failure, 24h continuous failure → disable, 410 → disable, at most 20 webhooks per org. State the ones you score ("disable after a day of failures", "skip briefly") or do not grade the exact numbers.
- SSRF detail: "connect to the **checked** address" and "do not follow redirects (3xx = failure)" are specific. State them or accept simpler "refuse private addresses at save time".
- Event catalogue breadth (connect/disconnect incl. stale sweep, health + status change, metrics, firmware scheduled/progress/finished/validated) is large. Ticket says "connects, health changes, and firmware updates" — either keep scored checks inside that triad or list the events.

### 2. Deterministic checks

Focused ExUnit: `webhooks_test`, `raised_events_test`, `deliver_webhook_test`, `signature_test`, `destination_test`. Prefer these over the full suite. Local/loopback HTTP only (or a stub adapter).

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `webhooks create-api-and-ui` | Org manage member | API + LiveView | webhook created with endpoint + product filter |
| `events raised-on-real-transitions` | Device connect / health status change / firmware update history record | event emission (the `raised_events` surface) | events fired from the real state-transition call sites, not only from a test hook |
| `delivery product-filter` | Webhook limited to product A; events on A and B | deliveries | only A's events queued; new product C joins when filter is "all products" |
| `signature standard-webhooks-vector` | Known secret, id, timestamp, body | `Signature.sign/4` (or header on a delivered request) | matches the Standard Webhooks vector / `verify/5` round-trip |
| `delivery snooze-not-raise` | Adapter returns `{:error, _}` | Oban job result | snoozed/retried; no `{:error, _}` emitted to error tracker; crash in our code still raises |
| `delivery failure-skip-and-disable` | Endpoint fails across the threshold; separate case: 410 | webhook row + product notification | deliveries skipped briefly after a failure; disabled after long failure / 410; previously covered products notified |
| `destination ssrf-refusal` | Literal private URL on save; hostname resolving to private at delivery; 3xx redirect | destination check + adapter | refused on save; refused at delivery; request goes to checked address; redirect not followed |
| `permissions manage-role` | manage vs view-only member | API/UI/audit | manage required to CUD; view-only cannot see URL/secret; audit logs host only |
| `preservation no-webhook-devices` | Device with no webhooks | update flow | unchanged (W11) |

Fake provider: yes for delivery — a local stub HTTP server or the reference's adapter test double. **Never** real internet. Signature checks are pure.

### 3. Ambiguity / unfairness

- Signature scheme (above) is the biggest unfairness if left unnamed.
- Event payload field names follow "Standard Webhooks convention" and the docs patch — a solver inventing a different payload schema would pass "carries the listed device events" loosely but fail hidden payload tests. Either grade only "event name + device id + timestamps present" or put the payload shape in visible docs the solver can read (the reference ships `docs/webhooks.md` **in the patch** — the solver's workspace at base does **not** have it). Hidden-payload tests are unfair unless the ticket defines the shape. Prefer grading event **names** + signature + delivery policy, not every payload key.
- "skipped briefly" / "fails too long" without numbers is a policy contest. State or loosen.
- Config key `WEBHOOKS_ALLOW_PRIVATE_DESTINATIONS` is implementation; ticket says "operator explicitly allows" — good.

### 4. Shortcuts

- Domain + API create webhooks and enqueue deliveries, but `UpdateHistory` never raises `.finished`. Fails firmware-event check — the planned incomplete.
- Custom HMAC not matching Standard Webhooks. Fails signature vector.
- SSRF check on save only; delivery uses DNS-fresh address or follows redirects. Fails destination checks.
- ETS cache never invalidated on webhook change. Fails product-filter after edit (stale deliveries).
- Fire events only from a test helper, not the real device/health/update paths. Fails `events raised-on-real-transitions`.
- Disable/permissions missing but deliveries work. Fails W8/W10.

### 5. Flakiness / nondeterminism

Medium–high. Oban retries/snooze: use Oban test mode with explicit job execution; assert snooze args, not wall-clock. ETS cache invalidation "across nodes" is multi-node in the reference — grade single-node invalidation only. Destination DNS tests must use deterministic hosts (no real DNS). Timestamp in signature is caller-supplied — inject it. Do not assert Sentry.

### 6. Coverage mix

- Positive: create; events raised; signed delivery; product filter; disable-on-410.
- Negative: private address refused; view-only denied; 3xx not followed.
- Preservation: devices without webhooks update as before; at most 20 webhooks/org; audit shape for non-webhook actions.
- Mixed: subscribed vs unsubscribed products; healthy vs failing endpoint; manage vs view-only — one fixture set.

### 7. Environment risk

- **Apache-2.0** — cleanest license of the batch.
- PostgreSQL required. **ClickHouse** — confirm focused webhook tests are PG-only before investing.
- Oban in app supervision. **Git dep `opentelemetry_oban`** must be cached offline.
- Elixir `~> 1.20.0` pinned narrowly.
- Local HTTP for destination tests — loopback only.
- **Exposure:** PR body credits Claude Code tooling (record, not exclude).
- **Not verified:** compilation, green base suite, offline dep cache. 52 files / +5286 is far above the 2–5 preference; guidelines allow large coherent features **when tractable** — this one is not yet tractable in the current pipeline.

### 8. Verdict

**HOLD** — coherent integrations capability and a strong named-test suite upstream, but scale (52 files), Standard-Webhooks/payload contract gaps, numeric retry policies, and an unproven PG(+Oban+git-dep) fixture make it unready next to smaller candidates.

### 9. Must-fix list

1. Name Standard Webhooks in the ticket (external contract) or accept any verifiable HMAC in checks — pick one.
2. Put scored numeric policies in the ticket (disable after a day / 410; brief skip) or grade them loosely.
3. Grade event names + delivery policy, not the full payload schema, unless `docs/webhooks.md` content is solver-visible.
4. Prove PG-only focused webhook tests, Oban test mode, and offline `opentelemetry_oban` cache on a smaller nerves_hub case (#3153 family) first.
5. Incomplete = missing `UpdateHistory` emit (compiling); also keep wrong-signature and SSRF-save-only as integrity controls.
6. Record Claude Code exposure; attribute only #3117 (Slack stack stays out).

| Verdict | Top risk |
| --- | --- |
| **HOLD** | Scale + unnamed Standard Webhooks/payload contract + unproven runtime |
