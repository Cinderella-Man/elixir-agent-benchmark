# Pinchflat #356 — min/max media duration filters on sources

**Status:** discovered  
**Source type:** historical PR  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#356](https://github.com/kieraneglin/pinchflat/pull/356) — *[Enhancement] Filter media based on min and/or max duration*  
**Author:** (upstream) · **Merged:** 2024-08-14  
**Task kind / family:** feature / source policy → pending-media query → form  
**Research date:** 2026-10-19  
**License:** AGPL-3.0-or-later

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `af8235c6b326d5901a242282c8ea327167e0c633` | Title `…(#356)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `8e9f02c8078bdba882830df0b54c2efee46e535a` | Matches PR API `base` — task base |

Reconstruct at **`8e9f02c8…`** and apply `pull/356.diff`, **excluding generated `priv/repo/erd.png`**.

## Why it is a good case

Users want to skip very short clips or very long streams per source. The PR adds optional `min_duration_seconds` / `max_duration_seconds` on `Source`, validates that min < max when both set, threads a `meets_min_and_max_duration` dynamic into the pending-media query (alongside existing title-regex / cutoff filters), and exposes fields on the source form. Coordinated schema + query + validation + UI; upstream already has named tests at the query and changeset layers.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat/sources/source.ex` | Schema fields + `validate_min_and_max_durations` (error when min ≥ max) |
| `lib/pinchflat/media/media_query.ex` | `meets_min_and_max_duration/0` dynamic AND-ed into `pending_media_items` |
| `lib/pinchflat_web/controllers/sources/source_html/source_form.html.heex` | Form inputs for min/max |
| `lib/pinchflat_web/controllers/sources/source_controller.ex` | Copy/template cast so the new fields round-trip (also nils `description` on the blank template) |
| `priv/repo/migrations/20240814193939_add_duration_limits_to_sources.exs` | Columns on `sources` |
| `test/pinchflat/media_test.exs` | Query membership / nil-bypass tests |
| `test/pinchflat/sources_test.exs` | Changeset min/max validation tests |

**Counts:** 4 substantive implementation files + 1 migration + 2 test files. Exclude `priv/repo/erd.png` (generated).

## Cross-component behavior to verify

- Pending media selection skips items outside `[min, max]` when those bounds are set.
- Nil min, nil max, or both nil means “no duration filter” (preserves today’s behaviour).
- Changeset rejects `min >= max` with a field error; accepts nil/singleton bounds and min < max.
- Existing filters (title regex, cutoff date, download prevention, format preference) still apply together.

## Draft ticket (shortest sufficient)

> Let me skip media that is too short or too long on a source. Add optional minimum and maximum duration limits (in seconds) on a source: when set, only media whose duration is within those bounds is eligible for download; when left blank, duration is not filtered. Reject a configuration where the minimum is not strictly less than the maximum. Keep the existing source filters working.

Clarified implementation brief (product shape: optional seconds, blank = unbounded, min < max). Does not name schema fields or query helpers.

## Proposed named acceptance checks

1. `query respects-min-max` — media below min / above max are not pending; in-range items are.
2. `query nil-bounds-are-unbounded` — nil min, nil max, or both nil leave all durations pending.
3. `source rejects-min-eq-max` / `source rejects-min-gt-max` — changeset errors on invalid pairs.
4. `source accepts-valid-bounds` — nil/singleton/min<max save and round-trip through the form.
5. `query keeps-other-filters` — title regex and cutoff still exclude as before (preservation).

Upstream tests cover 1–3 well; 4–5 need small curator extensions (form round-trip + combined filters).

## Plausible incomplete + integrity control

- **Incomplete:** schema + migration + form only; `media_query` never applies `meets_min_and_max_duration`. Compiling; fails check 1.
- **Integrity:** reject patches that treat blank as 0 (would drop all media), that drop other pending filters, or that accept min ≥ max.

## Preservation

- Sources without duration limits download exactly as before.
- Title-regex / cutoff / format-preference pending rules stay green.
- Retention and quality-upgrade paths are out of scope (they use different queries).

## Runtime / offline holds

- AGPL-3.0. SQLite + Oban; yt-dlp mocked — no YouTube.
- Exclude `priv/repo/erd.png` from applies and graded diffs.
- Verify SQLite migration applies cleanly at `8e9f02c8…`.

## Experiments (quick)

- `pull/356.diff` well-formed; 8 paths as listed (including `erd.png`). Diff parses.
- Squash parent `8e9f02c8…` from commit page (`parents:[…]`, “1 parent”); equals PR API `base`.

## Optional git apply

```
git checkout 8e9f02c8078bdba882830df0b54c2efee46e535a
git apply --exclude=priv/repo/erd.png pull/356.diff
```

## Status: discovered

Clean 4+1 file feature with a real schema↔query↔form relationship and upstream named tests. Distinct family from cookie policy (#640/#641), download errors (#610), and bandwidth (#646).

## Next action

Pin `8e9f02c8…` → apply diff minus `erd.png` → map checks 1–5 → incomplete = UI/schema only → three qualification rounds.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Let me skip media that is too short or too long on a source. Add optional minimum and maximum duration limits in seconds on a source: when set, only media whose duration is inside those bounds is eligible for download; when left blank, duration is not filtered. Reject a configuration where the minimum is not strictly less than the maximum. Keep the existing source filters working.

Clarified brief, 4 sentences. Product decisions stated: optional seconds, blank = unbounded, strict min < max. Does not name schema fields, query helpers, or the form.

**Hidden requirements flagged:**
- Media with **unknown** (`NULL`) duration when a bound is set: reference SQL (`duration_seconds >= ?`) excludes them. Ticket does not say whether unknown-duration media is eligible. Say "media without a recorded duration is not eligible when a limit is set" or accept both.
- Validation uses `get_change/2` on each bound separately. Editing only `max` on a source that already has `min` in the DB can accept `min >= max`. That is a reference bug, not a product choice — either fix the reference or state "validation considers the stored bounds too".

### 2. Deterministic checks

ExUnit + Ecto sandbox, SQLite. No jobs, no sleeps. Existing style: `media_test.exs` fixtures + `sources_test.exs` changesets.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `query duration-bounds-filter` | Source min=10 max=20; three pending media items with durations 5 / 15 / 25 | `Media.list_pending_media_items_for/1` | only the 15s item pending |
| `query nil-bounds-unbounded` | Same items; nil min / nil max / both nil | same | all eligible durations pending |
| `source rejects-min-not-below-max` | Changeset with min=max and min>max | changeset | error on the max field (or any field); not valid |
| `source accepts-valid-bounds` | nil/singleton/min<max | changeset + insert | valid, round-trips |
| `query edit-existing-validates-against-stored` | Persist min=10; update **only** max=5 | changeset | **invalid** (catches the `get_change` hole). If you keep reference behaviour, drop this check and say so in the ticket. |
| `query other-filters-preserved` | Title-regex / cutoff / download-prevented sources with duration bounds | pending set | other filters still exclude (preservation) |

Fake provider: none. yt-dlp is not in this path.

### 3. Ambiguity / unfairness

- NULL-duration policy (above) is the real contest.
- Strictness of `min < max` is stated — good. Do not let hidden tests require `min <= max` (some users want a single exact duration via min=max; the ticket forbids that on purpose).
- Form field labels ("Minimum Duration (seconds)") are cosmetic — do not grade copy.
- `description: nil` on the blank template is incidental; exclude from the contract.
- Error message text ("must be greater than minumum duration" — note the typo in the reference) must **not** be graded.

### 4. Shortcuts

- Schema + migration + form only; query never AND-s `meets_min_and_max_duration`. Compiles. Fails `query duration-bounds-filter`. This is the planned incomplete — good.
- Filter applied only in one consumer (`pending_media_items`) and not in the retention/quality paths. Ticket scopes to "eligible for download" — do not require other query families; say "download eligibility" so the solver is not graded on unmentioned paths.
- Treat blank as 0 → drops all media when only max is set. Caught by `query nil-bounds-unbounded`.
- Accept min ≥ max by validating only when both change in one submit. Caught by `query edit-existing-validates-against-stored` **if** you keep it.

### 5. Flakiness / nondeterminism

Low. Pure query/changeset. Watch ordering in `list_pending_media_items_for` — upstream asserts exact list equality; add `Enum.sort` or match by id-set if the query has no stable order.

### 6. Coverage mix

- Positive: in-range item pending; valid bounds save.
- Negative: out-of-range excluded; invalid bounds rejected.
- Preservation: nil bounds behave as today; title-regex + cutoff still work **together** with duration (one mixed test).
- Population: 3+ media items per query test (short / in-range / long) so a "drop everything" or "drop nothing" patch fails.

### 7. Environment risk

- **AGPL-3.0-or-later.**
- **SQLite** + Oban; runner claims PG/ClickHouse service handling — confirm the SQLite path works in the Pi fixture before qualification. This is the main environment unknown.
- yt-dlp mocked — no YouTube. Exclude `priv/repo/erd.png` (generated binary).
- Migration must apply at `8e9f02c8…`.

### 8. Verdict

**READY-WITH-FIX** — clean schema↔query↔form feature with upstream named tests; two policy holes (NULL duration, edit-time validation) must be settled before freeze.

### 9. Must-fix list

1. State NULL-duration eligibility in the ticket (or accept both in checks).
2. Decide edit-time validation: either require checks against stored bounds (and fix reference) or explicitly allow the `get_change` behaviour.
3. Grade on membership sets, not exact list order.
4. Incomplete = schema+migration+form without query predicate.
5. Prove SQLite fixture; exclude `erd.png`.

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | NULL-duration + edit-time validation unsettled |
