# Songs leak between profile playlists

With more than one listener in the database, profile pages are showing tracks from other people's playlists. A second report says that sending a drag-and-drop event for another user's song can change that user's ordering.

Restore playlist isolation. Listing a profile's songs must return only that profile's songs, in playlist order, and apply the requested limit to that owner's collection. A profile with no songs should stay empty even when other users have tracks. The rendered profile page must reflect the same ownership boundary.

Dragging a song is allowed only for its owner. Reject stale reorder events whose old position no longer matches. Forged events for another user's song must leave both playlists unchanged and keep the LiveView usable. Valid owner reorders must continue to work.

Use the real MediaLibrary context, Ecto queries and ProfileLive event handling. Add relevant regression tests without weakening existing behavior. The local test database uses the repository's existing test credentials. `MIX_ENV=test mix test test/live_beats/media_library_test.exs` runs the existing context checks; no audio upload, OAuth credentials or browser asset build are needed to reproduce this issue.
