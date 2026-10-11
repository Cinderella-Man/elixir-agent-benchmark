# Running and extending the benchmark

Use the [README quickstart](../README.md) on a dedicated Linux x86-64 execution host with Python 3.12+, Git and Docker. Python uses only the standard library. The current user must be able to run Docker containers. Source archives, base images, Hex/Rebar and application dependencies need HTTPS during preparation. Host Elixir, Node and databases are unnecessary. Retain enough disk for all sixteen application images, build trees and evidence, plus model weights if served on the same host.

`python3 scripts/benchmark.py init` opts in this checkout on its current host and records NVIDIA GPU identities/power limits when available. Later execution refuses a different host or changed GPU baseline. It never changes power settings. The maintainer's shared `CrosshairA16` workstation remains explicitly prohibited; `ratx570` also retains its stricter existing GPU power-service/hash checks. Other dedicated hosts are supported.

## Model endpoints

Edit `config/candidates.json` to contain the candidates you actually serve. IDs must be unique directory-safe names. Set `base_url` to the server root (without `/v1`), `model` to its API alias, `reasoning_effort` to a supported thinking level, and record model family, quantization and exact artifact revision/file/SHA-256. Each quantization gets its own candidate ID. The three checked-in entries describe the maintainer's deployments; replace their URLs, aliases and build pins for your installation.

- `token_counter: "llama_cpp"` uses `/v1/chat/completions/input_tokens` to count the exact chat template and tools. The tested server advertises build `b1-23b0202`. Use a build with that route, native tool calls, `/props` and `/v1/models`. Allocate at least `--ctx-size 262144` **per slot**, use the intended chat template, and disable automatic context shifting. Set `expected_build` to the value returned by your `/props`, or omit it when establishing a new deployment; the actual profile is still frozen at campaign start.
- `token_counter: "strata_owned_overflow_v1"` is specific to the reviewed Strata 0.1.42 launcher: source `61b3fb5dd3f1e8ec09cf7e4e05208bc6d3c46406`, `fit_max_tokens=False`, no native MCP/resume/prefix, no reasoning recovery/forced wrap-up. It deliberately requests an impossible response allowance and reads the prompt count from the pre-generation HTTP 400. Do not enable it against an arbitrary server that might clamp output and generate instead. This adapter is for the provisioned deployment, not a general Strata installation guide.

All candidates must report at least 262,144 context tokens. The current harness sends `temperature=0.6`, `top_p=0.95`, `top_k=20`, `min_p=0.05`, `repeat_penalty=1.0`, the configured reasoning effort and `enable_thinking=true`. Sampling and tokenizer differences between backends remain recorded candidate properties.

For one shared credential, create `.local/api-key` and set its permissions to 0600. For separate credentials, set each candidate's `api_key_env` to the environment-variable name containing its key. Unauthenticated local endpoints need neither. Credentials are sent only by the host controller; they are absent from agent containers and request JSON artifacts.

`python3 scripts/check_endpoints.py` performs two small, unscored requests per candidate: a bounded forced tool call, then a tool-result round trip with thinking enabled. It verifies prompt and completion accounting and saves records under `.local/endpoint-checks/`. The campaign repeats these checks and preserves them in its receipt. Unknown routes, unsupported reasoning levels, unavailable endpoints or insufficient context stop execution before scored attempts. Use `--candidates <id> ...` for focused setup checks.

## Prepare cases

```bash
python3 scripts/benchmark.py init
python3 scripts/check_endpoints.py
python3 scripts/qualify_suite.py --prepare
```

Preparation downloads exact source revisions and resolves container/dependency inputs, then records immutable image IDs, image digests, source archive hashes and fixture hashes beneath `.local/runtimes/`. Only broken source enters the agent image; the reference repairs and grading overlays stay outside. Preserve runtime records and Docker images to reproduce a campaign exactly: rebuilding may resolve different OS/Hex tooling even though application lockfiles and source revisions are pinned.

Qualification verifies every fixture's broken start, reference repair and early-exit bypass; historical cases also reject a declared incomplete repair. A campaign requires current valid controls for every selected case. After a controller change, run `python3 scripts/qualify_suite.py` to repeat checks using existing images. After grader/ticket-only changes, use `--refresh`. Source, dependency or runtime changes require `--prepare`. `--cases <id> ...` narrows fixture diagnostics. Seven additional original-case probes are available through `python3 scripts/check_partial_repairs.py`.

The maintainer's unified installation is `/srv/elixir-agent-benchmark/plausible-expansion` on `ratx570`. It is independent of the original pilot installation. The Coder390 256k campaign uses a temporary endpoint on GPU 4 / port 8412; its duplicate Swift service is restored after the campaign. This is deployment administration, not work performed by the benchmark runner.

## Run an independent attempt

```bash
python3 scripts/benchmark.py run \
  --case core-nimble-normalization \
  --candidate flash-next \
  --seed 101 \
  --out .local/results/pilot-v1/flash-next/core-nimble-normalization/seed-101
```

The output directory must not exist. It receives the exact requests, responses, transcript, final patch, runtime/fixture identities and grading result. A fresh sandbox is created for each attempt and for grading. The runner removes only its own uniquely named `eab-*` containers; it does not prune existing Docker images, stop unrelated containers or change services.

The command's JSON `status` and `grade.passed` determine the outcome. An API/infrastructure error is recorded explicitly; a shell command returning without an exception is not sufficient evidence of benchmark success. Do not repeatedly rerun only model failures and report the best result.

For a complete fixed matrix, the campaign driver uses one sequential queue per candidate endpoint:

```bash
python3 scripts/run_suite.py --campaign my-first-matrix --seeds 101
python3 scripts/report.py --campaign my-first-matrix
```

The default is every case in `config/benchmark.json`. There is no repository-specific suite switch. An explicit `--cases` list creates a diagnostic subset and does not receive a full-benchmark score. `--max-calls` and `--max-tokens` expose the action and cumulative completion allowances; neither selects a context-window size. The driver validates every selected fixture, checks every endpoint, and freezes candidate snapshots, serving profiles and protocol inputs in `campaign.json`. The report includes the per-case matrix and deterministic scores for complete matrices. `python3 scripts/score.py --campaign my-first-matrix` emits the same scoring data as JSON.

The report command exports selected evidence into `results/my-first-matrix` and writes `results/reports/benchmark-results.md`. Everything under `results/` is ignored by Git. The command redacts the configured endpoint credentials if they appear in an artifact. For later repeated campaigns, pass `--seeds 101 202 303`; every attempt remains separate. Use a new campaign ID for each matrix. The initial manually launched diagnostic campaigns are retained separately.

To show multiple campaigns without hiding earlier failures, use `python3 scripts/report.py --campaign pilot-v1 pilot-v2`. Each table entry names its campaign; the request-profile table exposes differences in reasoning settings. Use `--document another-report.md` to preserve a separate report under `results/reports/`. The reviewed summary in `docs/pilot-results.md` is maintained separately and is never overwritten by the exporter. After a documented evaluator correction, `python3 scripts/regrade.py --campaign pilot-v2` grades every completed frozen patch under current validated controls and keeps its original verdict. It does not generate replacement answers.

## Add a case

Create a `cases/<id>/` directory matching an existing manifest. Required files are `case.json`, `ticket.md`, `starter.patch`, `reference.patch` and either `hidden_test.exs` or a declared `acceptance_patch` with `acceptance_command`. Pin an upstream repository revision and compatible runtime; preserve the upstream license and attribution. The starter patch applies to upstream; the reference patch applies after the starter. Historical cases use an empty starter patch at the actual broken commit. `environment.patch` is optional for task-neutral compatibility fixes and must remain separate from model changes. An optional `reference-tests.patch` demonstrates a valid regression-coverage submission. Add the qualified case to `config/benchmark.json`, changing the inventory version for a released benchmark revision.

Provide an explicit original regression command and allowed edit areas. Design hidden checks against the ticket's observable contract; do not require a private implementation trick. Clarification topics have fixed answers for all candidates. New cases need source review, reference/broken/early-exit controls, review of plausible incomplete fixes, and a stability check under the intended environment before entering a scored campaign.

`System.halt(0)` control failures and missing ExUnit markers must remain failures. The marker parser expects one completed suite per grader invocation. Unsupported test aliases, intentionally skipped tests and external-service requirements need an explicit fixture adaptation, not a blanket pass rule.

With `require_regression_test`, changed/new test files execute on the repaired submission and separately on broken source. A completed failure in a test body must become a pass after repair; compile or setup failures are rejected as coverage evidence. Original tests are restored before acceptance and protected checks. CE exclusions must be declared, and protected pass/exclusion identities must match reference controls.

## Data boundaries

`.local/` contains private credentials, downloaded source, build logs, images' metadata and attempt artifacts. `results/` contains generated evidence exports and reports. Both directories are ignored and optional for a source checkout. Track the harness, case fixtures, configuration, licenses and reviewed documentation. Export selected credential-free evidence as a separate release asset or artifact archive; do not blindly publish `.local/`. The task source collection remains an external provenance source, not a runtime dependency.
