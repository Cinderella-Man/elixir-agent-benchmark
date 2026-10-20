# App candidate — nerves_hub_web PR #3153 (deleted device leaves deployment group and disconnects)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (bug repair with documented root cause in PR body)
**Project:** [nerves-hub/nerves_hub_web](https://github.com/nerves-hub/nerves_hub_web)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/nerves-hub/nerves_hub_web/pull/3153 |
| Title | Take a deleted device out of its deployment group and disconnect it |
| Author | **joshk** (maintainer) |
| Branch | `fix/soft-delete-clears-deployment-and-disconnects` |
| Created | 2026-10-15T22:07:02Z |
| Merged / closed | 2026-10-16T17:39:27Z |
| Merge commit SHA | `e9257511e0b1ed47e55e112cedfc083b9c2156e0` |
| **Base SHA (parent of merge)** | `5fba45e06958e9dc66174eca70157ea469154866` |
| Diff | https://github.com/nerves-hub/nerves_hub_web/pull/3153.diff |
| Commits | 2 |
| Tooling note | No AI co-author trailer observed on the inspected PR body. PR body contains a maintainer root-cause write-up; keep that out of the solver ticket. |

License at base: **Apache-2.0**. Mix at base: Elixir `~> 1.20.0`, Phoenix 1.8, Ecto + `ecto_ch` (ClickHouse), Oban, Thousand Island device endpoint.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> When I delete a device that is currently connected, it stays in its deployment group and keeps getting firmware-update work; the orchestrator loops on it and the connection stays up. Deleting a device should take it out of its deployment group and close its open connection so it is not selected for updates and cannot stay online. A device restored later can be matched to a deployment group again when it next connects. Fix it.

**Clarifiers (only if a hidden check would otherwise be unfair):**

- Delete is the existing soft-delete; certificates and keys are already handled elsewhere.
- Refusal to reconnect while deleted is pre-existing (cert / device-key / product-key paths); do not require new auth logic.
- Confirm-dialog copy is cosmetic unless the brief asks for it.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/nerves_hub/devices.ex` | `delete_device/1`: clear `deployment_id` in the soft-delete changeset **inside the existing Multi**; emit delete event after commit; return device with `deployment_group: nil`. |
| `lib/nerves_hub/events/device_events.ex` | New `deleted/1` → shared `disconnect/1` broadcasting `device_socket:<id>` `"disconnect"` (same path `moved_product/1` already used). |
| `lib/nerves_hub_web/components/device_page/settings_tab.ex` | Delete confirm copy now states disconnect + deployment-group removal (presentation only). |

**Cross-component behavior:** persisted soft-delete transaction (group membership) ↔ live socket disconnect (PubSub) ↔ orchestrator query (`Updates.available_for_update/3` must no longer see the device) ↔ restore path (group rematch on next connect). Leaving the device in the group keeps it on the update query and burns orchestrator slots; disconnecting without clearing the group leaves the selection bug.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/nerves_hub/devices_test.exs`, `test/nerves_hub_web/channels/websocket_test.exs` |
| Docs (1, mechanical) | `docs/device_authentication.md` |

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| C1 | After `delete_device/1`, `deleted_at` set **and** `deployment_id` cleared in DB (`Repo.reload`). |
| C2 | Device is no longer in `Updates.available_for_update(deployment_group, …)`. |
| C3 | A `"disconnect"` broadcast is received on `device_socket:<id>`. |
| C4 | Live websocket: connected device goes offline after delete; same key still within max-age is refused afterwards. |
| C5 | Confirmation/UI copy mentions disconnect and deployment removal (optional; low weight). |
| C6 | Preservation: ordinary delete without connection, destroy path, cert/key rejection of deleted devices, and restore rematch behavior remain. |

Upstream `devices_test.exs` covers C1–C3; `websocket_test.exs` covers C4. C6 should reuse existing suites rather than invent new auth requirements.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** clear `deployment_id` in `delete_device/1` but **do not** call `DeviceEvents.deleted/1`. Orphans the live socket (C3/C4 fail); orchestrator selection is fixed (C2 may pass). Coherent partial matching “durable state without the live process” lesson.

**Second incomplete:** broadcast disconnect but leave `deployment_id` set — C1/C2 fail while the UI looks correct.

**Integrity:** standard `System.halt(0)` early-exit; require executed named results and that websocket tests actually ran.

---

## 6. Preservation

- Soft-delete still removes certificates, pinned-device rows and network identities in the same Multi.
- `moved_product/1` behavior (disconnect on product move) unchanged after the shared helper extract.
- Pre-existing auth refusals for deleted devices remain the mechanism; no new registration policy.
- Restore device: no forced deployment group at delete time; rematch on next connect (as documented).
- Mixed population: connected vs idle devices; with vs without deployment group.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required (`NervesHub.Repo`, sandbox). |
| **ClickHouse** | `ecto_ch` + `NervesHub.AnalyticsRepo` URL from `CLICKHOUSE_URL` (default `http://localhost:8123/default_test`). Runner already has ClickHouse service handling — confirm this historical version’s migrations/startup. |
| Real device endpoint | `config/test.exs` starts `NervesHubWeb.DeviceEndpoint` on HTTPS with client-cert verification (`fail_if_no_peer_cert`). Websocket test uses Mint against `127.0.0.1:4101`. Port collisions across worktrees are documented upstream. |
| Oban | Present in deps; confirm whether selected tests need workers inline/stopped. |
| Git dependency | `opentelemetry_oban` from a GitHub branch — **offline cache must include this git dep**. |
| Native | `bcrypt_elixir` (log_rounds reduced in test). |
| S3 / Slack / Teams | Test config uses local file uploads and Req.Test for webhooks; keep external integrations off. |

**Not verified:** that ClickHouse and the HTTPS device endpoint boot offline in the current runner image, that the websocket test is deterministic under load, or that the git dependency is still fetchable. NervesHub is the heaviest of this batch; treat as “if feasible.”

---

## 8. Status / next action

**Status:** screened — strongest NervesHub candidate (3 implementation files, authentic orchestrator/socket bug, clear incomplete controls). Runtime (PG + ClickHouse + TLS device socket + git dep) is the main gate.

**Next action:** resolve multi-service fixture first (ClickHouse + device endpoint). If that holds, pin base `5fba45e0…` and qualify. If the device socket cannot be made offline-stable, defer rather than mock the disconnect boundary.
