# Web pilot fixture review

Two curated regression cases use the real, MIT-licensed [LiveBeats application](https://github.com/fly-apps/live_beats/tree/712204ca172ed6d36456c8ed4fd6aaba50099447), pinned to **`712204ca172ed6d36456c8ed4fd6aaba50099447`** (2023-03-06). LiveBeats is a music-sharing demo, not a production customer repository. The defects below are deliberately introduced for this benchmark; they are not claims about upstream bug reports.

The historical app pin keeps the pilot small: it predates the later Bumblebee/EXLA/Whisper startup and its model downloads. Current upstream head was inspected and rejected for this pilot's dependency footprint. The proposed runtime is `elixir:1.14.5-otp-25`; the app's committed lockfile resolves Phoenix 1.7.1, LiveView 0.18.17 and Ecto 3.9.1. The original application and dependencies are retained. [Mix project](https://github.com/fly-apps/live_beats/blob/712204ca172ed6d36456c8ed4fd6aaba50099447/mix.exs), [lockfile](https://github.com/fly-apps/live_beats/blob/712204ca172ed6d36456c8ed4fd6aaba50099447/mix.lock), [upstream license](https://github.com/fly-apps/live_beats/blob/712204ca172ed6d36456c8ed4fd6aaba50099447/LICENSE.md)

| Case | Injected defect | Independent grading coverage |
|---|---|---|
| [`web-settings-validation`](../cases/web-settings-validation/case.json) | Drops required tagline validation in the Ecto changeset and stops marking LiveView validation changesets for error display. | Context rejects empty tagline without persistence; change event displays errors; invalid submission can be corrected in the same LiveView; duplicate username rejection and valid updates remain functional. |
| [`web-playlist-isolation`](../cases/web-playlist-isolation/case.json) | Drops owner filtering from the playlist query and owner authorization from drag handling. | Owner-scoped listing/order/limit and empty profile; rendered LiveView content; forged cross-user reorder leaves both playlists intact; legitimate reorder works and stale old positions are rejected. |

These are actual Phoenix.LiveViewTest sessions with real Ecto/PostgreSQL state, not substituted modules or a mock application. They exercise controller/session authentication, application contexts, database queries and event handling. Upstream fixtures supply users/songs and Ecto SQL Sandbox provides test isolation. No audio upload, OAuth network request, Node installation or browser asset compilation is required by the new hidden tests.

## Files and application order

Each case contains `case.json`, `ticket.md`, `starter.patch`, `reference.patch`, and `hidden_test.exs`.

1. Obtain the exact repository revision and its locked dependencies during the preparation phase.
2. Apply `starter.patch` to that revision. It changes only the two relevant application source files; no setup/configuration change is mixed into the defect.
3. Give the agent the resulting sanitized application checkout and ticket. The case directory, original Git history, reference patch and hidden test file must stay outside its accessible workspace.
4. Capture candidate edits. Reapply them to a clean starter checkout, restore immutable grader/support files, and inject `hidden_test.exs` at `test/benchmark_hidden_test.exs`.
5. Run the case's existing-test regression command and `mix test test/benchmark_hidden_test.exs`. The reference patch applies **after** the starter patch and restores the original behavior.

The hidden tests were authored for these scenarios after source inspection. They assert persisted outcomes and LiveView behavior without matching a particular patch or AST. Because the reference implementation is public, these small cases establish an end-to-end pilot, not an uncontaminated model ranking or a broad estimate of Elixir ability. Both belong to the same source application; preserve their scenario-family labels but do not count the application twice when reporting repository diversity.

## Environment requirements

- The runtime declaration includes a PostgreSQL 16 Alpine sidecar with the upstream test credentials (`postgres`/`postgres`). The application expects `localhost`; a shared network namespace with the sidecar makes that reachable while blocking external network access during agent execution. `PGHOST=127.0.0.1` is documented in metadata, although this older application uses its literal test hostname.
- Each fresh test environment must create and migrate `live_beats_test` before use. `runtime.before_test_commands` declares both operations. The existing `mix test` alias also creates/migrates the database.
- Preparation installs Hex/Rebar and obtains/compiles pinned Mix dependencies. Execution needs the already prepared dependency/build caches; it must not fetch packages or model weights.
- Retain both Repo and ReplicaRepo startup configuration. Test configuration selects the primary Repo for reads, so the hidden assertions see transactional fixture writes.
- The case metadata names allowed source, test and migration edit prefixes. Grader tests and existing regression coverage must be protected independently of those authoring permissions.

## Validation status

Subsequent rig validation completed for both cases against real PostgreSQL and LiveView sessions: the broken state fails, the reference passes hidden and original suites, and an early-exit bypass is rejected. See the [executed controls and model attempts](pilot-results.md). The paragraph below records the earlier authoring checkpoint.

At authoring, source revisions, dependency declarations, patch substitutions and fixture files were inspected. No application compilation or test execution was performed on the shared workstation. Remote runner validation on authorized `ratx570` must establish: unmodified starter fails the new tests; the reference passes both hidden and existing checks; repeated runs are stable; and a candidate cannot alter grading inputs. Runtime or infrastructure failures must not be scored as model failures. The orchestration record owns the subsequent executed outcomes.
