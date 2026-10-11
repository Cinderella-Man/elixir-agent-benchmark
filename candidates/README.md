# Historical repair source packages

These twelve source packages use actual merged upstream fixes. Their broken branches point directly to original upstream pre-fix commits in the user's [Plausible fork](https://github.com/Cinderella-Man/plausible-analytics) and [Livebook fork](https://github.com/Cinderella-Man/livebook); no source defect was invented or transplanted. Each case therefore has its own historical source baseline.

**Current implementation:** executable counterparts live under `cases/` and are included by default in the single benchmark. See the [Plausible integration](../docs/plausible-integration.md) and [Livebook integration](../docs/livebook-integration.md). This directory preserves the source-review snapshots: `candidate.json` statuses and Plausible's `qualification.md` notes describe that earlier phase, and their artifact hashes remain intact. Current runtime admission facts live with the integration, not in these frozen source drafts. Model/context feasibility remains separate from runtime fixture controls.

| Candidate | Real problem | Broken branch |
| --- | --- | --- |
| [#6300](plausible-pr-6300/candidate.json) | Today/Last 24h ignore weekday matching | [codex/bug-pr-6300-weekday-comparison](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6300-weekday-comparison) |
| [#5939](plausible-pr-5939/candidate.json) | Editors cannot change a site's domain | [codex/bug-pr-5939-editor-domain-change](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-5939-editor-domain-change) |
| [#6763](plausible-pr-6763/candidate.json) | Page-filtered dashboard CSV export crashes | [codex/bug-pr-6763-filtered-csv-export](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6763-filtered-csv-export) |
| [#6449](plausible-pr-6449/candidate.json) | Shared-link edits accept an altered token or foreign segment | [codex/bug-pr-6449-shared-link-boundaries](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6449-shared-link-boundaries) |
| [#6441](plausible-pr-6441/candidate.json) | Property-restricted goals crash or overcount imported data | [codex/bug-pr-6441-imported-goal-properties](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6441-imported-goal-properties) |
| [#5956](plausible-pr-5956/candidate.json) | Dedicated CE tracker scripts fail after configuration changes | [codex/bug-pr-5956-ce-tracker-cache](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-5956-ce-tracker-cache) |
| [#2219](livebook-pr-2219/candidate.json) | Inputs introduced through frame updates render blank | [codex/bug-pr-2219-frame-inputs](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2219-frame-inputs) |
| [#2527](livebook-pr-2527/candidate.json) | Altered notebooks retain stamp authorization | [codex/bug-pr-2527-notebook-stamps](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2527-notebook-stamps) |
| [#2663](livebook-pr-2663/candidate.json) | Long numbered lists lose nested content | [codex/bug-pr-2663-nested-numbered-lists](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2663-nested-numbered-lists) |
| [#2800](livebook-pr-2800/candidate.json) | Erlang syntax errors fail during diagnostic formatting | [codex/bug-pr-2800-erlang-diagnostics](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2800-erlang-diagnostics) |
| [#2822](livebook-pr-2822/candidate.json) | Failed evaluation erases earlier context | [codex/bug-pr-2822-failed-evaluation-context](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-2822-failed-evaluation-context) |
| [#3076](livebook-pr-3076/candidate.json) | The real S3 storage form cannot save | [codex/bug-pr-3076-s3-storage-form](https://github.com/Cinderella-Man/livebook/tree/codex/bug-pr-3076-s3-storage-form) |

The table order is the proposed runtime-qualification order. The [research note](../docs/plausible-pr-candidates.md) contains evidence, alternatives and historical environment differences. The [expansion plan](../docs/large-codebase-expansion.md) records the behavioral scoring and context requirements.

## Files in each draft

- `candidate.json`: exact broken/fixed commits and trees, upstream PR and report links, branch name, toolchain pins, patch partition and artifact hashes.
- `ticket.md`: draft agent-facing bug report, with the diagnosis and implementation instructions omitted. Its concrete requirements must be frozen together with the eventual evaluator.
- `upstream.patch`: complete accepted upstream change, retained as provenance.
- `upstream-source.patch`: production-source portion of that change; a reference repair, never an exact-match scoring target.
- `upstream-tests.patch`: upstream tests and test-support changes. This is evidence for constructing the evaluator, not an already-qualified grader.
- `upstream-ancillary.patch`: other upstream changes, such as the changelog; empty when none exist.
- `tool-versions.upstream` or `versions.upstream`: original broken revision's toolchain declarations.
- `qualification.md` for Plausible; the shared Livebook [candidate research](../docs/livebook-pr-candidates.md) records its case-specific controls and portability issues.

For #5956, the complete upstream change includes an EE cache split and EE-only tests. They are retained with their original paths for provenance; the future runtime and acceptance contract remain Community Edition. Source and patches remain subject to the applicable upstream notices, including the separate notice for `extra/`; the patch bundle does not relicense them.

## Reproduce the source check

Use an existing Plausible clone containing the six repaired commits and their parents. Then run:

```sh
python3 scripts/verify_historical_candidates.py --repository /path/to/plausible-clone
python3 scripts/verify_historical_candidates.py --project livebook --repository /path/to/livebook-clone
```

The script makes no network calls and executes no application code. It validates the parent pairs and file hashes, compares the saved patches with upstream diffs, and reconstructs the exact repaired tree from both the complete patch and its three partitions using a temporary Git index. It does not change the clone's working tree or index. This is a provenance check, not a benchmark result or proof of behavioral correctness.

Executable fixtures require a frozen historical runtime, deterministic failure on the broken state, successful reference repair, protected neighboring behavior, effective regression coverage and integrity controls. Comparative campaign use additionally requires context-feasibility evidence. The attempt workspace receives only the broken source and ticket, with fresh Git history and no network; this candidate directory and its publicly available solutions remain outside it.
