# Altered notebook retains signed secret authorization

A signed Live Markdown notebook can still be treated as verified after extra executable content is inserted before its final stamp comment.

Start with a valid stamped notebook authorized to use a hub secret. Insert an additional code cell after its original content but before the stamp, then import it. The changed notebook must not retain verified status or the stamp's secret authorization; it should report that verification failed. Unchanged, legitimately signed notebooks must still import and verify correctly.

Fix the import behavior and add regression coverage for the altered notebook while preserving valid stamp handling.

Verification must cover executable cells in every supported language, including Elixir and Erlang. Valid signed content may contain Unicode; importing it must preserve its authorization without confusing byte offsets with character positions.
