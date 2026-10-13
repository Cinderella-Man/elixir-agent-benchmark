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

For each PR, in order:

1. **Prepare:** Docker builds each problem's image with the broken project, its Elixir/OTP version, dependencies, Node and Pi. Existing images are reused. The application checks the reference repair and tests before starting Pi; the model is not used during this setup.
2. **Repair:** Each problem gets a fresh container. Pi is installed in `/opt/pi` and edits the project in `/workspace`, using your model endpoint and the supplied ticket prompt. The source is copied into the image. Plausible cases also get separate PostgreSQL and ClickHouse containers.
3. **Grade:** The application saves Pi's patch, tests it in fresh containers, records the result and removes the temporary containers. Results and logs remain in the `benchmark-data` Docker volume.

Pi and the project run on the benchmark's Docker host. The model server can run elsewhere. Click a case in **Follow the run** to see its current command, live output and Pi activity.

## Run settings and results

Defaults: all twelve cases, seed 101, 32 model calls per case, up to 8,192 tokens per response and 65,536 generated tokens per case. Context is detected automatically and capped at 262,144 tokens. Advanced settings allow explicit overrides within the server's capacity. History is retained without compaction; exhausted budgets submit the current patch for grading.

One run is active at a time. Closing the browser does not stop it. **Stop run** cancels execution and cleans up this installation's containers. An application restart records active work as interrupted; start a fresh run rather than resuming it. Existing results are never overwritten.

All cases have equal weight. A final score requires a completed pass/fail outcome for every case; errors, cancellations and interrupted work remain visible and prevent a final score. The model's reported identity, effective budgets, requests, responses, patches and controls accompany each run. Missing identity metadata stays explicitly unverified; manual artifact pins are not required.

When a run ends, **Download report** saves its summary and per-case results. Data persists in the `benchmark-data` Docker volume.

[Setup, development and troubleshooting](docs/runbook.md) · [Evaluation contract](docs/evaluation.md) · [Inventory](config/benchmark.json) · [Design decisions](docs/design-tree.md)
