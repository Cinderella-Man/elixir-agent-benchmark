# Deep-dive dossier — Redix #356 sentinel socket leak

**Case-prep status:** deep-inspected 2026-10-19 (API + raw diff + commit history).  
**Verdict:** **best first Redix candidate** — small, described, offline-tested, clear later refactor to watch.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [whatyouhide/redix](https://github.com/whatyouhide/redix) |
| PR | [#356 Fix leaking socket in sentinel path](https://github.com/whatyouhide/redix/pull/356) |
| Diff | https://github.com/whatyouhide/redix/pull/356.diff |
| Author | [Linuus](https://github.com/Linuus) (CONTRIBUTOR), merged by whatyouhide |
| PR body | Present (quoted below) |
| Created / Merged | 2026-10-11T17:37:07Z / 2026-10-14T14:16:44Z |
| Branch | `Linuus:fix-sentinel-socket-leak` |
| Base SHA | `6e95bbd533f7d2c8d6fde5f30269a8fe52628794` |
| Head SHA | `787fac8d56d6f73837dc65f27589d0d15cad2c72` |
| Merge commit | `933edc09fe6428c8f90e368115b85a057935a385` |
| Size | 1 commit, +49 / −5, **2 changed files** |
| License | **MIT** (`LICENSE.txt` verified at base SHA) |
| Elixir requirement at base | `~> 1.15` (Redix `1.9.1` at the #351 base; same line at this base — `mix.exs` not re-probed at `6e95bbd`, mark minor-unverified) |

Linked issues: none declared. No `Closes #…` in the body.

### PR body (verbatim)

> When a sentinel reported a server with the wrong role, or the ROLE check failed, the connector never closed the server socket and moved on to the next sentinel. If the next sentinel worked, the socket stayed open for the life of the connection.  
> The connector now closes it, and a fake-node test covers it.

---

## 2. Shortest ticket / brief

> In the Redis Sentinel connect path, when a sentinel reports a server with the **wrong role**, or the `ROLE` check fails, the already-opened server socket is left open while the connector moves on to the next sentinel. If a later sentinel succeeds, the failed attempt's socket stays leaked for the life of the connection. Close that socket on failure. Keep the successful path returning exactly one live socket. Fix it.

---

## 3. File roles + key quotes

| File | Role |
| --- | --- |
| `lib/redix/connector.ex` | Close server socket when ROLE/wrong-role fails |
| `test/redix/connector_test.exs` | Fake-node regression |

Implementation (the whole fix):

```elixir
result =
  case sync_command(transport, server_socket, ["ROLE"], timeout) do
    {:ok, [^expected_role | _]} -> :ok
    {:ok, [role | _]} -> {:error, {:wrong_role, role}}
    {:error, _reason_or_redis_error} = error -> error
  end

# The caller only gets the socket on success, so we close it here. Otherwise it
# leaks when the connection moves on to the next sentinel.
if result != :ok, do: _ = transport.close(server_socket)

result
```

Test (key quote): *"Sockets are linked to the process that owns them."* — helper `linked_ports/0` diffs `Process.info(self(), :links)` before/after `Connector.connect/2` and asserts the only new port is the successful socket.

---

## 4. Named acceptance assertions ↔ requirements

| Assertion (upstream test name) | Requirement |
| --- | --- |
| `"closes the server socket when a sentinel reports a server with the wrong role"` | Wrong-role attempt's socket is closed; next sentinel tried; exactly one live linked port (`linked_ports() -- ports_before == [socket]`) |
| Happy-path sentinel connect (existing `describe "sentinel"` tests) | Successful path returns one socket; no extra close |
| ROLE-check **failure** (`{:error, reason}` from `sync_command`) | Same close-on-failure behavior (covered by the `if result != :ok` form — note the upstream test only exercises **wrong role**, not a transport/ROLE command error; see §9) |

Requirement mapping:

- R1 wrong-role → close server socket, continue to next sentinel.
- R2 ROLE-check error → close server socket, continue.
- R3 success → exactly one live socket owned by the caller.
- R4 non-sentinel connect path unchanged.

---

## 5. Compiling incomplete + named failure

**Incomplete A — close only on `{:error, {:wrong_role, _}}`, forget `{:error, reason}`.**  
Named failure: the upstream test only covers wrong-role; a hidden test should add a ROLE-command failure. If checks stay faithful to upstream only, this incomplete may pass — **curator must add a ROLE-error case or accept the gap**.

**Incomplete B — close after selecting the next server / on the wrong socket.**  
Fails the linked-ports delta (`linked_ports() -- ports_before == [socket]`) or closes the good socket.

**Incomplete C — skip sentinel fallback entirely (return error on first wrong-role).**  
Fails the test setup that wires `[wrong_sentinel, right_sentinel]` and asserts `{:ok, socket, _address}`.

**Named failure for B/C:** `test "closes the server socket when a sentinel reports a server with the wrong role"` in `test/redix/connector_test.exs`.

---

## 6. Integrity control

- Reject closing the socket on **success** (would break R3; the test's `ports_after -- ports_before == [socket]` catches it).
- Reject `transport.close` on the sentinel's own socket rather than the server socket.
- Reject "fix" that stops trying further sentinels after a wrong-role report.
- Reject a test that only asserts `{:ok, …}` without the port-link delta (that would not observe the leak).

---

## 7. Preservation

- Non-sentinel `Connector.connect/2` path unchanged (other tests in the file cover SSL opts, DNS, etc.).
- Successful sentinel path still returns `{:ok, socket, address}` with one linked port.
- Existing `assert_connected_address/1` sentinel tests still pass.
- `Redix.PubSub` and normal `Redix` startup unchanged.

---

## 8. Runtime / offline

- **Confirmed offline.** New test uses `Redix.Cluster.FakeNode.start/1` to stand up two fake servers (replica + primary ROLE replies) and two fake sentinels answering `SENTINEL get-master-addr-by-name`. No real Redis/Sentinel.
- Pattern: TCP listeners in-process; assert socket lifetime via `Process.info(self(), :links)` port filter.
- Elixir `~> 1.15`. No new deps.
- **Do not** require a live Sentinel service for acceptance.

---

## 9. Reference challenges / later fixes / flaky risks

### Later commits to the same files after merge (CRITICAL)

| SHA | PR | Date | What it changed | Risk to this case |
| --- | --- | --- | --- | --- |
| **`d938d31`** | [#357 Refactor some code](https://github.com/whatyouhide/redix/pull/357) | 2026-10-14 (same day, **after** #356) | Parent `933edc0` (= #356 merge). Rewrites the close as `tap(result, fn :ok -> :ok; _other -> _ = transport.close(server_socket) end)`. Inlines `linked_ports/0` into the test as `self() |> Process.info(:links) |> elem(1) |> Enum.filter(&is_port/1)`. +7/−10 across `connector.ex` + `connector_test.exs`. Coveralls: 1 line in `connector.ex` lost coverage. | **Semantic-preserving refactor.** Behavior identical. If the reference solution is taken at `933edc0` and tests at `main`/`d938d31`, the `tap/2` style vs `if` style may trip a brittle style check — behavior checks should not care. The test helper name disappearing is a real collision if hidden tests call `linked_ports/0`. |
| `dcf0ae3` | [#355 Add retry_on_auth_error](https://github.com/whatyouhide/redix/pull/355) | 2026-10-14 (**before** #356 on `main`) | Also in `connector.ex`: closes the socket on **auth/select setup** failures with a nearly identical comment (*"Callers only get the socket on success, so we close it here. Otherwise it leaks in processes that own it and retry, such as Redix.PubSub."*). Adds `retry_on_auth_error` option, `{:connector_stop, …}` protocol. | **Same-day sibling, same theme (socket leak on failure path), different code path (AUTH/SELECT vs ROLE).** Do not confuse the two. #356 is the ROLE/sentinel path; #355 is the auth path. A combined "close on every failed setup" ticket would be a new synthesis, not either PR. |

No commits to `connector.ex` after `d938d31` on the history page (repo `pushed_at` 2026-10-14).

### Flaky risks

- Low. The test is deterministic: FakeNode replies are scripted; socket lifetime is observed via process links, not timing.
- Do **not** replace the linked-port assertion with a sleep-based fd count.
- `async: true` on `Redix.ConnectorTest` is fine (FakeNode ports are reserved).

### Unverified

- Full 40-char SHA of `d938d31` and `dcf0ae3` not captured from HTML (short SHAs only). Short SHAs are unique in this repo window; expand via `git rev-parse` at prep time if the curator format requires full SHAs.
- `mix.exs` Elixir string read at `7c6cb60` (#351 base), not at `6e95bbd` (#356 base). Same file line is believed unchanged between them (no `mix.exs` commits in that window on the histories read) — treat as minor-unverified.

---

## 10. Curator record fields

```yaml
case_id: redix-356-sentinel-socket-leak
project: whatyouhide/redix
pr_url: https://github.com/whatyouhide/redix/pull/356
base_sha: 6e95bbd533f7d2c8d6fde5f30269a8fe52628794
merge_sha: 933edc09fe6428c8f90e368115b85a057935a385
head_sha: 787fac8d56d6f73837dc65f27589d0d15cad2c72
merged_at: 2026-10-14T14:16:44Z
task_kind: bug_fix_resource_leak
impl_files: 1
test_files_touched: 1
total_files: 2
license: MIT (LICENSE.txt)
elixir: "~> 1.15"
offline: true
fake_node_tests: true
db_required: false
pr_body_empty: false
linked_issues: []
later_commits_same_files:
  - sha: d938d31
    pr: 357
    date: 2026-10-14
    note: "semantic-preserving tap/2 refactor of the exact close; test helper inlined"
  - sha: dcf0ae3
    pr: 355
    date: 2026-10-14
    note: "before #356 on main; same socket-leak theme on AUTH/SELECT path"
related_prs: ["https://github.com/whatyouhide/redix/pull/355", "https://github.com/whatyouhide/redix/pull/357"]
coverage_gap: "upstream test covers wrong-role only; ROLE command error path untested upstream"
difficulty_hint: low
scope_risk: focused_one_file
```

---

## 11. Next action

1. **Promote as the first Redix preparation candidate** — small, described, offline FakeNode test, clear R1–R4.
2. At prep, decide the snapshot SHA:
   - Behavioral reference at `933edc0` (the #356 merge) is the faithful fix.
   - If tests are taken from `main` after `d938d31`, either port the inlined `linked_ports` logic or keep the `linked_ports/0` helper yourself — do not assume the helper name survives.
3. Optionally add a hidden ROLE-command-error acceptance (the coverage gap in §4) so incomplete A fails.
4. Keep #351 separate; mention #355 only as same-theme context so the curator does not merge the two bug reports into one ticket.
