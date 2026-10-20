# Source and fixture review

## Prepared fork selected by the user

The final case uses [Cinderella-Man/ash](https://github.com/Cinderella-Man/ash), with [fork PR #1](https://github.com/Cinderella-Man/ash/pull/1) preserving the prepared source pair:

| Role | Branch | Commit |
| --- | --- | --- |
| Broken prepared baseline | `codex/ash-pr-3031-benchmark` | `91d0b01085167e31193e93541623ef48c9f762b8` |
| Reference repair | `codex/ash-pr-3031-reference` | `ef09550410abc5444c3efc41b4c4b0f7c5a7c12a` |

The baseline is the actual upstream parent plus three neutral preparation paths: `.tool-versions`, `test/test_helper.exs`, and `test/support/line_buffered_io.exs`. It pins the already validated runtime, installs the reviewed line-buffering adapter, and defaults ExUnit to seed 0 and two concurrent cases. Application code, dependencies and the existing focused tests are unchanged. The reference commit replays the accepted upstream repair with original authorship. Both retained reference patches are byte-identical to the upstream diff.

The benchmark needs no `environment.patch`: preparation is already present in the pinned source. Plain focused `mix test` commands suffice; the ordinary grader also supplies seed 0. Tree IDs, adapter equivalence and branch/PR details are retained in [fork-preparation.json](fork-preparation.json). The following upstream review explains the authentic repair from which this fork pair was derived.

## Accepted upstream repair

The candidate was selected from the [existing research](../../../docs/research/new-candidates-2026-10-19/ash-3031-calculation-arguments.md) and [deep dive](../../../docs/research/new-candidates-2026-10-19/deep-dive-ash-3031.md). No prior `ash-pr-3031` bundle existed in active or rejected inventory. GitHub's live PR API confirms [PR 3031](https://github.com/ash-project/ash/pull/3031) was accepted as squash commit `190987ec134a6a01b72d3eb8d9dcb26577b15873` on 2026-10-15; a search cache still showed the earlier open state. The immutable Git object establishes the source identity.

The research's branch base `bc4f2bbd99ca4a2077908a49f036a65dc42b5828` is not the accepted commit's parent. Using it would import unrelated signal, tenant and action changes. The actual parent is `abc634f5a725fadad850dacefc4284dd1d803fad`, tree `79fd67fae33f72492146b09d4f3ab30d7e3c6bb6`. The fixed tree is `bd766f9d5d7af701358373166ae9ed047b3cc57f`. The reference and exact upstream test patches reconstruct this fixed tree.

Five substantive implementation files coordinate one argument-validation contract:

| File | Responsibility |
| --- | --- |
| `lib/ash/query/calculation.ex` | Calculation construction and permitted argument options |
| `lib/ash/query/query.ex` | Literal/expression validation and normalized values |
| `lib/ash/filter/filter.ex` | Filter call forms and the user-input expression boundary |
| `lib/ash/query/function/type.ex` | Evaluation of already validated literals |
| `lib/ash/sort/sort.ex` | Calculation sort input normalization and errors |

The sixth changed file is the upstream calculation-argument test suite. Tests are counted separately. Model submissions may legitimately touch fewer files.

Upstream author: `barnabasJ`; accepted in `ash-project/ash`. The snapshot retains the upstream SPDX copyright headers and `LICENSES/MIT.txt`. `reference-tests.patch` is the exact upstream addition. The curator `/root` derived independent grouped acceptance assertions from those fixtures, preserving their SPDX headers. The ticket expresses outcomes without naming the PR, affected paths, private AST fields or the reference's repair strategy. The independent review is recorded separately.

The later commits flagged in discovery were inspected: `da464b83` adds calculation authorization, `5b7d8ec2` changes aggregate/sort type determination, and `8922691a` adjusts return type specifications. They concern different contracts; they are absent from this pinned pair and are not silently folded into the reference. This bounded review does not claim an exhaustive search of all later upstream defects.

Acceptance uses private ETS resources, fixed timestamps and UUID fixture values, and seed 0. It exercises real Ash query construction and execution. Preservation uses the existing calculation directory and sort suite. No database, cloud account, browser, network data or sleeps are needed. Elixir 1.20.2 / OTP 29.0.5 is pinned by image digest, with locked upstream dependencies; the source's `.tool-versions` specifies the 1.20/29 family. Erlang schedulers are bounded at two and native make uses `-j2`. Manifest commands use ExUnit concurrency two; selected regression probes initially used the runtime default of four. The amended environment sets the default to two as well.

The earlier candidate used a neutral test-output environment overlay, documented in [reporter-diagnosis.md](reporter-diagnosis.md). The user-requested fork now includes that reviewed adapter in its baseline source, with an SPDX header. It prevents partial output from one formatter joining another formatter's complete line, without changing reporters or assertions. This preparation is separate from the five-file upstream application repair.

The incomplete control is the complete reference minus the sort implementation change. It is intended to leave valid filter/load behavior fixed while malformed sort containers still fail. The integrity control adds a compile-time early exit after the reference, which must be rejected as an incomplete suite. Neither control's success is assumed before executable qualification.
