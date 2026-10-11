# Pilot protocol

This is the first runnable slice of the user's Elixir-focused benchmark. The user authorized implementation after accepting eight foundational decisions. The larger design remains quality-first: identical agent tools and instructions, realistic existing-project work, independent acceptance checks, and broader coverage through new cases.

This document describes the original four-case pilot. The subsequent [Plausible integration](plausible-integration.md) adds six cases to the unified benchmark and extends the shared grader to execute new test files, protect pass/exclusion states and assess fail-before/pass-after coverage where required. Historical model verdicts remain tied to their original evaluator; new fixture controls do not silently regrade old model attempts.

## Cases

| Case | Existing project | Work exercised | Hidden tests |
| --- | --- | --- | ---: |
| `core-nimble-normalization` | NimbleOptions | Investigate lost defaults and custom conversions in nested Elixir data | 6 |
| `core-genstage-cancelled-demand` | GenStage | Repair cancellation/backpressure behavior across real producer and consumer processes | 4 |
| `web-settings-validation` | LiveBeats | Restore Ecto validation and LiveView error/correction behavior | 4 |
| `web-playlist-isolation` | LiveBeats | Repair owner-scoped queries and forged reorder handling | 4 |

These are deliberately introduced regressions in pinned upstream source. They are not claims about historical upstream bugs. LiveBeats is a historical public demo application, not a representative current production application. The core projects are real libraries. The pilot uses conceptual inspiration from the supplied task collection without copying its published prompts, solutions or test bundles.

## Attempt contract

Each attempt receives a fresh bugged checkout with a single initial Git commit, the ticket, shell/file/test tools, local project/dependency documentation and a deterministic clarification tool. The original upstream Git history, reference patch, hidden tests, model API credentials, host filesystem and Docker socket are unavailable to the agent. Internet access is disabled. Web-case PostgreSQL runs in a private network namespace with no external interface; the agent container shares only that namespace.

The common agent uses OpenAI-compatible native tool calls. It can execute `bash`, request a clarification by topic, and `submit`. Each command starts in `/workspace`; shell state does not persist. The pilot sets temperature 0.6, top-p 0.95, seed 101, explicit `xhigh` reasoning with thinking enabled, at most 32 model calls and 65,536 server-reported completion tokens, with at most 8,192 per response. Budgets are enforced by the host controller. A server ignoring these settings must be identified before stronger comparative claims; raw requests, response usage and server properties are retained.

The first diagnostic campaign used generic `high` and exposed a template rejection before inference on the 27B endpoints. Those errors are retained in the optional evidence export, including `results/diagnostics/api-tool-repro.json`; the corrected campaign explicitly uses the supported `xhigh` value.

The first runs use already available Coder390, Swift 1.5 and Flash-Next endpoints. This is a harness compatibility sample, not the final quality shortlist. Exact model artifact pins are in `config/candidates.json`; runtime properties are captured per attempt. Unsupported seed behavior or backend reasoning-token accounting must not be silently treated as identical sampling semantics.

Existing endpoint context sizes are retained and differ; the pilot does not compact history. Coder390's OTP attempt reached its 65,536-token window after 30 calls and ended with an explicit context error. This is an incomplete attempt with a preserved partial patch, not proof of a weaker model. A comparative campaign needs a common declared context budget and compaction policy, with a separate track for testing larger usable windows.

## Acceptance and integrity

The final patch is replayed onto a fresh copy of the same bugged image, with a fresh database where needed. The declared regression command first runs against the submitted workspace, including the agent's changes to tracked tests. Then tracked original tests are restored, hidden tests are introduced only for grading, and the hidden suite and original regression suite run separately. The agent's submitted tests cannot replace the original test identities. Declared source/test/migration edit areas are accepted, along with new, non-hidden top-level diagnostic files ending in `.ex`, `.exs`, `.md`, `.txt` or `.json`. This exception permits normal reproduction scripts without permitting changes to existing build configuration. The pilot disallows symlink patches and patches above one MiB.

The original grader rejected such diagnostic scripts before executing the tests. That was an evaluator defect, not evidence of a bad repair. `scripts/regrade.py` assesses all completed saved patches under the corrected rule and preserves the original verdict; it never regenerates a model answer.

A second correction adds the submitted-workspace regression check: restoring original tests alone could conceal broken tests that an agent added to a tracked file. Every completed frozen patch is assessed under this correction too. Earlier regrades are archived under their controller hash. Web cases use the declared relevant regression files, so this remains bounded regression coverage rather than a proof about all application behavior.

The GenStage upstream test `producer callbacks handle_cancel/3 on consumer down` exhibited a reference-control race: its callback notification arrives before the producer installs the monitor, allowing the test to kill the consumer too early and observe `:noproc` instead of `:killed`. The grader inserts `:sys.get_state(producer)` as a barrier before the kill, both in submitted and restored tests. It retains the original assertion and all test identities. The failed reference control is preserved in `results/controls-history/genstage-upstream-monitor-race.json`. This adaptation changes grading synchronization, not the candidate's saved patch or agent-visible workspace.

Success requires all three checks to pass, evidence that the suites finished, the expected number of hidden tests and all protected test identities from the reference controls. A zero exit status with no executed tests is a failure. The formatter and restored tests are controlled by the evaluator. This protects ordinary grading integrity; it is not a proof against every deliberately adversarial program capable of introspecting its own BEAM test process.

Before any model attempt, each fixture must attest that its broken start fails, its reference repair passes, and an explicit `System.halt(0)` bypass does not pass. The attestation is tied to the image, fixture files, controller and formatter hashes. Changed fixtures or harnesses require new controls. All grading, including controls, runs on the authorized rig.

Tool output is bounded while being drained, commands have hang watchdogs, and submitted patches survive ordinary model/API errors when capture remains possible. Errors, exhausted budgets and incomplete attempts remain explicit. A partial artifact is retained but does not silently become a completed successful attempt.

## Reporting

Publish a case-by-candidate matrix with raw pass/fail/error status and links to trajectories, patches and verifier output. These four cases share only three source projects and a single attempt per model is not a stable success-rate estimate. Do not turn this pilot into a percentage leaderboard, compare it to SWE-bench, or choose a deployment winner from it. No throughput or latency score is computed. ExUnit diagnostics may contain their own elapsed-time lines; those are not performance evidence or selection inputs.
