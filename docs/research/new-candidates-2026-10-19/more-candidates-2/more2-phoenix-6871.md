# Phoenix #6871 — `:max_channels_per_transport` on `Phoenix.Endpoint.socket/3`

**Status:** discovered
**Source type:** historical PR
**Project:** [phoenixframework/phoenix](https://github.com/phoenixframework/phoenix)
**PR:** [#6871](https://github.com/phoenixframework/phoenix/pull/6871) — *Allow setting :max_channels_per_transport in Phoenix.Endpoint.socket/3*
**Source revisions:** base = first parent of merge `3fc1fb16c2fb7b4c37ee6e6f85a8f8fbbda5905e` (pin at draft) · 1 commit, squash-merged 2026-10-09
**Author:** SteffenDE · **Merged:** 2026-10-09
**Task kind / family:** feature / endpoint socket configuration → transport → channel join limit
**Research date:** 2026-10-19
**Exposure:** public historical PR

## Authentic work

`:max_channels_per_transport` (how many channels one transport process may join) could only be set inside `use Phoenix.Socket`. For sockets you do not define yourself — most importantly `Phoenix.LiveView.Socket` — there was no way to override it at the endpoint.

The PR lets `socket/3` accept `:max_channels_per_transport`, copies it into the websocket/longpoll transport config, and lets that value override the one from `use Phoenix.Socket`. Invalid values (non-positive integer / non-integer) raise `ArgumentError` at compile time.

## Implementation scope

| File | Role |
| --- | --- |
| `lib/phoenix/endpoint.ex` | `put_socket_opts/2` (replaces `put_auth_token/2`): copies `:auth_token` and `:max_channels_per_transport` into websocket and longpoll transport config; validates positive integer |
| `lib/phoenix/socket.ex` | Doc: the option can also be set at `Endpoint.socket/3` and overrides the `use Phoenix.Socket` value |
| `test/phoenix/endpoint/endpoint_test.exs` | Compile-time `ArgumentError` for `nil` and `0` |
| `test/phoenix/integration/websocket_channels_test.exs` | Join limit honored from endpoint; endpoint value overrides `use Phoenix.Socket` value |
| `test/phoenix/integration/long_poll_channels_test.exs` | Same for longpoll |

**Counts:** 2 substantive implementation files, 3 test files. Tests exercise both transports (websocket + longpoll) at the integration boundary.

## Cross-component behavior to verify

- `socket "/path", MySocket, websocket: [...], max_channels_per_transport: 1` limits joins per transport process to 1; the second join returns `"too many channels joined"`.
- When both `use Phoenix.Socket` and `socket/3` set the option, the endpoint value wins.
- Longpoll transport honors the same option (not only websocket).
- Invalid values raise `ArgumentError` naming `:max_channels_per_transport` at compile time.
- Sockets without the option keep the existing default (100) and existing `:auth_token` handling.

## Draft ticket (clarified implementation brief)

> Let `Phoenix.Endpoint.socket/3` accept `:max_channels_per_transport` so the join limit can be set for sockets the application does not define (for example `Phoenix.LiveView.Socket`). The endpoint value must override whatever `use Phoenix.Socket` sets, apply to both websocket and longpoll transports, and reject non-positive or non-integer values with a clear compile-time error. Sockets that do not pass the option must keep today's behaviour.

Public names to freeze if graded: `:max_channels_per_transport` on `Phoenix.Endpoint.socket/3`; error message should name the option (exact wording need not be scored).

## Acceptance design (proposed, unexecuted)

- Websocket: endpoint with `max_channels_per_transport: 1`; join topic A OK; join topic B on the same transport returns error `"too many channels joined"`.
- Override: `LimitedUserSocket` with `use Phoenix.Socket, max_channels_per_transport: 1` mounted with endpoint `max_channels_per_transport: 2` — two joins succeed, third fails.
- Longpoll: same limit honored across polls on one session.
- Compile-time: `max_channels_per_transport: nil` and `: 0` raise `ArgumentError`.
- Preservation: sockets without the option still allow the default number of joins; `:auth_token` still works.

## Plausible incomplete (proposed)

Wire the option for websocket only and forget longpoll (or copy it into transport config but forget the override of `use Phoenix.Socket`). Compiles; the longpoll or override named test fails.

## Integrity control (proposed)

Acceptance must not pass if the option is accepted but ignored (joins unlimited), if it applies globally to all sockets on the endpoint rather than the mounted one, or if invalid values are silently coerced instead of raising.

## Runtime / offline

- Phoenix integration tests run with in-process websocket/longpoll clients (no external broker). Elixir requirement from `mix.exs` (`@elixir_requirement`).
- Node/browser not required for these ExUnit integration tests.

## License / provenance

- MIT (Phoenix). Public GitHub PR. No private edition.

## Holds / unknowns

- Skip-list Phoenix identities 6840 (local-path validation) and 6762 (LongPoll tokens) are different families; do not merge.
- LiveView's `Phoenix.LiveView.Socket` is the motivating consumer but the case stays inside Phoenix; do not require a LiveView change.
- The error string `"too many channels joined"` is already the existing channel-join overflow reason (visible in the current tests); reuse it rather than inventing a new one.

## Coverage added

Endpoint → transport configuration → channel-join enforcement across two coordinated implementation files and two transport integrations. Distinct from the already-filed URL-validation and LongPoll-token families.

## Next action

If drafting: pin Elixir/OTP from historical CI at merge, freeze the option name and override rule in the brief, and use "websocket-only wiring" as the incomplete control.

---

## Grilling (2026-10-19)

### 1. Minimum ticket

Good clarified brief. The product decisions are visible: endpoint value **overrides** `use Phoenix.Socket`, applies to **both** websocket and longpoll, invalid values raise at compile time, omitted option keeps today's behaviour. That is the whole contract.

Two nits:
- "a clear compile-time error" — do not pin `ArgumentError` or the message text in hidden checks unless the ticket says so. `ArgumentError` is the idiomatic choice and the upstream test uses `assert_raise ArgumentError, ~r/:max_channels_per_transport must be a positive integer/`. If those tests are solver-visible, fine. If they are hidden, grade "raises when `socket/3` is compiled" and nothing more.
- Do not require a LiveView change. Already stated. Good.

### 2. Named deterministic checks (ExUnit, no sleep)

Proposed, unexecuted. `_work/phoenix-6871.diff` contains real upstream tests — they are the right shape.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `ws limit-from-endpoint` | endpoint `max_channels_per_transport: 1`; one transport process joins topic A then topic B | channel replies | A ok; B → `"too many channels joined"` |
| `ws endpoint-overrides-use` | `LimitedUserSocket` with `use Phoenix.Socket, max_channels_per_transport: 1`, mounted with endpoint value `2` | joins | 2 succeed, 3rd → overflow error |
| `lp limit-from-endpoint` | same option on a longpoll mount; join 2 topics on one session | replies | 2nd join → overflow |
| `compile rejects nil` | `max_channels_per_transport: nil` | `socket/3` compile | raises |
| `compile rejects zero` | `max_channels_per_transport: 0` | `socket/3` compile | raises |
| `preserve default-joins` | socket with no option | joins | still allows the default (100) |
| `preserve auth-token` | existing `:auth_token` path | transport config | unchanged |

All in-process Phoenix integration clients. No external broker. Deterministic.

### 3. Ambiguity / unfairness

- Error **text** `"too many channels joined"` is the pre-existing channel-join overflow reason and is already visible in current tests — fair to reuse. Do not invent a new string and pin it.
- Per-mount vs global: the ticket says "for sockets the application does not define" and override semantics. Integrity must reject "applies to every socket on the endpoint."
- Non-integer values (atoms, floats): ticket says "non-positive or non-integer". Covered.
- Does the option belong on `socket/3` opts or inside `websocket: [...]`? Ticket says `socket/3`. Clear.

### 4. Shortcuts + compiling incomplete

- Incomplete A = websocket wiring only, forget longpoll. Compiles. Fails `lp limit-from-endpoint`.
- Incomplete B = copy into transport config but forget the `use Phoenix.Socket` override. Compiles. Fails `ws endpoint-overrides-use`.
- Shortcut: accept the option and ignore it (joins unlimited). Caught by `ws limit-from-endpoint`.
- Shortcut: apply the limit to every socket on the endpoint. Caught by `preserve default-joins` on a sibling mount.
- Shortcut: silently coerce `nil`/`0`. Caught by the compile-reject checks.

### 5. Flakiness

Low–medium. Phoenix channel integration tests use ports and unique topics (the diff uses `System.unique_integer` — good). Keep tests `async` only where the port setup allows. No timers, no external services.

### 6. Preservation mix

Good: default joins, `:auth_token`, sockets without the option. Add one sibling socket on the same endpoint with **no** limit to prove the option is per-mount, not global.

### 7. Environment risk

Good. Phoenix test suite is self-contained (in-process websocket/longpoll clients). No DB, no Node. MIT. Only 2 impl files — at the low end of the 2–5 band, but the cross-component story is real (endpoint macro → transport config → join enforcement on two transports) and it is a valid focused feature. Not a one-line fix with tests bolted on.

**Evidence gap:** unexecuted. Diffs exist.

### 8. Verdict

**READY-WITH-FIX** — clean, well-scoped feature with visible override rule and both transports covered; needs executed checks and a decision on how hard to pin the raise type.

### 9. Must-fix list

1. Execute the three integration checks + two compile-reject checks; record outcomes.
2. Grade "raises at compile time" only (or state `ArgumentError` in the ticket). Do not pin the message string in hidden checks.
3. Incomplete = websocket-only; name `lp limit-from-endpoint`.
4. Add a per-mount negative: a sibling socket without the option still allows the default.
5. Confirm the integration tests run offline (they should — in-process clients).

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Unexecuted + raise-type/message over-pinning |
