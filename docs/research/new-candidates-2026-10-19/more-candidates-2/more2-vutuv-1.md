# More2 candidate — vutuv PR #2368 (link spam: signup trap, nofollow, auto-freeze)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (operator incident report in PR body; Mastodon-compatible social profile)
**Project:** [wintermeyer/vutuv](https://github.com/wintermeyer/vutuv)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/wintermeyer/vutuv/pull/2368 |
| Title | Link spam: trap single-name sign-ups, nofollow profile links, freeze new accounts that plant a link |
| Author | **wintermeyer** (maintainer) |
| Merged | 2026-10-13 (squash) |
| Merge commit SHA | `e48053a9c4d9f74dfaece90cce6df7d328dc957a` |
| **Base SHA (parent of squash)** | `a449ec57e5c8d528e829f7a578cff2a9502721b1` |
| Squash parents | **1 parent** — squash verified via API commit object |
| Diff | https://github.com/wintermeyer/vutuv/pull/2368.diff |
| Commits in PR | 1 (squash) |
| Scale | 33 files, +685 / −170 |
| Exposure note | PR body states “An AI agent wrote this text in my name” — record as exposure metadata (same policy as already-filed vutuv #2365/#2373). |

License: **MIT**. Mix: Elixir `~> 1.20`; Phoenix, LiveView, Ecto. Lightest runtime of this batch.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> Two spam accounts signed up with a single lowercase word as their only name, confirmed their address, and put a search-engine link plus copy into the headline. Our signup trap only caught same first/last names. Close that hole, stop profile prose from passing link juice to outside URLs, and automatically freeze brand-new accounts that plant a foreign link in their headline. Freezes must be reversible and visible to admins as automatic (not as a human report or admin action). Do not delete accounts. Fix it.

Do **not** name `SignupTrap`, `LinkSpam`, `LinkSpamSweeper`, `ugc nofollow`, `:link_spam_check`, or file paths. “Admins can see the source of a freeze” is the visible product outcome; leave module names and the 30-minute cadence to the solver (cadence may be stated if needed to make the job observable offline).

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/vutuv/signup_trap.ex` | Second trap rule: single lowercase name with the other name field empty (the September same-word rule missed these). |
| `lib/vutuv_web/markdown.ex` | Profile prose / DM renderer marks **off-site** links `rel="ugc nofollow noopener noreferrer"`; in-site links stay followed. |
| `lib/vutuv/moderation/link_spam.ex` | Check: brand-new account (last day) with one name + foreign link in headline → auto-freeze. Never deletes. Thawed account is exempt. |
| `lib/vutuv/moderation/link_spam_sweeper.ex` | GenServer clock (every 30 minutes) that runs the check. |
| `lib/vutuv/moderation.ex` | `auto_freeze_user/2` ledger + `auto_frozen_ids/1` / counts / samples so admin UI and reports can tell automatic freezes from admin/report freezes. |
| `lib/vutuv/application.ex` | Supervise the sweeper behind `:link_spam_check` (cold deploy: new child). |
| `lib/vutuv/reports.ex`, `lib/vutuv/reports/daily_report.ex` | Daily report includes auto-freeze count + sample. |
| `lib/vutuv_web/controllers/admin/account_controller.ex`, `lib/vutuv_web/templates/admin/account/frozen.html.heex`, `lib/vutuv_web/views/admin/account_html.ex` | Frozen list shows freeze **source** (automatic check vs admin vs report). |
| `lib/vutuv_web/report_details.ex`, `lib/vutuv_web/views/admin/report_html.ex`, email templates | Surface the auto-freeze metric in admin report + German daily email. |

**Cross-component behavior:** signup trap ↔ markdown link policy ↔ moderation freeze ledger ↔ admin source labels ↔ daily report. A freeze that does not record its rule cannot be labeled “automatic”; a trap that blocks the new shape still leaves headline link-planting free.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (9) | `link_spam_test`, `signup_trap_test`, `admin/account_controller_test`, `signup_trap_registration_test`, `markdown_test`, `markdown_bluesky_test`, `moderation_case_controller_test`, `post_controller_test`, `post_image_controller_test`, `dev_webhook_controller_test` |
| Docs (2, mechanical) | `docs/ADMINS.md`, `docs/architecture/authentication.md` |
| Gettext (5, mechanical) | `priv/gettext/**` |
| Config (1) | `config/test.exs` |

**Implementation count:** **~10** code paths (trap + markdown + moderation domain + sweeper + app + reports + admin UI). Larger than the 2–5 preference; admitted as a **coherent multi-layer security feature** if vutuv runtime is already proven (#2365/#2373 family). Gettext/docs are mechanical.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| V1 | Signup with a single lowercase name (other name empty) is trapped/rejected (the new spam shape). |
| V2 | Signup with distinct first/last names still works (preservation). |
| V3 | Off-site link in profile prose/DM renders `ugc nofollow` (+ noopener noreferrer). |
| V4 | On-site / relative link is **not** nofollowed. |
| V5 | New account (within the lookback) with one name + foreign link in headline is auto-frozen; account is hidden like an admin freeze but **not** deleted and login is not blocked. |
| V6 | A freeze records the automatic rule name; `/admin/accounts/frozen` labels it “automatic check” (distinct from admin/report). |
| V7 | A thawed account is not re-frozen by the same rule (exemption sticks). |
| V8 | Daily report and email include the auto-freeze count/sample. |
| V9 | Preservation: ordinary accounts (two names, no link) are never frozen; posts keep followed links as before; size/rate limits unchanged. |

Upstream tests cover V1–V8 in unit/controller form. V9 needs a positive preservation witness (mixed population).

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** trap + nofollow work, but no sweeper/ledger — V5–V8 fail.

**Second incomplete:** auto-freeze works but labels every freeze “admin” — V6 fails.

**Third incomplete:** nofollow applied to **all** links including on-site — V4 fails (overreach).

**Integrity:** standard `System.halt(0)` early-exit; require executed moderation + markdown + admin controller tests, not only `SignupTrap` unit tests.

---

## 6. Preservation

- Normal two-name signups and ordinary posting.
- In-site links remain followed.
- Admin manual freeze / report freeze paths and their labels.
- Existing moderation cases and post/media pipelines.
- Mixed population: two-name clean, single-name clean (if allowed), single-name + headline link, two-name + headline link, thawed spam account.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required (test alias migrates). |
| LiveViewTest / lazy_html | Present. |
| Req / link verification | Keep offline — do not score external link checks. |
| GenServer sweeper | Deterministic if tests call `LinkSpam.run/1` directly (as upstream does); do not require wall-clock 30-minute waits. |
| Browser | Not required. |
| Assets/Node | Confirm focused tests do not need assets. |

**Not verified:** compilation, green base suite, offline dep cache. PR body notes the AI-written prose (exposure metadata only). Grade HTTP/status/ledger outcomes, not exact German report wording unless a check names it.

---

## 8. Status / next action

**Status:** screened — strongest **multi-layer security** candidate this pass (trap + link policy + moderation job + admin provenance + report). MIT, plain Phoenix/Ecto. Bigger file count but one user story (stop link-plant spam).

**Next action:** verify squash parent `a449ec57…`, pin base, run moderation/markdown/admin tests unchanged/reference/incomplete. Exposure: AI-written PR prose (record, not exclude). Pair after a vutuv fixture exists (same runtime as already-filed #2365/#2373). Optional lineage: #2372 (expired certificates under “Previously held”) is **adjacent moderation UI** but a different product outcome — keep separate per LINEAGE-MERGE-POLICY.

## Grilling (2026-10-19)

### 1. Minimum solver ticket

> Two spam accounts signed up with a single lowercase word as their only name, confirmed their address, and put a search-engine link plus copy into the headline. Our signup trap only caught same first/last names. Close that hole. Also stop profile prose from passing link juice to outside URLs (on-site links stay normal), and automatically freeze brand-new accounts that plant a foreign link in their headline — freeze, never delete; freezes must be reversible and shown to admins as automatic rather than as a human report or admin action. A thawed account must not be frozen again by the same rule.

Maintenance report. States the product outcomes: new trap shape, nofollow only for off-site links, auto-freeze window + link-in-headline, freeze-not-delete, provenance label, thaw exemption.

**Hidden requirements flagged:**
- "brand-new" window is **one day** in the reference (`@window_minutes 24*60+30`). Ticket must say "registered within the last day" or accept a band. Unstated = unfair.
- "foreign link" definition: reference uses `Markdown.foreign_link?/1` (off-site), and a pasted bare address counts. Say "a link or pasted address that leaves the site".
- Exact admin label strings ("automatic check") and German report wording are presentation — grade the **distinguishability** (automatic ≠ admin ≠ report), not the German copy, unless a check names it (do not).
- Sweeper cadence (30 min, first tick 5 min) is implementation. Ticket correctly leaves it open; checks call `run/1` directly.

### 2. Deterministic checks

ExUnit + ConnCase + LiveViewTest. Sweeper disabled in tests (`config :vutuv, :link_spam_check, false`) — call `LinkSpam.run/1` with an explicit `now`. No wall-clock waits.

| ID | Input setup | Observable | Pass condition |
| --- | --- | --- | --- |
| `trap single-lowercase-name` | User attrs: one lowercase name, other empty | `SignupTrap.match/1` | trapped/rejected |
| `trap two-names-preserved` | Distinct first + last | same | not trapped (preservation) |
| `markdown off-site-nofollow` | Profile prose with off-site markdown link and a pasted bare URL | rendered HTML | `rel="ugc nofollow noopener noreferrer"` (or at least ugc nofollow) on those links |
| `markdown on-site-followed` | Relative / same-site link | rendered HTML | **no** nofollow on that link |
| `moderation auto-freezes-new-link-account` | User: inserted now-ish, confirmed, one name, headline with foreign link; call `LinkSpam.run(now)` | user + ledger | frozen (hidden like admin freeze), **not** deleted, login still possible for owner; ledger records the automatic rule |
| `moderation thaw-exempt` | Same user already has an admin-action ledger row (thawed) | `LinkSpam.run/1` | not re-frozen |
| `admin frozen-list-labels-source` | One automatic freeze + one admin freeze | `/admin/accounts/frozen` | the two are labeled distinctly (automatic vs admin) |
| `report includes-auto-freeze-count` | ≥1 automatic freeze | daily report data | count/sample present (assert the number/ids, not German prose) |
| `preservation ordinary-accounts` | Two-name clean account; two-name + headline link; single-name without link | `LinkSpam.run/1` | none of the ordinary accounts frozen |

Fake provider: none. Do **not** score external link checks (Req) — `foreign_link?/1` is a pure HTML/markdown predicate.

### 3. Ambiguity / unfairness

- The single-name trap shape is already in the ticket ("single lowercase word as their only name") — fair. Do not also require trapping uppercase or multi-word single fields unless stated.
- Whether a **two-name** account with a headline link is frozen: reference requires exactly one of first/last name. Ticket says "brand-new accounts that plant a foreign link" in the spam story context (single-name). The reference is narrower. State "accounts with only one name" in the freeze rule or widen the reference. As drafted the ticket could be read as "any new account with a link" — **tighten it**.
- `ugc nofollow noopener noreferrer` vs just `nofollow`: ticket says "stop link juice" — grade at least `nofollow`/`ugc nofollow`; the extra rel tokens are reference detail.
- Freeze visibility semantics ("profile disappears for everybody but owner and admins") is product behaviour worth stating if scored.

### 4. Shortcuts

- Trap + nofollow only; no sweeper/ledger. Fails auto-freeze + admin label + report checks.
- Auto-freeze everything with a link (including old or two-name accounts). Fails `preservation ordinary-accounts`.
- nofollow every link including on-site. Fails `markdown on-site-followed`. Integrity.
- Freeze and delete the account. Fails "not deleted" / login check.
- Label every freeze "admin". Fails `admin frozen-list-labels-source`.
- Re-freeze after thaw. Fails `moderation thaw-exempt`.

### 5. Flakiness / nondeterminism

Medium if mishandled. GenServer sweeper is disabled in tests — keep it that way; graded checks pass `now` explicitly into `run/1` so the lookback window is deterministic. Do not assert on `NaiveDateTime.utc_now` side effects. Sandbox ownership: sweeper must not run in tests (reference documents this). LiveView admin tests are synchronous.

### 6. Coverage mix

- Positive: trap catches new shape; off-site nofollow; auto-freeze works; admin sees source; report counts.
- Negative: on-site links followed; ordinary accounts untouched; thawed not re-frozen.
- Preservation: two-name signup; manual admin freeze / report freeze labels; posts keep followed links; size/rate limits unchanged.
- Mixed population in one `run/1` call: clean two-name, single-name clean, single-name+link, two-name+link, already-thawed single-name+link — one pass, exact freeze set.

### 7. Environment risk

- **MIT** — lightest of this batch. PostgreSQL required (test alias migrates). Phoenix/LiveView/Ecto, Elixir `~> 1.20`.
- Req present — keep link verification offline; grade pure `foreign_link?/1`.
- Gettext churn (5 locale files) is mechanical — out of graded diff.
- **Exposure:** PR body states "An AI agent wrote this text in my name" — record as exposure metadata (same policy as #2365/#2373). Does not exclude, but do not treat the PR prose as independent product review.
- Asset/Node needs: confirm focused tests are asset-free.
- **Not verified:** compilation, green base suite, offline dep cache.

### 8. Verdict

**READY-WITH-FIX** — best multi-layer security story of the pass with a real trap→markdown→moderation→admin chain, but the freeze rule shape (single-name + lookback) is under-specified in the ticket and the file count (~10) is above the 2–5 preference.

### 9. Must-fix list

1. Tighten the ticket: auto-freeze applies to **single-name**, registered **within the last day**, headline with a **foreign** link/address; thaw exempts.
2. Grade ledger fields and distinguishability, not German report/email wording.
3. One mixed `run/1` population test; pass `now` explicitly.
4. Incomplete controls: trap+nofollow only; freeze labeled as admin; nofollow overreach; delete instead of freeze.
5. Record AI-written PR prose as exposure; prove vutuv fixture (companion to #2365/#2373).

| Verdict | Top risk |
| --- | --- |
| **READY-WITH-FIX** | Freeze-rule shape under-specified + large multi-layer file count |
