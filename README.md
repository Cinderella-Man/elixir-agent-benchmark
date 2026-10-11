# Elixir agent benchmark

Compare coding models through Elixir agent work: understanding a project, taking actions with tools, changing code and verifying the result.

The benchmark contains **16 cases**: the original four pilot cases, six historical Plausible repairs, and six historical Livebook repairs. The default campaign runs all of them. [The inventory](config/benchmark.json) fixes the case list; repository breakdowns belong to the same benchmark.

The first 12 model attempts have ended: ten reached grading and two stopped with context/tool-protocol errors. Earlier setup failures are retained separately. All four fixtures pass reference/broken/early-exit validation, and seven deliberately incomplete repairs are rejected. Execution was on `ratx570`; the final check confirms unchanged GPU power controls and no remaining benchmark containers.

Source material: [Cinderella-Man/elixir-sft-dataset tasks](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/main/tasks). The source audit pins and inspects this collection; the pilot uses newly authored scenarios in existing projects. A source task, a variant and an independent benchmark scenario are different units.

The application cases use actual broken upstream commits and accepted repairs, with separate public branches in the user's forks. [Plausible](docs/plausible-integration.md) exercises CE application behavior with PostgreSQL and ClickHouse. [Livebook](docs/livebook-integration.md) adds notebook imports, Markdown formatting, LiveView inputs/storage and evaluator behavior. Grading uses executable acceptance and regression checks, including effective fail-before/pass-after coverage. No AI judge or patch-similarity score is used.

All sixteen fixtures have [current qualification evidence](docs/benchmark-qualification.json) from the authorized rig. The twelve historical cases reject their declared incomplete repairs; [seven additional probes](docs/benchmark-partial-controls.json) cover the original pilot. Twenty-seven bounded Python checks validate the controller, inventory and reporting/scoring behavior. No new model attempts or performance measurements are part of this integration.

```bash
# On the authorized rig, after fixture and campaign qualification:
python3 scripts/run_suite.py --campaign comparison-v1 --seeds 101 202 303
python3 scripts/report.py --campaign comparison-v1 --document comparison-v1.md
```

Each model and quantization is a separate candidate with pinned artifacts. Campaigns freeze the cases, evaluator, budgets and candidate configuration. Completed full matrices receive an equally weighted case score; missing or errored attempts remain visible and prevent a final score. See [the comparison protocol](docs/comparison-protocol.md). Common context capacity, token accounting and feasibility still need qualification before a comparative model campaign; the expansion has not produced new model rankings.

This directory is self-contained and can become a separate repository. Planning notes, source evidence, fixtures and benchmark tooling belong here; other local projects are not dependencies.

- [Design decisions](docs/design-tree.md)
- [Glossary](CONTEXT.md)
- [Source task audit](docs/source-task-audit.md)
- [Concrete scenario sketches for discussion](docs/scenario-sketches.md)
- [Running and extending the pilot](docs/runbook.md)
- [Plausible cases and qualification](docs/plausible-integration.md)
- [Livebook cases and qualification](docs/livebook-integration.md)
- [One-benchmark comparison protocol](docs/comparison-protocol.md)
- [Pilot protocol and limits](docs/pilot-protocol.md)

Generated transcripts, patches, test logs, runtime inventories and detailed reports live under the ignored `results/` directory. They are optional evidence artifacts, not required source files. Keep reviewed summaries in `docs/`; share a reviewed evidence archive separately when publishing a campaign. Private working data and credentials remain under the ignored `.local/` directory.

The objective is the strongest useful coding and tool-use quality. Small or old models do not enter merely to increase replica count. Speed, memory and usable context remain deployment constraints, not substitutes for solving the work correctly.

Do not run benchmarks or speed measurements on the shared workstation. Execution on the separate `ratx570` rig is authorized. Preserve its GPU power-limit services and settings exactly. The runner enforces the host and recorded power envelope. It does not start, stop or reconfigure model services.
