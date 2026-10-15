# ChatGPT subscription provider verification — 2026-10-15

The existing dashboard and Pi runner now support app-owned ChatGPT sign-in and the public OpenAI Responses route. This is provider implementation evidence, not case solvability evidence. No account has been connected and no live OpenAI repair attempt has been made.

## Checks completed

- Formatting and the full default functional test suite pass with warnings treated as errors: **146 passed, 5 Docker-tagged tests excluded**. The suite includes real pinned Pi processes with synthetic model transports for all three providers. The new Responses test executes a workspace write and verifies the next request's complete history, exact call/item IDs, namespace, tool result and encrypted reasoning.
- Authentication tests exercise PKCE, browser-bound state, callback replay/denial, signed JWT verification (issuer, audience, nonce, expiry and signature), stable host/client registration across restart, returning-account identity checks, owner-only storage, serialized rotating refresh, earliest renewal, transient/terminal errors, missing plan permission and revocation.
- Provider tests exercise catalog filtering/order, official-origin enforcement, credential redaction, complete-stream accounting, reasoning included once in output usage, soft-threshold stopping, interrupted/failed streams, direct-admission errors, late quota failure metadata and pausing inference until explicit reconnect. Metadata checks remain available for already submitted repairs.
- LiveView/controller tests exercise sign-in, session-bound callbacks, account model selection, run enablement, sign-out and retaining independent settings when switching between local and subscription providers.
- The production Docker image builds successfully. The idle dashboard was recreated with the updated image; startup reports no cleanup error or active run. Browser inspection verified the subscription connection card, sign-in link, high reasoning default and 262,144-token soft threshold. Existing historical run evidence remains visible.

The functional suite ran in the tooling container with two CPUs and two Erlang schedulers, with networking disabled and the current bridge mounted over the installed bridge. Production compilation uses the existing two-scheduler toolchain. No speed, throughput or latency measurement was performed or inferred from test/build durations.

## Remaining live validation

A user must authorize this app through **Continue with ChatGPT** and select an account-visible model. Successful browser sign-in and catalog access alone do not establish inference eligibility; a completed response is required. Account/workspace/region restrictions and provider changes can still prevent access.

Two fresh ordinary benchmark runs with the same model, settings and frozen cases supply the planned blind solvability evidence. They have not been run here. Fixture qualification and prompt/grader fairness remain separate requirements; the Plausible 6449 ambiguity recorded in the design tree remains unresolved. This change does not admit cases automatically, add new cases or change acceptance checks.

## Source contract

The adapter follows OpenAI's [registration](https://developers.openai.com/siwc/token-sharing-open-source/sign-in), [session/refresh](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions), [models/inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference), [preview restrictions](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations) and [error recovery](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery) documentation, inspected on this date. App credentials are separate from Codex credentials and saved outside the run artifact tree. Local-model strict limits remain separate from subscription soft-threshold policies.
