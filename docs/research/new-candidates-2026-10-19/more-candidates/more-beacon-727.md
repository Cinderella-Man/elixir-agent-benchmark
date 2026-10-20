# Beacon #727 — asset responses must negotiate content encoding

**Status:** discovered  
**Source type:** historical PR  
**Project:** [BeaconCMS/beacon](https://github.com/BeaconCMS/beacon)  
**PR:** [#727](https://github.com/BeaconCMS/beacon/pull/727) — *fix: negotiate asset encoding*  
**Author:** leandrocp · **Merged:** 2025-01-15  
**Task kind / family:** bug_fix / HTTP content-encoding negotiation for runtime CSS/JS  
**Research date:** 2026-10-19  
**License:** MIT

## Identity SHAs (verified)

| Role | SHA | Notes |
| --- | --- | --- |
| Squash / merge commit | `6e69859a7f9d20263055f78f020c5cc1daf8ab12` | Title `…(#727)`, **1 parent** (squash-merge) |
| First-parent / squash parent (base) | `8ce6717d86bce85248ee86ad691f9029411b7d87` | Sole parent — task base |

PR metadata: `commitsCount: 4`, same-day open/merge. Reconstruct at **`8ce6717d…`** and apply `pull/727.diff` (ignore the unrelated `dev.exs` bind-address tweak or treat it as mechanical).

## Why it is a good case

Runtime CSS/JS were stored once brotli-compressed and **always** served with `content-encoding: br`, even when the client’s `accept-encoding` did not include `br`. Clients without brotli got undecodable bytes. The PR keeps raw + brotli + gzip (+ raw deflate body) in ETS and the assets controller picks the encoding from `accept-encoding` with a clear preference order. Coordinated across `RuntimeCSS`, `RuntimeJS`, `AssetsController`, and a small `Layouts` path fix. Upstream tests name the preference matrix. The ticket can describe wrong encodings without naming the ETS tuple or `:zlib.gzip`.

**Lineage note:** related to #716 (*Retry CSS asset loading*, same asset pipeline, 8 days earlier). **Not merged into one case:** #716 is a missing-ETS-retry/nil-hash robustness fix; #727 is encoding negotiation. Different product outcomes — keep separate (see [LINEAGE-MERGE-POLICY](../large-features/LINEAGE-MERGE-POLICY.md) “when not to merge”). If both enter the corpus, note the shared subsystem.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/beacon/runtime_css.ex` | Store `{hash, css, brotli, gzip}` in ETS; `fetch/2` by encoding (`:brotli`/`:gzip`/`:deflate`); `load!` builds gzip via `:zlib` and brotli via `ExBrotli` (brotli may be nil) |
| `lib/beacon/runtime_js.ex` | Same tuple/fetch/load contract for JS |
| `lib/beacon/web/controllers/assets_controller.ex` | Parse `accept-encoding`; prefer `br`, then `gzip`, then deflate/uncompressed; set `content-encoding` only when an encoding is used |
| `lib/beacon/web/components/layouts.ex` | `asset_path` uses the resolved router (small correctness fix in the same PR) |

**Counts:** 4 substantive implementation files (+ `dev.exs` mechanical). Tests in `runtime_css_test.exs`, `runtime_js_test.exs`, `assets_controller_test.exs`.

## Cross-component behavior to verify

- CSS and JS share the **same** preference policy (`br` > `gzip` > uncompressed).
- When brotli compression failed at load time (`nil`), the controller **falls back to gzip** rather than serving nil.
- `content-encoding` is omitted for the uncompressed/deflate path and matches the body actually sent.
- Hash/URL stability (`current_hash`) still works for cache-busting paths.

## Draft ticket (shortest sufficient)

> Some browsers cannot decode our CSS/JS assets because we always send brotli, even when the client did not ask for it. Serve runtime CSS and JS using the encodings the request actually accepts (prefer better compression when available), and fall back cleanly when a compression step is unavailable. Fix it.

## Proposed named acceptance checks

1. `assets_brotli-preferred` — `accept-encoding: br` → body is brotli, `content-encoding: br`.
2. `assets_fallback-gzip-when-no-brotli` — `accept-encoding: gzip` (no br) → gzip body + `content-encoding: gzip`.
3. `assets_uncompressed-when-no-encoding` — no/unmatched `accept-encoding` → uncompressed body, **no** `content-encoding` header.
4. `assets_brotli-nil-falls-back-to-gzip` — brotli slot nil at load; request asks for br → gzip body (not empty).
5. `assets_js-same-policy` — JS mirrors the CSS matrix (checks 1–3 on JS).
6. `assets_hash-path-still-serves` — hashed `__beacon_assets__` route still returns 200 with the negotiated body (preservation).

## Plausible incomplete + integrity control

- **Incomplete:** implement gzip fallback in the controller but keep ETS 3-tuple / never store gzip (or only fix CSS, not JS). Compiling; fails checks 2 or 5.
- **Integrity:** reject patches that always send `content-encoding: br`, that send `br` with a gzip/uncompressed body, or that drop the raw copy so uncompressed clients get compressed bytes.

## Preservation

- `current_hash` / asset URL generation unchanged (aside from the layouts router clarification in the PR).
- Existing loader and assets tests stay green.
- Do not require the #716 retry behavior; keep that out of the brief.

## Runtime / offline holds

- MIT. No services. `ExBrotli` and `:zlib` only.
- `dev.exs` HTTP bind change in the diff is unrelated to the product outcome — do not grade it; either strip from the reference apply or leave unasserted.
- Check OTP zlib gzip determinism in fixtures (hash of body, not compressed bytes, in assertions).

## Experiments (quick)

- `pull/727.diff` well-formed; named upstream tests: `fetch defaults to compressed`, `fetch uncompressed deflate`, `brotli has preference`, `fallback to gzip when brotli is not accepted`, `fallback to deflate when compression is not accepted`.
- Squash parent `8ce6717d…` verified (1 parent). Not combined with #716.

## Status: discovered

Spec-clear 4-file HTTP correctness bug with a strong upstream test matrix. Complements (does not duplicate) the multi-node media case #713.

## Next action

Pin base `8ce6717d…` → apply diff (optionally strip `dev.exs`) → map checks 1–6 → incomplete = CSS-only or no-gzip-fallback → qualification. If #716 is also selected later, record shared-subsystem overlap in both dossiers.

## Grilling (2026-10-19)

### Minimum ticket
Correct maintenance report. States the product outcome (negotiate encodings the client accepts, prefer better compression, fall back when a compression step is unavailable) without naming the ETS tuple, `:zlib`, or the preference order internals. "prefer better compression when available" is the one soft spot — the reference is `br` > `gzip` > uncompressed. Either name that order or accept any order that prefers `br` when accepted and never sends `br` to a non-`br` client. Do not require "gzip before deflate" as hidden policy if the ticket does not say it.

### Named deterministic checks
Unexecuted. Upstream already names the matrix — map these to protected tests, do not invent a second contract:
1. `assets_brotli-preferred` — `accept-encoding: br` → brotli body + `content-encoding: br`
2. `assets_fallback-gzip-when-no-brotli` — `gzip` (no br) → gzip body + `content-encoding: gzip`
3. `assets_uncompressed-when-no-encoding` — empty/unmatched → raw body, **no** `content-encoding`
4. `assets_brotli-nil-falls-back-to-gzip` — brotli slot nil; client asks br → gzip body, not empty/nil crash
5. `assets_js-same-policy` — checks 1–3 on JS, not CSS only
6. `assets_hash-path-still-serves` — hashed `__beacon_assets__` route 200 with negotiated body (preservation)

Without (4) the "never store gzip / panic on nil brotli" incomplete survives. Without (5) CSS-only passes. Without (3) the always-`content-encoding` cheat passes. Without (6) a solver can break routing while fixing the codec pick.

Also needed: `content-encoding` value must match the **body actually sent** (br header + gzip bytes is the classic cheat). Assert by decoding, not just header presence.

### Ambiguity / unfairness
- Preference order: see above. If you grade exact `br` > `gzip` > deflate, say so in the ticket ("prefer brotli, then gzip, then plain").
- Raw deflate body path in the reference is an implementation detail. Do not require a separate `deflate` encoding label unless the ticket names it.
- "fall back cleanly when a compression step is unavailable" is fair for the nil-brotli case. Do not also require recovering from a crashed `ExBrotli` load mid-request.
- `Layouts.asset_path` router fix is incidental. Do not grade it unless you put it in the ticket (you should not).
- `dev.exs` bind-address tweak is mechanical. Strip from reference apply or leave unasserted. Never count it as an implementation file.

### Shortcuts + compiling incomplete
CSS-only fix fails (5). Controller gzip path with ETS still 3-tuple (no stored gzip) fails (2). Always send `content-encoding: br` with any body fails (1)+(3). Send br header with gzip body fails the decode witness. Drop the raw copy so uncompressed clients get compressed bytes fails (3). Hash/route change that serves the wrong entry fails (6). Incomplete: "gzip in controller, never store gzip" and "fix CSS only" both compile.

### Flakiness
Low–medium. Assert on decoded content / stable asset hash, not compressed-byte equality (`:zlib` gzip is deterministic enough at a pinned OTP but brotli output may differ by encoder version — pin `ExBrotli` and assert **decode round-trip + header**, not exact br bytes). No clocks, no network. Controller tests can be sync.

### Preservation
`current_hash` / cache-busting URLs unchanged. Loader and existing assets tests stay green. Uncompressed clients still get valid CSS/JS. Do **not** require #716 retry/ETS-retry behavior — keep that out of the brief and out of the checks.

### Env
MIT. No services. `ExBrotli` + `:zlib` only. **Nothing executed** — no apply, no compile, no test. 4 implementation files is in the sweet spot. Strip or ignore `dev.exs`. Pin OTP so gzip/br fixture expectations stay stable.

### Verdict
**READY-WITH-FIX** — clean 4-file HTTP correctness bug, real visible contract, upstream test matrix, no harness mystery. Holding only on execution + a few check tightenings, not on product ambiguity.

### Must-fix before qualification
1. Pin base `8ce6717d…`, apply diff minus `dev.exs`, run unchanged/reference/incomplete. Unchanged must fail 1–5; reference must pass.
2. State the preference order in the ticket or accept any client-safe preference that prefers `br` when accepted.
3. Body/header consistency witness (decode the body; do not trust `content-encoding` alone).
4. Incomplete: CSS-only and no-gzip-storage. Integrity: always-br, br-header+gzip-body, dropped raw copy.
5. Grade decoded content / hash stability, not exact brotli bytes. Keep #716 out of scope.
