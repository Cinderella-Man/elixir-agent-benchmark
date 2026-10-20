# Ueberauth #217 — sign and verify the OAuth state nonce cookie

**Status:** discovered
**Source type:** historical PR
**Project:** [ueberauth/ueberauth](https://github.com/ueberauth/ueberauth)
**PR:** [#217](https://github.com/ueberauth/ueberauth/pull/217) — *Sign and verify the state nonce cookie*
**Source revisions:** base = first parent of merge `b02dc2d8b72754665f4b90b87d9362e49a18f6b2` (pin at draft) · 1 commit, squash-merged 2026-10-11
**Author:** mvanhorn · **Merged:** 2026-10-11
**Task kind / family:** feature (security hardening) / OAuth CSRF state cookie lifecycle
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

Ueberauth's OAuth CSRF protection stores the state nonce in a cookie and compares it to the `state` query param on callback. The cookie was **unsigned**, so a tampered or forged cookie could pass or fail the check depending on attacker control of both sides.

The PR signs the state cookie (`put_resp_cookie(..., sign: true)`) and reads it with `fetch_cookies(signed: [...])`, so unsigned or tampered cookies are rejected before the provider callback runs. Protected strategies now require a stable host-provided `conn.secret_key_base` across both phases (and across instances). Plug is bumped to `~> 1.10` for signed-cookie support. After upgrade, in-flight flows with unsigned cookies must be restarted (documented in CHANGELOG).

## Implementation scope

| File | Role |
| --- | --- |
| `lib/ueberauth/strategy.ex` | `put_resp_cookie(..., sign: true)`; `get_state_cookie/1` uses `fetch_cookies(signed: [@state_param_cookie_name])`; docs on `secret_key_base` requirement |
| `mix.exs` | Plug `~> 1.10`; version bump |
| `CHANGELOG.md` | Upgrade note (unsigned cookies rejected; restart in-flight flows) |
| `test/ueberauth_test.exs` | Signed cookie value ≠ raw state; tampered/wrong-secret/missing cookies → `csrf_attack`; valid signed cookie accepted whether or not cookies were pre-fetched; missing/invalid secret raises |

**Counts:** 1 substantive implementation file (`strategy.ex`), 1 dependency floor (`mix.exs`, mechanical), 1 changelog, 1 test file.

## Cross-component behavior to verify

- Request phase: response cookie is signed (raw value ≠ state); `same_site` still honored.
- Callback phase: valid signed cookie + matching `state` param → auth proceeds; cookie cleared (`max_age == 0`).
- Tampered cookie, wrong secret, missing cookie, or `state` param ≠ cookie → `ueberauth_failure` with `csrf_attack` **before** the provider is invoked.
- Works whether or not `fetch_cookies` was already called on the conn.
- Protected strategies with `secret_key_base` of `nil` or non-binary raise (Plug configuration error / FunctionClauseError).
- Strategies with state-cookie disabled are unchanged (no cookie set).

## Draft ticket (clarified implementation brief)

> The OAuth state nonce cookie is unsigned, so it can be tampered with or forged. Sign the state cookie and verify it on callback, rejecting unsigned or tampered cookies as a CSRF failure before the provider runs. Protected strategies must require a stable, strong `conn.secret_key_base` on both phases. Keep same-site behaviour and the no-state-cookie mode unchanged. Bump the Plug requirement if signed cookies need it.

Public names to freeze if graded: cookie name `ueberauth.state_param` (existing), failure error key `csrf_attack` (existing).

## Acceptance design (proposed, unexecuted)

- Request: `resp_cookies["ueberauth.state_param"].value != private[:ueberauth_state_param]` (signed).
- Happy path: signed cookie + matching state → `ueberauth_auth` set; cookie expired.
- Rejections (each named): `cookie <> "tampered"`, `"SFMyNTY.invalid.signature"`, cookie signed with a different secret, `state` param different from cookie, missing cookie, `state` param nil — all yield `csrf_attack` and no auth.
- Secret required: `secret_key_base` nil / `:invalid` raises.
- Preservation: custom `same_site` still applied; disabled state-cookie strategy sets no cookie.

## Plausible incomplete (proposed)

Sign the cookie on the request phase but still read it with `fetch_session`/unsigned `fetch_cookies` on callback (or the reverse). Compiles; the tampered-cookie rejection named test fails.

## Integrity control (proposed)

Acceptance must not pass if the cookie is merely present but unverified, if rejection happens after the provider callback is invoked, if a missing `secret_key_base` silently skips signing, or if the disabled-state-cookie mode starts setting a cookie.

## Runtime / offline

- Elixir `~> 1.14` (from `mix.exs`). Pure Plug/ExUnit with test strategies; no network, no real OAuth provider.
- Node/browser not required.

## License / provenance

- MIT (Ueberauth). Public GitHub PR. No private edition.

## Holds / unknowns

- Guardian #748 (select verifying secret from the connection) is in the skip list and is a different project/family; do not merge.
- Exact raise shape for a missing secret (Plug's vs `FunctionClauseError`) is Plug-version dependent; grade "raises / does not silently proceed", not a particular exception module, unless the visible tests pin it (upstream uses `assert_raise FunctionClauseError`).
- Upgrade note (restart in-flight flows) is documentation, not a scored obligation.

## Coverage added

New project (Ueberauth) in the corpus: OAuth CSRF state cookie security at the strategy boundary. Auth/security family not yet represented by filed Guardian/Ecto/Phoenix work.

## Next action

If drafting: pin Elixir/OTP from historical CI at merge, freeze the sign+verify contract and rejection list from the brief, and use "sign-only, no verify" as the incomplete control.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Good security brief: sign + verify the state cookie, reject unsigned/tampered **before** the provider runs, require `conn.secret_key_base` on both phases, keep `same_site` and the no-state-cookie mode, bump Plug if needed.

One word must go: **"strong"** in "require a stable, strong `conn.secret_key_base`". Strength is not graded and not defined. The reference only requires a binary secret that Plug can sign with. A solver who validates entropy is doing extra work; a solver who accepts any binary is correct. Say "a stable binary `conn.secret_key_base`" and stop.

Public names (`ueberauth.state_param`, `csrf_attack`) are correctly identified as existing — fine to freeze.

### 2. Named deterministic checks (ExUnit, no sleep)

Proposed; `_work/ueberauth-217.diff` contains the real upstream tests, including a solid rejection matrix. Pure Plug. No sleep.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `request cookie-is-signed` | `run_request` with a secret | `resp_cookies["ueberauth.state_param"].value` | ≠ raw `private[:ueberauth_state_param]`; `same_site` still applied |
| `callback happy-path` | signed cookie + matching `state` | assigns + cookie | `ueberauth_auth` set; cookie expired (`max_age == 0`) |
| `reject tampered-cookie` | cookie `<> "tampered"` | assigns | `ueberauth_failure` / `csrf_attack`; provider **not** invoked |
| `reject forged-signature` | `"SFMyNTY.invalid.signature"` | same | `csrf_attack` |
| `reject wrong-secret` | cookie signed under a different `secret_key_base` | same | `csrf_attack` |
| `reject state-mismatch` | `state` param ≠ cookie | same | `csrf_attack` |
| `reject missing-cookie` / `reject nil-state` | absent cookie / nil param | same | `csrf_attack` |
| `reject unsigned-but-matching` | raw `state` as the cookie value | same | `csrf_attack` (unsigned must not pass) |
| `secret-required` | `secret_key_base` = `nil` / `:invalid` | `run_request` | raises (any exception — see §3) |
| `works pre-fetched-or-not` | `fetch_cookies` already called, and not | both paths | same accept/reject outcome |
| `preserve same-site` | custom `state_param_cookie_same_site` | resp cookie | still honored |
| `preserve disabled-mode` | state-cookie disabled | resp cookies | no `ueberauth.state_param` set |

The upstream matrix's first tuple (`{state, state, @secret_key_base}`) is the unsigned-but-value-matching case — correct and important. Keep it.

### 3. Ambiguity / unfairness

- "strong" secret (above) — drop it.
- Missing-secret raise shape: upstream pins `assert_raise FunctionClauseError`. That is Plug-version-dependent. If upstream tests are solver-visible, pinning is fair. If they are hidden checks, grade "raises / does not silently proceed" and accept any exception module. Decide which and write it down.
- Cookie **signing** is specified. An encrypting scheme is a different contract — do not accept it silently, but also do not over-specify the signed-cookie wire format. Grade "unsigned or tampered values are rejected," not "the value starts with `SFMyNTY`."
- Upgrade note (restart in-flight flows) is documentation — correctly out of scope.

### 4. Shortcuts + compiling incomplete

- Incomplete A = sign on request, read unsigned on callback (or the reverse). Compiles. Fails `reject tampered-cookie` / `reject unsigned-but-matching`.
- Incomplete B = sign+verify but skip the secret check. Compiles. Fails `secret-required`.
- Shortcut: cookie is merely present and never verified. Caught by the rejection matrix.
- Shortcut: reject **after** invoking the provider. Integrity check: assert the provider mock/call count is zero on rejection.
- Shortcut: missing secret silently skips signing. Caught by `secret-required`.
- Shortcut: disabled mode starts setting a cookie. Caught by `preserve disabled-mode`.

### 5. Flakiness

**Low.** Pure Plug/ExUnit, test strategies, no network, no real OAuth provider, no timers.

### 6. Preservation mix

Good: `same_site`, disabled mode, pre-fetched cookies. Add an explicit provider-not-invoked assertion on the rejection path (the "before the provider runs" clause is currently only implicit).

### 7. Environment risk

Excellent. Elixir `~> 1.14`, Plug `~> 1.10`, offline. MIT. **1 substantive implementation file** — the focused-task allowance, not a multi-file case. The cross-phase contract (request signs ↔ callback verifies ↔ secret required) is still real work; do not promote it as a 2–5 file example.

**Evidence gap:** unexecuted. Diffs exist.

### 8. Verdict

**READY-WITH-FIX** — authentic security hardening with a discriminating rejection matrix and a clean offline env; needs the word "strong" removed, a decision on the raise-shape pin, and executed checks.

### 9. Must-fix list

1. Remove "strong" from the ticket. Require only a stable binary `secret_key_base`.
2. Decide: pin `FunctionClauseError` only if upstream tests are solver-visible; else grade "raises."
3. Execute the named matrix; record outcomes.
4. Incomplete = sign-only / no-verify; name `reject tampered-cookie` as the failure.
5. Add an explicit "provider not invoked on rejection" assertion.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | "strong" wording + exception-shape pin + unexecuted |
