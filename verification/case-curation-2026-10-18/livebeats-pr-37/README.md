# LiveBeats 37 curation

Status: approved after three fresh matching qualification rounds and two reviewed fresh Astra successes. The unchanged bundle is parked in `cases_approved/livebeats-pr-37/`. Only this case was active for its two model runs.

The bounded feature displays the current song title and artist in the browser tab and native Media Session metadata, updates them when songs change, restores the ordinary title on Stop Listening and preserves playback/tab behavior without the optional API. The source pair is `a94cf610dae100ac0c6a8aa45a1e41ed67f1c93d` → `d25554632f960a959a4d1c60abf09be804cb298c`. Exact upstream tree reconstruction passed. See the [requirements-first review and amendment history](../../../docs/research/livebeats-37-contract-review-2026-10-18.md).

The runtime uses pinned Elixir 1.14.5/OTP 25.2.3 on Ubuntu 24.04, within the project's declared Elixir range, to support the existing pinned offline Chromium recipe. Historical Phoenix/LiveView and asset-tool dependencies remain locked. PostgreSQL 14.5, real signed application sessions, generated local WAV files and the actual tokenized file endpoint replace external accounts/media. The unrelated Ping hook is disabled to avoid latency measurement. No performance claims are derived from routine logs or watchdogs.

## Preparation and qualification history

- An initial runtime-only call lacked `provenance.json` and stopped before building. Adding the real pinned source/tree record allowed the historical project, dependencies, assets and pristine database baseline to build.
- Independent review corrected an unexecuted draft: fallback playback alone did not check unconditional tab-title behavior; the revised assertion covers title lifecycle and stale-song replacement. A duplicate fixture response send was removed before tests ran.
- Version `1a38632208daf9a381d97de015904a0ac620a6af6f5a7df1574ec3d4cc91fd17` failed qualification. Every playback witness failed in both starting and reference code, while the access-control witness passed. This is invalid fixture evidence, not a feature failure or model attempt. [Sanitized named outcomes](invalid-controls-1.json) bind the retained raw controls under that version in the controller data volume.
- Two local diagnostic executions established HTTP 500 from a wrong fixture audio path: the existing application helper adds a `songs/` subdirectory. The fixture now uses that helper for directory and filenames. Code inspection also showed that the grader's pre-test commands execute before patch application; asset rebuilding therefore moved into protected suite setup after the patch is present. The helper synchronizes actual playback or the application's visible autoplay prompt. No feature assertion was relaxed. Both diagnostics and the initial controls remain retained.
- Version `9f6cfbe9f302e82316a651ba153ed5cefaa7678e1c26f3671cc53f0f9a5f65bc` contains those independently reviewed environment corrections. The initial corrected round passed: reference 3 acceptance/2 preservation/3 submitted tests; unchanged fails all three feature assertions; server-only partial fails only native media metadata and passes both preservation checks; early exit is rejected. All three fresh rounds matched; their exports remain under [pre-suffix-amendment](pre-suffix-amendment/qualification-round-1.json). No model ran against this draft.

- Before model validation, a final static audit found that the narrower `_test.mjs` suffix could exclude legitimate edits to the visible `preservation.mjs` suite from behavioral regression proof. Version `a9bcc81b844cf5727f0540874d609141743fbd84c19edd367ccce1f6a227c815` changes only that manifest field to `.mjs`; independent review approved it. Assertions and all other artifacts are unchanged. All three fresh rounds for this final version passed with matching named outcomes, phases and failure types. See [round 1](qualification-round-1.json), [round 2](qualification-round-2.json) and [round 3](qualification-round-3.json). Prepared images were reused; each control received fresh isolated workspace/service state.

Existing approved cases stayed excluded throughout. The bundle can be restored by moving its folder back into `cases/`, with no configuration edits.

A model-catalogue connection error occurred before the first launch, creating no attempt. The read-only lookup was retried successfully. The first actual run uses the ordinary Pi runner with `gpt-6-astra`, high reasoning effort, a 262,144-token response-boundary soft threshold, compaction disabled and no automatic retries.

## Two fresh Astra runs

| Run | Calls | Generated tokens | Acceptance / preservation / submitted | Review |
| --- | ---: | ---: | --- | --- |
| `20261018-112222-d26a9986` | 15 | 3,396 | 3 / 2 / 4 passed | [Repair 1](astra-1-review.md) |
| `20261018-112715-6649a5da` | 25 | 4,675 | 3 / 2 / 4 passed | [Repair 2](astra-2-review.md) |

Both runs completed with cleanup finished, verified sealed receipts, verified usage ledgers and behavioral regression coverage. They used the same frozen release, experiment, settings, prompts, runtime, qualification and initial request (excluding distinct session keys). No serving revision is available, so this establishes matching recorded inputs, not a claim about an unpublished backend revision. [Machine-readable results](astra-results.json).

Both repairs are valid client-side alternatives to upstream: title/artist flow through the existing play event and the browser updates title and native metadata. Their additional pause clearing and navigation handling are permitted choices, not extra hidden requirements. Existing preservation assertions remain intact. Parent and independent review found no actionable semantic defect, test weakening or grader shortcut. Submitted patches are retained as [repair 1](astra-1.patch) and [repair 2](astra-2.patch).

The promoted artifact hashes match the qualified admission record; [all bundle hashes](bundle-sha256.json) also bind the admission receipt. Qualification, not model output, remains the source of the reference fixture. No third model attempt was run.
