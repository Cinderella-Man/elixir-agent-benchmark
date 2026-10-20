# app-candidate-mydia-1105

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/getmydia/mydia/pull/1105 |
| Title | Require permission and respect account restrictions for library bulk actions |
| Project | getmydia/mydia |
| Source type | Historical merged PR (authorization bug fix) |
| PR head SHA | `d04d23062f604e05dbe44766dae2e5746f518a39` (last of 4 commits) |
| First commit | `89b41023343c5488dde0484de0e2f5a3ceeb73da` |
| Parent of first commit (likely base) | `961f9f05034b691bf5d7ba1121898572ad775ad8` |
| Merged at | 2026-10-10T21:56:35Z |
| License | **AGPL-3.0** |
| Elixir | `~> 1.20` |
| Verification | **Unverified** — PR body/diff inspected; tests not executed |

## Why it is a case

The library list (`MediaLive.Index`) is reachable by guest and read-only accounts, but write actions never checked role. Anyone with a session could send LiveView events (bulk monitor, batch edit, reclassify, rescan, batch delete including disk files). Accounts limited by category/age could also pass out-of-scope ids in a bulk selection.

What must stay consistent:

- LiveView event handlers (`batch_monitor`, `batch_delete_confirmed`, `batch_reclassify`, `trigger_rescan`, `batch_edit_submit`, per-row `toggle_item_monitored`) require the matching update/delete permission.
- Context writes (`Media.BulkWrites`, `Media.Deletion`) filter every id-scoped query through `Mydia.Media.Restrictions` / caller scope.
- Denied actions change nothing and show the usual permission flash; allowed actions still work for privileged users.
- Invalid `monitored` input returns `{:error, :invalid_monitored}` without touching the DB.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/mydia_web/live/media_live/index.ex` | `with_media_permission/3`, `authorize_media/2`, batch handlers |
| `lib/mydia_web/live/media_live/index/library_actions.ex` | **New** — toggle/rescan actions moved out (ratchet) |
| `lib/mydia_web/live/media_live/index/reclassify_flash.ex` | **New** — reclassify flash messages |
| `lib/mydia/media/bulk_writes.ex` | Scope-aware bulk update; invalid monitored guard |
| `lib/mydia/media/deletion.ex` | Scope-aware bulk delete |

Tests (separate): `bulk_writes_scope_test.exs`, `index_authorization_test.exs`, `reclassify_flash_test.exs`.

## Draft ticket

> Guests and read-only users can change library items by sending LiveView events directly, and restricted accounts can bulk-edit ids outside their allowed categories. Enforce update/delete permissions on every library write action and keep bulk operations inside the caller's account restrictions. Denied or out-of-scope actions must change nothing. Fix it.

## Named acceptance checks

1. **guest-bulk-denied** — guest session: `batch_monitor` / `batch_delete_confirmed` / `batch_edit_submit` / `batch_reclassify` / `trigger_rescan` / `toggle_item_monitored` change nothing (permission flash).
2. **readonly-denied** — same for read-only role.
3. **privileged-allowed** — admin/update role can still batch monitor, edit, reclassify, rescan, delete.
4. **restrictions-skip-ids** — bulk update/delete skip ids outside the caller's category/age scope; counts reflect only visible items.
5. **invalid-monitored-guard** — unrecognised monitored value returns error and does not write.
6. **out-of-scope-flash** — out-of-scope id shows error flash; view stays alive.

## Incomplete + integrity control

- **Incomplete:** authorize batch delete and monitor but leave `batch_edit` or `trigger_rescan` without `with_media_permission`. Fail the corresponding **guest-bulk-denied** case.
- **Integrity:** unchanged tree fails **guest-bulk-denied** (writes succeed). Reference passes all. **privileged-allowed** blocks “deny everyone.”

## Preservation

- Unrestricted scope still reaches every item (`an unrestricted scope still reaches every item`).
- Normal library listing and non-bulk row UI unchanged.
- String form values `"true"`/`"false"` still accepted from the batch form.

## Runtime / offline holds

- SQLite local (author verified full suite on SQLite) and PostgreSQL in CI — both offline.
- No external media server required for these authorization tests.
- Flutter player side not involved.

## Status

**discovered** — textbook authorization + scope consistency across LiveView and context layers; strong named tests in PR.

## Next action

Run `index_authorization_test.exs` + `bulk_writes_scope_test.exs` at base `961f9f05...`; map each event name in the ticket to a failing test on unchanged.
