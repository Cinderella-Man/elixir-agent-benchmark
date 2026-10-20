# Deep-dive dossier — nimble_parsec #154 choice fallback after traversal errors

**Case-prep status:** deep-inspected 2026-10-19 (API + raw diff + commit history + issue #146).  
**Verdict:** strong focused compiler-contract case. Pure library, offline, clear issue with reproduction. Watch two same-week follow-ups on `compiler.ex`.

---

## 1. Identity

| Field | Value |
| --- | --- |
| Repo | [dashbitco/nimble_parsec](https://github.com/dashbitco/nimble_parsec) |
| PR | [#154 fix: Allow choice fallback after traversal errors](https://github.com/dashbitco/nimble_parsec/pull/154) |
| Diff | https://github.com/dashbitco/nimble_parsec/pull/154.diff |
| Author | [mvanhorn](https://github.com/mvanhorn) (CONTRIBUTOR), merged by **josevalim** |
| PR body | Present; ends with **`Closes #146`** |
| Created / Merged | 2026-08-11T12:57:26Z / 2026-08-11T14:57:27Z (same day, ~2h) |
| Branch | `mvanhorn:fix/146-post-traverse-choice-fallback` |
| Base SHA | `083498e808ed40be8d48e8af58b7860dd3909c63` |
| Head SHA | `634d7aaf51a4230f87c68767cd7caccd9456dbd2` |
| Merge commit | `5b8bb30d2d0fa449035f433231eea71952489d23` |
| Size | 1 commit, +80 / −5, **2 changed files** |
| License | **Apache-2.0** per `mix.exs` `package().licenses` at base. *(Upstream repo license field is null on GitHub; a root `LICENSE`/`LICENSE.md` returned 404 at the base SHA — the Hex package declares Apache-2.0. Do not label this MIT.)* |
| Elixir requirement at base | `~> 1.12` (NimbleParsec version `1.4.2`) |

### Linked issue #146

- [issue #146 post_traverse failure does not fail choice](https://github.com/dashbitco/nimble_parsec/issues/146)
- Opened 2025-02-26 by **foresttoney**; closed 2026-08-11 by josevalim as completed in #154.
- Reproduction in the issue (author's words): a `bytes(6) |> post_traverse(date_parser)` inside `choice([…, empty() |> replace(nil)])` — *"the failure condition defined in parse_date doesn't actually fail the choice combinator - you just end up with the error message as the result of the combinator."*
- Author's expected vs actual (from the issue's ExUnit block):
  - valid `"100501"` → `{:ok, [~D[2010-05-01]], "", %{}, {1, 0}, 6}`
  - invalid `"000000"` → **expected** `{:ok, [nil], "", %{}, {1, 0}, 6}`  
    **actual (bug)** `{:error, "expected YYMMDD date", "", %{}, {1, 0}, 6}`

---

## 2. Shortest ticket / brief

> `post_traverse/3` callbacks may return `{:error, reason}`. The compiler turns that into the parsec's **final** error instead of routing it through the active `catch_all` / `choice` fallback like other unbound combinators. As a result, a `choice/2` whose first branch consumes input and then errors in a traversal callback does not try a later branch from the original input. Make traversal errors fall back like other parser failures in a choice. Successful traversals must still return the transformed result without needless fallback. Fix it.

---

## 3. File roles + key quotes

| File | Role |
| --- | --- |
| `lib/nimble_parsec/compiler.ex` | Honor `catch_all` for traversal errors (`traverse_error/2`) |
| `test/nimble_parsec_test.exs` | Regressions under `describe "choice/2 combinator"` |

Implementation core (new private functions):

```elixir
defp traverse_error(reason, %{catch_all: nil}) do
  quote do
    {:error, unquote(reason), rest, context, line, offset}
  end
end

defp traverse_error(_reason, %{catch_all: catch_all, acc_depth: n}) do
  {_, _, _, body} = build_proxy_to(:unused, catch_all, n)
  body
end
```

And the two call sites: compile-time `{:error, reason}` from `apply_traverse` now goes through `traverse_error/2` instead of emitting a final error tuple; the runtime `{:error, reason}` clause of the generated `case` does the same.

PR body key sentence: *"Update traversal error generation in `NimbleParsec.Compiler` to honor the active `catch_all` continuation already carried in compiler configuration, following the failure-routing pattern used by other unbound combinators."*

---

## 4. Named acceptance assertions ↔ requirements

Upstream named tests added in the PR (all under `describe "choice/2 combinator"`):

| Assertion (test name) | Requirement |
| --- | --- |
| `"falls back after a post-traversal error"` | Consuming branch + `post_traverse` error → second branch runs from original input; returns its result with correct rest/context/line/offset. Also: same input where the callback **succeeds** returns the transformed acc without fallback. |
| `"falls back after a pre-traversal error"` | `pre_traverse` error also routes through `catch_all` (same fix surface). |
| `"falls back after a quoted traversal error"` | Compile-time `{:error, reason}` form (quoted traversal) falls back in `choice`; standalone (no `catch_all`) still returns `{:error, "quoted traversal error", …}`. |
| `"returns a parser error when no branch succeeds after a traversal error"` | No matching fallback → still an `{:error, reason, …}` parse error (not a crash, not a silent `:ok`). |

Concrete expectations worth copying into checks:

- `choice_post_traverse("a\nc!")` → `{:ok, ~c"a\nc", "!", %{}, {2, 2}, 3}` (first branch success, **no** fallback).
- `choice_post_traverse("a\nz!", context: %{source: :initial})` → `{:ok, [nil], "!", %{source: :initial}, {2, 2}, 3}` (fallback; context preserved).
- `choice_quoted_post_traverse("a\nc!")` → `{:ok, [nil], "!", %{}, {2, 2}, 3}`.
- `standalone_quoted_post_traverse("a\nc!")` → `{:error, "quoted traversal error", "!", %{}, {2, 2}, 3}` (no `catch_all` → still final error).

---

## 5. Compiling incomplete + named failure

**Incomplete A — also fall back on *successful* traversals.**  
Fails: `"falls back after a post-traversal error"` first half — `choice_post_traverse("a\nc!")` must return `~c"a\nc"`, not the fallback `nil`.

**Incomplete B — fix only the compile-time `{:error, reason}` clause, not the runtime `case` clause.**  
Fails: `"falls back after a quoted traversal error"` / `"falls back after a post-traversal error"` (the runtime `{:error, reason}` path is the common one for `post_traverse` MFA returns).

**Incomplete C — always route through `catch_all`, even when `%{catch_all: nil}`.**  
Fails: `standalone_quoted_post_traverse("a\nc!")` which must keep `{:error, "quoted traversal error", …}`.

**Named failure for A:** `test "falls back after a post-traversal error"` (first assertion).  
**Named failure for C:** `test "falls back after a quoted traversal error"` (second assertion).

---

## 6. Integrity control

- Reject swallowing traversal errors (always continuing as success).
- Reject changing the shape of a *successful* traversal result (`{rest, acc, context}` / three-element tuple).
- Reject catching errors at **parse runtime** with try/rescue — the architecture is compile-time codegen; the fix is in generated clause routing (`build_proxy_to/3` to the existing `catch_all`).
- Reject "fixes" that alter `repeat`/`lookahead`/`eventually` error routing beyond the traversal path (preservation of the rest of the suite).
- Reject requiring Timex or any date library — upstream tests use a local `error_when_last_is_z` / `NimbleParsecTest.QuotedTraversal.error/5` stub.

---

## 7. Preservation

- Existing `choice/2`, `lookahead`, `repeat`, `label` tests must stay green (the PR adds tests beside them; it does not change those code paths' contracts).
- Standalone traversals without `choice`/`catch_all` still produce final `{:error, reason, rest, context, line, offset}`.
- Line/offset bookkeeping after fallback is the **fallback branch's** position (`{2, 2}, 3` in the upstream examples), not the failed branch's — hidden tests must not demand the failed branch's offsets.
- No generator (`generate/3`) behavior change in this PR.

---

## 8. Runtime / offline

- **Fully offline.** Pure Elixir parser-combinator library. ExUnit only. No services, no DB, no network.
- Elixir `~> 1.12`. Dev/test extras are documentation-oriented (`ex_doc` escript for docs alias); the test suite itself has essentially no test-only deps in `mix.exs`.
- Excellent low-prep diversity case (macro/compiler codegen semantics).

---

## 9. Reference challenges / later fixes / flaky risks

### Later commits to `lib/nimble_parsec/compiler.ex` after merge `5b8bb30` (CRITICAL)

| SHA | PR | Date | What | Relation to #154 |
| --- | --- | --- | --- | --- |
| **`4abe35a`** | [#155 Use string_slice in ascii_string and binary_string](https://github.com/dashbitco/nimble_parsec/commit/4abe35a) | 2026-08-11 (**same day, immediately after**; parent **is** `5b8bb30`) | Adds `:string_slice` combinator + `Compiler.string_slice/4`, `newline_possible?/2`; CHANGELOG notes a bug fix: *"ascii_string/3 and utf8_string/3 nested in choice/2, lookahead/2 or lookahead_not/2 now produce an error message naming the character class once, instead of repeating it :min plus one times"*. +175/−1 across 4 files. | **Adjacent, not a fix to #154.** Touches `compile_unbound_combinator` and `label/1` near the traversal code. Introduces new combinators and error-label behavior that #154 does not have. If the snapshot is `5b8bb30` but tests are taken from later `master`, tests for `string_slice` will not exist yet (good). If someone rebases #154 onto post-#155, label expectations may shift. |
| **`6f00961`** | [#158 Print codepoints in generated guards as character literals](https://github.com/dashbitco/nimble_parsec/commit/6f00961) | 2026-08-13 | Rewrites `bin_range_to_guard/2` to emit `?a`-style tokens via `char/1` (`{:__block__, [token: …], [codepoint]}`). +53/−15. Cosmetic/codegen-printing only. | **Cosmetic follow-up.** Should not affect #154 behavior. Risk is only if a hidden test string-matches generated guard source (the #158 tests do that — do not import them). |

No further `compiler.ex` commits after `6f00961` on the history page (repo `pushed_at` 2026-08-13).

### Flaky risks

- Low. All upstream new tests are pure function assertions on parsec results — no timing, no processes.
- `async: true` is already used; no shared state.
- One subtlety: `choice_post_traverse` uses `times(ascii_char([?a..?z, ?\n]), 3)` so input `"a\nc"` / `"a\nz"` exercises line/offset (`{2, 2}, 3`). Hidden tests must expect the **fallback branch's** offsets after a fallback.

### Unverified / corrections

- Screening note previously said "MIT (Dashbit)". **Corrected: Apache-2.0** per `mix.exs` package licenses. Root LICENSE file not found at base SHA (404 on `LICENSE`, `LICENSE.md`).
- Full 40-char SHAs for `4abe35a` / `6f00961` not captured from HTML (short SHAs only).
- Issue #146 used Timex in the reporter's example; upstream tests avoid that dependency. Do not put Timex in the case.

---

## 10. Curator record fields

```yaml
case_id: nimble-parsec-154-choice-fallback
project: dashbitco/nimble_parsec
pr_url: https://github.com/dashbitco/nimble_parsec/pull/154
issue_url: https://github.com/dashbitco/nimble_parsec/issues/146
base_sha: 083498e808ed40be8d48e8af58b7860dd3909c63
merge_sha: 5b8bb30d2d0fa449035f433231eea71952489d23
head_sha: 634d7aaf51a4230f87c68767cd7caccd9456dbd2
merged_at: 2026-08-11T14:57:27Z
task_kind: bug_fix_parser_compiler
impl_files: 1
test_files_touched: 1
total_files: 2
license: Apache-2.0 (mix.exs package.licenses)
license_file: not found at base (404 LICENSE / LICENSE.md) — unverified filename
elixir: "~> 1.12"
offline: true
services_required: []
db_required: false
pr_body_empty: false
linked_issues: ["https://github.com/dashbitco/nimble_parsec/issues/146"]
later_commits_same_files:
  - sha: 4abe35a
    pr: 155
    date: 2026-08-11
    note: "string_slice combinator; parent is 5b8bb30; adjacent codegen, not a fix"
  - sha: 6f00961
    pr: 158
    date: 2026-08-13
    note: "character-literal guards; cosmetic printing"
difficulty_hint: medium
scope_risk: focused_compiler_semantics
```

---

## 11. Next action

1. Promote as a **non-web, non-DB diversity case** (macro/compiler error routing). Low prep.
2. Freeze the snapshot at merge `5b8bb30` (or head `634d7aa`) so #155's `:string_slice` work is **not** in tree — keeps the ticket to traversal/`catch_all` only.
3. Write acceptance from the four named tests in §4, including the standalone no-`catch_all` preservation case.
4. Do not merge with #153 (test-only) or #155 (slice change) to inflate scope.
