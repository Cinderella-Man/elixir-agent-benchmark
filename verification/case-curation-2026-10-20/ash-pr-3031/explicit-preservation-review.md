# Explicit preservation wording

Author `/root`; independent requirements-first reviewer `/root/contract_review`; 2026-10-20. Decision: **approve for import**.

The first run on the stronger-check version, `20261020-160506-224bb2fa`, completed and failed exactly the two added preservation checks. Both independent reviewers also identified those defects in its sealed patch: nil tuple containers lost omitted/default semantics, and typed operator hydration could recast normalized literals. No existing tests were weakened and no grading shortcut was found. This is a model failure, not an infrastructure interruption. Its official failed grade, patch, named outcomes and receipts remain in `astra-amended-1.json` and `astra-amended-1.patch`.

Two independently generated repairs have now missed these existing requirements. The next version makes their observable scope explicit in the ticket and corresponding requirement descriptions:

> Normalized literals must retain their values in typed comparisons inside calculation expressions, including beside expression arguments. A nil argument container in a tuple filter means omitted arguments and must still apply defaults.

The reviewer read the revised visible contract before the checks and confirmed that this is a minimal clarification of existing public behavior. It prescribes no representation, helper, callback count or repair strategy. Alternative implementations remain valid. Directory comparison confirmed only `ticket.md` and two requirement descriptions in `case.json` changed; all 15 checks, source, runtime, references and incomplete/integrity controls remain unchanged.

Reviewed SHA-256:

- `case.json`: `ab0d8eaaf8d66eaf9988f6479084a4b4c38469cc9ddbd37c30292fb687fc3efe`
- `ticket.md`: `b94486381d4c3edef6170c0a0a03a1bd8ab9c577409618513891233e8afcb8fa`

The new immutable candidate is `09528c895206c98feddc652314bef1da31dd72ee7e870218b187bb1ec704f394`. Both earlier attempts remain attached to their original versions and do not count toward its validation. Three fresh controls and two new ordinary blind solver runs are required. New solver contexts receive only the revised public task/source, with no previous patch, hidden check, failure trace or reference solution.
