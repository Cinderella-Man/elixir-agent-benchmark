# Application design

The benchmark is a local, single-user Elixir application. Enter a llama.cpp or Strata endpoint, inspect its automatically discovered model details, and start a run. Phoenix LiveView provides setup, preparation, fixture checks, progress, cancellation and saved results.

## Contract

| Area | Decision |
| --- | --- |
| Cases | Twelve actual upstream PR repairs: six Plausible, six Livebook |
| Model | One endpoint and its currently served model per run |
| Identification | Server-reported metadata; unknown properties stay explicit; no manual artifact pins |
| Agent | Pinned Pi CLI inside each problem container, using read, bash, edit and write |
| Dependencies | Docker supplies the application, build tools, PostgreSQL and ClickHouse |
| Deployment | Public, portable configuration without personal paths, machine identities or host-specific hardware policies |
| Interface | Local website |
| Context | Detected capacity, capped at 262,144 tokens by default |
| Budgets | Up to 8,192 tokens per response, 65,536 generated tokens and 32 calls per case |
| Attempts | One per case, seed 101 by default; advanced settings available |
| History | Persist model details, settings, logs, exchanges, patches and results |
| Interruption | Save interrupted work and start a fresh run |
| Scoring | Equal case weight; executable checks; incomplete runs have no final score |
| Isolation | Offline attempt workspaces without solutions, upstream history, Docker access or credentials |

## Boundaries

`Model` owns discovery and native token accounting. `Pi` launches the external Pi CLI and records its events. `PiGateway` enforces budgets while forwarding Pi's complete native requests. `Fixtures` prepares pinned Docker environments. `Sandbox` owns isolated workspaces and dependent services. `Grader` qualifies cases and evaluates repairs. `Agent` pairs one Pi attempt with independent grading. `Runner` coordinates these modules; `Runs` supervises one active run and persists its state independently of browser connections. `Store` owns local artifacts. The website presents these operations.

Docker host networking allows the controller to reach loopback model endpoints. The website itself binds only to loopback; fixture containers have no external network. Execution begins when the user clicks Run. Source inspection, builds, synthetic correctness tests and metadata discovery work without benchmark execution.

See [evaluation](evaluation.md), [operation](runbook.md), and the [decisions](adr/0003-single-model-website.md).
