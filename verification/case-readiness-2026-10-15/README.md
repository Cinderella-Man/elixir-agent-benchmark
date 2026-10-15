# Existing-case readiness checks

These artifacts support the [eleven-case review](../../docs/verification/existing-case-readiness-2026-10-15.md). They do not modify the scored cases or their prompts.

- `recheck.exs` qualifies all eleven cases against the current grader, then replays the shared-link malformed-input policy alternative through the full grader.
- `plausible-5956-alternative.patch` is a curator-authored two-file repair against the starting CE source. It preserves the existing cache modules, makes local writes immediate and uses a single value per cache key. It is an alternative implementation experiment, not a blind model solution.
- `check_alternative.exs` grades that tracker repair, including submitted tests and preservation, after current qualification exists.
- `export.py` validates identities and produces portable evidence without raw logs or timing fields.

Use the existing `eab-tooling:dev` image, Docker socket access and `mix run --no-start`, following the [functional-audit setup](../task-quality/README.md#reproduce-without-a-model). Set `EAB_DATA_DIR` to a separate persistent directory; never use an active controller's data directory. Seed it with prepared `cache/`, `sources/`, `build-seeds/` and `runtimes/` records if available. A missing image may require preparation. Do not copy credentials, installation state, controller runs or leases.

From the repository root, run sequentially with the same Docker mounts and environment:

```sh
mix run --no-start verification/case-readiness-2026-10-15/recheck.exs
mix run --no-start verification/case-readiness-2026-10-15/check_alternative.exs
```

The recorded run uses one preparation worker and one case at a time. Existing sandbox CPU/memory limits remain in force. Qualification may reuse a receipt only when its full current identity matches; fresh versus reused evidence must be reported accurately. Watchdogs detect hangs; no duration is used as speed evidence. No script invokes a model or changes the controller's run history.

The dated exporter also expects the original audit's ignored `input-snapshot.json`, sanitized `run-metadata.json` and aggregate `subscription-status.json` under `.local/case-readiness-2026-10-15/`. These came from read-only inspection during the audit. They record case-file hashes, verified source archive receipts, saved controller run metadata and account-status counts without credentials, endpoint addresses or raw transcripts. The exporter intentionally fails if they are absent or the inputs have changed; do not fabricate them to reproduce an old attestation. The checked-in portable evidence identifies the original inputs. A later re-audit should record its own date and input snapshot.

For this recorded audit:

```sh
python3 verification/case-readiness-2026-10-15/export.py \
  .local/case-readiness-2026-10-15/runtime-data
```

Raw qualification records remain under the isolated data directory's `controls/` and `jobs/`; full challenge results are under `readiness/`. A completed functional run does not establish two blind model successes or independent human review.
