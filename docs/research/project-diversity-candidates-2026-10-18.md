# Broader project and task diversity: seventeen additional projects

**Follow-up direction:** the user's subsequent request prioritizes ordinary end-user applications. Use the [application catalogue](end-user-application-candidates-2026-10-18.md) for the current drafting priorities; the library/framework findings below remain research reserves.

Research date: **2026-10-18**, following the request for more cases in more projects. This pass documents concrete leads in **17 additional projects** beyond the earlier Livebook/Plausible, Ecto, Phoenix/LiveView, Plug, Oban, Absinthe, Broadway and Bandit investigations. Six main entries are worth drafting next, three are useful focused reserves, and eight have specific source, contract or execution holds. These counts describe research dispositions, **not admitted or functionally qualified cases**.

The expansion adds different work: request-dependent authentication, process ownership, typed error propagation, protocol serialization, structured document generation, macro evaluation, tree matching, dataframe operations, numerical tracing, streaming, browser session handoff and cache consistency. Four HTTP-client projects appear, but should not dominate the next release merely because their environments look convenient.

No project builds, test suites, fixture controls, model attempts, speed benchmarks or performance measurements ran. Research used primary source diffs, discussions, accepted ancestry and historical setup. All execution proposals below remain unverified. The prior rejection history and active inventory are unchanged.

## First drafting choices

For a varied drafting wave, prioritize **Guardian**, **Finch** and **ExDoc**, and retain **Jason** as a focused macro task. Guardian and ExDoc are sensible first new-project choices alongside an already-screened supported-project candidate under the existing small-pilot policy. Finch follows with a different lifecycle boundary. Tesla, Req and Mint supply additional options, rather than a reason to fill the whole wave with HTTP clients. This ordering reflects coverage and preparation uncertainty, not measured difficulty.

| Project and source | What the solver has to make consistent | Substantive implementation scope | Main remaining preparation work |
| --- | --- | --- | --- |
| [Guardian #748](https://github.com/ueberauth/guardian/pull/748) | Request-specific keys across header, session and cookie authentication; explicit missing keys must not silently use a global secret | 5 files | Pin local JWT/Plug environment; verify positive tenant-specific authentication and fail-closed lookup across every entry point |
| [Finch #391](https://github.com/sneako/finch/pull/391) | HTTP/1 and HTTP/2 worker termination, pool registration and optional metrics after resizing | 3 files | Synchronize Registry state so background cleanup cannot hide the defect; qualify local HTTP/2 fixture |
| [ExDoc #2270](https://github.com/elixir-lang/ex_doc/pull/2270) | User metadata survives XML escaping across package, cover and generated page documents | 3 executable templates | Generate/unzip an EPUB and parse decoded values; qualify local fixture/native test dependency. Compact repair, not high complexity inferred from three similar sites |
| [Tesla #939](https://github.com/elixir-tesla/tesla/pull/939) | Explicit secret values redact during inspection but preserve real credentials at middleware/adapter boundaries | 2 files | Freeze opt-in scope; pair non-disclosure checks with exact transmitted-value and ordinary-string preservation |
| [Req #337](https://github.com/wojtekmach/req/pull/337) | gzip/Brotli/zstd failures become typed errors through the normal request pipeline | 2 files | Prepare historical native codecs; test non-bang results and error steps, not only a raised exception |
| [Mint #514](https://github.com/elixir-mint/mint/pull/514) | IPv6 brackets and local zone handling agree across HTTP/1, HTTP/2, forward proxies and CONNECT | 5 files | State the zone policy, capture each local wire representation, and preserve DNS/IPv4/explicit headers |

The detailed [network-client report](network-client-candidates-2026-10-18.md) covers Tesla, Finch, Req and Mint. [Authentication research](auth-policy-candidates-2026-10-18.md) covers Guardian; [tooling/cache/mail research](tooling-cache-mail-candidates-2026-10-18.md) covers ExDoc. Each records exact source revisions, substantive path roles, draft outcomes, proposed preservation/partial controls, historical runtime and licenses, and follow-up searches.

“Draft next” does not mean the source reference has been proved correct. Examples of remaining discriminating work are Req's error-pipeline checks and Finch's synchronized cleanup observation. Native optional dependencies, common test helpers and excluded test tags also need actual qualification.

## Focused reserves that add different reasoning

These are intentionally small references. Keep them as a smaller part of the corpus, rather than combining unrelated fixes to meet a file-count target.

| Project and source | Distinct outcome | Scope / next gate |
| --- | --- | --- |
| [Jason #95](https://github.com/michalmuskala/jason/pull/95) | `json_map` values evaluate once at construction while later repeated encoding preserves the captured values and caller bindings | 1 implementation file. Strong macro/evaluation reserve; add exact-once and repeated-encoding witnesses and prepare historical dependencies. No memory or speed comparison is needed. |
| [Credo #1258](https://github.com/rrrene/credo/pull/1258) | A static check combines `use` syntax, conventional case-helper names and filename suffixes to warn about misnamed test files | 1 implementation file. State the naming heuristic and exemptions, invoke the check explicitly, and preserve unrelated `use` expressions. |
| [Ueberauth #217](https://github.com/ueberauth/ueberauth/pull/217) | OAuth request/callback state cookies retain integrity, including when cookies were already fetched | 1 implementation file plus a dependency-floor change. Use local provider fixtures, valid signed callbacks and invalid/unsigned cookies; retain disabled-protection compatibility. |

Jason is described in the [data/serialization report](data-serialization-candidates-2026-10-18.md), Credo in the [tooling report](tooling-cache-mail-candidates-2026-10-18.md), and Ueberauth in the [authentication report](auth-policy-candidates-2026-10-18.md). Mint #496 is another focused reserve within an already-counted project, involving CONNECT destination versus TLS identity; it is not an eighteenth new project.

## High-diversity candidates with concrete holds

These remain useful leads. Their limitations are specific work items, not reasons to erase the projects from future discovery.

| Project and source | Coverage contribution | What must be resolved |
| --- | --- | --- |
| [Floki #624](https://github.com/philss/floki/pull/624), optionally [#623](https://github.com/philss/floki/pull/623) + #624 | Descendant tree queries, parsing and Boolean selector composition; 2 substantive matcher paths for #624, 4 for the full pair | Contract/reference challenge for attribute-plus-class compounds such as `:has([data-x].marked)`. Explicitly scope supported inner syntax; do not promise full CSS `:has` conformance. |
| [Explorer #1138](https://github.com/elixir-explorer/explorer/pull/1138) | Null-equal joins across eager/lazy dataframes and an Elixir/Rust boundary; 4 runtime paths plus interface declarations | Offline pinned Rust/Polars build and loading the submitted NIF, never a prebuilt reference artifact. Strengthen right-join matched-payload assertions. |
| [Nx #1815](https://github.com/elixir-nx/nx/pull/1815) | Captured tensors, traced operands, gradients and backend selection; 1 implementation path | The Mix project lives in `nx/`; add explicit subdirectory support. Use small CPU BinaryBackend/Evaluator checks and avoid unrelated peer-node startup. |
| [Pow #650](https://github.com/pow-auth/pow/pull/650) | Completed writes become visible across ETS and Mnesia; 2 backend files | A deterministic interleaving must distinguish completed writes from early returns. The upstream async assertion assumes scheduler order, and a changed test file also contains an inadmissible speed assertion. Historical common setup uses PostgreSQL/Mnesia/EPMD. |
| [AshAuthentication #1187](https://github.com/team-alembic/ash_authentication/pull/1187) | Cross-site POST callback → same-origin form → existing browser session; 4 runtime/template paths | Real local browser/session witness; Elixir/OTP, native dependencies and PostgreSQL 16+ setup. Decide whether the later callback-cleanup correction belongs in the promised lifecycle. |
| [Cachex #407](https://github.com/whitfin/cachex/pull/407) + [#411](https://github.com/whitfin/cachex/pull/411) | Caller context across callbacks, queued operations, hooks and scheduled warmers; 7 implementation paths | Coherent larger corrected feature. Select the complete accepted correction range, resolve synthetic-source support, freeze dependencies without an upstream lock, and design deterministic recurring-callback checks. |
| [Swoosh #665](https://github.com/swoosh/swoosh/pull/665) | Attachment IDs through construction and two provider payloads; 3 implementation paths | Predicted default-CID regression for existing in-memory inline attachments. Establish a preservation witness and attributable corrected reference. Loopback provider endpoints can avoid real email delivery. |
| [NimbleCSV #59](https://github.com/dashbitco/nimble_csv/pull/59) | Arbitrarily chunked data → lazy lines → CSV parsing; 1 implementation path | Encoded-newline scanning may split UTF-16 at an unaligned byte position. Resolve the reference challenge or independently review an openly narrower encoding contract. |

The [data report](data-serialization-candidates-2026-10-18.md) details Floki, Explorer, Nx and NimbleCSV. The [authentication report](auth-policy-candidates-2026-10-18.md) details Pow and AshAuthentication. The [tooling/cache/mail report](tooling-cache-mail-candidates-2026-10-18.md) details Cachex and Swoosh. None of the source concerns above is represented as a locally executed failure.

## What the feature-plus-fix idea adds this time

- **Floki #623 + #624 is an actual adjacent upstream interval.** The matching PR's immediate parent is the parser PR's accepted commit. It demonstrates that a multi-PR capability can fit the present source model without a synthetic tree. The compound-selector contract concern remains independent of that clean ancestry.
- **Cachex #407 + #411 is a coherent corrected feature, but requires careful extraction.** #411 was rebased as ten accepted commits; its API “merge commit” identifies only the final one-file correction. The whole pre-feature interval also includes unrelated formatting edits. Neither endpoint metadata nor PR count alone identifies the right source patch.
- **AshAuthentication's later cleanup fix predates the POST feature as a defect.** Include it only if the task explicitly promises the broader callback lifecycle. A later edit in the same file is not automatically a regression caused by the feature.
- **Req's assigns feature was corrected and then reverted.** That lineage is recorded as deferred, not promoted because its initial PR was merged. Swoosh likewise remains held until its preservation concern is settled.

Exact identities and primary evidence for these points are in the linked reports. The [previous composition analysis](expanded-case-research-2026-10-18.md#the-current-source-verifier-what-already-works-and-what-needs-support) still governs synthetic selected-patch trees. This research did not change the importer or reconstruct these new composites.

## How to preserve variety when selecting the next cohort

Track the **behavior family**, not just repository names. Mint, Finch, Req and Tesla are different projects but share an ecosystem; Guardian and Ueberauth likewise share authentication concepts. Mix a protocol/lifecycle case with a document/data case and an application workflow. Keep previously researched application work such as Livebook's app-proxy/session feature in contention instead of replacing every application task with a small library problem.

Use both successful behavior and preservation as the selection lens: tenant A must authenticate as A; a resized pool must still serve requests; redacted credentials must still reach the adapter; malformed compression must reach the error pipeline; the EPUB must retain its decoded metadata; a valid join must contain the actual matching payload. This avoids cases whose “repair” is simply disabling a capability or dropping data, a lesson retained from the [old exclusion history](new-case-candidates-2026-10-18.md#do-not-rediscover-or-relabel-the-old-decisions).

Keep the native/data and browser leads visible while runtime support is developed. Replacing Explorer's Rust execution with a prebuilt binary, mocking away AshAuthentication's browser cookie behavior, or flattening Nx source without provenance would remove the property that makes those cases valuable. The existing policy favors preparing projects one at a time and reusing verified runtime families; this catalogue supplies choices for that sequence, not a new numerical quota.

## Evidence, exclusions and next stage

The four companion reports retain screened-out and focused alternatives, including mixed PR bundles, later reversions, missing assertions, unsupported historical setup and reference defects. They distinguish complete diff inspection from inventory-only screening. Ash core and Bodyguard received additional lighter screening in the authentication investigation; they are not counted among the 17 detailed project leads above. Search result totals are not eligible-case counts or projected admission yield.

Before adding any case, settle its visible contract, prepare exact offline source/runtime inputs, challenge the reference and plausible partial solutions, complete independent review and fresh qualification rounds, then obtain the existing two reviewed blind successes. None of those execution/admission gates is replaced by this research. All old accepted, rejected and deferred identities remain traceable in the earlier reports.

Companion evidence:

- [Network clients: Req, Mint, Finch, Tesla](network-client-candidates-2026-10-18.md)
- [Data and serialization: Floki, Explorer, Nx, Jason, NimbleCSV](data-serialization-candidates-2026-10-18.md)
- [Authentication and state: Guardian, Pow, AshAuthentication, Ueberauth](auth-policy-candidates-2026-10-18.md)
- [Tooling, cache and mail: ExDoc, Credo, Cachex, Swoosh](tooling-cache-mail-candidates-2026-10-18.md)
