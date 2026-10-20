# app-candidate-changelog.com-339

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/thechangelog/changelog.com/pull/339 |
| Title | First time commentor validation |
| Project | thechangelog/changelog.com |
| Source type | Historical merged PR (bounded moderation feature) |
| PR head SHA | `400e86e853277ec1a0a69310564c538b38c514a9` (last of 8 commits) |
| First commit | `3d510881acfc42cdb4bc30334c4ca6efde13e838` |
| Parent of first commit (likely base) | `a3ff4fd53e42841aae80fef2edd1bcc5bbf54a45` |
| Merged at | 2020-12-16T20:07:22Z |
| License | Custom: content/design © Changelog Media LLC; code under MIT-style permission |
| Verification | **Unverified** — diff/HTML inspected; tests not executed |

## Why it is a case

New commenters must not notify subscribers until an admin approves them. The feature spans schema (`approved_commenter` on person), comment create/update flow, notifier branching, admin moderation UI/actions, and email templates.

What must stay consistent:

- Comment create: unapproved commenter's comment is stored but **not** notified; approved commenter still notifies.
- Comment update path: approved comment still notifies/redirects as before.
- Admin approve/revoke commenter changeset + comment moderation tables/forms agree on the new state.
- Email content for unapproved commenter is sent only on the moderation path that should alert admins.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/changelog/schema/person.ex` | `approve_commenter_changeset` / `revoke_commenter_changeset` |
| `lib/changelog/schema/news/news_item_comment.ex` | Comment schema + approved-flag awareness |
| `lib/changelog/notifier.ex` | `notify/1` branches on `approved` (or commenter approval) |
| `lib/changelog_web/controllers/news_item_comment_controller.ex` | Public create path must not notify unapproved |
| `lib/changelog_web/controllers/admin/news_item_comment_controller.ex` | Moderation actions |
| `lib/changelog_web/email.ex` + email templates | Unapproved-commenter admin email |
| `priv/repo/migrations/..._add_approved_commenter_column.exs` | Persistence |

Tests (separate): comment schema/controller/admin controller tests + factory/conn_case.

## Draft ticket

> Comments from first-time commenters show up publicly and notify subscribers before anyone has reviewed them. Hold notification for commenters who are not yet approved, keep approved commenters' notifications working, and let admins approve or revoke a commenter. Fix it.

## Named acceptance checks

1. **unapproved-no-notify** — creating a comment as an unapproved/new commenter stores the comment and does **not** send the subscriber notification.
2. **approved-notifies** — creating a comment as an approved commenter still notifies.
3. **update-approved-still-notifies** — updating an approved comment follows the existing notify/redirect behavior (preservation).
4. **admin-approve-then-notify** — after admin approves the commenter, a subsequent comment notifies.
5. **admin-revoke-stops-notify** — after revoke, a new comment does not notify.
6. **unapproved-admin-email** — moderation path can send the unapproved-commenter admin email (or named template exists and is invoked only there).

## Incomplete + integrity control

- **Incomplete:** add the schema column and admin approve/revoke, but leave `Notifier.notify/1` notifying every comment. Fail **unapproved-no-notify**.
- **Integrity:** unchanged tree fails **unapproved-no-notify**; reference passes all. Positive checks 2–3 must still pass so “disable all notifications” is not a valid repair.

## Preservation

- Existing commenter comment + notify flow unchanged.
- Admin comment table/forms remain usable for already-approved users.
- No requirement to change public comment rendering beyond moderation state.

## Runtime / offline holds

- PostgreSQL + mailer stubs (Swoosh/Bamboo-era `ChangelogWeb.Email`) — offline if mail is captured/stubbed in tests.
- Docker-compose / yarn.lock noise in the PR is mechanical; do not count as implementation.
- No S3/YouTube for this path. Offline fixtures feasible.

## Status

**discovered** — authentic moderation workflow with positive and negative notification paths; multi-file schema/controller/email consistency. Historical (2020) toolchain may need older Elixir pin — **runtime version risk noted**.

## Next action

Confirm Elixir/OTP pin at `a3ff4fd5...` (2020 tree); if too old for the runner, either use a later backport-era revision of the same behavior or record a runtime hold.
