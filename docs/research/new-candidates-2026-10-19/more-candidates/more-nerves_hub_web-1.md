# More candidate — nerves_hub_web PRs #3154+#3156 (penalty box retries + atomic penalty/audit)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR **lineage** (combined under LINEAGE-MERGE-POLICY: #3156 is explicitly stacked on #3154 and is the obvious coherence fix)
**Project:** [nerves-hub/nerves_hub_web](https://github.com/nerves-hub/nerves_hub_web)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR A URL | https://github.com/nerves-hub/nerves_hub_web/pull/3154 |
| PR A title | Give devices fresh update attempts after an orchestrator penalty |
| PR B URL | https://github.com/nerves-hub/nerves_hub_web/pull/3156 |
| PR B title | Record a device's penalty and its audit in one transaction |
| Author | **joshk** (collaborator) |
| PR B relation | Body: “This is stacked on #3154” |
| PR A merge (squash) | `bb447dc6e38de61773f0fdb1e5f8ef99a4886c67` (1 parent) |
| **PR A base (parent of squash A)** | `d35a64034295c83200d26c0f5494dc4db442e37e` |
| PR B merge (squash) | `8d77c7cb0cfdbea5708d38e9400aa11e4d681460` (1 parent) |
| **PR B parent = PR A squash** | `bb447dc6…` — lineage stacking **verified** on commit HTML |
| Combined reference | tree at `8d77c7cb…` (= A then B) |
| Incomplete control | tree at `bb447dc6…` (= A only) |
| Diffs | https://github.com/nerves-hub/nerves_hub_web/pull/3154.diff , `.../pull/3156.diff` |

Note: PR B HTML also lists intermediate commit SHAs from the PR branch; the **merged squash** `8d77c7cb` is the freeze point.

License: **Apache-2.0**. Mix: Elixir `~> 1.20.0`, Phoenix, Ecto, Oban. Runtime gates from app-mining still apply (PG + ClickHouse + TLS device endpoint) — see holds.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> After the deployment orchestrator puts a device in the penalty box, the device stays blocked forever unless someone clears it by hand. When a penalty ends, the device should get a full set of update attempts again and become eligible for updates. Also make the penalty write coherent: the “automatically blocked firmware upgrades” audit and any cleared inflight update must be recorded together with the penalty, so we never log a block that did not stick. A device that is refused an update must still not receive one. Fix it.

Do **not** name `enforce_failure_limits`, `put_device_in_penalty_box`, `update_blocked_until`, `DeviceEvents`, `Ecto.Multi`, or file paths.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/nerves_hub/devices/updates.ex` | **Core.** Unify the two penalty entry points (`verify_update_eligibility/3` and orchestrator `schedule_devices!`) so both clear `update_attempts` and share one enforcement helper. PR B: write penalty + audit + clear-inflight as one transaction (`Ecto.Multi` + `Repo.transact`); log/broadcast only after the penalty is recorded; still refuse the device if the penalty row is rejected. |
| `lib/nerves_hub/managed_deployments/orchestrator/coordinator.ex` | Orchestrator scheduling now calls the shared enforcement instead of `update_blocked_until/2` (which left attempts intact and re-blocked devices forever). |

**Cross-component behavior:** eligibility check ↔ orchestrator scheduling must agree on what “penalized” means (attempts cleared, `updates_blocked_until` set). PR A alone leaves a hole: penalty/audit/inflight were separate writes, so a refused penalty still produced an “automatically blocked” audit. Combined outcome is one enforcement path and one atomic penalty record.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (A) | `test/nerves_hub/devices/updates_test.exs`, `test/nerves_hub/managed_deployments/default_coordinator_test.exs`, `test/nerves_hub/managed_deployments/orchestrator_test.exs`, `test/nerves_hub/managed_deployments/required_release_test.exs` |
| Test (B) | `test/nerves_hub/devices/updates_test.exs` (extends) |

**Implementation count:** **2** files (updates + coordinator). Small file count, deep investigation (two disagreeing penalty paths, attempt accounting, transactional audit). Acceptable as a focused multi-component task.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| N1 | Device that exceeds failure threshold/rate is penalized: `updates_blocked_until` set and `update_attempts` **cleared**. |
| N2 | After the penalty window elapses, the device is eligible again with a **full** set of attempts (not still over threshold). |
| N3 | Orchestrator scheduling and eligibility enforcement use the same penalty rule (no path that blocks without clearing attempts). |
| N4 | Repeated penalty windows do not forever re-block solely because old attempts were never cleared (the original bug). |
| N5 | Penalty + “automatically blocked firmware upgrades” audit + cleared inflight update are written together: if the penalty cannot be recorded, the audit must **not** claim the device was blocked. |
| N6 | A device that is refused remains refused (no update sent) even when the penalty write fails. |
| N7 | Preservation: a device under threshold still receives updates; existing audit template/broadcast shape for a successful penalty remains. |

Upstream A tests cover N1–N4; B tests cover N5–N6. N7 needs a positive preservation witness.

---

## 5. Incomplete / integrity controls

**Natural incomplete (the combined lineage intermediate):** tree at `bb447dc6…` (PR #3154 only). Attempts are cleared and eligibility works, but penalty/audit/inflight are still separate writes — N5 fails (audit can claim a block that did not stick).

**Second incomplete (compiling on A):** keep `put_device_in_penalty_box` clearing attempts, but leave orchestrator on `update_blocked_until/2` — N3/N4 fail.

**Third incomplete:** Multi writes penalty+audit together but still logs “automatically blocked” before the transaction commits — N5’s “audit must not claim a block that did not stick” half fails.

**Integrity:** standard `System.halt(0)` early-exit; require executed named results on `updates_test` + coordinator tests.

---

## 6. Preservation

- Devices that never hit failure limits still update on the orchestrator pass and via eligibility.
- Existing audit template fields and DeviceEvents update broadcast remain (B only adds `DeviceEvents.updated/1` after success).
- Firmware-less devices (no `current_device_firmware`) must not crash logging (A fixes `get_in` nil access — keep as a soft requirement only if visible in the starting source).
- Mixed population: under-limit, over-rate, over-threshold, penalty-active, penalty-just-expired.

---

## 7. Runtime / offline holds

Same class as nerves_hub #3153:

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required. |
| ClickHouse | `ecto_ch` paths may pull in; confirm focused tests can run with PG-only or bring ClickHouse service. |
| TLS device socket | **Not required** for these checks (no DeviceEndpoint). |
| Oban | App supervision may start Oban — offline-safe if deps cached. |
| Git dep | `opentelemetry_oban` branch dep must be cached offline. |

**Not verified:** compilation, green base suite, offline dep cache. Prefer focusing `devices/updates_test` + `default_coordinator_test` rather than full suite.

---

## 8. Status / next action

**Status:** screened — best **combined-lineage** candidate this pass. #3156 is an obvious product improvement (atomic penalty/audit) stacked on #3154; one case, ticket states the final behavior; intermediate #3154 tree is the natural incomplete control. Two implementation files but real ownership/transaction investigation.

**Next action:** pin base `d35a6403…` for the full combined reference at `8d77c7cb…`; prove PG fixture without device TLS first; author N5 as the discriminating check between A-only and A+B. Apache-2.0 in provenance; attribute **both** PRs.

---

## Grilling (2026-10-19)

### Minimum ticket
The brief mixes two outcomes (fresh attempts after penalty + atomic penalty/audit) and then says "Fix it." That is honest for a combined lineage but the second clause is dense. Tighten to two sentences: "When the orchestrator penalty expires, the device must become eligible again with a full set of update attempts. Also make the penalty write atomic with its audit and any cleared inflight update so we never log a block that did not stick. A refused device must still not receive an update." Do not name `Ecto.Multi`, `update_attempts`, or helpers.

### Named deterministic checks
N1–N7 are proposed and unexecuted. N5 is the only check that separates A-only from A+B — it **must** be a named protected test, not a bullet. Required named set:
1. penalty sets `updates_blocked_until` and clears attempts (N1)
2. after window, full attempts (N2)
3. orchestrator and eligibility use one penalty rule (N3)
4. repeated penalties do not self-reblock (N4)
5. penalty+audit+inflight atomic — if penalty fails, no "automatically blocked" audit (N5)
6. refused device gets no update even when penalty write fails (N6)
7. under-threshold device still updates (N7 positive)

Without (5) the intermediate passes. That is the combined-lineage discriminator.

### Ambiguity / unfairness
- "Full set of update attempts" is clear enough if the starting source shows how attempts are counted. If the threshold is configurable, the brief should say "a full set (as if newly seen)" not "exactly N".
- N5's "audit must not claim a block that did not stick" is the right phrasing; do not grade log line text.
- "A device that is refused must still not receive one" is essential and easy to get wrong (log-then-send). Keep it visible — it is.
- Firmware-less device nil-logging fix: dossier says "soft requirement only if visible in the starting source". Correct. Do not score a crash fix that is not in the visible contract.

### Shortcuts + compiling incomplete
Natural incomplete = #3154-only tree (fails N5). Second incomplete = clear attempts but orchestrator still uses `update_blocked_until/2` (fails N3/N4). Third = log before commit (fails N5's second half). Under-weighted shortcut: make eligibility and orchestrator share a helper but still do separate writes in the orchestrator path — N3 must assert **behavioral** agreement (no path blocks without clearing), not just "calls the same function".

### Flakiness
Untested. Penalty-window timing (N2) is the flake candidate if checks `Process.sleep` through a window. Mandate clock injection or a window of 0 / past timestamp in fixtures. Oban/ClicHouse side paths could introduce async noise; keep checks synchronous and focused on `devices/updates_test` + coordinator tests.

### Preservation
N7 is thin. Need mixed population: under-limit, over-rate, over-threshold, penalty-active, penalty-just-expired — one named test each or one test with a fixture set. Audit template/broadcast shape must be preserved on success (dossier notes it). Add it as a named check.

### Env
**Heavy and unproven.** PostgreSQL required; ClickHouse may be pulled in; Elixir `~> 1.20.0`; git dep `opentelemetry_oban` must be cached; no compile, no green base suite, no offline dep proof. TLS device endpoint is correctly excluded. This is not a "maybe" — it is a full project-runtime onboarding that has not started. Elixir 1.20 availability is the same wall as Mydia.

### Combined-lineage requirements
**REQUIRED.** Dossier depends on #3154+#3156. Rules:
1. Case ID visible as the lineage; do not score two near-duplicate penalty cases.
2. `provenance.json` lists both PRs; combined reference = tree at `8d77c7cb…`; incomplete = `bb447dc6…`.
3. Ticket states the **final** behavior (fresh attempts + atomic penalty/audit) — already in the draft brief; keep both clauses.
4. N5 is the named discriminator between intermediate and combined.
5. Pin base `d35a6403…` for reconstruction.

### Verdict
**HOLD** — lineage design is sound; zero execution; runtime (PG + possible ClickHouse + Elixir 1.20 + git deps) is a multi-day onboarding before a single check can be named as proven.

### Must-fix before qualification
1. Prove runtime: Elixir ~> 1.20, PG fixture without device TLS, focused tests compile and run at base and base+patch. Record offline dep cache including `opentelemetry_oban`.
2. Name N5 (atomicity) as a protected check — this is the combined-lineage gate.
3. Replace penalty-window sleeps with deterministic clock/past-timestamp fixtures.
4. Strengthen N3 to behavioral agreement, not shared-function existence.
5. Add named mixed-population and audit-shape preservation checks.
6. Apache-2.0 notice; both PRs in provenance.
