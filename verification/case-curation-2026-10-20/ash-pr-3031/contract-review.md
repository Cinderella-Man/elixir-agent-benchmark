# Independent contract review: ash-pr-3031

- Reviewer: `/root/contract_review`
- Package author: `/root`
- Review date: 2026-10-20
- Review axis: requirements/specification, using the `code-review` skill
- Repository review base: `d9684ec85319e3c86be384f534ddd19af4b10562`
- Branch supplied for review: `codex/curate-researched-multifile-case`
- Solver source revision inspected: `abc634f5a725fadad850dacefc4284dd1d803fad`
- Decision: **APPROVE the contract and curated assertion mapping.** Runtime qualification remains a separate, pending gate.

## Requirements-first attestation

I first read `solver-contract.md` and ordinary source, documentation, and existing tests from the pristine source checkout. I did not inspect the reference implementation, upstream added tests, acceptance checks, research dossier, or PR diff during that phase. I sent the author my independently derived requirements and ambiguities before receiving authorization to inspect the proposed package.

Only after that report did I inspect `case.json`, `ticket.md`, `acceptance.patch`, `reference.patch`, `reference-tests.patch`, `incomplete.patch`, and `integrity.patch`. The solver contract and draft ticket are byte-identical. This review contains no solver execution or test-result claims. I ran read-only patch-application checks, source searches, and byte comparisons; I ran no tests, builds, speed measurements, or performance comparisons.

## Independently derived requirements

The ticket explicitly requires consistent valid scalar/array arguments and atom/string names across loads, filters, and sorts; preservation of cast and constrained literal values beside expressions; structured input errors for malformed containers, unknown names, and custom-type rejection; rejection of expressions through both `filter_input` forms; and preservation of ordinary calculations, coercion, and required/optional/default behavior, including normalized nil.

The source adds the following discoverable meaning:

1. Existing calculation arguments accept map/keyword forms, recognize atom/string names, and normalize indexed maps for arrays. See `lib/ash/query/query.ex:2556`, `lib/ash/type/helpers.ex:8`, and `documentation/topics/resources/calculations.md:131`.
2. `allow_expr?` controls whether an argument accepts expressions. Expressions use coercion, which deliberately differs from literal casting. See `lib/ash/resource/calculation/argument.ex:45`, `lib/ash/query/function/type.ex:25`, and `lib/ash/type/type.ex:420`.
3. Defaults apply to omitted arguments. Optional supplied nil remains nil; required supplied nil fails even when a default exists. Literal/function/MFA defaults are supported. The same rules must hold after normalization produces nil. See `lib/ash/resource/calculation/argument.ex:36` and `lib/ash/query/query.ex:2724`.
4. Type constraints may transform values. Supported scalar/array type failures include `:error` and `{:error, reason}`. Existing string-error handling retains the callback's reason. See `lib/ash/type/type.ex:267`, `:416`, `:446`, `:532`, and `lib/ash/query/query.ex:2699`.
5. Public invalid-input errors follow Ash's invalid error classification. The contract does not prescribe a particular leaf exception, error-list ordering, AST wrapper, helper name, file decomposition, or callback invocation count.

No requirement establishes precedence when both atom and string spellings of one argument are supplied. Recovery from arbitrary callback exceptions or unsupported return shapes is not implied.

## Curated hidden assertion mapping

Line references below identify lines in the reviewed `acceptance.patch`, including its patch header. Each row covers every assertion and loop expansion in that grouped test. “Invalid” means the public `{:error, %Ash.Error.Invalid{}}` result; it does not require a particular internal error representation.

| Group and patch lines | Assertions checked | Visible basis |
| --- | --- | --- |
| Literal arrays, 177–190 | Loading the nested calculation produces true for the matching ID and false for other records. Five developer filter paths return exactly the matching record: nested calculations with either array-expression permission, direct expression call, map input, and tuple input. | “mixing literal and expression arguments”; “valid scalar/array arguments”; “loads, filters and sorts.” Existing calculation/filter forms are visible in source. The two nonmatching records distinguish failed ID membership from failed date comparison. |
| String argument names, 192–200 | Map `filter_input` and tuple developer filters return the matching record; descending sort places it first; loads return true only for that ID. Timestamp text must cast successfully. | “atom/string argument names work consistently” and preservation of cast values; existing datetime casting and public sort semantics. No order is asserted between tied false records. |
| Array expressions, 202–207 | A tags expression filters to the record with nonnil tags and loads true for it. | Valid array arguments and supported expressions. Expression nodes must remain expressions rather than being treated as indexed literal maps. |
| User-input boundary, 209–217 | Literal arguments succeed in both map and tuple input forms; otherwise equivalent expression arguments yield Invalid in both forms. | Explicit `filter_input` map/tuple expression-rejection requirement. Literal acceptance prevents implementing the boundary by rejecting all calculation input. |
| Malformed filter containers, 220–224 | Both forms yield Invalid for nil, a string, a non-keyword list, and an integer. | “malformed argument containers … return structured input errors.” Nil is not required to fail specifically as a malformed container: treating it as no arguments still must fail because this fixture has required arguments. |
| Malformed sort containers, 227–230 | String, non-keyword list, and integer argument containers yield Invalid through `sort_input`. | Same explicit malformed-container requirement across sorts. |
| Unknown names, 233–236 | Integer, undeclared string, and undeclared atom names yield Invalid. | “unknown arguments … return structured input errors.” The check permits any appropriate invalid-input leaf error. |
| Normalized literals, 239–256 | A trimmed scalar and a custom string-to-map cast both load true beside an expression; their direct filters and a nested scalar calculation return both matching-title records and no other title. | “cast and constrained values survive beside expressions.” The custom type exposes discarded normalization or inappropriate recasting through observable values; no cast count or wrapper is asserted. |
| Nil/default semantics, 259–267 | With both literal and expression siblings, a blank string normalized to nil fails required arguments with and without a default; optional normalized nil succeeds; an omitted callback default succeeds; a valid trimmed literal succeeds. | Explicit “required/optional/default … including values normalized to nil,” plus source rules that defaults apply only to absent input. |
| Ordinary coercion, 270–272 | Explicit `type(" match ", :string)` preserves surrounding spaces. | Explicit “Preserve … expression coercion.” `Ash.Type.String.coerce/2` visibly uses `allow_empty?: true, trim?: false`; calculation literal normalization must not change that behavior. |
| Callback rejection matrix, 369–377 | Scalar constraint, array cast, array constraint, and nested-array cast rejections yield Invalid through each of load, filter, and sort (12 combinations). | Explicit custom-type rejection and scalar/array consistency requirements, including supported `:error` callbacks. Nested arrays are already supported by `Ash.Type`. |
| Valid custom populations, 380–395 | For scalar, array, and nested-array normalized values: both records remain present on load with true/false results; filters return exactly the matching record; descending sorts preserve both and order true before false. | Valid cast/constrained values and ordinary calculation/filter/sort semantics. The checks rule out blanket rejection, lost records, and constant calculation results. |
| Callback messages, 398–401 | The public result is Invalid and its message includes the reason supplied by the callback. | Structured custom-type errors plus preservation of existing string-error propagation in `query.ex`. The asserted text is fixture-provided diagnostic data, not a framework wording requirement. |

All 13 required identifiers in `case.json` match the grouped acceptance tests. The three declared requirement entries collectively map to every acceptance group. The four declared starting-failure identifiers are included in that set; whether they actually fail at the base is left to runtime qualification.

## Upstream supplemental tests and preservation

Both curated fixture/setup blocks are byte-identical to those in `reference-tests.patch` after the two module renames. The supplemental upstream assertions cover the same requirements:

- Literal-array nested/direct/map/tuple filters and loads correspond to the first curated group.
- String-keyed literal loads/filters/sorts correspond to the second group.
- Array-valued expressions correspond to the third group.
- User-input acceptance/rejection, malformed filters/sorts, and unknown names correspond to groups four through seven.
- Trimmed scalars, custom cast/constrained maps, literal siblings, normalized nil, default callbacks, ordinary coercion, and nested scalar filters correspond to groups eight through ten.
- Twelve callback-rejection combinations, three valid custom-type populations, and callback message retention correspond to groups eleven through thirteen.

The upstream file additionally requires a specific `NoSuchInput` leaf and the existing `"does not support expressions"`/`"is required"` substrings. Those are recognizable source conventions, but the curated solver acceptance appropriately does not make their exact spelling or leaf type a condition of success. The grading commands do not independently name `reference-tests.patch`; supplemental oracle tests must not silently become additional solver obligations.

Existing `test/calculations` and `test/sort/sort_test.exs` provide relevant preservation coverage. Their configured seed and bounded concurrency are compatible with functional qualification. This review does not establish their execution result.

## Coverage limits and fixture assessment

No blocking missing obligation or unfair implementation assumption was found. Coverage samples the contract rather than enumerating every combination. Indexed-map arrays, explicit nil, MFA defaults, direct rejection when an argument itself disallows expressions, and every malformed-input/entry-point combination are not individually covered by these 13 groups. These remain source-supported preservation expectations, not new hidden requirements or a claim of exhaustive validation.

`incomplete.patch` is byte-for-byte the reference implementation patch with only the `lib/ash/sort/sort.ex` section removed. It applies cleanly to the pinned source. Static inspection shows a plausible compilable partial fix: existing sort calls still use the unchanged `from_resource_calculation/3` API, and the removed sort helpers have no callers in retained changes. The partial therefore targets a real omission—sort container normalization/error classification—rather than an obvious unresolved symbol. **Actual compilation and behavioral rejection of that partial remain runtime gates.**

`integrity.patch` introduces a compile-time `System.halt(0)` in a new library file. It is an adversarial harness-integrity fixture, not an implementation candidate or a solver-visible requirement. Whether the harness rejects an early successful process exit without test evidence remains a separate qualification check.

The reference implementation's new option, type-wrapper metadata, and helper decomposition are implementation choices. Acceptance checks do not require them.

## Reviewed package hashes

SHA-256 values identify the exact draft reviewed:

| File | SHA-256 |
| --- | --- |
| `case.json` | `b535a1d3befee071f44951272ee376d67e013a86b95fb6ad43e6d6d8ae9b4630` |
| `ticket.md` | `892d6f1633f36b6a85ec158da2ce1b77401b8ac072b6bc054ba892e9e6192de8` |
| `acceptance.patch` | `7553bb9c30e0359d7e8d0d3aefd7c69edbc9fa4e8cfcfd728d193d24a45a8328` |
| `reference.patch` | `06e3d0584c23c9b69a8e473afb55b880339084d4e8a368102eaf40bf34f36430` |
| `reference-tests.patch` | `ef3d7c8a3392ec08cdf888c0dcd0ec44e564a4bad67b90395bdfecbd48e18e69` |
| `incomplete.patch` | `552acbfe4db0123df75888198526500028f77caa99694b1c54af491d750bbb1b` |
| `integrity.patch` | `3b954ff88ed1cfc58d47171917e5c338e8f613c7f046671bad164c0499718f42` |

## Final draft amendment review

Reviewer `/root/contract_review` independently reviewed the amendment supplied by author `/root` on 2026-10-20. **APPROVE the amended package identified by the final hashes below for the contract-review gate.** This approval applies to an immutable candidate containing these exact files; the preceding hash table and patch line references describe the initial draft.

The amendment does not change the requirements-first assessment or assertion mapping:

- `ticket.md` remains byte-identical to the contract read before hidden material.
- The saved pre-format acceptance body reconstructs the exact previously reviewed patch hash, `7553bb9c30e0359d7e8d0d3aefd7c69edbc9fa4e8cfcfd728d193d24a45a8328`. The formatted body is byte-identical to the body of the final acceptance patch. I independently parsed both bodies with `Code.string_to_quoted!/1` and compared them after recursively removing AST metadata; they are equal. No fixtures, assertions, or test semantics changed.
- All 13 required test identifiers still match the final acceptance tests, and the requirement links still cover exactly those identifiers.
- `starting_failures` now contains all ten names reported as failed by the pristine `empty_patch.hidden.test_results` in `exploratory-controls.json`. I compared these sets directly and confirmed that each reported failure phase is `test`. The earlier four-name placeholder was incomplete; retaining the initial invalid qualification evidence and creating a new immutable candidate is the appropriate correction.
- The environment clarification adds the user's existing functional-only machine constraint, including the prohibition on speed/throughput/latency benchmarks, performance comparisons, and timing commands. It adds no behavioral obligation to the code repair.
- The reference implementation, upstream supplemental tests, incomplete implementation, and integrity fixture retain their previously reviewed hashes. The provenance record identifies the same source pair.

The final acceptance groups begin at patch lines 182, 204, 232, 244, 265, 277, 284, 293, 321, 352, 451, 464, and 483, respectively, in the same order as the assertion-mapping table above.

### Exploratory evidence inspected

I inspected the named outcomes in `exploratory-controls.json`, which identify the **initial** candidate `a25d3e7fabd6772a0d2ce2de5d5e512a1cd1651d352a5236359f82a86c17c13d`:

| Control | Recorded named outcome |
| --- | --- |
| Pristine/empty patch | Hidden suite completed: ten failures and three passes; all ten failures are test-body failures. Preservation completed with 117 passes. |
| Reference patch | Hidden suite completed with 13 passes; preservation with 117 passes; submitted suite with 170 passes. |
| Partial repair | Hidden suite completed with only the malformed-sort group failing; preservation and submitted suites each completed with 117 passes. This supplies execution evidence that the partial compiled and reached the intended behavior check. |
| Early exit | Rejected; no completed suites or named test results were credited. |

These observations support the manifest correction and the intended positive/negative controls. They do **not** make the initial four-name qualification valid, and they do **not** substitute for the three fresh qualification rounds on the amended candidate. Those final rounds were still a separate pending gate at this addendum. I ran only source parsing and read-only comparisons during this amendment review, not tests, builds, or measurements.

### Final reviewed hashes

I recomputed each SHA-256 value and confirmed an exact match with `final-draft-hashes.json`.

| File | SHA-256 |
| --- | --- |
| `case.json` | `a62afa198835702983c6e0a6c2646875583ba9445aab1cf164cd0c3aeee0d2d6` |
| `ticket.md` | `892d6f1633f36b6a85ec158da2ce1b77401b8ac072b6bc054ba892e9e6192de8` |
| `acceptance.patch` | `9537f29ab5b06ef1b5364efd6eaa1695b386d4fe540047c0f94a24228fb39281` |
| `reference.patch` | `06e3d0584c23c9b69a8e473afb55b880339084d4e8a368102eaf40bf34f36430` |
| `reference-tests.patch` | `ef3d7c8a3392ec08cdf888c0dcd0ec44e564a4bad67b90395bdfecbd48e18e69` |
| `incomplete.patch` | `552acbfe4db0123df75888198526500028f77caa99694b1c54af491d750bbb1b` |
| `integrity.patch` | `3b954ff88ed1cfc58d47171917e5c338e8f613c7f046671bad164c0499718f42` |
| `provenance.json` | `58117a715899847d92340a05af5dc0e2f79b2a3bd1b500e429f83eb9d97c2257` |
