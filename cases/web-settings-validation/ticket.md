# Profile settings silently accept invalid input

Users report that clearing their profile tagline no longer produces a validation error. Some saves replace the existing tagline with an empty value. Invalid edits also fail to display useful validation feedback while typing.

Repair the settings workflow. Both username and profile tagline are required. An invalid validation event or save must preserve the previously stored values and keep the form usable with errors visible. After correcting an invalid edit, the user must be able to save successfully in the same LiveView session. Existing username uniqueness and format rules must continue to apply.

This is the LiveBeats music-sharing demo. Work within its existing Accounts context, Ecto changesets and LiveView form conventions. Add regression coverage where useful; do not replace the application or bypass its database.

The test database is available locally, with the existing test configuration's credentials. `MIX_ENV=test mix test test/live_beats/accounts_test.exs` runs the existing Accounts checks. No GitHub OAuth credentials or browser asset build are needed for the server-side test workflow.
