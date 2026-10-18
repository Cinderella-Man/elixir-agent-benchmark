# Frozen eleven-case inputs and repeatability

This package binds the case content, executable qualification, environment, Pi input and intended strong-model validation policy. Read `evidence.json` for the recorded result and `validation-plan.json` for account-access status. Fixture qualification and two blind model successes are separate gates.

## Contents

- `release.json`: the ordinary benchmark release identity, inventory, case-file checksums, Pi package/lock identity and runner implementation hash. Exact case bodies are versioned under `cases/`; the local store also retains immutable copies under this release ID.
- `inputs/*.json`: each exact ticket, appended instructions, actual initial Responses payload and tool definitions captured from pinned Pi in its pristine workspace. Also includes the agent image, runtime facts and dependency-lock checksums. Requests were intercepted locally before provider access; these are not model attempts.
- `qualification-outcomes.json`: every named test state, exclusion, failure phase/type and regression-coverage decision for all four controls, with raw logs removed. All three rounds must match this record.
- `evidence.json`: three-round receipts, runtime/source/image identities, effective resource limits, artifact checksums and remaining validation limits. Routine durations are omitted; this is functional evidence only.
- `validation-plan.json`: the selected model target, reasoning setting, effective token policy and fixed two-attempt policy. The connected account catalog includes GPT-6-Astra, and one completed response established current inference eligibility; see `inference-check.json`. This is not a case attempt.

The captured Responses payload also includes Pi's `prompt_cache_key`, a fresh session identifier used for cache affinity. The offline capture's value is retained faithfully; future attempts generate their own values. Prompt text and tool schemas are stable; byte-identical complete network requests or cache behavior are not claimed.

The stable ticket path is `/tmp/eab-ticket.md`. Pi's private configuration directory remains unique per process. Each benchmark workspace runs one Pi process and has its own temporary filesystem. The regression test in `test/eab/pi_test.exs` launches two fresh real Pi processes and compares their initial prompts and tool schemas.

The prompt-path repair and a dashboard provider chooser follow qualification. They change the runner release identity (and the bridge changes the agent image), but no fixture, grading input, grader implementation or qualification runtime. The exporter checks that only the bridge and dashboard implementation differ and verifies each of the three qualification identities against the final checkout. No model results from the earlier release carry over.

## Verify the freeze

Run from the repository root in the configured Elixir tooling environment:

```sh
MIX_ENV=test mix run --no-start verification/frozen-cases-2026-10-15/verify.exs
```

This performs identity/evidence checks only. `MIX_ENV=test` avoids the controller's runtime initialization of a data directory and session secret; the application is not started. It fails after any relevant case, runner, Pi, recorded input or plan change. Treat such changes as a new version; keep this package and prior runs with their original meaning.

## Reproduce functional checks

Use a new isolated data directory whose path contains `case-freeze-2026-10-15`. Do not use the dashboard's data volume. Optionally seed only prepared `cache/`, `sources/`, `build-seeds/` and `runtimes/` from a compatible local preparation. Never copy credentials, controller runs, leases, controls or qualification receipts. Verify prepared images are still available; rebuilding an image changes environment identity and requires fresh qualification.

The tooling image comes from the repository Dockerfile (`docker buildx build --load --target tooling -t eab-tooling:dev .`). The recorded image ID identifies this audit; rebuilding may produce a new environment that needs fresh qualification.

Use the bounded tooling wrapper, replacing the final script name as needed:

```sh
docker run --rm --cpus=2 --memory=4g \
  --user "$(id -u):$(id -g)" \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex -e ERL_FLAGS='+S 2:2' \
  -e EAB_DATA_DIR=/app/.local/case-freeze-2026-10-15/runtime-data \
  -v "$PWD:/app" -v /var/run/docker.sock:/var/run/docker.sock \
  -w /app eab-tooling:dev \
  mix run --no-start verification/frozen-cases-2026-10-15/repeat.exs
```

`repeat.exs` refuses to overwrite existing evidence. It runs the ordinary `Qualification.run` three times, one case/preparation worker at a time. After each complete round it archives controls and qualification receipts, so the next round must execute all four controls again. It compares individual test outcomes rather than just aggregate pass counts. A failed round or disagreement stops the process and remains recorded; there is no retry-until-pass loop. The ExUnit order seed is `0` in all three rounds. This checks repeatability at one fixed seed, not all possible schedules or orders.

After successful repeatability, `capture.exs` attaches the pinned Pi image and records the real initial request for each case, one at a time. It compiles the existing `Eab.Agent` source under a different module name, changing only the `Pi.run` call to the local capture function. Production prompt construction therefore runs unchanged. The capture stops before submission/checkpointing, executes no solver tools, and sends no request to a provider. It is an inspection harness, not an alternate solver.

The one-off exporter was retired on 2026-10-18; its source remains in Git history. The exported evidence and historical checksums remain unchanged. The original export validated `.local/case-freeze-2026-10-15/pre-prompt-fix.json`, which records the implementation before the prompt-path repair. Do not fabricate it for later reproductions; publish a new dated record for a later audit.

## Before blind validation

The benchmark's own ChatGPT account was connected on 2026-10-15. Its catalog includes `gpt-6-astra`; a single request through the production subscription transport completed successfully (HTTP 200, 11 input tokens, 5 output tokens). The public receipt contains no account identifiers or credentials. This checks present inference eligibility only. Use the same resolved model and frozen settings for two fresh ordinary Pi attempts per case, retain every failure/interruption, and review successful patches. A resume is not another fresh attempt.

The subscription policy is a 262,144-generated-token **soft threshold**, checked between complete responses and including reasoning in the provider's output usage. A final response may exceed the remaining threshold. Context and per-response limits are provider-enforced; no fixed capacity, sampling seed or serving revision is asserted. Reasoning is `high`; compaction and automatic Pi retries are disabled. Local-model hard budgets are a different policy and must be recorded separately for later comparisons.

Qualification uses one preparation worker and lookahead 1. The deployed controller uses the existing defaults of two preparation workers and lookahead 4; solver attempts remain sequential. These are recorded separately in the evidence and validation plan.

The host clock remains live. Image identities and observed locale/timezone are recorded, but three successful repetitions do not prove absence of flakiness or complete test coverage. These public historical cases may have appeared in model training.
