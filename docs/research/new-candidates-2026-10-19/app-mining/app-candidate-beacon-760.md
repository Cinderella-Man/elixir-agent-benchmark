# app-candidate-beacon-760

## Identity

| Field | Value |
| --- | --- |
| URL | https://github.com/BeaconCMS/beacon/pull/760 |
| Title | Add lifecycle stage `:after_unpublish_page` |
| Project | BeaconCMS/beacon |
| Source type | Historical merged PR (bounded lifecycle feature) |
| PR head SHA | `796e289fddde1657b65266961b87db42b5f60247` (1 commit) |
| Parent of first commit (likely base) | `62048af5e2d9ee1ae4e754fce7be3020a1c2396e` |
| Merged at | 2025-02-14T17:45:50Z |
| License | MIT (DockYard, Inc.) |
| Elixir | `~> 1.14` |
| Verification | **Unverified** — diff inspected; tests not executed |

## Why it is a case

Beacon's page lifecycle covers publish/unpublish hooks. A new `:after_unpublish_page` stage must be registered in config, invoked from the unpublish path (including the Content GenServer `unpublish_page` handle_call), and documented/validated like other lifecycle stages.

What must stay consistent:

- Config lifecycle schema/defaults accept and store `:after_unpublish_page` callbacks.
- `Beacon.Lifecycle.Page.after_unpublish_page/1` runs after a successful unpublish and receives the page.
- Existing lifecycle stages (publish etc.) still fire; unpublish still removes publication state.

## Implementation roles

| File | Role |
| --- | --- |
| `lib/beacon/config.ex` | Lifecycle option for `:after_unpublish_page` |
| `lib/beacon/lifecycle/page.ex` | `after_unpublish_page/1` entry point |
| `lib/beacon/content.ex` | Unpublish flow / GenServer `handle_call({:unpublish_page, page}, ...)` invokes the stage |

Tests (separate): `config_test.exs`, `content_test.exs` ("lifecycle after_unpublish_page"), `test_helper.exs` hook.

## Draft ticket

> Host apps need a callback after a page is unpublished (for example to drop caches or notify other systems). Add a lifecycle stage that runs after unpublish completes, wired the same way as the existing page lifecycle stages.

## Named acceptance checks

1. **stage-invoked** — unpublishing a published page invokes the configured `:after_unpublish_page` callback with that page.
2. **after-success-only** — the stage runs only after unpublish succeeds (not on failed/no-op unpublish).
3. **config-accepted** — configuration can register the stage; invalid lifecycle keys still rejected as before.
4. **preservation** — existing publish lifecycle callbacks still run; page remains unpublished in Content.

## Incomplete + integrity control

- **Incomplete:** add config + `Lifecycle.Page.after_unpublish_page/1` but never call it from Content unpublish. Fail **stage-invoked**.
- **Integrity:** unchanged tree fails **stage-invoked**; reference passes. **preservation** blocks removing other lifecycle stages.

## Preservation

- Publish/unpublish data effects unchanged aside from the hook.
- Other lifecycle stages (`:after_publish_page` etc.) keep working.

## Runtime / offline holds

- PostgreSQL only; callbacks are local modules — offline feasible.
- No media/cloud.

## Status

**discovered** — small coherent feature with explicit public API (`:after_unpublish_page`) allowed in the ticket; 3 implementation files.

## Next action

Run `content_test.exs` lifecycle case at base/head; confirm callback arity and error policy if callback raises (defer if unspecified).
