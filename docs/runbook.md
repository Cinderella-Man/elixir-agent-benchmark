# Running and extending the benchmark

Run commands from this directory on the authorized `ratx570` rig. The working installation is `/srv/elixir-agent-benchmark`. Python 3.12+, Docker, Git, SSH and HTTPS access for source/image preparation are required. Elixir and PostgreSQL run inside pinned containers, not on the host.

The Plausible integration is staged separately at `/srv/elixir-agent-benchmark/plausible-expansion`. Its six historical cases additionally use Node during preparation and ClickHouse during tests. See the [integration protocol](plausible-integration.md) and recorded image pins. No benchmark or performance test runs on the shared workstation.

## Prepare

Place the model endpoint credential in `.local/api-key` with mode 0600. Edit `config/candidates.json` to describe the intended endpoints and their artifact identities; never commit the credential. The current pilot uses the existing rig services without changing their configuration.

The current adapter requires OpenAI-style chat completions and model listing plus the serving stack's `/props` route for metadata. A different runtime needs an explicit metadata adapter before entering a campaign. The pilot is not yet a general client for every OpenAI-compatible server.

```bash
python3 scripts/benchmark.py init
python3 scripts/benchmark.py prepare --case core-nimble-normalization
python3 scripts/benchmark.py controls --case core-nimble-normalization --out .local/results/controls/core-nimble-normalization.json
```

Repeat preparation and controls for the other case IDs from the protocol. Preparation downloads the pinned source revision and required runtime/dependencies, then records immutable image IDs, base/service image digests, source archive hashes and fixture hashes beneath `.local/runtimes/`. It builds only the bugged source into the agent image; reference patches and hidden graders are excluded. The first build resolves dependency packages into that image; keep its runtime record and image when reproducing a campaign.

Alternatively, `python3 scripts/qualify_suite.py --suite plausible --prepare` prepares and checks all six historical cases without model calls. Use `--suite pilot` for the original four. On prepared images, `--refresh` permits grader/ticket updates only when source, runtime and service inputs still match; rerun controls afterward. These controls also reject each Plausible case's specified incomplete repair. They do not establish model context feasibility.

Model runs require a successful, current control attestation. Initialization records the existing power service and GPU cap state; it cannot alter them. Do not reinitialize to accept an unexplained change.

After all four controls are valid, `python3 scripts/check_partial_repairs.py` verifies seven deliberately incomplete repairs are rejected. It runs only on the rig and writes `results/partial-repair-controls.json`. The pilot has executed this check successfully; it supplements broken/reference/early-exit controls with evidence that fixing only one part of a ticket is insufficient.

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

For a complete fixed matrix, the suite driver uses one sequential queue per candidate endpoint:

```bash
python3 scripts/run_suite.py --campaign my-first-matrix --seeds 101
python3 scripts/report.py --campaign my-first-matrix
```

The default suite is `pilot`. Select `--suite plausible` explicitly for its six cases, or provide an explicit `--cases` list. `--max-calls` and `--max-tokens` expose the action and cumulative completion allowances; neither selects a context-window size. The report shows only cases selected or attempted in the requested campaigns, including regression-coverage outcomes when required.

The second command exports selected evidence into `results/my-first-matrix` and writes `results/reports/pilot-results.md`. Everything under `results/` is ignored by Git. The command redacts the local endpoint key if it appears in an artifact. For later repeated campaigns, pass `--seeds 101 202 303`; every attempt remains separate. Use a new campaign ID for each matrix. The initial manually launched diagnostic campaigns are retained separately.

To show multiple campaigns without hiding earlier failures, use `python3 scripts/report.py --campaign pilot-v1 pilot-v2`. Each table entry names its campaign; the request-profile table exposes differences in reasoning settings. Use `--document another-report.md` to preserve a separate report under `results/reports/`. The reviewed summary in `docs/pilot-results.md` is maintained separately and is never overwritten by the exporter. After a documented evaluator correction, `python3 scripts/regrade.py --campaign pilot-v2` grades every completed frozen patch under current validated controls and keeps its original verdict. It does not generate replacement answers.

## Add a case

Create a `cases/<id>/` directory matching an existing manifest. Required files are `case.json`, `ticket.md`, `starter.patch`, `reference.patch` and either `hidden_test.exs` or a declared `acceptance_patch` with `acceptance_command`. Pin an upstream repository revision and compatible runtime; preserve the upstream license and attribution. The starter patch applies to upstream; the reference patch applies after the starter. Historical cases use an empty starter patch at the actual broken commit. `environment.patch` is optional for task-neutral compatibility fixes and must remain separate from model changes. An optional `reference-tests.patch` demonstrates a valid regression-coverage submission. Add the case to an explicit suite in `config/suites.json`.

Provide an explicit original regression command and allowed edit areas. Design hidden checks against the ticket's observable contract; do not require a private implementation trick. Clarification topics have fixed answers for all candidates. New cases need source review, reference/broken/early-exit controls, review of plausible incomplete fixes, and a stability check under the intended environment before entering a scored campaign.

`System.halt(0)` control failures and missing ExUnit markers must remain failures. The marker parser expects one completed suite per grader invocation. Unsupported test aliases, intentionally skipped tests and external-service requirements need an explicit fixture adaptation, not a blanket pass rule.

With `require_regression_test`, changed/new test files execute on the repaired submission and separately on broken source. A completed failure in a test body must become a pass after repair; compile or setup failures are rejected as coverage evidence. Original tests are restored before acceptance and protected checks. CE exclusions must be declared, and protected pass/exclusion identities must match reference controls.

## Data boundaries

`.local/` contains private credentials, downloaded source, build logs, images' metadata and attempt artifacts. `results/` contains generated evidence exports and reports. Both directories are ignored and optional for a source checkout. Track the harness, case fixtures, configuration, licenses and reviewed documentation. Export selected credential-free evidence as a separate release asset or artifact archive; do not blindly publish `.local/`. The task source collection remains an external provenance source, not a runtime dependency.
