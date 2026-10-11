# Historical Plausible repair candidates

These six drafts use actual merged upstream fixes. Their broken branches point directly to original upstream pre-fix commits in [the user's fork](https://github.com/Cinderella-Man/plausible-analytics); no source defect was invented or transplanted. Each case therefore has its own historical source baseline.

**Status: source verified, runtime unqualified.** Exact parent relationships, artifact hashes and patch reconstruction have been checked. Application builds, fail-before/pass-after controls, incomplete-repair probes and context feasibility remain pending. These directories deliberately sit outside `cases/`, so the existing campaign runner cannot accidentally treat them as runnable fixtures.

| Candidate | Real problem | Broken branch |
| --- | --- | --- |
| [#6300](plausible-pr-6300/candidate.json) | Today/Last 24h ignore weekday matching | [codex/bug-pr-6300-weekday-comparison](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6300-weekday-comparison) |
| [#5939](plausible-pr-5939/candidate.json) | Editors cannot change a site's domain | [codex/bug-pr-5939-editor-domain-change](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-5939-editor-domain-change) |
| [#6763](plausible-pr-6763/candidate.json) | Page-filtered dashboard CSV export crashes | [codex/bug-pr-6763-filtered-csv-export](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6763-filtered-csv-export) |
| [#6449](plausible-pr-6449/candidate.json) | Shared-link edits accept an altered token or foreign segment | [codex/bug-pr-6449-shared-link-boundaries](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6449-shared-link-boundaries) |
| [#6441](plausible-pr-6441/candidate.json) | Property-restricted goals crash or overcount imported data | [codex/bug-pr-6441-imported-goal-properties](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-6441-imported-goal-properties) |
| [#5956](plausible-pr-5956/candidate.json) | Dedicated CE tracker scripts fail after configuration changes | [codex/bug-pr-5956-ce-tracker-cache](https://github.com/Cinderella-Man/plausible-analytics/tree/codex/bug-pr-5956-ce-tracker-cache) |

The table order is the proposed runtime-qualification order. The [research note](../docs/plausible-pr-candidates.md) contains evidence, alternatives and historical environment differences. The [expansion plan](../docs/large-codebase-expansion.md) records the behavioral scoring and context requirements.

## Files in each draft

- `candidate.json`: exact broken/fixed commits and trees, upstream PR and report links, branch name, toolchain pins, patch partition and artifact hashes.
- `ticket.md`: draft agent-facing bug report, with the diagnosis and implementation instructions omitted. Its concrete requirements must be frozen together with the eventual evaluator.
- `upstream.patch`: complete accepted upstream change, retained as provenance.
- `upstream-source.patch`: production-source portion of that change; a reference repair, never an exact-match scoring target.
- `upstream-tests.patch`: upstream tests and test-support changes. This is evidence for constructing the evaluator, not an already-qualified grader.
- `upstream-ancillary.patch`: other upstream changes, such as the changelog; empty when none exist.
- `tool-versions.upstream`: original broken revision's toolchain declarations.
- `qualification.md`: remaining case-specific controls and portability issues.

For #5956, the complete upstream change includes an EE cache split and EE-only tests. They are retained with their original paths for provenance; the future runtime and acceptance contract remain Community Edition. Source and patches remain subject to the applicable upstream notices, including the separate notice for `extra/`; the patch bundle does not relicense them.

## Reproduce the source check

Use an existing Plausible clone containing the six repaired commits and their parents. Then run:

```sh
python3 scripts/verify_historical_candidates.py --repository /path/to/plausible-clone
```

The script makes no network calls and executes no application code. It validates the parent pairs and file hashes, compares the saved patches with upstream diffs, and reconstructs the exact repaired tree from both the complete patch and its three partitions using a temporary Git index. It does not change the clone's working tree or index. This is a provenance check, not a benchmark result or proof of behavioral correctness.

Promotion into `cases/` requires a frozen historical runtime, deterministic failure on the broken state, successful reference repair, protected neighboring behavior, effective regression coverage, integrity controls and context-feasibility evidence. The future attempt workspace receives only the broken source and ticket, with fresh Git history and no network; this candidate directory and its publicly available solutions remain outside it.
