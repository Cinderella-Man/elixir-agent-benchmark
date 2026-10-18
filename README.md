# Elixir Agent Benchmark

The standalone **Elixir SWE Bench** [results page](results-page/README.md) displays published runs. Click **Add to results page** on a completed full run to export it and rebuild the local page. Push the resulting public JSON file to GitHub to deploy through GitHub Pages.

A local Elixir website that evaluates coding models against historical PR tasks. During the [sequential curation loop](docs/case-curation-loop.md), the nine existing cases are temporarily parked in `cases_approved/`. Only case folders inside `cases/` are run. Moving folders back into `cases/` restores them automatically, with no inventory or configuration edits.

The application prepares Docker images, checks the fixtures, runs the [Pi coding agent](https://github.com/earendil-works/pi) in isolated Docker workspaces, and grades its repairs with executable tests. There is no AI judge or speed score.

## Start

Use Linux x86-64 with **Docker Engine and Docker Compose**. Elixir/OTP, Pi, its Node runtime, Git, build tools, PostgreSQL and ClickHouse are provided by containers. Serve the model separately; the application does not download, start or switch models.

From this checkout:

```sh
docker compose up --build -d
```

Open [http://localhost:4000](http://localhost:4000). Enter the server root, for example `http://localhost:8080`, and an optional API key. Model details load automatically. Click **Run benchmark**; first preparation downloads project dependencies and fixture images. The website shows each stage, case results and downloadable evidence.

To use your ChatGPT subscription, choose **ChatGPT** under **Model source**, then **Continue with ChatGPT**. Authorize this app in your browser using your usual sign-in method, including Google, and select a model from your account's catalog. The endpoint is configured automatically. The callback uses `127.0.0.1` on the dashboard port. No Platform API key or Codex credential file is needed. Saved account/workspace registrations appear in the connection panel; each keeps its own credentials. [Manage the app's ChatGPT allowance](https://chatgpt.com/settings/usage).

Execution starts only when you click **Run benchmark**. Connecting to an endpoint reads model metadata without generating output.

The website is available only from the computer running it. The model endpoint can be on that computer or another reachable machine. If the server requires an API key, enter it under **Server credentials**.


## Run memory on the model host

The benchmark can sample the served model's VRAM and RAM throughout each run. This is independent of optional performance measurements. On this installation it is configured for **ratx570**, using its existing Tailscale SSH access; it does not start, stop or switch the model.

The [Elixir collector](tools/memory_collector/README.md) requires Linux cgroup v2, a dedicated model service, `ss` and NVIDIA's `nvidia-smi`. Its release includes Erlang/OTP, so the model host does not need Elixir installed. Build and install the release as described in its README, then set these values in the benchmark's ignored `.env` and rebuild/recreate the benchmark container:

```dotenv
EAB_MEMORY_SSH_TARGET=root@ratx570
EAB_MEMORY_HOSTS=ratx570,100.70.151.84
EAB_MEMORY_REMOTE_COLLECTOR=/srv/elixir-agent-benchmark/memory-collector/bin/eab_memory_collector
EAB_MEMORY_REMOTE_KEY_FILE=/srv/model-rig-lab/.local/secrets/api-key
```

Copy the model host's **already verified** SSH public host entry into `/data/memory/known_hosts` in the benchmark volume (mode 600). The SSH client uses strict host verification and no private key or agent; this configuration relies on Tailscale SSH authentication. The remote key-file path refers to the existing model API key **on that host**. Its contents never enter the benchmark or its evidence. `EAB_MEMORY_HOSTS` must list the exact hostnames/IPs used in the model endpoint URL; other hosts and hosted APIs are not sampled. Empty `EAB_MEMORY_SSH_TARGET` disables collection.

Sampling starts before benchmark work and takes a final reading on completion, failure or cancellation. It resolves the local model listener, checks the artifact and configured context, and follows all GPU processes in its dedicated service cgroup. GPU allocations are mapped by physical UUID; unrelated services are excluded. RAM is cgroup `memory.current`, including charged page cache and kernel memory. Process RSS and whole-host RAM are retained separately in the raw observations. Collection never uses the service-lifetime `memory.peak` as a run peak.

Each run saves:

- `memory-samples.jsonl`: timestamped readings at a target one-second interval, with per-GPU allocation, service RAM, process RSS, RAM breakdown and simultaneous RAM + VRAM.
- `memory.json`: session identities, per-GPU and aggregate sampled peaks, sample count and coverage. The combined peak is the maximum observed RAM + VRAM in one sample, not the sum of independent maxima.
- `run.json` and `report.md`: the final summary. The dashboard provides summary and raw-sample downloads.

Initial collector failure prevents a configured run from starting. Later disconnects, process/model changes or sampling gaps greater than 2.5 seconds preserve available readings and mark coverage partial; they do not alter repair scores. Resume appends a separate session, and application restart marks unfinished collection partial. Previously unmeasured parts of a resumed run remain partial. Samples can miss sub-second peaks; configured context capacity does not mean every task filled that context. These are observations of this deployment, not interchangeable VRAM/RAM or a guaranteed minimum hardware specification.

## How it runs

Pi attempts follow the inventory order, with preparation and grading running alongside them:

1. **Prepare:** Missing baselines prepare oldest-PR-first within runtime families, independently of frozen Pi order. The first case may need an earlier seed; exact cached baselines skip that ancestry. Once its attempt starts, two workers prepare/check a four-case lookahead window. Cached artifacts hold the broken project, its Elixir/OTP version, compiled dependencies and initialized databases. Pi is attached separately. Existing artifacts and valid fixture checks are reused; the model is not used during setup.
2. **Repair:** Exactly one Pi attempt runs at a time. Pi is installed in `/opt/pi` and edits the project in `/workspace`, using your model endpoint and the supplied ticket prompt. At most one additional fresh workspace waits for the next attempt, with separate PostgreSQL and ClickHouse containers for Plausible cases.
3. **Grade:** The application saves Pi's patch and grades it in fresh containers while the next Pi attempt runs. There is one grader and room for one queued submission; if grading falls behind, the next attempt waits. Temporary containers are removed, while results and logs remain in the `benchmark-data` Docker volume.

The case list shows preparation, workspace startup, Pi activity and grading separately. Cache messages explain reuse or rebuilding. A case that is not ready can still cause a wait; inventory order is preserved.

Compatible PRs reuse pristine dependency and compilation artifacts from completed preparation builds. Each revision gets its exact source, with changed dependencies and affected code rebuilt; compilation-setting changes invalidate broader state. Hex/npm downloads are cached separately across builds. Existing case images still skip preparation entirely, and agent or grader changes never enter these caches.

Plausible cases save clean PostgreSQL and ClickHouse snapshots after the original revision's migrations. Both Pi and grading get independent writable copies. Compatible migration histories can seed new baselines; subsequent model runs restore the exact saved state. Service startup still happens, so this is not a promise of zero wait. Docker images and the persistent controller data must both remain available.

Pi and the project run on the benchmark's Docker host. The model server can run elsewhere. Click a case in **Follow the run** to see its current command, live output and Pi activity.

## Run settings and results

Local-server defaults: the active inventory only, seed 101, unlimited model and tool calls, up to 8,192 tokens per response and 65,536 generated tokens per case. Context is detected automatically and capped at 262,144 tokens. Advanced settings allow explicit overrides within the server's capacity. History is retained without compaction; exhausting either the generation budget or context window submits the current patch for grading.

ChatGPT subscription defaults are a **262,144 generated-token threshold per case** and **high reasoning effort**. Change them under Advanced run settings; available reasoning levels depend on the selected model. The threshold is checked between complete responses, so one response may exceed it. Reasoning tokens count once within output usage. OpenAI enforces context and response limits; no seed, exact prompt preflight or hard response cap is claimed. Full history, Pi tools, workspaces and grading use the same execution flow. Effective policies are saved in results and reports; strict local runs and subscription runs cannot join the same comparison.

For solvability validation, follow the [case-selection and validation guidelines](docs/pr-selection-guidelines.md): review the shortest sufficient task contract, repeat fixture controls three times, then obtain two reviewed **fresh blind successes** with matching frozen inputs, model and settings. Preserve every failure and interruption; explicit infrastructure retries are new attempts, while resume is recovery. Two successes demonstrate feasibility without proving that every later failure is the model's fault. This remains manual curation; the application does not automatically admit cases.

One run is active at a time. Closing the browser does not stop it. **Stop run** cancels execution and cleans up this installation's containers. After interruption, reconnect the same model with the same settings and choose **Resume unfinished cases**. Completed passes, failures and evaluation errors stay fixed; saved submissions resume grading, and unfinished Pi work starts in a fresh workspace with its prior evidence preserved. Changed release, model or settings require a new run. Historical runs without checkpoint receipts cannot resume.

All cases have equal weight. A final score requires a completed pass/fail outcome for every case; errors, cancellations and interrupted work remain visible and prevent a final score. The model's reported identity, effective budgets, requests, responses, patches and controls accompany each run. Missing identity metadata stays explicitly unverified; manual artifact pins are not required.

Each run freezes a checksummed release and experiment identity. Select a case for its acceptance, preservation and submitted-test results, named failures and short error excerpts. Full logs, patches, trajectories and grading output remain downloadable. History and case lists are paginated; reports include project/task breakdowns and interrupted-generation counts.

Under **Retained preparation**, preview removal of one case's cached state or unreferenced artifacts. Shared state and active work are protected; nothing is automatically evicted. Missing builds stop if the data filesystem is below the configured free-space reserve (5 GiB by default). When a run ends, **Download report** saves its summary and per-case results. Data persists in the `benchmark-data` Docker volume.

[Setup, development and troubleshooting](docs/runbook.md) · [Evaluation contract](docs/evaluation.md) · [Inventory](config/benchmark.json) · [Design decisions](docs/design-tree.md) · [SWE-bench research](docs/research/swe-bench.md)

[Task-quality research and the twelve-PR audit](docs/verification/task-quality-audit-2026-10-14.md) assess whether these fixtures measure their stated tasks. Protocol `elixir-agent-benchmark-v3` removes Plausible 6300 because its reference fails the timezone contract, promotes custom checks for all eleven remaining cases, and accepts equivalent readable Erlang diagnostic layouts. See the [promotion verification](docs/verification/task-quality-promotion-2026-10-14.md) for final-fixture qualification and challenge replays. Historical scores keep their original inventory and checks.

[The original eleven-case freeze](docs/verification/case-freeze-2026-10-15.md) records three fresh qualification rounds, exact Pi inputs and environment identities. [Astra validation](verification/astra-confirmation-2026-10-15/README.md) established two reviewed successful repairs for nine cases. Protocol `elixir-agent-benchmark-v4` excludes Plausible 6763 and 6441; their unchanged bundles and rejection reasons are preserved under [cases_rejected](cases_rejected/README.md). Historical evidence retains the original inventory.

New case selection follows the [PR guidelines](docs/pr-selection-guidelines.md), favoring coherent changes across 2–5 implementation files and broader project/task coverage. Drafts use [versioned admission contracts](docs/case-admission.md), with exact upstream reconstruction, recorded independent review and executable qualification; two fresh strong-model passes are additionally required by the manual solvability policy before validated comparisons. The website also supports comparable-run matrices and reference-aware release cache removal. Storage snapshots distinguish per-image shared/unique bytes from Docker-wide totals.
