# Upstream projects

The benchmark preserves twelve actual upstream repairs. Source is fetched at the exact broken revision in each case manifest; it is not vendored into this repository.

- [Plausible Analytics](https://github.com/plausible/analytics): AGPL-3.0 source, with separate upstream terms for `extra/`. Licenses are retained under `licenses/plausible-LICENSE.md` and `licenses/plausible-extra-COPYING.txt`. Executable fixtures select Community Edition behavior. Provenance patches retain their original paths and do not relicense enterprise code.
- [Livebook](https://github.com/livebook-dev/livebook): Apache License 2.0, Copyright (C) 2021 Dashbit. The license is retained under `licenses/livebook-LICENSE`.

Exact broken and repaired revisions, PR references and fixture patches are retained in `cases/<case-id>/`. Historical defects are already repaired upstream; these fixtures do not describe the current upstream releases. Source checkouts preserve upstream license and attribution files. Publicly available cases and repairs may have appeared in model training data.

Docker images install the MIT-licensed [Pi coding agent](https://github.com/earendil-works/pi) and its dependencies from the pinned npm lockfile under `priv/pi/`. Package distributions retain their upstream license files. Pi is the external agent runtime; it is not vendored source in this repository.
