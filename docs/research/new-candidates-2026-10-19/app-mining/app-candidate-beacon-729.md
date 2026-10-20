# app-candidate-beacon-729

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/BeaconCMS/beacon/pull/729 |
| Title | fix: crash recovery |
| Project | BeaconCMS/beacon |
| Source type | Historical merged PR (boot/race bug fix) |
| PR head SHA | `49cd8f5043b617e7f38cca90b625287ae767034e` (last of 3 commits) |
| First commit | `fdb7c12c978b380b91eb910f5f32ab4fd5901e4d` |
| Parent of first commit (likely base) | `6e69859a7f9d20263055f78f020c5cc1daf8ab12` |
| Merged at | 2025-01-17T17:07:02Z |
| License | MIT (DockYard, Inc.) |
| Elixir | `~> 1.14` |
| Verification | **Unverified** — diff inspected; tests not executed |

## Why it is a case

Beacon must start before the host Endpoint so requests are blocked until the host app is ready. Otherwise boot races produce blank pages and boot errors. The fix also moves endpoint config reads to runtime (`Beacon.Private.endpoint_config/2`, `endpoint_host/2`) so compile-time endpoint config is not required at boot.

What must stay consistent:

- Supervision order: Beacon (or its readiness) before Endpoint accepts traffic.
- Host endpoint config is read at runtime, not compile time (crash recovery / distillery-style releases).
- Generated site tasks (`beacon.gen.site`) and router host matching still work after the ordering change.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/beacon/beacon.ex` | Start/order related boot behavior |
| `lib/beacon/private.ex` | Runtime endpoint config/host helpers (`otp_app!`, `endpoint_config/2`, `endpoint_host/2`) |
| `lib/beacon/router.ex` | Host matching uses runtime endpoint host |
| `lib/mix/tasks/beacon.gen.site.ex` | Generated site matches new boot expectations (supporting) |

Tests (separate): `test/mix/tasks/gen_site_test.exs` adjustments; guides upgrades.

## Draft ticket

> During deploy and boot, Beacon can answer requests before the host app is ready, which causes blank pages and startup crashes. Make Beacon come up so requests wait until the host endpoint is ready, and stop depending on compile-time endpoint configuration at boot. Fix it.

## Named acceptance checks

1. **runtime-endpoint-config** — endpoint host/config is resolved at runtime from the otp_app (no crash when compile-time endpoint config is absent).
2. **beacon-before-endpoint-readiness** — requests cannot be served by Beacon until host Endpoint is up (ordering/ownership evidence via supervision or a blocking first request).
3. **router-host-match** — `beacon_site` host matching still works against the runtime endpoint host.
4. **preservation** — gen.site generated apps still boot; existing routes continue to resolve.

## Incomplete + integrity control

- **Incomplete:** add `Beacon.Private` helpers but leave router still reading compile-time endpoint config, or reorder only in docs. Fail **runtime-endpoint-config** or **beacon-before-endpoint-readiness**.
- **Integrity:** unchanged tree fails the race/config checks; reference passes. **preservation** keeps gen.site green.

## Preservation

- Sites already booted with compile-time config still work when that config is present.
- No change to page rendering itself.

## Runtime / offline holds

- Needs a host Endpoint in tests (Beacon test support already has endpoints).
- True multi-node deploy race is hard to reproduce; checks should use supervision/`Application.ensure_all_started` ordering rather than real Fly.io.
- Offline feasible with local test endpoint.

## Status

**discovered** — authentic crash-recovery bug with OTP/runtime-config work across 4 implementation files. Named upstream tests are mostly gen.site; curator checks must assert ordering.

## Next action

Design a deterministic **beacon-before-endpoint-readiness** check (process readiness or first-request block) and run it unchanged vs. reference.
