# Combined case: Pinchflat cookie policy (#640 + #641)

**Status:** discovered — **combined lineage** (preferred over freezing #640 alone)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**License:** AGPL-3.0  
**Task kind:** feature (multi-consumer policy)  
**Policy:** see [LINEAGE-MERGE-POLICY.md](../LINEAGE-MERGE-POLICY.md)

## Why combine

| PR | Merged | What it did |
| --- | --- | --- |
| [#640](https://github.com/kieraneglin/pinchflat/pull/640) | 2025-03-05 ~16:06 PT | Introduces `cookie_behaviour` (`:always` / `:when_needed` / `:never`) on sources; wires it through yt-dlp consumers. At merge, `:when_needed` = **slow indexing only**. |
| [#641](https://github.com/kieraneglin/pinchflat/pull/641) | 2025-03-05 ~16:41 PT (**+35 min**) | Obvious hole: still retry downloads with cookies when the error is cookie-related (`Sign in to confirm…`, members-only). `:when_needed` becomes indexing **and** `:error_recovery`. |

Freezing #640 alone would reject a solver who implements the obvious “also use cookies to recover failed downloads when needed” behavior. That is the better product and is visible from the ticket if we say it.

**One case** covering both outcomes. Intermediate (indexing-only) is the natural incomplete.

## Reconstruction

Use **both** patches in order at the right bases (Pinchflat squash-merges):

1. Base **A** = squash parent of #640 = **`59f8aa69…`** (not `b790e051`, which is `A^`).
2. Apply #640 (`pull/640.diff`, exclude generated `priv/repo/erd.png`).
3. Apply #641 (`pull/641.diff`) on top — **or** take a single tree = post-#641 head if you freeze one SHA.
4. Provenance lists **both** PRs and both applied commits (`ac89594…`, `a97bb24…`).

Do not claim the case is “only #640”.

## File roles (union, ~8–10 implementation)

| Area | Role |
| --- | --- |
| Source / settings schema + migration | `cookie_behaviour` stored on source (or app default) |
| yt-dlp command / runner adapters | Conditionally pass cookies |
| Indexer path | Uses cookies when behaviour says so |
| Downloader path | Uses cookies; **with #641**, retries with cookies on cookie-like errors |
| Metadata / other consumers | Same policy |
| UI / LiveView | Expose the setting |
| Tests | Policy matrix + download error retry |

Exact paths in `deep-dive-pinchflat-640.md` / `deep-dive-pinchflat-610.md`; re-verify file list when building the bundle.

## Solver ticket (clarified feature brief)

> When I set a source’s cookie behavior to “when needed”, cookies should be used only when they are actually required: for slower full indexing passes, and to retry a download when the failure looks like a cookie/login problem (for example sign-in confirmation or members-only videos). “Always” always sends cookies; “never” never does. Make this consistent for indexing, downloading, and any other yt-dlp use on that source, and let me set the behavior on a source. Keep existing sources working.

This **includes** #641’s recovery rule as a visible product outcome (it is the “when needed” meaning we want). It does **not** name files or the `:error_recovery` atom.

## Named acceptance (proposed)

| ID | Check |
| --- | --- |
| A1 | `:always` passes cookies on indexing, download, and metadata |
| A2 | `:never` never passes cookies |
| A3 | `:when_needed` + fast/slow indexing: cookies on **slow** indexing path only |
| A4 | `:when_needed` + download failure matching cookie/sign-in style: **retries with cookies** and can succeed |
| A5 | `:when_needed` + unrelated download failure: **no** cookie retry |
| A6 | UI/API can set and persist the behavior; defaults preserve old behavior |

## Incomplete control (compiling)

Implement #640 only: `:when_needed` = indexing only, no cookie-retry on download errors.  
**Expected named failure:** A4 (and any combined “when needed” meaning check).

## Integrity / shortcuts

Reject: always retry every download with cookies; ignore the setting on one consumer (e.g. metadata still sends cookies when `:never`).

## Preservation

- Sources without an explicit behavior keep prior defaults.
- Ordinary downloads without cookies still work.
- Members-only / sign-in messaging still surfaces when cookies are absent and retry is not applicable.

## Runtime / offline holds

- AGPL-3.0.
- SQLite + Oban; tests mock yt-dlp (Mox) — offline OK if fixtures stay mocked.
- Do not require live YouTube.

## Experiment notes (from deep-dive)

- #640 and #641 patches apply cleanly at their bases (exclude `erd.png`).
- Mix tests green for #640 alone; re-run the **combined** tree before freeze.
- Later PRs may change cookie rules again — pin the **combined** tree SHA after apply.

## Next action

1. Build reference = A + #640 + #641 (or post-#641 squash head).
2. Write incomplete = #640-only tree.
3. Map A1–A6 to protected checks; keep `erd.png` out of applies.
4. Independent contract review on the ticket above (cookie-retry rule is now **stated**, not hidden).
