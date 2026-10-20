# Ash 3031 curation

Status: in progress. Branch `codex/curate-researched-multifile-case`, main base `d9684ec85319e3c86be384f534ddd19af4b10562`. Selected from the already researched Ash 3031 dossier; not previously admitted or rejected.

The actual first parent is `abc634f5a725fadad850dacefc4284dd1d803fad`, fixed squash commit `190987ec134a6a01b72d3eb8d9dcb26577b15873`. The discovery note's `bc4f2bbd` base is older and includes unrelated changes. The corrected pair changes five implementation files and one upstream test file. MIT notice is at `LICENSES/MIT.txt`.

All 13 original bundles are parked under `cases_approved/`; their complete original hashes are retained in `original-inventory.json`. Draft is `.local/ash-curation/draft`; source is `.local/ash-curation/source`. No model run has started. The controller was idle with no cleanup error and no other workload containers before parking. Rebuild controller, prepare immutable draft, record independent requirements-first review, execute three fresh qualification rounds, export, disable observer inside idle controller, and run Astra twice. Restore all bundles/controller before finishing.

## Preparation checkpoint

Initial immutable exploratory candidate: `a25d3e7fabd6772a0d2ce2de5d5e512a1cd1651d352a5236359f82a86c17c13d`. Source reconstruction passed. Qualification is running via `/tmp/ash-qualify.exs` in the controller and uses `/data/candidates/ash-pr-3031/<version>/files`; the controller inventory is empty. The exact pristine failure list will be taken from executed controls before the final candidate is imported. The initial draft's four-name expected-failure list is provisional. The hidden checks have since received formatting only, for readability; their semantics are unchanged.

Independent requirements-first contract review approved the initial package. Updated manifest/check formatting will receive an addendum before final admission. No model has run; the image's normal timing observer remains installed until singleton model validation. Current preparation uses bounded schedulers/native compilation and no speed evaluation.

Retained execution scripts `repeat-qualification.exs`, `export-qualification.exs`, `validation-preflight.exs`, `start-astra.exs`, and `export-astra.exs` are intended to run through `bin/eab rpc` with `Code.eval_file` after copying them into the controller. They reference the current candidate pointer under `/data/curation/ash-pr-3031-current.json`, retain original receipts, and refuse invalid gate transitions.
