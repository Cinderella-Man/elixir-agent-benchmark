# Running and developing the application

## Deployment

Use Docker Engine and Docker Compose on Linux x86-64. Start with `docker compose up --build -d`, then open `http://localhost:4000`. Set `PORT` to select another local port. The application and all preparation tools live in the container; the host does not need Elixir, Node, Git, PostgreSQL or ClickHouse installed to run an existing checkout.

Preparation needs internet access and enough disk for twelve historical application builds. Each case is prepared and checked, attempted by Pi, then graded before the next case starts. The first generation request contains the actual ticket. Valid image and control records are reused. The controller never starts or changes the model server.

The website is the only user interface. Build, test and Docker lifecycle commands below are developer/deployment operations, not a second benchmark CLI.

## Model endpoints

Enter the server root, optionally with a trailing `/v1`. Credentials must use the API-key field rather than URL user information. The application reads `/health`, `/v1/models` and `/props`; discovery does not generate model output. API keys stay in memory and must be re-entered after a browser/application restart. Connection errors are shown in the website.

llama.cpp must support tools, `/props` and the non-generating `/v1/chat/completions/input_tokens` route. Generation uses `/v1/chat/completions`. Configure the server with a suitable chat template and sufficient per-slot context. The [server API](https://github.com/ggml-org/llama.cpp/blob/8bb3cf0d216a5ae48360179f2931daf284be4d01/tools/server/README.md) defines these routes.

Stock Strata support uses `/v1/messages/count_tokens` and `/v1/messages` with text, automatic tools and full thinking/tool history. Input accounting includes cached input tokens. The adapter follows the [v0.1.43.1 source contract](https://github.com/Niko1221/Strata/blob/a0116b2782a5b82622358c04a06496485d12b2d6/serve/server.py); each actual Pi request is counted before generation and checked against reported usage afterward.

Advanced settings control context, response tokens, cumulative generated tokens, model calls and the seed. Sampling/template behavior otherwise follows the server's recorded defaults. Changing model or serving settings during a run invalidates it. A server reporting a model alias is not proof of an exact model artifact; hashes and missing properties are not guessed.

## Containers and persistence

Compose mounts the local Docker socket into the trusted controller only. The controller uses host networking to reach a server bound to `127.0.0.1`; the web listener binds only to loopback. Fixture containers retain network isolation and never receive the Docker socket. A small Node transport wrapper launches the pinned Pi CLI in each problem container and forwards its HTTP requests over `docker exec` JSON lines. The Elixir controller alone talks to the configured endpoint. The wrapper contains no agent logic; Pi manages prompts, history and tools. PostgreSQL and ClickHouse share an otherwise offline network namespace with their corresponding attempt.

Run artifacts, session secrets, image identities, fixture controls and build caches live in `/data`, persisted by the `benchmark-data` volume. The website provides individual artifact downloads. Protect and back up the volume; `docker compose down` preserves it. Do not delete the volume if its results are needed. Preparation errors retain build logs under `/data/build/<case-id>/build.log`.

Stopping or restarting does not silently retry model failures. Completed results, errors, cancellations and interruptions stay separate. Startup retries cleanup of containers left by an interrupted process, using this installation's ownership labels. Unrelated containers, volumes and images are never pruned. A cleanup failure blocks new runs until cleanup succeeds or the application is restarted after fixing Docker access.

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

Add a manifest and symptom-focused ticket to `cases/<id>/`, with the historical broken revision, reference repair, acceptance patch and optional task-neutral environment patch. Include reference regression tests where required and a plausible incomplete-repair probe. Preserve commit provenance alongside the case and upstream licenses under `licenses/`. Add the case to the versioned inventory only after qualification on the intended execution host. The grader requires explicit `mix test` commands and completed trusted ExUnit records.
