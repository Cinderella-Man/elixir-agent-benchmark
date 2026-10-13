# Elixir Agent Benchmark

A local Elixir website that evaluates one served coding model against **twelve historical PR repairs**: six Plausible and six Livebook cases. Enter a llama.cpp or Strata endpoint, inspect the automatically discovered model, and click **Run benchmark**.

The application prepares Docker images, checks the fixtures, runs the [Pi coding agent](https://github.com/earendil-works/pi) in isolated Docker workspaces, and grades its repairs with executable tests. There is no AI judge or speed score.

## Start

Use Linux x86-64 with **Docker Engine and Docker Compose**. Elixir/OTP, Pi, its Node runtime, Git, build tools, PostgreSQL and ClickHouse are provided by containers. Serve the model separately; the application does not download, start or switch models.

From this checkout:

```sh
docker compose up --build -d
```

Open [http://localhost:4000](http://localhost:4000). Enter the server root, for example `http://localhost:8080`, and an optional API key. Model details load automatically. Click **Run benchmark**; first preparation downloads project dependencies and fixture images. The website shows each stage, case results and downloadable evidence.

Execution starts only when you click **Run benchmark**. Connecting to an endpoint reads model metadata without generating output.

The website is available only from the computer running it. The model endpoint can be on that computer or another reachable machine. If the server requires an API key, enter it under **Server credentials**.

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

Defaults: all twelve cases, seed 101, unlimited model and tool calls, up to 8,192 tokens per response and 65,536 generated tokens per case. Context is detected automatically and capped at 262,144 tokens. Advanced settings allow explicit overrides within the server's capacity. History is retained without compaction; exhausting either the generation budget or context window submits the current patch for grading.

One run is active at a time. Closing the browser does not stop it. **Stop run** cancels execution and cleans up this installation's containers. After interruption, reconnect the same model with the same settings and choose **Resume unfinished cases**. Completed passes, failures and evaluation errors stay fixed; saved submissions resume grading, and unfinished Pi work starts in a fresh workspace with its prior evidence preserved. Changed release, model or settings require a new run. Historical runs without checkpoint receipts cannot resume.

All cases have equal weight. A final score requires a completed pass/fail outcome for every case; errors, cancellations and interrupted work remain visible and prevent a final score. The model's reported identity, effective budgets, requests, responses, patches and controls accompany each run. Missing identity metadata stays explicitly unverified; manual artifact pins are not required.

Each run freezes a checksummed release and experiment identity. Select a case for its acceptance, preservation and submitted-test results, named failures and short error excerpts. Full logs, patches, trajectories and grading output remain downloadable. History and case lists are paginated; reports include project/task breakdowns and interrupted-generation counts.

Under **Retained preparation**, preview removal of one case's cached state or unreferenced artifacts. Shared state and active work are protected; nothing is automatically evicted. Missing builds stop if the data filesystem is below the configured free-space reserve (5 GiB by default). When a run ends, **Download report** saves its summary and per-case results. Data persists in the `benchmark-data` Docker volume.

[Setup, development and troubleshooting](docs/runbook.md) · [Evaluation contract](docs/evaluation.md) · [Inventory](config/benchmark.json) · [Design decisions](docs/design-tree.md) · [SWE-bench research](docs/research/swe-bench.md)

New case drafts use [versioned admission contracts](docs/case-admission.md), with exact upstream reconstruction, recorded independent review and executable qualification before entering the inventory. The website also supports comparable-run matrices and reference-aware release cache removal. Storage snapshots distinguish per-image shared/unique bytes from Docker-wide totals.
