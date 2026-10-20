# TeslaMate #5782 — Keep tokens out of logs and redact userinfo in errors

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#5782](https://github.com/teslamate-org/teslamate/pull/5782)  
**Source revisions:** base `6eadba7878d2cad5c96e66fb86576c5b8767d95b` → merge `4d233612d6390e055a91e90d3d6ab8825e4eac98`  
**Author:** JakobLichterfeld · **Merged:** 2026-09-25  
**Task kind / family:** bug_fix / secret redaction in API errors & logs  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Why it is a good case

After #5781, sign-in and refresh can surface error messages. Those messages (and debug logs) must never contain tokens or URL userinfo. The PR spans the Tesla API error struct, auth error paths, and logging — with a deliberate **fail-closed** rule when redaction is impossible. That is authentic security work with observable outcomes (what appears in log/error strings) and a preservation obligation (errors remain useful enough to diagnose).

## Implementation file roles

| File | Role |
| --- | --- |
| `elixir/lib/tesla_api.ex` | Client entry: ensure logged/raised surfaces do not dump raw token-bearing structs/URLs. |
| `elixir/lib/tesla_api/auth.ex` | Auth-specific logging of refresh/sign-in failures with redaction. |
| `elixir/lib/tesla_api/error.ex` | Error formatting: strip/redact userinfo from URLs; fail closed if redaction cannot be applied. |

Tests: `test/tesla_api/auth/refresh_test.exs`, `test/tesla_api/error_test.exs`, `test/tesla_api_test.exs` (+ CHANGELOG).

**Counts:** 3 substantive implementation files, 3 test files.

## Cross-component behavior to verify

- Debug-level logging of auth still omits tokens.
- Error messages that embed a URL do not include userinfo (`https://user:pass@host/...` → redacted).
- If redaction fails, behavior is fail-closed (do not emit the raw secret-bearing string) — exact policy must be in the visible brief if scored.
- Normal error text (status, OAuth code/message without secrets) remains present (positive preservation).

## Draft ticket (shortest sufficient)

> Sign-in and token-refresh failures can put token material or URL credentials into logs and error messages, including at debug level. Those secrets must never be written out. Keep the remaining error text useful enough to diagnose the failure, and if a message cannot be safely cleaned, do not leak it. Fix it.

## Proposed named acceptance checks

1. `error redacts-url-userinfo` — error/inspect path for a URL with userinfo contains host/path but not password.
2. `auth debug-log omits-tokens` — capture debug log around refresh; assert access/refresh tokens absent.
3. `error fail-closed-on-unredactable` — input that cannot be redacted does not emit the raw secret string.
4. **Preservation:** ordinary OAuth `error`/`error_description` without secrets still appear; HTTP status still recorded.

## Plausible incomplete + integrity control

- **Incomplete:** redact only `TeslaApi.Auth` logs but leave `TeslaApi.Error` URL formatting raw (check 1 fails).
- **Integrity:** reject patches that replace all errors with a constant string (check 4), or that only redact at info level while debug still dumps the struct.

## Preservation

Existing auth/API tests that assert useful error payloads (sans secrets) must pass.

## Runtime / offline holds

- No Tesla network. All unit/mocked.
- Log capture in ExUnit must be deterministic (`ExUnit.CaptureLog`); no timing.

## Status: discovered

Focused reserve (3 files) — strong security flavor, smaller than #5781.

## Next action

Draft only if a secret-hygiene family is wanted after #5781. Confirm the fail-closed rule is stated in the ticket so hidden checks are fair.
