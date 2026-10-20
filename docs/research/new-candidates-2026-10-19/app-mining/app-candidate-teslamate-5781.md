# TeslaMate #5781 — Safe token refresh and honest sign-in errors

**Status:** discovered  
**Source type:** historical PR  
**Project:** [teslamate-org/teslamate](https://github.com/teslamate-org/teslamate)  
**PR:** [#5781](https://github.com/teslamate-org/teslamate/pull/5781)  
**Source revisions:** base `5a18471788265824d06ce96349ec202021009b01` → merge `6eadba7878d2cad5c96e66fb86576c5b8767d95b`  
**Author:** JakobLichterfeld · **Merged:** 2026-09-24  
**Task kind / family:** bug_fix / auth token refresh + LiveView sign-in  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Why it is a good case

Coherent security/correctness work across the Tesla auth client and the sign-in LiveView:

1. Token refresh must not send refresh/fleet tokens to another host when the token endpoint answers with a redirect.
2. Rejected tokens (`invalid_grant` / `login_required`) must be distinguished from other refresh failures so the UI can say “tokens are invalid”.
3. Sign-in must not crash on async exit, must ignore a second submit while one is in flight, and must surface the actual cause.

That is a real user/caller problem (paste tokens → wrong/missing error, or tokens leave the machine). The ticket must **not** name “stop following redirects” or the OAuth error-code list.

## Implementation file roles

| File | Role |
| --- | --- |
| `elixir/lib/tesla_api/auth/refresh.ex` | Refresh POST handling: classify `@invalid_token_errors`, treat redirect as typed error (`redirect_error/1`), parse 200 JSON token payload, keep prior refresh token when response omits one (RFC 6749). |
| `elixir/lib/tesla_api/middleware/follow_redirects.ex` | **Deleted** — middleware that followed redirects for the Tesla client. |
| `elixir/lib/tesla_api/auth.ex` | Auth pipeline wiring (drop redirect middleware; related error surface). |
| `elixir/lib/teslamate_web/live/signin_live/index.ex` | `start_async` sign-in; clause per outcome (`:ok`, `:already_signed_in`, `:invalid_tokens`, other `%TeslaApi.Error{}`, `{:exit, _}`); ignore double-submit while `signing_in`. |
| `elixir/lib/teslamate_web/live/signin_live/index.html.heex` | Error copy / form state. |

Tests (separate count): `test/tesla_api/auth/refresh_test.exs`, `test/tesla_api/middleware/follow_redirects_test.exs` (removed/adjusted), `test/teslamate_web/live/sign_in_test.exs`, `test/support/mocks/api.ex`. Many gettext `.po` files are mechanical i18n — do not count as implementation.

**Counts:** 4–5 substantive implementation files (auth/refresh, deleted middleware, auth wiring, signin LiveView module + template), tests separate.

## Cross-component behavior to verify

- Refresh against a redirecting “token endpoint” must not follow to another host; user sees a refresh failure, tokens are not posted onward.
- A rejected-token OAuth body must reach the sign-in page as the invalid-tokens message, not a generic crash or opaque failure.
- Concurrent/double submit does not start two refreshes (second click ignored while in flight).
- Successful refresh still signs in; `:already_signed_in` still redirects to car live.

## Draft ticket (shortest sufficient)

> When I sign in with saved Tesla tokens, a bad or hostile refresh response can leave me with a useless error or, worse, cause my tokens to be sent somewhere they should not go. Rejected tokens and other refresh failures need to be reported accurately on the sign-in page, and a single sign-in attempt must stay well-behaved if I click twice or the process dies. Keep normal successful sign-in working. Fix it.

## Proposed named acceptance checks

1. `refresh does-not-follow-redirects` — Tesla mock/env returns 3xx to another host; assert request goes only to the configured token URL and result is a typed refresh failure (no follow).
2. `refresh classifies-rejected-tokens` — OAuth error body with `invalid_grant` / `login_required` yields `:invalid_tokens` (or equivalent surfaced to LiveView).
3. `sign-in reports-invalid-tokens` — LiveView shows the invalid-tokens message and returns to a usable form.
4. `sign-in ignores-second-submit-while-in-flight` — second `"sign_in"` event does not start another call.
5. `sign-in handles-async-exit` — exit reason is logged/handled, form recovers (no LiveView crash).
6. **Preservation:** successful token refresh + sign-in still redirects; ordinary transport errors still show a token-refresh failure message.

## Plausible incomplete + integrity control

- **Incomplete:** classify invalid tokens in Refresh but leave the LiveView generic (check 3 fails); or guard double-submit but still follow redirects (check 1 fails).
- **Integrity:** reject patches that swallow all refresh errors as success, or that hardcode “invalid” for every failure (preservation check 6).

## Preservation

Existing auth refresh success-path tests and sign-in success tests must pass. Do not require network access to auth.tesla.com — tests already use mocks (`test/support/mocks/api.ex`).

## Runtime / offline holds

- **No live Tesla OAuth** — keep mocked HTTP/Tesla client only. Flag any test that needs the real token endpoint as hold.
- LiveView tests need the standard Phoenix test stack (local).
- Broad gettext churn is mechanical; hide from the solver or ignore in file counts.

## Status: discovered

Best multi-file TeslaMate candidate in this pass (auth + LiveView + deleted middleware).

## Next action

Draft as the first TeslaMate case. Confirm mocked refresh fixtures cover redirect vs invalid_grant vs transport error. Pair with #5782 (token redaction) only in reporting as an auth-hardening family.
