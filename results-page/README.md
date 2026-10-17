# Elixir SWE Bench results page

A static, shareable page for Elixir SWE Bench results, produced by this repository's benchmark runner. One dot represents the current admitted cases from one completed run. Repeated runs stay separate. No server, database, npm packages or external assets are needed to serve it.

The page contains a title, maximum model-size slider and one shared chart, with labels immediately left of their dots. Case outcomes and recorded settings open below the chart. There is no comparison selector or model search.

The initial records cover the same nine valid cases: **Astra 9/9**, **Qwen3.8-Flash-Next-GSQ-RCO-abliterated IQ3_S 8/9**, **Swift-1.5-Qwen3.8-27B Q4_K_M 5/9**, and **Qwen3.8-27B Q4_K_M 2/9**. Rejected cases are excluded from the public data and details. These are recorded outcomes, not new executions. Effective settings can differ between rows and remain visible in the details; the local runner's strict comparison rules are unchanged.

Model weight sizes remain visible, separately from observed GPU and RAM allocation. Flash has a loaded-process observation at 262,144 configured context: 69.8 decimal GB across three RTX 3090s, 7.8 GB sampled service RAM and a 51.5 GB service-lifetime RAM peak. The public record includes per-GPU allocations, CPU, KV cache type, runtime version, timestamp, RSS and cgroup observations. This snapshot does not establish peak memory during the saved run, a fully occupied context, or the minimum hardware needed with another offload/cache configuration. The other local models have no captured memory profile yet; Astra is an API model.

The slider filters model weight-file size in decimal GB. At 50 GB, both 17.4 GB Qwen models appear even though their runtime memory has not been measured. Observed VRAM/RAM remains separate deployment data and does not determine eligibility for this size filter. A numeric limit hides unknown-size/API models; All restores them. Each case shows its saved generated-token count. Durations and throughput remain unmeasured for the existing runs.

## Preview

From the repository root:

```sh
python3 results-page/publish.py build
python3 -m http.server 4173 --bind 127.0.0.1 --directory results-page/dist
```

Open [the local preview](http://127.0.0.1:4173). You can also open `results-page/dist/index.html` directly in a browser; data is loaded from a local script, so no fetch server is required. Generated `dist/` files are ignored by Git.

## Adding a result

Export the original `run.json` from a completed benchmark run:

```sh
python3 results-page/publish.py add /path/to/run.json \
  --model-label 'My model 32B' \
  --quantization 'Q4_K_M' \
  --size-gb 20.5 \
  --resources /path/to/memory-observation.json \
  --evidence-url 'https://example.com/public-run-evidence'
```

All flags are optional. Model name, quantization and size use saved artifact metadata when available, including legacy runs whose routing aliases differ from their artifact names. `--quantization` and `--size-gb` mark owner-supplied values; absent metadata stays unknown. `--note` adds context shown in the details. The command creates one small JSON file in `results-page/results/` and rebuilds the preview. It refuses to overwrite an existing run; edit its public JSON deliberately to correct a label or note.

For the Docker installation, copy the original run file out to an ignored local directory first:

```sh
mkdir -p .local/publication
docker compose cp benchmark:/data/runs/RUN_ID/run.json .local/publication/run.json
python3 results-page/publish.py add .local/publication/run.json
```

The exporter requires a completed full-inventory source run and a pass/fail grade for every case. Errors, interruptions, partial repeats and unknown settings are rejected. Every current case must occur in the run with matching fixture hashes. It exports only those current cases, recomputes counts from their outcomes and leaves the original run unchanged. Endpoint URLs, account identifiers, transcripts and raw provider metadata are excluded. It uses the recorded grades, not a new audit of the underlying grading receipts. Review the model label, optional note and evidence link before publishing.

Commit the new file in `results-page/results/` and push it to `main`. After the one-time Pages setup below, GitHub rebuilds and publishes automatically. No manifest or HTML edits are needed. Alternatively, add a JSON record in the same schema as the existing file; `check` and `build` validate all records.

```sh
python3 results-page/publish.py check
python3 -m unittest discover -s results-page -p 'test_*.py'
```

The builder checks every public record against `config/benchmark.json` and the current case fixture hashes. A changed inventory or fixture makes stale records fail validation: explicitly re-export eligible source runs or replace records with new runs before publishing. Do not splice attempts from different runs together. Unknown future settings fail validation; extend the public schema when that happens.

## Capture memory and future timings

`scripts/model_resources.py` reads the selected inference process with `nvidia-smi` and Linux procfs/cgroup counters, plus authenticated model properties. It performs no inference and no speed measurement. Run it **on the model host**, with the engine PID (not the Python HTTP server PID):

```sh
python3 scripts/model_resources.py --pid ENGINE_PID \
  --endpoint http://127.0.0.1:PORT --key-file /path/to/existing-api-key \
  --output /path/to/memory-observation.json
```

The key, host address, PID, absolute artifact path and GPU UUIDs are not exported. GPU usage is attributed by process PID and physical GPU UUID before producing public values; whole-host GPU/RAM figures can include unrelated work. On the inspected Strata deployment, its own hardware panel selected the wrong physical GPUs, so it was not used for memory attribution. The exporter accepts a snapshot only when artifact, backend and context match the result. A matching artifact name is not a checksum/provenance guarantee.

For an **explicitly authorized, isolated performance environment only**, `EAB_PERFORMANCE_ENV=<environment-label>` enables attempt timing in the runner. Leave it unset on the shared workstation. Timing is disabled by default, including in ordinary functional tests. The label identifies the operator's measurement environment; it does not automatically certify isolation or hardware suitability.

Timed attempts retain monotonic elapsed milliseconds from Pi startup through submission, excluding fixture preparation and independent grading. Model-request milliseconds include prompt processing, generation and response transfer; displayed output tokens/s is total generated tokens divided by total request time, not pure decode speed. Per-case minutes and all-case totals include failed attempts with their outcomes visible. Existing wall-clock logs are not retrospectively promoted to qualified speed evidence. Input/context size is not a generated-token count. New runs on configured model hosts automatically collect memory separately from performance measurements. Speed qualification still requires a separate suitable environment and explicit authorization.

## Publish with GitHub Pages

This repository's default project-site URL will be:

**[https://cinderella-man.github.io/elixir-agent-benchmark/](https://cinderella-man.github.io/elixir-agent-benchmark/)**

The page's display name is **Elixir SWE Bench**. If you rename the GitHub repository to `elixir-swe-bench`, its default Pages address becomes `https://cinderella-man.github.io/elixir-swe-bench/`. The workflow supplies `GITHUB_REPOSITORY`, which the builder uses for page navigation links automatically. For a local preview after renaming, set `GITHUB_REPOSITORY=Cinderella-Man/elixir-swe-bench` when building. Existing frozen benchmark IDs and historical result records remain unchanged.

GitHub Pages serves HTML, CSS and JavaScript at `<owner>.github.io/<repository>/`. Public repositories can use Pages on GitHub Free. [GitHub's Pages overview](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)

One-time setup:

1. Commit and push `results-page/` and `.github/workflows/results-page.yml` to `main`.
2. Open the repository's [Settings → Pages](https://github.com/Cinderella-Man/elixir-agent-benchmark/settings/pages).
3. Under **Build and deployment → Source**, select **GitHub Actions**.
4. Open **Actions → Publish benchmark results → Run workflow**. Future pushes that change result files, page files or the inventory will publish automatically.

The workflow runs the publication checks, builds `results-page/dist/`, uploads only that folder, and deploys it to the `github-pages` environment. All asset paths are relative so the page works under the repository subpath. Repository source, private run files and benchmark services are not part of the deployed folder. Configure a custom domain separately if wanted later.

[GitHub's source-configuration instructions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) · [GitHub's custom workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)

## Files

- `index.html`, `styles.css`, `app.js`: page and interactions.
- `results/*.json`: one public record per run; these are the everyday additions.
- `publish.py`: validates/export records and assembles the static site using Python 3.10+.
- `test_publish.py`: functional checks for eligibility, current-case projection, model metadata, GPU attribution and public exports.
- `dist/`: generated HTML, assets and downloadable result data; deployed by GitHub Actions.

### Automatic memory from benchmark runs

The benchmark now streams model-service memory from a configured model host during each ordinary run; see [runner setup](../README.md#run-memory-on-the-model-host). `publish.py add path/to/run.json` automatically includes its saved `memory` summary. No separate `--resources` option is needed for these runs.

`resources.kind = "run_samples"` records sampled run peaks for VRAM, service RAM, RSS and simultaneous RAM + VRAM, plus per-GPU peaks, configured context, runtime, KV cache, interval, sample count and complete/partial coverage. The exporter strips private host/service identifiers and GPU UUIDs. It refuses to combine resumed sessions from different deployments or physical GPUs. The page distinguishes run samples from the earlier `loaded_snapshot`; the old results are not backfilled with new measurements. Model weight size remains a separate field and slider.
