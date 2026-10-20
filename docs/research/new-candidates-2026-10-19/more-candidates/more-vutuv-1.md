# More candidate — vutuv PR #2365 (photo posts rejected when filename has no extension)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (user/client report in PR body; Mastodon-compatible media API)
**Project:** [wintermeyer/vutuv](https://github.com/wintermeyer/vutuv)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/wintermeyer/vutuv/pull/2365 |
| Title | Buffer can publish posts with a photo |
| Author | **wintermeyer** (maintainer) |
| Merged | 2026-10-11 |
| Diff | https://github.com/wintermeyer/vutuv/pull/2365.diff |
| Commits / squash | Not re-fetched this pass — **re-verify merge parents before reconstruction** (HTML+diff method used; commit pages not opened for this PR) |
| Exposure note | PR body states “An AI agent wrote this text in my name” — record as exposure metadata (same policy as vutuv #2373). |

License: **MIT**. Mix: Elixir `~> 1.20`; Phoenix 1.8, LiveView, Ecto. Lightest runtime of this batch.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> Publishing a post with a photo from Buffer fails with an unknown error; text-only posts arrive. The media upload endpoint answers 422 for every photo Buffer sends. Buffer’s upload name has no usable file extension. Accept image uploads whose format can be determined from the file’s own bytes when the filename does not name a format, and keep refusing files that are not images (including ones that merely have an image-like filename). Fix it.

Do **not** name `image_extension_from_content`, magic-byte patterns, or file paths. Mentioning Buffer is the observed client context; leave “how to detect format” to the solver.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/vutuv/uploads.ex` | Adds content-based extension detection (`image_extension_from_content/1`: JPEG/PNG/WebP/HEIF magic bytes; HEIF brand whitelist). Reuses existing `valid_extension?/2` whitelist helper. |
| `lib/vutuv_web/controllers/mastodon_api/media_controller.ex` | When the upload filename is not a whitelisted extension, synthesize a safe filename from content (`"upload" <> extension`); still passes the path to `Posts.create_pending_image/3`. Filename that already names an image keeps working; unknown content falls through to existing refusal. |
| (callers) | `Posts.create_pending_image/3` gains path + filename arguments — coordinate the post-media pipeline, not only the plug. |

**Cross-component behavior:** media controller ↔ upload whitelist/decode pipeline. Content sniffing must only **name** the container; the existing decode/moderation path must still reject a text file renamed `notes.jpg`. Do not weaken the size/count/rate limits.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (1) | `test/vutuv_web/controllers/mastodon_api/media_controller_test.exs` (covers `blob`, bare name, name with query string, `.bin`) |
| Docs (1, mechanical) | `docs/architecture/mastodon-api.md` |

**Implementation count:** **2–3** files (uploads helper + media controller + `Posts` call-signature). Slightly under the 2–5 preference; keep as a **focused multi-file** diversity pick (MIT, plain Ecto/LiveView, real client integration).

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| V1 | `POST /api/v2/media` with a real JPEG/PNG/WebP body and filename `blob` (or bare `photo`) returns success / pending image, not 422. |
| V2 | Same for a filename with a signed-URL query suffix (`photo.jpg?X-Amz-Expires=…`) and for `.bin`. |
| V3 | A text file (or random bytes) named `notes.jpg` is still refused. |
| V4 | A filename that already names an accepted image extension still works (preservation). |
| V5 | Size / image-count / rate-limit rules are unchanged. |
| V6 | After accept, the stored pending image is a decodable image of the declared type (downstream moderation/post attachment still sees an image). |

Upstream media controller tests cover V1–V4. V5–V6 need preservation witnesses.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** add magic-byte detection in `Uploads` but **do not** call it from the media controller — V1/V2 still 422.

**Second incomplete:** controller synthesizes extensions from content but **skips** the decode/validity path for content-named uploads — V3 fails (text bytes accepted).

**Integrity:** standard `System.halt(0)` early-exit; require executed controller tests, not only `Uploads` unit tests.

---

## 6. Preservation

- Named-image uploads (the common client path) unchanged.
- Rejection of non-images and over-size files.
- Mastodon API auth / rate limits / pending-moderation behavior.
- Mixed population: named jpg, `blob` png, query-string name, `.bin` jpeg, `notes.jpg` text.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required (test alias migrates). |
| LiveViewTest / lazy_html | Present; fine for controller/HTML checks. |
| Req / link verification | Keep offline — do not score external link checks. |
| Assets/Node | Confirm whether the focused media tests need assets; avoid if possible. |
| Browser | Not required. |

**Not verified:** compilation, green base suite, offline dep cache, merge-parent SHA. PR body notes the member-visible Buffer error string (“An unknown error has occurred”) is not a required exact-text check — grade the HTTP status/acceptance outcome.

---

## 8. Status / next action

**Status:** screened — **diversity** pick (MIT, plain Phoenix/Ecto, authentic third-party client symptom, content-vs-name investigation). Smaller than the multi-file preference; keep as one focused case rather than inflating file count.

**Next action:** verify squash parents on the merge commit page, pin base, run media controller tests unchanged/reference/incomplete. Exposure: AI-written PR prose (record, not exclude). Pair only after a vutuv fixture exists (same runtime as already-filed #2373).

## Grilling (2026-10-19)

### Minimum ticket
Maintenance report is almost right. States the client symptom (Buffer photo upload → 422, text posts fine), the missing capability (determine format from bytes when the filename names no format), and the preservation rule (still refuse non-images, including image-like filenames). Do **not** name `image_extension_from_content`, magic bytes, or paths — the draft already avoids that. Two tightenings:
- "Buffer's upload name has no usable file extension" is fine as observed context. Do not require supporting every extension-less client; grade the bytes-detection behavior.
- The `photo.jpg?X-Amz-Expires=…` signed-URL suffix case is a second failure mode (query string poisoning the extension). If V2 is scored, say "filenames may carry a query-string suffix" in the ticket. Right now it is a hidden extra.

### Named deterministic checks
Unexecuted. V1–V6 are the right obligations:
1. V1 — real JPEG/PNG/WebP body + filename `blob` (or bare `photo`) → accepted, not 422
2. V2 — same with signed-URL query suffix and with `.bin`
3. V3 — text/random bytes named `notes.jpg` → **still refused**
4. V4 — filename that already names an accepted image extension → unchanged (preservation)
5. V5 — size / image-count / rate limits unchanged
6. V6 — accepted upload is a decodable image of the declared type (downstream still sees an image)

Without V3 the "accept everything with magic bytes" or "accept anything extension-less" cheats pass. Without V4 the rewrite can break the common named-filename path. Without V6 a solver can name the container and skip decode/moderation. Without V2 the query-string and `.bin` clients still fail — that is half the ticket's real world.

Upstream controller tests cover V1–V4. V5–V6 are curator obligations and must be named before freeze.

### Ambiguity / unfairness
- Do not grade the exact Buffer error string ("An unknown error has occurred") — the dossier already says this. Grade HTTP status / accept-or-refuse.
- Format set: reference detects JPEG/PNG/WebP/HEIF (with brand whitelist). Ticket says "image". Either say which formats are in scope or accept any detection scheme that accepts those and still refuses non-images. Do not require HEIF brand-whitelist detail in hidden checks.
- Synthesized filename (`"upload" <> extension`) is reference detail. Grade "stored pending image is a decodable image", not the name.
- 2–3 implementation files is under the 2–5 preference. Acceptable as a focused diversity pick per guidelines — do not pad the file count. Be honest in corpus summaries.
- Merge-parent SHAs are **unverified** in the dossier. That is a provenance defect, not a style nit.

### Shortcuts + compiling incomplete
Magic-byte helper unused by the controller (incomplete as stated) compiles and fails V1/V2. Controller synthesizes from content but skips decode/validity for content-named uploads — fails V3 (text accepted). Accept every extension-less upload regardless of bytes — fails V3/V6. Break the named-extension path while adding content detection — fails V4. Weaken size/rate limits to make Buffer succeed — fails V5 (integrity). Rename-only happy path that special-cases the literal string `blob` — fails V2 (other bare names) and is a known cheat; V1 must use more than one bare name.

### Flakiness
Low–medium. Magic-byte detection is pure. Pending-image decode (V6) should use fixture files checked into the test dir — not network, not Buffer. Rate-limit checks need deterministic setup (fixed clock or direct store state), not wall-clock sleeps. Do not assert on Req/link verification or any external HTTP. Confirm the focused media tests are asset-free; if the controller test pulls Node assets, scope the graded suite to the upload plug + uploads helper.

### Preservation
Named-image uploads (the common path) unchanged. Non-images and over-size files still refused. Mastodon API auth / rate limits / pending-moderation behavior unchanged. Mixed population in one test: named jpg, `blob` png, query-string name, `.bin` jpeg, `notes.jpg` text — exact accept set, one pass. That mixed witness is the real anti-shortcut control; do not skip it.

### Env
**MIT** — lightest of this batch. PostgreSQL required (test alias migrates). Phoenix 1.8 / LiveView / Ecto, Elixir `~> 1.20`. Req present — keep link verification offline and ungraded. **Not verified:** compilation, green base suite, offline dep cache, **merge-parent SHAs**. Exposure: PR body states "An AI agent wrote this text in my name" — record as exposure metadata (same policy as #2373 / more2-vutuv-1). Does not exclude; do not treat the PR prose as independent product review.

### Verdict
**READY-WITH-FIX** — authentic third-party client symptom, real content-vs-name investigation, good negative case (V3), and a light MIT runtime. Holding on unverified merge parents, unexecuted suite, and the ticket's silent second failure mode (query-string suffix).

### Must-fix before qualification
1. Re-verify squash/merge parents on the merge commit page; pin the base SHA. Not optional.
2. Ticket: mention the query-string suffix filename if V2 is scored. Do not grade the Buffer error string.
3. Name V5–V6 as protected tests. One mixed-population accept/reject test (named jpg / blob png / query name / `.bin` jpeg / `notes.jpg` text).
4. Incomplete = helper not wired. Second incomplete = skip decode for content-named uploads. Integrity = accept-any-extension-less, special-case `blob`, weakened limits, broken named-filename path.
5. Prove the focused media tests run without Node assets. Record AI-written PR prose as exposure. Pair only after a vutuv fixture exists (companion to #2373 / more2-vutuv-1).
