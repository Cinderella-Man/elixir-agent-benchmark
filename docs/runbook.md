# Running and developing the application

## Deployment

Use Docker Engine and Docker Compose on Linux x86-64. Start with `docker compose up --build -d`, then open `http://localhost:4000`. Set `PORT` to select another local port. The application and all preparation tools live in the container; the host does not need Elixir, Node, Git, PostgreSQL or ClickHouse installed to run an existing checkout.

Cold preparation needs internet access and enough disk for twelve historical application builds. The first case is prepared and checked before other preparation starts. Once its attempt begins, a bounded window of upcoming cases prepares in the background. Pi attempts preserve inventory order, with one active Pi and at most one additional waiting workspace. A single grader checks saved submissions alongside subsequent attempts; one submission may wait for that grader before new attempts pause. The first generation request contains the actual ticket. Valid image and control records are reused. The controller never starts or changes the model server.

`EAB_PREPARE_AHEAD` controls the preparation window (default `4`, allowed `1`–`12`); `EAB_PREPARE_WORKERS` controls concurrent preparation jobs (default `2`, allowed `1`–`4`). Set these when starting Compose. Preparation includes fixture qualification, which can start database services; these counts are separate from the active Pi, waiting workspace and grader. Existing per-container CPU and memory ceilings still apply, and dependency compilation uses two Erlang schedulers. These are concurrency limits, not a host-wide CPU or RAM reservation. Reduce preparation workers on a shared Docker host. The design assumes a remote model server, though local endpoints still work.

The website is the only user interface. Build, test and Docker lifecycle commands below are developer/deployment operations, not a second benchmark CLI.

## Model endpoints

Enter the server root, optionally with a trailing `/v1`. Credentials must use the API-key field rather than URL user information. The application reads `/health`, `/v1/models` and `/props`; discovery does not generate model output. API keys stay in memory and must be re-entered after a browser/application restart. Connection errors are shown in the website.

llama.cpp must support tools, `/props` and the non-generating `/v1/chat/completions/input_tokens` route. Generation uses `/v1/chat/completions`. Configure the server with a suitable chat template and sufficient per-slot context. The [server API](https://github.com/ggml-org/llama.cpp/blob/8bb3cf0d216a5ae48360179f2931daf284be4d01/tools/server/README.md) defines these routes.

Stock Strata support uses `/v1/messages/count_tokens` and `/v1/messages` with text, automatic tools and full thinking/tool history. Input accounting includes cached input tokens. The adapter follows the [v0.1.43.1 source contract](https://github.com/Niko1221/Strata/blob/a0116b2782a5b82622358c04a06496485d12b2d6/serve/server.py); each actual Pi request is counted before generation and checked against reported usage afterward.

Advanced settings control context, response tokens, cumulative generated tokens and the seed. Model and tool calls are unlimited; Pi can continue until it finishes or exhausts the generation budget or context window. There is no attempt-wide wall-clock cutoff. Individual model requests and setup/grading commands retain their watchdogs, and Stop run remains available. Sampling/template behavior otherwise follows the server's recorded defaults. Changing model or serving settings during a run invalidates it. A server reporting a model alias is not proof of an exact model artifact; hashes and missing properties are not guessed.

## Containers and persistence

Compose mounts the local Docker socket into the trusted controller only. The controller uses host networking to reach a server bound to `127.0.0.1`; the web listener binds only to loopback. Fixture containers retain network isolation and never receive the Docker socket. A small Node transport wrapper launches the pinned Pi CLI in each problem container and forwards its HTTP requests over `docker exec` JSON lines. The Elixir controller alone talks to the configured endpoint. The wrapper contains no agent logic; Pi manages prompts, history and tools. PostgreSQL and ClickHouse share an otherwise offline network namespace with their corresponding attempt.

Run artifacts, session secrets, image identities, build seed records, fixture controls, pristine source snapshots and build contexts live in `/data`, persisted by the `benchmark-data` volume. Docker images, build layers and BuildKit package caches live in the host Docker daemon's storage; preserving `/data` alone does not preserve them. The website provides individual artifact downloads. Protect and back up the volume; `docker compose down` preserves it. Do not delete the volume if its results are needed. New project build output is saved under `/data/build/projects/<input-hash>/build.log`, with toolchain construction in `toolchain.log`; the runtime record references its log, and each case's activity log records preparation failures.

Preparation has independent content-addressed project, database and Pi records in `/data/cache/`. A matching record validates that its Docker images still exist, then skips its build/bootstrap work. A Pi update does not invalidate the project or databases. Missing components rebuild automatically when Run is clicked. On a project rebuild, source snapshots are reused by repository and exact revision. The controller builds or reuses an installed toolchain image, then selects a completed pristine build seed with the same repository, toolchain image identity, runtime settings and build policy. The seed may come from any compatible PR; inventory order and preparation concurrency are unchanged. Logs name the seed case and revision, or explain that no compatible seed exists.

Source exports verify the requested commit and the case's recorded broken tree, exclude upstream Git history, and keep tracked files even if `.gitattributes` marks them `export-ignore`. An archive receipt binds repository, tree and archive checksum; an intact cached export works without contacting upstream. A missing receipt causes a fresh export; a corrupt archive or mismatched receipt is rejected. Cases with submodules need an explicit export contract and are rejected for now. The new exporter identity causes a one-time invalidation of older project preparation; it does not run again on valid exact-case hits.

The new revision replaces the seed's source, removing deleted files and obsolete generated assets while preserving unchanged source mtimes, dependency worktrees and Mix build state. Mix fetches changed dependencies and compiles stale code. Changed dependency identities/options invalidate their compiled output and that of dependent packages, including native objects left in their worktrees. Changes to project compilation settings or the configuration tree conservatively discard compiled output and dependency worktrees. Removed dependencies are cleaned. A fresh final image stage contains only the reconciled workspace, fresh initial Git commit and preparation metadata; it does not inherit the old revision's source layers. Pi is attached afterward. Every rebuilt case still needs its own valid qualification receipt before Pi starts.

Fixture builds disable BuildKit's per-invocation provenance attestations so cached toolchains retain stable image identities on Docker's containerd image store. The benchmark still records exact source revisions, build inputs and image identities in its own runtime artifacts.

Hex tarballs and npm package downloads use shared, locked [BuildKit cache mounts](https://docs.docker.com/build/cache/optimize/#use-cache-mounts). These remain useful across toolchain changes and compilation invalidations. The Hex lock is released before dependency compilation, so independent preparations can compile concurrently. The controller image includes the Buildx plugin and uses the local Docker builder. The generated recipe and seed helper are hashed automatically; this change causes a one-time rebuild of older preparation records. Missing seed images fall back to cold preparation. Images, seeds, layers, downloads and snapshots are retained locally; there is no remote cache publication or automatic pruning.

Only pristine source and preparation artifacts are reusable. A seed is published atomically after a successful image build, using an immutable image identity and content-addressed tag; concurrent builds copy completed images into independent workspaces. Agent writes, reference repairs, grader overlays and database changes from attempts never feed back into preparation caches. Missing or changed inputs rebuild the affected components and requalify where necessary before Pi starts.

Plausible's default baseline runs the original source's `mix ecto.create --quiet` and `mix ecto.migrate` once. Persistent service data is relocated outside the stock images' Docker volumes to `/opt/eab-state`, validated, and captured only after clean service shutdown. Both database images must exist before the baseline record is published. Each Pi/grading workspace then starts new services with independent writable layers, with a fresh ClickHouse server UUID. Livebook uses its prepared project image and fresh process-local state. A case that tests installation/migration behavior must explicitly declare `"baseline": {"mode": "fresh"}` and its setup contract.

Database seeds require matching engine digests, installed toolchain, bootstrap policy, configuration/data/dependency inputs and an unchanged ordered migration prefix. Migration helpers are fingerprinted conservatively; opaque calls include all application source. New cross-repository migration dependencies reject forward reuse. A compatible completed seed applies only missing migrations; otherwise a family initializes from empty engines. Before extending eight capture generations, a shallow checkpoint copies the state onto its engine/layout base. Exact baseline hits never traverse this ancestry. This is conservative compatibility, not a guarantee that every consecutive PR can share a database seed.

This implements the proposed "prepare one PR, update source/dependencies, migrate, save the next" approach through immutable forks. Preparation selects an available compatible seed; it does not mutate a live Pi workspace or run `git pull`. The present scheduler preserves the first-case gate and bounded inventory lookahead, so it does not guarantee oldest-first preparation. For a larger corpus, family-aware preparation ordering remains separate from the frozen order of Pi attempts.

Qualification receipts live in `/data/qualifications/` and cover the baseline, relevant checks and evaluator. Pi, model and descriptive ticket changes do not repeat fixture controls. This baseline contract requires one-time requalification of the existing cases on the intended execution host; older raw-service records are not silently treated as prepared snapshots. Test aliases may still check for pending migrations when tests execute, and service/process startup still occurs. No startup-time claim has been measured on this shared machine.

The same twelve cases now declare protocol `elixir-agent-benchmark-v2` because database initialization moves before repairs and the agent call cap has been removed. Existing run records preserve their original protocol; v1 and v2 results should not be silently merged into one comparison.

Preparation, workspace, Pi and grading failures become case errors without interrupting unrelated active work; remaining valid cases continue in inventory order, and any error prevents a final score. Stopping or restarting does not silently retry failures. Stop drains preparation, workspace, Pi and grading workers, including their subprocesses, before removing owned containers. Saved submissions awaiting grading are marked cancelled or interrupted alongside active attempts. Startup retries cleanup of containers left by an interrupted process, using this installation's ownership labels. Unrelated containers, volumes and images are never pruned. A cleanup failure blocks new runs until cleanup succeeds or the application is restarted after fixing Docker access.

## Releases, recovery and evidence

New runs freeze case fixtures, inventory order, controller/evaluator identity and Pi identity in `/data/releases/<hash>/`. Their experiment identity adds the declared endpoint/model profile, effective settings and offline network policy. The exact prepared image/database/source identity is saved per case and sealed into its submission receipt. Model provenance remains server-reported: an unchanged alias is not proof that a server still hosts identical weights.

After stopping or restarting, wait for cleanup, reconnect the same model, restore the same advanced settings, select the interrupted run and click **Resume unfinished cases**. Completed passes and failures are reused only after their submission and grading checksums verify. Evaluation errors stay visible and are not retried by resume. A sealed submission goes back to grading without new Pi calls. Unsubmitted work moves to `prior-attempts/<case>/<generation>/` before a fresh attempt starts; prior usage and evidence remain recorded. Different release, model, settings or prepared environment require a new run. Historical records without sealed checkpoints cannot resume.

Raw grading output lives in each case's `grade.json`; `attempt.json` contains compact scoring checks. The run record and history index contain compact outcomes and artifact references, not full logs. The website shows named expected/observed failures, bounded excerpts and fixed evidence links. History uses pages of 20 runs and case results pages of 25. The filesystem history index reads small summaries; it is not yet a database index for arbitrarily large histories. Corrupt run records appear individually without overwriting their original evidence.

## Retention and disk space

Completed baselines remain retained across model runs and controller restarts. **Retained preparation** previews explicit removal for one case or unreferenced project/database/Pi artifacts. Removal rechecks the preview, protects shared seed ancestry and references, and refuses to operate while runs, preparation, workspaces or cleanup hold leases. It removes only application-owned tags without force. Images Docker cannot remove remain recorded, with the reason shown. Engine images, layouts, source exports, package caches and BuildKit layers are not pruned by this control. Counts are references, not estimates of unique storage usage.

`EAB_CACHE_MIN_FREE_GB` defaults to `5` and blocks new missing-component builds below that reserve; valid hits still work and no warm corpus is automatically evicted. This checks the controller data filesystem. When Docker stores images on a different filesystem, mount an accessible path from that filesystem into the controller and set `EAB_DOCKER_STORAGE_PATH` to that mounted path using a Compose override. Without that configuration, the controller cannot assert the Docker daemon's free space. A pre-build reserve check is not a reservation of all future build space, especially with concurrent jobs.

Deleting images outside the application is detected as missing cache state. Deleting `/data` loses receipts, releases and run evidence even if image layers survive. Back up both persistence domains if required.

## Bounded correctness checks

All developer dependencies also run in Docker:

```sh
docker build --target tooling -t eab-tooling:dev .
docker run --rm --cpus=2 --user "$(id -u):$(id -g)" \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v "$PWD:/app" -w /app eab-tooling:dev mix deps.get
docker run --rm --cpus=2 --user "$(id -u):$(id -g)" \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v "$PWD:/app" -w /app eab-tooling:dev \
  sh -c 'mix format --check-formatted && MIX_ENV=test mix test --warnings-as-errors'
```

To also verify the production Docker launcher and controller file copies with a synthetic repair, give the test container access to Docker:

```sh
docker run --rm --network none --cpus=2 \
  --user "$(id -u):$(id -g)" --group-add "$(stat -c %g /var/run/docker.sock)" \
  -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v "$PWD:/app" -v /var/run/docker.sock:/var/run/docker.sock \
  -w /app -e EAB_DOCKER_TESTS=1 eab-tooling:dev \
  sh -c 'MIX_ENV=test mix test --warnings-as-errors'
```

Tests include the real pinned Pi CLI editing a temporary workspace through synthetic llama.cpp and Strata replies, plus grading records; they do not run a benchmark or load a model. To preview the website:

```sh
docker run --rm --cpus=2 --network host \
  --user "$(id -u):$(id -g)" -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v "$PWD:/app" -w /app eab-tooling:dev sh -c 'mix assets && mix run --no-halt'
```

A release build uses `docker compose build`. Previewing and connecting do not start a run; execution begins only from the Run button.

The development commands use your user ID so generated files remain writable. Docker keeps dependencies and compiled code in `.local/docker-deps` and `.local/docker-build`, separate from native Elixir builds. Release builds and PR workers use their own container filesystems.

## Pi runtime

`priv/pi/package.json` and `package-lock.json` pin Pi and all npm dependencies. `priv/pi/runtime.json` pins the glibc and musl Node images so older Ubuntu and Alpine fixtures can run the same Pi version without replacing their project runtime. All installation happens during Docker builds. Pi's own retries, compaction, extensions, MCP, skills, prompt templates and automatic network activity are disabled. It uses only the configured model and standard read, bash, edit and write tools; task clarification details are included in the instructions upfront.

Pi uses its normal medium thinking level for Strata and models whose template reports reasoning support. The adapter preserves Pi's thinking request and the server's reasoning-budget configuration. Reasoning counts toward the response and total token budgets. Workers include GNU command-line tools and ripgrep on both Alpine and Ubuntu images.

Click a case to follow its `activity.log`: Docker commands and output, model responses as they arrive, and Pi's tool commands and results. The panel updates every second and offers a full-log download. Artifacts also include the ticket, instructions, Pi configuration, `pi-events.jsonl`, model requests, SSE responses, usage, patch and grading output. The transport validates each completed model response before passing it to Pi; the website can display the response while it arrives.

## Adding a PR case

The [SWE-bench/SWE-bench Verified research](research/swe-bench.md) is complete, with recommendations incorporated into [the expansion plan](benchmark-expansion-plan.md). No new cases have been added. Immutable release snapshots, source receipts, retention, recovery and compact evidence are implemented. Real qualification of the existing twelve, candidate review/admission records and broader grading contracts still precede an expanded comparison.

Add a manifest and symptom-focused ticket to `cases/<id>/`, with the historical broken revision, reference repair, acceptance patch and optional task-neutral environment patch. Include reference regression tests where required and a plausible incomplete-repair probe. Preserve commit provenance alongside the case and upstream licenses under `licenses/`. Add the case to the versioned inventory only after qualification on the intended execution host. The grader requires explicit `mix test` commands and completed trusted ExUnit records.
