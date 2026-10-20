# Wiring Xiaomi MiMo 2.6 Pro to elixir-swe-bench

**Date:** 2026-10-19  
**Question:** Can we run MiMo V2.6 Pro through this benchmark using the Xiaomi desktop subscription?  
**Status:** researched from local machine + benchmark source. **Not wired. No code changes.**

## What the benchmark actually accepts

From `lib/eab/model.ex`, `lib/eab/openai.ex`, `lib/eab/pi.ex`:

| Backend id | Detection | Protocol | Auth |
| --- | --- | --- | --- |
| `llama_cpp` | default if not strata | OpenAI-style chat completions **plus** llama.cpp extras | Bearer / x-api-key |
| `strata` | `GET /health` service=="strata" or `build_info` contains "strata" | Anthropic Messages (`/v1/messages`) | Bearer / x-api-key |
| `openai_subscription` | URL is exactly `https://api.openai.com` | OpenAI Responses (`/v1/responses`) | ChatGPT OAuth account |

`Eab.Model.discover/2` **requires** all of:

- `GET /health` → loaded model, context length
- `GET /v1/models` → active `model_alias` must appear in `data[].id`
- `GET /props` → llama.cpp-style props (`model_alias`, `model_path`, `build_info`, `default_generation_settings`, `chat_template`, …)

A generic OpenAI-compatible cloud API (just `/v1/chat/completions`) **fails discovery**. There is no Xiaomi / MiMo provider in this codebase.

## What the Xiaomi desktop subscription has

Checked locally under `%APPDATA%\Xiaomi MiMo AI\`:

| Artifact | Finding |
| --- | --- |
| `model-catalog.json` | Includes **`mimo-v2.6-pro`** (“MiMo V2.6 Pro”, TEXT) and `mimo-v2.6-flash`, plus ASR/TTS models. Account is present. |
| `preferences.json` | Desktop default model is already `mimo-v2.6-pro`. |
| `desktop-api.json` | Local helper on `127.0.0.1:<port>` with a session token. Probed `/v1/models`, `/health`, `/props`, `/v1/chat/completions` → **all 404**. This is **not** an OpenAI/llama.cpp server. |
| `~/.config/mimocode/mimocode.jsonc` | Empty schema only — no custom provider pointing at Xiaomi. |

Hugging Face org `XiaomiMiMo` publishes **MiMo-V2.6-Pro-RL / Pro-MOPD at ~1T parameters**. That cannot run on this 16 GB laptop. Use must be **cloud/API**, not local weights.

## Bottom line

**Not out of the box.** The desktop subscription exposes MiMo 2.6 Pro to the MiMo Desktop/MiMoCode app, not as an HTTP model server the benchmark can discover. ChatGPT path is OpenAI-only (`assert_endpoint!` hardcodes `https://api.openai.com`).

## Feasible wiring paths (none done)

### A. Thin llama.cpp-shaped shim (no benchmark code change) — **best if an HTTP API exists**

If you can obtain an OpenAI-compatible (or other) HTTP endpoint for `mimo-v2.6-pro` from Xiaomi (developer portal / API product — homepage markets “API Access”, exact base URL not verified here):

1. Run a small local proxy that implements:
   - `GET /health` → `{"loaded":true,"status":"ok","context_length":<N>}`
   - `GET /props` → llama.cpp-like `model_alias`, `default_generation_settings.n_ctx`, `build_info`, …
   - `GET /v1/models` → `{"data":[{"id":"mimo-v2.6-pro",...}]}`
   - `POST /v1/chat/completions` (+ `POST /v1/chat/completions/input_tokens` for counting) → forward to Xiaomi API
2. Point the dashboard at `http://127.0.0.1:<shim-port>` as **Local server**.
3. Document identity honestly: server-reported, not a weight checksum.

Pi gateway (`Eab.PiGateway`) only special-cases `openai_subscription` and `strata`; a shimmed `llama_cpp` path uses the existing chat-completions transport.

### B. Extend `Eab.Model` / `Eab.Pi` with a `xiaomi` or generic `openai_compat` backend

- Discovery: skip `/props` or accept OpenAI `/v1/models` only.
- Transport: chat completions or whatever Xiaomi’s API uses (OpenAI-compatible is common).
- Keep accounting (input/output/reasoning tokens) on the same footing as other backends.
- This is **real product work** in the benchmark, not a config tweak.

### C. Serve weights yourself with llama.cpp

Only for open weights that fit (e.g. Distill-Qwen-9B). **Not** V2.6 Pro (1T). Out of scope for this machine.

### D. MiMoCode capability API (`mimo llm-server`)

MiMoCode can mint OpenAI-compatible `/v1` tokens over the configured models (`provider/model` form). Even then, elixir-swe-bench still needs `/health` + `/props`, so path A’s shim would still sit in front. Also: `mimo` CLI was not on this shell’s PATH; desktop session tokens are process-local.

## Subscription vs API product

Desktop subscription ↔ MiMo Desktop/MiMoCode UI. A **developer API** (the site’s “API Access”) is typically a separate product/key. Confirm with Xiaomi whether your subscription includes a machine-callable HTTP API for `mimo-v2.6-pro`. Do **not** scrape the desktop app’s private helpers.

## Recommended next steps

1. Confirm whether your Xiaomi account can call an HTTP inference API for `mimo-v2.6-pro` (base URL + API key + OpenAI-compatible?).
2. If yes → implement path **A** (local shim) and smoke-test `Eab.Model.discover` against it.
3. If no → either buy/use API access, or run a smaller open MiMo (e.g. Distill-9B) via llama.cpp for a pilot; Pro is not local.
4. Optional product work: path **B** so the dashboard lists Xiaomi next to ChatGPT / Local.

## Evidence (local, 2026-10-19)

- `model-catalog.json` entries: `mimo-v2.6-pro`, `mimo-v2.6-flash`
- Desktop helper port from `desktop-api.json`; standard OpenAI/llama.cpp routes returned `{"code":"not-found"}`
- Benchmark source: `lib/eab/model.ex` (`discover/2`, backends), `lib/eab/openai.ex` (`@url "https://api.openai.com"`), `lib/eab/pi.ex` (provider wiring)
