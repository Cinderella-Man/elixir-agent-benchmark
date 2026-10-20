# Deep-dive dossier — Redix #351 least-busy routing

**Case-prep status:** deep-inspected 2026-10-19 (API + raw diffs + commit history).  
**Verdict:** viable candidate, but large (10 files) and PR body is empty — contract must be recovered from the diff.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [whatyouhide/redix](https://github.com/whatyouhide/redix) |
| PR | [#351 Least-busy routing in Redix.Cluster pools](https://github.com/whatyouhide/redix/pull/351) |
| Diff | https://github.com/whatyouhide/redix/pull/351.diff |
| Author | whatyouhide (owner/maintainer, merged by self) |
| PR body | **empty** ("No description provided") |
| Created / Merged | 2026-09-17T16:14:03Z / 2026-09-17T17:31:20Z |
| Branch | `least-busy-routing` |
| Base SHA | `7c6cb60b25ec0613d5acabddb34b74db258439a0` |
| Head SHA | `d176f337f207e49997eff279654b914e98317291` |
| Merge commit | `490d0205afa4f8c4f5198789990a8ab4d4c21fe6` |
| Size | 2 commits, +518 / −408, **10 changed files** |
| License | **MIT** (`LICENSE.txt` verified at base SHA) |
| Elixir requirement at base | `~> 1.15` (from `mix.exs`, Redix version `1.9.1`) |

Linked issues: none declared in the PR. The empty body is a maintainer-merge; substance lives in the diff and in `pages/Cluster.md`.

---

## 2. Shortest ticket / brief

> In `Redix.Cluster` connection pools, route each command to the connected pool member with the fewest requests awaiting replies (ties broken at random). Least-busy is per **node**, not per slot: same-node different-slot commands must share one connection (one pipeline). Selection reads queue size from the connection's existing ETS table in the caller process. Requests count until their replies arrive, even after the caller times out. Apply this to primary pools, replica pools, and redirects. Keyless commands prefer connected primaries. Drop caller-sticky affinity. Keep slot ownership and MOVED/ASK redirections correct.

Contract notes (recovered from the diff, because the body is empty):

- Queue entry = one pipeline sent to a connection.
- Registry value shape changes from `{role, state}` to `{role, state, queue_table}`.
- Pool sizes move from the slot table into `Registry.put_meta(registry, :pool_sizes, …)`.
- `get_connection/4` and `get_replica_connection/4` lose the `pool_size` argument (now `/3`); `get_connection_by_node/3` loses `caller` (now `/2`).
- Explicit warning in docs: separate calls have **no connection affinity**.

---

## 3. File roles + key quotes

| File | Role |
| --- | --- |
| `lib/redix/cluster.ex` | Pool-side routing, grouping by node, deadline context |
| `lib/redix/cluster/manager.ex` | Lookup, selection, registry value shape, pool-size meta |
| `lib/redix/connection.ex` | Publishes queue table + state into Registry |
| `pages/Cluster.md` | User-facing pooling docs |
| `test/redix/cluster/fake_node_test.exs` | Fake-node integration (two new tests) |
| `test/redix/cluster/manager_lookup_test.exs` | Unit selection tests (least-busy, ties) |
| `test/redix/cluster/manager_test.exs` | Manager lifecycle (lookup spread rewritten) |
| `test/redix/cluster/connection_telemetry_test.exs` | Registry value shape update |
| (+ further test files in the 10-file set) | |

Key quotes from the diff:

- `pages/Cluster.md`: *"Redix chooses which pool member to route a given request to using a rudimentary 'least-busy' algorithm, selecting the connection with the fewest commands awaiting replies."*
- `pages/Cluster.md` (warning callout): *"Separate calls have **no connection affinity**. Do not rely on connection state!"*
- `manager.ex` `select_connection/1`: shuffle then `Enum.min_by` on `{state != :connected, :ets.info(table, :size)}`; comment: *"A deleted queue must not look idle. Disconnected members are fallbacks."*
- `cluster.ex` grouping: *"Same-node, different-slot commands must not be split across pool members either: least-busy selection is per **node**, not per slot."*
- `connection.ex`: Registry value becomes `{role, state, data.table}`.

---

## 4. Named acceptance assertions ↔ requirements

From upstream tests added/changed in the PR (usable as named acceptance):

| Assertion (test name) | Requirement |
| --- | --- |
| `"same-node different-slot commands share one connection"` | Grouping is per node; pipeline count via telemetry `node_count == 1` |
| `"a timed-out request keeps its member busy while later calls use healthy members"` | Timed-out request still counts in queue; other members used; queue sizes `[0, 0, 1]` |
| `"replica lookup selects the least-busy member across replica nodes"` | Replica selection is least-busy across replicas of a primary |
| `"#{route} lookup spreads ties and selects the smallest queue"` (routes: primary, replica, redirect, keyless) | Tie-breaking spreads; smallest queue wins; deleted ETS table does not look idle |
| `"lookups from one caller spread across the node pool"` | Sticky caller affinity is gone |
| `"primary/node lookup prefers connected members and falls back when all are disconnected"` | Connected preferred; disconnected only as fallback |
| `"routes around a disconnected member while its process stays alive"` | Disconnected member skipped without killing the process |
| `"Manager.get_connection/3 and get_replica_connection/3 return :error instead of raising when the slot table is momentarily gone"` | Guard against missing tables preserved |

---

## 5. Compiling incomplete + named failure

**Plausible incomplete A — slot-first, not node-first grouping.** Keep least-busy but group only by slot (the pre-#351 behavior). Fails: `"same-node different-slot commands share one connection"` (expects `node_count == 1`).

**Plausible incomplete B — sticky `phash2(caller)` left in `lookup_connection`.** Fails: `"lookups from one caller spread across the node pool"` and the tie-spread matrix.

**Plausible incomplete C — least-busy without the `state != :connected` key.** A disconnected member with a small/absent table could win. Fails: `"#{route} lookup spreads ties and selects the smallest queue"` second half (`:ets.delete(busier_table)` must not make it idle) and the disconnected-fallback tests.

**Named failure for A:** `test "same-node different-slot commands share one connection"` in `test/redix/cluster/fake_node_test.exs`.

---

## 6. Integrity control

- Reject a "fix" that always picks index 0 / `hd(members)`.
- Reject disabling the pool (`pool_size: 1` only) as a substitute for least-busy.
- Reject a solution that changes slot ownership or breaks MOVED/ASK (the PR preserves `connect_for_redirect` and `primary_for_slot`).
- Reject treating a deleted queue table as idle (`:ets.info(table, :size)` → `:undefined` must sort after any number).
- Reject reintroducing caller affinity (`:erlang.phash2(self(), …)`).

---

## 7. Preservation

Must keep working:

- Ordinary non-cluster `Redix` behavior (untouched).
- Slot-correct routing and hash-slot grouping (issue #315 lineage).
- MOVED/ASK redirect deadline budget (issue #337 comment remains in the diff).
- Missing-table guards return `:error` instead of raising (issues around Manager restart, #327).
- Replica `:prefer_replica` falls back to primary.
- Telemetry pipeline events still tag `cluster` / `node_count`.

---

## 8. Runtime / offline

- **Confirmed offline-capable.** Upstream tests use `Redix.Cluster.FakeNode` (a TCP fake Redis node) and a bare Registry/ETS harness in `manager_lookup_test.exs`. No real Redis Cluster required.
- New tests in the PR (`same-node…`, `timed-out request…`, `least-busy across replica nodes`, tie-spread matrix) are all FakeNode or pure Registry/ETS.
- Elixir `~> 1.15`; deps: `telemetry`, `nimble_options`, optional `castore`.
- Test-time deps include `propcheck`, `stream_data` — full suite may want those, but the targeted tests do not.

---

## 9. Reference challenges / later fixes / flaky risks

### Later commits to the same files after merge

| SHA | Date | What | Relevance |
| --- | --- | --- | --- |
| `dcf0ae3` (#355, Linuus) | 2026-10-14 | **Add `retry_on_auth_error` option.** Touches `manager.ex` (+2 comment lines only), `connection.ex`, `connector.ex`, `socket_owner.ex`, `start_options.ex`. Introduces `{:connector_stop, …}` and closes setup sockets on failure. | Later commit to `manager.ex`, but only a comment. Also same-day *predecessor* on `connector.ex` relative to #356. Not a fix to #351 semantics. |
| — | after 2026-10-14 | No further commits to `manager.ex` or `cluster.ex` as of the Oct 14 history page (repo `pushed_at` 2026-10-14). | Clean window. |

**Full SHA of #355 merge commit:** `dcf0ae3` (short; full form not captured — mark unverified if a full SHA is required).

### Lineage with #350 (explicitly requested)

- [#350 Reduce Redis Cluster pool churn](https://github.com/whatyouhide/redix/pull/350), merged 2026-09-10, merge commit `3c931c0` (short; full unverified).
- 2 commits, empty body, author whatyouhide. Force-pushed twice (`b8c7505` → `d131605` → `8038fe0`).
- Coveralls: `manager.ex` 100 lines changed, 98 covered (98%).
- #351's base `7c6cb60` is after #350's merge — #351 **builds on** #350's pool-churn reduction.
- **Do not treat #350 and #351 as two independent cases** without a written combined outcome. Prefer #351 alone (later complete behavior) or a corrected-feature family only if both are required for one user-visible result.

### Flaky risks

- `Enum.shuffle` + `Enum.min_by` ties: upstream guards this with `for _attempt <- 1..20` / `1..100` loops and `MapSet` equality. Acceptance should use the same idiom, not single-shot equality on ties.
- Queue-size observation (`:ets.info(table, :size)`) is timing-sensitive if a test races reply arrival. The upstream `"timed-out request keeps its member busy"` test pins this with a stalled FakeNode and asserts sizes `[0, 0, 1]` — prefer that over sleeps.
- Registry value shape `{role, state, table}` is an internal contract; hidden tests that match the old `{role, state}` shape will fail after the fix — that is correct, but the ticket must not require the old shape.

---

## 10. Curator record fields

```yaml
case_id: redix-351-least-busy-routing
project: whatyouhide/redix
pr_url: https://github.com/whatyouhide/redix/pull/351
base_sha: 7c6cb60b25ec0613d5acabddb34b74db258439a0
merge_sha: 490d0205afa4f8c4f5198789990a8ab4d4c21fe6
head_sha: d176f337f207e49997eff279654b914e98317291
merged_at: 2026-09-17T17:31:20Z
task_kind: feature_with_preservation
impl_files: 3
test_files_touched: 7
total_files: 10
license: MIT (LICENSE.txt)
elixir: "~> 1.15"
offline: true
fake_node_tests: true
db_required: false
pr_body_empty: true
related_prs: ["https://github.com/whatyouhide/redix/pull/350"]
later_commits_same_files:
  - sha: dcf0ae3
    pr: 355
    note: retry_on_auth_error; manager.ex comment-only
difficulty_hint: high
scope_risk: large_diff_and_test_churn
```

---

## 11. Next action

1. If a Redix case is wanted **now**, start with **#356** (tiny, described, same fake-node offline style) to prove the runner.
2. For #351 itself: write the contract explicitly (least-busy = min in-flight queue size from the connection ETS table; ties random; per-node grouping) **before** checks, because the PR body is empty.
3. Decide #350-vs-#351 lineage in writing: recommended default is **#351 only**, with #350 noted as ancestor, not a second case.
4. Prefer the named FakeNode/manager_lookup assertions above; avoid inventing private-helper tests.
