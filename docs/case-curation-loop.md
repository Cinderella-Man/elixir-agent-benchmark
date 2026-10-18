# Sequential case curation

`cases/` is the active set. `cases_approved/` is a temporary holding folder, excluded from runs. Folder membership determines the active set; `config/benchmark.json` only supplies defaults and a preferred ordering. New folders are discovered automatically.

For each researched candidate:

1. Develop and independently review its bundle, then complete three fresh matching fixture qualification rounds using the existing admission APIs.
2. Export it to `cases/<id>/`. It must be the only case folder there.
3. Run Astra twice through the ordinary Pi runner, with fresh contexts and matching frozen inputs/settings. Preserve and review both repairs and verification results, including any failed or interrupted attempts.
4. Once validated, move the unchanged case folder to `cases_approved/`, commit and push on the current branch, then take the next candidate.

When additions are finished, restore the folders manually:

```sh
mv cases_approved/*/ cases/
```

No case files, IDs or configuration need editing. Rebuild/recreate a running Docker controller as usual to pick up changed files. Keep it idle while changing case membership; frozen releases reject changes during a run.

All local qualification is functional work with bounded resources, never speed measurement. See [selection guidelines](pr-selection-guidelines.md), [admission APIs](case-admission.md), and the [application candidates](research/end-user-application-candidates-2026-10-18.md).
