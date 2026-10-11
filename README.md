# Elixir agent benchmark

Compare coding models through Elixir agent work: understanding a project, taking actions with tools, changing code and verifying the result.

The first increment is a four-case end-to-end pilot. It establishes a runnable evaluation path; these small curated repairs are not enough to rank general model quality. See the [pilot summary](docs/pilot-results.md) for what has actually run and [the expansion plan](docs/expansion-plan.md) for the next work.

The first 12 model attempts have ended: ten reached grading and two stopped with context/tool-protocol errors. Earlier setup failures are retained separately. All four fixtures pass reference/broken/early-exit validation, and seven deliberately incomplete repairs are rejected. Execution was on `ratx570`; the final check confirms unchanged GPU power controls and no remaining benchmark containers.

Source material: [Cinderella-Man/elixir-sft-dataset tasks](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/main/tasks). The source audit pins and inspects this collection; the pilot uses newly authored scenarios in existing projects. A source task, a variant and an independent benchmark scenario are different units.

The next application expansion uses [six actual historical Plausible repairs](candidates/README.md), with separate public branches at their original broken commits. The source pairs, repair patches and provenance have been verified; their historical runtimes and behavioral acceptance tests are not yet qualified. These drafts stay outside the runnable pilot cases.

This directory is self-contained and can become a separate repository. Planning notes, source evidence, fixtures and benchmark tooling belong here; other local projects are not dependencies.

- [Design decisions](docs/design-tree.md)
- [Glossary](CONTEXT.md)
- [Source task audit](docs/source-task-audit.md)
- [Concrete scenario sketches for discussion](docs/scenario-sketches.md)
- [Running and extending the pilot](docs/runbook.md)
- [Pilot protocol and limits](docs/pilot-protocol.md)

Generated transcripts, patches, test logs, runtime inventories and detailed reports live under the ignored `results/` directory. They are optional evidence artifacts, not required source files. Keep reviewed summaries in `docs/`; share a reviewed evidence archive separately when publishing a campaign. Private working data and credentials remain under the ignored `.local/` directory.

The objective is the strongest useful coding and tool-use quality. Small or old models do not enter merely to increase replica count. Speed, memory and usable context remain deployment constraints, not substitutes for solving the work correctly.

Do not run benchmarks or speed measurements on the shared workstation. Execution on the separate `ratx570` rig is authorized. Preserve its GPU power-limit services and settings exactly. The runner enforces the host and recorded power envelope. It does not start, stop or reconfigure model services.
