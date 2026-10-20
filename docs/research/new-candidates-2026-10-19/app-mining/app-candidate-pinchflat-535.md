# Pinchflat #535 — Token-protect OPML feed route

**Status:** discovered  
**Source type:** historical PR (security hardening)  
**Project:** [kieraneglin/pinchflat](https://github.com/kieraneglin/pinchflat)  
**PR:** [#535](https://github.com/kieraneglin/pinchflat/pull/535)  
**Source revisions:** base `246ca3b299612746d616644c3cf61cb4b2a0aba4` → merge `f51b219860b33d550cdacada488569cc2b895eb0`  
**Author:** kieraneglin · **Merged:** 2024-12-31  
**Task kind / family:** bug_fix/feature (route security) / plugs + router + settings  
**Research date:** 2026-10-19  
**License:** AGPL-3.0

## Why it is a good case

If `expose_feed_endpoints` is on, the OPML URL was guessable from the instance URL alone. The fix requires an installation-specific token, wired through settings (generated on migrate), plugs, router pipelines, and the UI that copies OPML URLs. Cross-component security behavior with deterministic ConnCase tests. Clear fail states (wrong/missing token) and interaction with basic auth / expose_feed_endpoints.

## Implementation file roles

| File | Role |
| --- | --- |
| `lib/pinchflat_web/plugs.ex` | New module: `maybe_basic_auth/2`, `basic_auth/2`, `token_protected_route/2`, `allow_iframe_embed/2`. |
| `lib/pinchflat_web/router.ex` | Pipeline `[:maybe_basic_auth, :token_protected_route]` on OPML route. |
| `lib/pinchflat_web/endpoint.ex` | Related plug note/fix for XML extension handling (same PR; inspect carefully — Phoenix quirk mentioned). |
| `lib/pinchflat/settings/setting.ex` | `route_token` field. |
| `priv/repo/migrations/20241230192618_add_route_token_to_settings.exs` | Add token column; `gen_random_uuid()` up; reversible stub down. |
| `lib/pinchflat_web/controllers/sources/source_html.ex` + index/actions templates | Build OPML URLs with `route_token` query param. |

Tests: `plugs_test.exs`, `podcast_controller_test.exs`, `routing_test.exs`.

**Counts:** 5–6 implementation files (plugs, router, endpoint, settings, migration, HTML helpers/templates), tests separate.

## Cross-component behavior to verify

- OPML route without token (or wrong token) is rejected even when feeds are exposed.
- Correct token succeeds when `expose_feed_endpoints` is true; when false, token **and** basic auth apply per stated rules.
- UI “copy OPML” includes the token; no user setup required (auto-generated).
- Existing feed endpoints’ expose/basic-auth behavior is preserved.

## Draft ticket (clarified implementation brief)

> Anyone who knows my Pinchflat URL can fetch the OPML export when feed endpoints are exposed. Require an installation-specific secret in the OPML URL in all cases, auto-generate it, and include it when the app copies the OPML link. When feed endpoints are not exposed, keep requiring HTTP basic auth in addition. Keep podcast RSS behavior unchanged aside from this protection. Fix it.

## Proposed named acceptance checks

1. `opml rejects-missing-token`
2. `opml rejects-wrong-token`
3. `opml allows-correct-token` (with expose on)
4. `opml requires-basic-auth-when-not-exposed` (plus token)
5. `copy-opml-url includes-token`
6. **Preservation:** non-token RSS routes behave as before when exposed.

## Plausible incomplete + integrity control

- **Incomplete:** add plug but forget UI URL builder (copy link broken).
- **Integrity:** reject patches that accept any non-empty token, or that disable basic auth when feeds are unexposed.

## Preservation

Existing podcast/source feed tests.

## Runtime / offline holds

- ConnCase + SQLite settings; no external network.
- Token generation uses DB `gen_random_uuid()` — confirm SQLite supports this in their migrations (PR notes a Phoenix bug workaround in endpoint).
- Security framing is real; avoid “security theater” checks that only look at code shape.

## Status: discovered

Good security/plug family candidate; slightly more product rules than #485.

## Next action

Draft after confirming SQLite `gen_random_uuid()` migration runs in test. Keep token equality checks timing-safe only if upstream tests demand it (do not invent extra crypto requirements).
