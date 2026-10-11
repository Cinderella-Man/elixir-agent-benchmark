# Upstream projects

The pilot evaluates curated changes to these independent open-source projects. Their source is fetched at the exact revision in each case manifest, rather than vendored into this repository.

- [NimbleOptions](https://github.com/dashbitco/nimble_options), revision `825c05837f236c612c6ac2855735ec6cf7f2be69`, Apache License 2.0.
- [GenStage](https://github.com/elixir-lang/gen_stage), revision `73957a6479cd4ec392834a2fa418bc32ea7e7fbc`, Apache License 2.0.
- [LiveBeats](https://github.com/fly-apps/live_beats), revision `712204ca172ed6d36456c8ed4fd6aaba50099447`, MIT License.

Available upstream license files are retained under `licenses/`. GenStage declares Apache-2.0 in its pinned `mix.exs`; this review found no standalone license file in its root. Starter and reference patches include small modifications to these projects; the upstream notices continue to apply to those portions. These scenarios are benchmark-authored regressions, not reports of unresolved vulnerabilities or defects in the upstream releases.

The [Elixir SFT dataset](https://github.com/Cinderella-Man/elixir-sft-dataset) supplied the source-task survey and conceptual direction. The current pilot does not copy its task prompts, reference solutions or test bundles. Its directory count is not used as the benchmark's number of independent scenarios.

The historical application cases retain real upstream repairs and test changes as provenance:

- [Plausible Analytics](https://github.com/plausible/analytics): AGPL-3.0 source; its `extra/` directory has separate upstream terms. Copies are retained under `licenses/plausible-LICENSE.md` and `licenses/plausible-extra-COPYING.txt`. The full provenance patches retain original paths and do not relicense enterprise code. Executable fixtures select Community Edition behavior. Exact source revisions are recorded in `candidates/plausible-pr-*/candidate.json`.
- [Livebook](https://github.com/livebook-dev/livebook): Apache License 2.0, Copyright (C) 2021 Dashbit, as stated in its historical README. Its license is retained under `licenses/livebook-LICENSE`; exact historical source and repair revisions are recorded in `candidates/livebook-pr-*/candidate.json`.

These historical cases are previously repaired upstream defects. The broken fork branches reproduce historical states and do not describe the current upstream release. Source archives preserve their upstream license and attribution files.
