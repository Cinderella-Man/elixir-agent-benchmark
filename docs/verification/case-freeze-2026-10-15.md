# Eleven-case freeze — 2026-10-15

This record covers the eleven current cases, including the clarified Plausible 6449 ticket. Its scope is executable fixture repeatability and frozen inputs. Blind model solvability is a later gate.

## Functional evidence

**All eleven cases passed three fresh full qualification rounds (132 expected control outcomes)** through the ordinary qualification path, using isolated data, one preparation worker and one case at a time. Each round accepted all eleven references and rejected all eleven unchanged, early-exit and incomplete controls: 33 accepted references and 99 correctly rejected negative controls across the three rounds. The exporter checks every normalized named test outcome, exclusion and failure phase against the first round; aggregate scores alone are insufficient.

The ExUnit order seed is `0`. Qualification receipts are archived between rounds and never reused. Prepared immutable project and database images are reused. The host clock remains live. These checks do not establish absence of flakiness under every seed or environment, or complete coverage of valid alternative implementations.

## Frozen inputs

[The freeze package](../../verification/frozen-cases-2026-10-15/README.md) contains a release manifest, case checksums, runtime and service image identities, source revisions, dependency-lock checksums, Pi configuration, actual initial model payloads and a read-only verifier. Exact case tests and prompts remain versioned under `cases/` and are bound by the release manifest. The frozen release is `9a5256a9d0d791c4384a3859b1bf353843dd5bc858919b4d76da42df84c2378d`, matching the deployed controller. The read-only verifier passed; it checks case, runner, Pi, build configuration, input and evidence identities, including all three rounds against the exported named outcomes.

Pi is `@earendil-works/pi-coding-agent` **1.2.0** with the recorded lockfile. A regression test revealed that Pi expanded its ticket file using a random temporary directory. The bridge now uses a stable ticket path within each isolated workspace. Two fresh real Pi processes produce identical initial prompts and tool schemas. This repair and the dashboard's explicit provider chooser do not change the fixture grader; the exported evidence binds both qualification and final runner identities.

The provider chooser, cancellation behavior, callback, model transport and stable Pi input were checked with 30 passing targeted tests (`mix test test/eab_web/chatgpt_test.exs test/eab_web/dashboard_test.exs test/eab/pi_test.exs test/eab/openai_test.exs --seed 0`). The deployed production build passed `mix compile --warnings-as-errors`. Desktop and 390-pixel mobile layouts were inspected in the browser.

Initial payloads are captured by intercepting the real Pi request locally before provider access. No solver tools execute and no reference solution or hidden check is supplied. This is input inspection, not a model attempt or a new solver flow. Pi generates a fresh cache-affinity key per session; the captured value is retained, while prompt text and tool schemas are stable. The freeze does not claim identical complete network requests or cache behavior between attempts.

## Intended model validation

The recorded target is **`gpt-6-astra`**, **high** reasoning, with a **262,144 generated-token soft threshold per case**. Reasoning tokens count in output usage. The threshold is checked between completed responses, so the final response can exceed the remaining allowance. Context and response limits are provider-enforced; no deterministic sampling seed or fixed serving revision is claimed. Compaction and automatic Pi retries are disabled. The plan requires two fresh ordinary runs, preserving unsuccessful and interrupted attempts and reviewing successful patches.

The connected account's catalog includes the target, and one small response completed through the production subscription transport: HTTP 200, 11 input tokens and 5 output tokens. The [sanitized connection receipt](../../verification/frozen-cases-2026-10-15/inference-check.json) records this separately from case attempts. No blind model validation attempt was performed here. The target follows [official model documentation](https://developers.openai.com/api/docs/models/gpt-6-astra) and is resolved against [the connected account's catalog and inference access](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference). Select ChatGPT in the dashboard, sign in, select the resolved model and use the existing Run button. A different target or changed settings requires a new recorded input version.

Even two successful blind attempts provide solvability evidence, not proof that every later failure is attributable only to the model. These public historical cases may have appeared in training data.
