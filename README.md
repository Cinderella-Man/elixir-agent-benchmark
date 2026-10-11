# Elixir agent benchmark

Compare local coding models and quantizations by having them diagnose and repair Elixir projects. Each agent gets a bug report, a full repository, terminal tools and tests in an isolated, offline Docker environment.

**One benchmark, 16 cases:** six real Plausible PRs, six real Livebook PRs, and four authored regressions in NimbleOptions, GenStage and LiveBeats. Every case runs by default. Repairs are scored by executable acceptance and regression checks, including useful regression tests where coverage is missing. **No AI judge or subjective code-quality score.**

## Run

Use a dedicated **Linux x86-64** machine with **Python 3.12+, Git and Docker**, Docker access for your user, and disk space for the application images and dependencies. Preparation needs internet access; agent containers have none. Elixir, PostgreSQL and ClickHouse run in containers.

Serve your models separately. The current adapters support **llama.cpp with `/v1/chat/completions/input_tokens`**, plus the reviewed Strata adapter described in the [runbook](docs/runbook.md#model-endpoints). An arbitrary OpenAI-compatible endpoint is insufficient. Every server must support native tool calls and at least **262,144 context tokens**. This repository does not download or start models.

```bash
git clone https://github.com/Cinderella-Man/elixir-agent-benchmark.git
cd elixir-agent-benchmark

# Edit config/candidates.json: one entry per model + quantization you serve.
# Set the endpoint URL, served model alias, reasoning setting and artifact pins.
# For llama.cpp use token_counter: "llama_cpp"; pin your own expected_build.
# If authentication is required, put the key in .local/api-key (chmod 600),
# or set api_key_env on each candidate to an environment-variable name.

python3 scripts/benchmark.py init
python3 scripts/check_endpoints.py
python3 scripts/qualify_suite.py --prepare
python3 scripts/run_suite.py --campaign comparison-001
python3 scripts/report.py --campaign comparison-001
```

`init` records the execution host and existing GPU power limits. Endpoint checks make two small, unscored requests per model. `qualify_suite` builds all 16 fixtures and verifies that broken code fails, reference repairs pass, and invalid repairs are rejected. Reuse prepared images on later runs; rerun qualification after changing the evaluator or cases.

The campaign runs **all configured candidates × all 16 cases**, using seed 101. For repeated attempts, add `--seeds 101 202 303`. Each run needs a new campaign name; existing attempts are never overwritten. `--candidates <id> ...` selects models; `--cases <id> ...` is for diagnostics and receives no full-benchmark score.

## Budgets and results

All candidates get **262,144 context tokens**, **8,192 tokens per response**, **65,536 generated tokens per attempt** and **32 model calls**. Reasoning and tool-call syntax count toward generation. History is retained without compaction. The runner counts each complete prompt, reserves response space plus eight safety tokens, and grades the current patch when a budget is exhausted. `--max-calls` and `--max-tokens` change the attempt budgets; the context policy lives in [config/benchmark.json](config/benchmark.json).

Open **`results/reports/benchmark-results.md`** for the comparison and per-project breakdown. Scores are **passed attempts / planned attempts × 100**, with equal case weight and all declared seeds included. Missing attempts and infrastructure/API errors remain visible and block a final score. Model/quantization identities, server profiles, fixtures and budgets are frozen for each campaign.

Transcripts, patches and raw checks stay in `.local/results/<campaign>/`; the report command exports evidence to `results/<campaign>/`. Both directories are ignored by Git. Historical PRs and solutions are public, so prior training exposure is possible. A 256k allowance does not mean every case consumes or validates all 256k tokens.

[Detailed setup and troubleshooting](docs/runbook.md) · [Scoring protocol](docs/comparison-protocol.md) · [Case inventory](config/benchmark.json)
