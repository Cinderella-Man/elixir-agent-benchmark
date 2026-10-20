# Preservation amendment review

Author `/root`; independent reviewer `/root/contract_review`; 2026-10-20. Requirements/specification axis of the existing code-review workflow.

Decision: approve the contract and assertion mapping, conditional on complete functional confirmation. Runtime qualification and fresh model validation remain separate gates. The reviewer read the unchanged ticket and public starting-source contracts before opening the added assertions.

The typed-normalized-literal fixture maps input 2 to 6. Comparing this value against an attribute holding 6 must retain its meaning beside an expression argument. Loaded results and filtered records are observable outcomes; the assertions impose no wrapper, metadata shape, helper, or callback count.

The starting tuple parser converts nil to an empty map. Checking omitted arguments receive defaults through developer filtering and `filter_input` preserves established behavior. It remains consistent with the existing required-argument check: omission without a required argument's default still fails.

A valid alternative can pass both without matching the reference representation. The previous 13 groups and all other package files are unchanged. Only the two checks and their manifest mappings were added. Reviewed SHA-256 values:

- `case.json`: `b8da601f39461d6e47a41368cf3a0eeb808d9eca71ab92f0ab5df7021b284c29`
- `acceptance.patch`: `152367e0306670c43d5422403b543f5b11c8fd63b4fb5850959250c21bc4ab87`

The root curator must confirm reference success, pristine starting failures, the diagnosed sealed-submission failures, and meaningful controls. Import creates an immutable draft; three complete fresh qualification rounds must enforce those control conditions before admission. The original first attempt and its passing official grade are retained on their original candidate. This reviewer ran no commands that mutate state, tests, builds, qualification or model calls.

Functional confirmation completed: reference passes both added checks, pristine preserves nil/default behavior and fails normalized comparison, and the sealed first submission fails both with test-body assertion failures. See `first-submission-probes.json`. Full three-round controls remain required for the imported amendment.
