# Reference implementation scope — 2026-10-15

The eleven cases in [`elixir-agent-benchmark-v3`](../../config/benchmark.json), inspected at commit `489b968eb2d9ce2e85489e8a1c290c1fc9ca6036`, are skewed toward one-file implementations. **Seven of eleven reference patches touch one implementation path; three touch 3–4; one touches eight.** This supports prioritizing coordinated multi-file work during expansion.

This is a static patch audit, not a model evaluation, fixture requalification or measure of difficulty. A small repair can require substantial investigation. Counts describe the reference, not the number of files a valid model solution must edit.

## Counts

The implementation columns come only from each case's `reference.patch`. Tests, acceptance overlays and documentation are excluded. Added/deleted lines are raw patch churn, including whitespace; they are not a difficulty score. Paths are reported as represented in these patches, including a deleted/moved path in Plausible 5956.

| Case | Implementation paths | Added / deleted lines | Scope visible in reference |
| --- | ---: | ---: | --- |
| [Plausible 5939](../../cases/plausible-pr-5939/reference.patch) | 1 | 1 / 0 | Domain-change permission in one LiveView |
| [Plausible 6763](../../cases/plausible-pr-6763/reference.patch) | 1 | 1 / 1 | One query-optimizer condition |
| [Plausible 6449](../../cases/plausible-pr-6449/reference.patch) | 3 | 34 / 11 | Shared-link schema, context and form |
| [Plausible 6441](../../cases/plausible-pr-6441/reference.patch) | 3 | 76 / 50 | Goals and imported-query modules |
| [Plausible 5956](../../cases/plausible-pr-5956/reference.patch) | 8 | 184 / 88 | Tracker caches, lifecycle and consumers, including deleted old cache path |
| [Livebook 2219](../../cases/livebook-pr-2219/reference.patch) | 4 | 31 / 8 | Notebook/cell traversal and two LiveViews |
| [Livebook 2527](../../cases/livebook-pr-2527/reference.patch) | 1 | 17 / 5 | Signed Markdown import |
| [Livebook 2663](../../cases/livebook-pr-2663/reference.patch) | 1 | 10 / 4 | Markdown list formatting |
| [Livebook 2800](../../cases/livebook-pr-2800/reference.patch) | 1 | 4 / 23 | Erlang diagnostic formatting |
| [Livebook 2822](../../cases/livebook-pr-2822/reference.patch) | 1 | 14 / 2 | Evaluation-context retention |
| [Livebook 3076](../../cases/livebook-pr-3076/reference.patch) | 1 | 2 / 1 | Storage-form ownership initialization |

All eleven are bug-fix tasks from two applications. Seven single-path references are about 64% of this inventory. This describes this selected corpus only, not the distribution of professional developer work.

Plausible 5956's eight paths should not be read as eight independent implementation components: the patch removes `lib/plausible_web/tracker_script_cache.ex` and introduces cache code under `lib/plausible/site/` and `extra/lib/`. New candidate reviews should explain moves/splits and count renames once. The conclusion that this reference lies outside the 2–5-file center does not depend on counting the deleted path separately.

## Reproduce the raw counts

Run from the repository root. `git apply --numstat` reads patch statistics without applying the patch.

```sh
python3 - <<'PY'
import json
import subprocess
from pathlib import Path

for case in json.loads(Path("config/benchmark.json").read_text())["cases"]:
    patch = Path("cases") / case / "reference.patch"
    rows = subprocess.check_output(
        ["git", "apply", "--numstat", str(patch)], text=True
    ).splitlines()
    counts = [row.split("\t", 2) for row in rows]
    print(case, len(counts), sum(int(row[0]) for row in counts),
          sum(int(row[1]) for row in counts))
PY
```

The existing cases were not edited or regraded for this audit. Their prompt/fairness questions and unperformed strong-model validation remain separate; in particular, Plausible 6449's multi-file shape does not resolve its [documented policy ambiguity](../design-tree.md#subscription-model-validation--design-interview-2026-10-15).

Use the [PR selection guidelines](../pr-selection-guidelines.md) to shape new additions. Keep historical scores tied to their original releases rather than removing small cases to change the distribution retroactively.
