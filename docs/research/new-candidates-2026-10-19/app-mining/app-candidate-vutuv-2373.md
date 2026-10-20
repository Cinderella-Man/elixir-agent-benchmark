# App candidate — vutuv PR #2373 (visitors see every expired credential)

**Status:** screened (source-inspected; no build/test/qualification executed)
**Research date:** 2026-10-19
**Source type:** historical PR (member-reported visibility defect)
**Project:** [wintermeyer/vutuv](https://github.com/wintermeyer/vutuv)

---

## 1. Identity

| Field | Value |
| --- | --- |
| PR URL | https://github.com/wintermeyer/vutuv/pull/2373 |
| Title | Visitors see every expired credential, same-named ones too |
| Author | **wintermeyer** (maintainer) |
| Branch | `fix-renewed-qualifications-hidden` |
| Created | 2026-10-19T09:47:46Z |
| Merged / closed | 2026-10-19T10:03:39Z |
| Merge commit SHA | `d45e22c70fbfd6e34ba12811f12c7b7a85d22fed` |
| **Base SHA (parent of merge)** | `8c83df2ffc60aca41cc409fcaa6828b613c4e02d` |
| Diff | https://github.com/wintermeyer/vutuv/pull/2373.diff |
| Related | Follow-on to earlier same-surface work (#2372); the PR body cites a member with two “CCNA Routing and Switching” periods (2001 and 2009) — older one vanished when logged out. |
| Commits | 1 |
| Tooling note | PR body explicitly states: “An AI agent wrote this text in my name.” Record as provenance/exposure metadata. Code + tests remain the behavioral evidence. |

License at base: **MIT** (Copyright (c) 2016). Mix at base: Elixir `~> 1.20`, Phoenix 1.8, LiveView, Ecto/PostgreSQL, Req.

---

## 2. Ticket (shortest sufficient, maintenance-report shape)

> When I am logged out I see fewer of my expired certificates than when I am logged in — specifically, an older expired credential disappears if I later earned another credential with the same name. Visitors should see the same credential list the owner sees, including expired ones and including two entries that share a name. Keep showing expired entries under a “previously held” style group, and keep search/JSON-LD from claiming expired credentials are currently held. Fix it.

**Clarifiers if needed for fair grading:**

- Two same-named periods stay two rows (do not merge/dedupe by name across expiry periods).
- Ordering remains valid-first, then most recently awarded.
- Agent/docs and CV surfaces must not disagree with the profile page.

Do **not** name `visible_to/2`, `valid_first/1`, or `split_expired/1` in the solver ticket.

---

## 3. File roles (substantive implementation)

| Path | Role |
| --- | --- |
| `lib/vutuv/profiles/qualification.ex` | Removes the visitor-only renewal-hiding scope `visible_to/2` (and its SQL “exists later same-name” rule). Keeps `expired?/2`, `expired_dynamic/0`, `valid_first/1`, `ordered/1`. |
| `lib/vutuv_web/live/user_profile_live.ex` | Profile preload no longer takes `owner?` for qualifications; card still folds expired under “Previously held”; JSON-LD still only lists valid credentials. |
| `lib/vutuv_web/controllers/qualification_controller.ex` | Public section page reads `valid_first |> ordered` for everyone (was `visible_to(false) …`). |
| `lib/vutuv_web/cv/cv.ex` | CV qualification list uses the same unfiltered ordered query; expired entries labeled. |
| `lib/vutuv_web/agent_docs/profile_doc.ex` | Agent/docs qualification list: all entries, valid first, expired flagged. |
| `lib/vutuv_web/templates/qualification/manage.html.heex` | Owner manage template aligned with the split_expired presentation. |

**Cross-component behavior:** one visibility policy must hold on profile card, public qualifications page, CV export, and agent docs simultaneously. A partial change that updates only the controller leaves CV/docs still hiding renewals — exactly the reported symptom on another surface.

### Test / docs / generated (separate counts)

| Kind | Paths |
| --- | --- |
| Test (2) | `test/vutuv/profiles/qualification_test.exs` (removes old `visible_to/2` tests; keeps ordering/expired tests), `test/vutuv_web/controllers/qualification_controller_test.exs` |
| Docs (1, mechanical) | `docs/architecture/profiles.md` |

**Note on file count:** six implementation paths is slightly above the preferred 2–5. The group is one visibility policy across presentation surfaces, not independent copies of a string. Acceptable as a deliberately coherent larger task; do not inflate further.

---

## 4. Named checks (curator proposal, not executed)

| ID | Observable obligation |
| --- | --- |
| D1 | Visitor and owner see the **same** qualification rows, including multiple expired same-named periods (e.g. two “CCNA …” entries). |
| D2 | Expired entries still appear under the previously-held grouping on the profile card / section page (not dropped, not mixed into “current”). |
| D3 | CV shows expired credentials (with expiry labeling) rather than omitting them. |
| D4 | Agent docs list expired entries flagged `expired`. |
| D5 | JSON-LD / search metadata names **only** valid (non-expired) credentials. |
| D6 | Ordering: valid first, then most recently awarded. |
| D7 | Owner manage UI still lists all entries with expired badge. |
| D8 | Preservation: non-qualification profile sections, citing-job badges, and ordinary non-expired lists unchanged. |

Upstream tests after the PR cover ordering/expired predicates and controller output; the old `visible_to/2` describe block is deleted. D1/D2 need mixed same-name populations in fixture data — the deleted tests are the best source of those shapes.

---

## 5. Incomplete / integrity controls

**Plausible incomplete (compiling):** delete `visible_to/2` from the controller path only (public page shows all), but leave CV and agent docs on a still-hiding query — D3/D4 fail while the reported page looks fixed.

**Second incomplete:** show expired rows everywhere but still collapse same-named renewals in the profile preload — D1 fails.

**Integrity:** standard `System.halt(0)` early-exit; require executed named results including the controller/HTML boundary, not only `Qualification` helper tests.

---

## 6. Preservation

- `expired?/2` vs `expired_dynamic/0` remain in sync (upstream comment requires this).
- JSON-LD continues to omit expired credentials (D5 is positive preservation of search-safety, not part of the bug).
- Owner editor, work-experience citation of lapsed credentials, and non-qualification tabs unchanged.
- Do not “fix” by deleting the expired concept entirely or by merging same-named rows.

---

## 7. Runtime / offline holds

| Hold | Detail |
| --- | --- |
| PostgreSQL | Required; `test` alias runs `ecto.create` + `ecto.migrate`. |
| Phoenix/LiveView | LiveViewTest + lazy_html for DOM assertions. |
| External HTTP | `req` is a dep for link verification etc. Selected qualification/profile tests should not need outbound HTTP; keep verification features offline. |
| Assets | `assets.setup` in aliases; confirm whether test path needs Node/Milkdown or only compiled assets. |
| No BigQuery / ClickHouse / Ash | Lightest runtime in this batch. |

**Not verified:** green base suite, offline dep cache, or LiveView connected-mount determinism. vutuv’s test alias auto-migrates — good for fixtures; still distinguish setup failures from assertion failures.

---

## 8. Status / next action

**Status:** screened — best *diversity* pick in this batch (MIT, plain Phoenix/Ecto, multi-surface consistency, authentic member report). Slightly larger than the 2–5 preference; keep as one coherent task.

**Next action:** pin base `8c83df2f…`, build mixed same-name expired fixtures, qualify unchanged/reference across profile + controller + CV + agent-docs assertions. Record the PR-body AI-writing disclosure in provenance. Independent contract review must decide how strictly to grade JSON-LD (D5) versus the reported bug (D1–D4).
