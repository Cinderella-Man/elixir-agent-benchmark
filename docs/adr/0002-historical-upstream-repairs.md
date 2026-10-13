# Use actual upstream PR repairs

Every case preserves an upstream defect at its exact broken revision, with an accepted PR establishing repair provenance. Each snapshot has its own pinned runtime recipe. Case manifests and provenance records identify the source commits and trees.

A reference repair qualifies the checks; submissions may implement another valid repair. Only deterministic executable checks determine outcomes. Source review or a merged PR alone cannot qualify a fixture: the broken, reference, incomplete-repair and integrity controls must execute successfully on the intended host.
