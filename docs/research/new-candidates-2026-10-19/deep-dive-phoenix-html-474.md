# Deep-dive dossier — phoenixframework/phoenix_html PR #474 (+ follow-up #475)

**Status:** screened (discovery complete; no qualification executed)  
**Research date:** 2026-10-19  
**Dossier kind:** case-creation pack (everything needed to freeze a case, no bundle written)

---

## 1. Identity

| Field | Value |
| --- | --- |
| Project | [phoenixframework/phoenix_html](https://github.com/phoenixframework/phoenix_html) |
| Feature PR | [#474 — Add json_escape](https://github.com/phoenixframework/phoenix_html/pull/474) |
| Follow-up PR | [#475 — Transition json_escape/5 to 4-arity after escaping](https://github.com/phoenixframework/phoenix_html/pull/475) |
| Feature author | `josevalim` (José Valim) |
| Follow-up author | `preciz` (PR body notes “Assisted-by: Antigravity CLI:Gemini 3.8 Flash”) |
| Feature head branch | `jv-json-escape` |
| Feature commit | `faaf618b07ca43e611dc6e7d5f745219ff684883` (“Add json_escape”) |
| **Base SHA (feature)** | `677e5720758ab1671ee33d0487ada07780b1d057` (“Improve docs”) |
| **Merge SHA (feature)** | `6548938fa8892699dbc17b7e93bd5801c7131ded` |
| Feature merged | 2026-08-18 into `main` by josevalim (4 checks passed) |
| Follow-up commit | `50bf953127678ef7b921243c6994311a6274ecfa` |
| Follow-up merge SHA | `7cbed8256057aaa3e6b266d780c7cb7824610aca` |
| Follow-up merged | 2026-09-04 into `main` by josevalim (2 checks passed) |
| Reviewers | SteffenDE approved #474 (“Ha, I wanted this in at least one occasion in the past already!”). #475 had no reviews. |
| PR body (#474) | **Empty** (“No description provided.”). |
| PR body (#475) | Performance note only: “After finalizing a chunk, transition back to json_escape/4 instead of passing 0 to json_escape/5. This avoids redundant binary_part/3 calls on consecutive escape characters and reduces VM register overhead. This aligns json_escape with html_escape and improves performance.” |

**URLs**
- https://github.com/phoenixframework/phoenix_html/pull/474
- https://github.com/phoenixframework/phoenix_html/pull/475
- Diff endpoints used: `https://github.com/phoenixframework/phoenix_html/pull/474.diff`, `.../475.diff`
- Raw sources at merge SHAs via `raw.githubusercontent.com`

---

## 2. Shortest ticket / brief (product decisions stated)

### Recommended solver-visible brief (clarified implementation brief)

> Add a public helper in `Phoenix.HTML` that takes **already-encoded JSON** (a binary) and returns HTML-safe content suitable for embedding inside an HTML `<script>` tag, so the JSON cannot break out of the script context. Name the public function `json_escape/1`. It must accept a binary and return `{:safe, iodata}`. Escape exactly the characters `<`, `>`, and `&` as the JSON Unicode escape sequences `\u003C`, `\u003E`, and `\u0026` (uppercase hex). Leave all other characters — including quotes, backslashes, and already-escaped JSON sequences such as `\"` and `\\` — unchanged. An empty binary returns `{:safe, ""}`. Preserve the existing HTML/JS/CSS escaping helpers.

### Why these product decisions must be in the brief

| Decision | Why it cannot be left to hidden tests |
| --- | --- |
| Name `json_escape/1` | Public API name is the requested outcome. |
| Arity 1, binary-only input | `javascript_escape/1` accepts `{:safe, _}` too; `json_escape/1` does not. Solvers must know the contract. |
| Return `{:safe, iodata}` | Distinct from `javascript_escape/1`, which returns a bare binary for bare input. |
| Exact escape table `<`→`\u003C`, `>`→`\u003E`, `&`→`\u0026` | Multiple safe encodings exist (lowercase `\u003c`, `\x3C`, HTML entities `&lt;`, escaping `/` as `<\/`, …). Without stating the table, graders overconstrain. |
| Input is already-encoded JSON | The function does not JSON-encode; it only escapes HTML-context breakouts. |
| Quotes/slashes unchanged | Inverse obligation — incomplete solutions that HTML-escape the whole payload or re-encode JSON fail here. |

**Task kind / family:** bounded feature / HTML–JSON safety helper (security-adjacent).  
**Ticket style:** clarified implementation brief (repository PR body is empty, so the brief is the frozen product contract).

---

## 3. Implementation roles + key code quotes

### Files and roles

| File | Role | Count class |
| --- | --- | --- |
| `lib/phoenix_html.ex` | Public `json_escape/1` + private scanner clauses | **1 implementation file** |
| `test/phoenix_html_test.exs` | Behavior tests for `json_escape/1` | tests (count separately) |
| `CHANGELOG.md` | **Not updated** by either PR (see §6) | docs — absent |

Focused one-file feature. #475 is a **1-line private-helper tweak** inside the same file.

### Public API after #475 (frozen contract)

```
Name:            Phoenix.HTML.json_escape/1
Spec:            @spec json_escape(binary) :: safe
Guard:           when is_binary(data)
Return:          always {:safe, iodata}
                 — empty input  → {:safe, ""}
                 — no escapes   → {:safe, original_binary}   (identity fast path)
                 — with escapes → {:safe, iolist of chunks + inserted escapes}
Escapes table:   ?< → "\\u003C"   ?& → "\\u0026"   ?> → "\\u003E"
Not escaped:     quotes (" '), backslash, slash, U+2028/U+2029, NUL, non-ASCII
Input:           already-encoded JSON binary (not iodata, not {:safe, _})
```

### Key implementation quote (post-#475, SHA `7cbed82`)

```elixir
@doc ~S"""
Escapes encoded JSON for safe insertion into an HTML script tag.

The given JSON must already be encoded. The characters `<`, `>`, and `&`
are encoded as JSON Unicode escape sequences and the result is marked as
HTML safe.

    iex> json = ~s({"name":"</script>"})
    iex> json |> json_escape() |> safe_to_string()
    "{\"name\":\"\\u003C/script\\u003E\"}"

"""
@spec json_escape(binary) :: safe
def json_escape(data) when is_binary(data) do
  {:safe, json_escape(data, 0, data, [])}
end

escapes = [
  {?<, "\\u003C"},
  {?>, "\\u003E"},
  {?&, "\\u0026"}
]
```

Scanner is a two-mode binary walker (`json_escape/4` for “at an escape”, `json_escape/5` for “accumulating a plain run with `len`”). The `skip`/`original` pair lets untouched runs be returned as `binary_part` slices of the original (zero-copy identity path).

### #475 delta (the only change)

```diff
-      json_escape(rest, skip + len + 1, original, [acc, part | unquote(insert)], 0)
+      json_escape(rest, skip + len + 1, original, [acc, part | unquote(insert)])
```

After emitting an escape, #474 re-entered the 5-arity clause with `len = 0` (which would call `binary_part(original, skip, 0)` on the next escape). #475 re-enters the 4-arity clause instead. **No public API change. No test change.** Title “json_escape/5 to 4-arity” refers to the *private* helper, not the public `json_escape/1`.

### Adjacent public API (preservation targets, same module)

```
html_escape/1        (accepts {:safe,_} / iodata; returns {:safe, iodata})
safe_to_string/1     (unwraps {:safe, iodata})
javascript_escape/1  (accepts binary | {:safe,_}; returns binary | {:safe, binary})
css_escape/1         (binary → binary)
```

---

## 4. Named acceptance assertions ↔ visible requirements

Tests added in #474 (verbatim from `test/phoenix_html_test.exs` at merge SHA `6548938`):

```elixir
test "json_escape/1" do
  assert json_escape("") == {:safe, ""}

  assert ~s({"data":"</script><!--&>"})
         |> json_escape()
         |> safe_to_string() == ~S({"data":"\u003C/script\u003E\u003C!--\u0026\u003E"})

  assert ~S({"data":"\"quotes\" and \\slashes"})
         |> json_escape()
         |> safe_to_string() == ~S({"data":"\"quotes\" and \\slashes"})
end
```

Plus the doctest (run via `doctest Phoenix.HTML`):

```elixir
iex> json = ~s({"name":"</script>"})
iex> json |> json_escape() |> safe_to_string()
"{\"name\":\"\\u003C/script\\u003E\"}"
```

### Assertion map

| Named assertion | Visible requirement it scores | Discriminates |
| --- | --- | --- |
| `A1 empty → {:safe, ""}` | Empty binary contract; return shape `{:safe, _}` | Bare-string return; `nil`/error |
| `A2 script-breakout payload` | `<` `>` `&` → `\u003C` `\u003E` `\u0026`; `/` in `</script>` left alone | Identity; HTML-entities encoding; escaping `/`; missing `&` |
| `A3 JSON-escaped quotes/slashes preserved` | Already-encoded JSON (`\"`, `\\`) untouched | Re-encoding / double-escaping; HTML-escaping quotes |
| `A4 doctest `</script>` case` | Same as A2 at module doc level | Same as A2 |
| `A5 existing `javascript_escape` tests still pass` | Preservation of sibling helpers | Accidental rewrite of JS escape |
| `A6 existing `html_escape` tests still pass` | Preservation of HTML escape | Same |

### Proposed additional named assertions for a case (if graded)

| ID | Assertion | Why needed |
| --- | --- | --- |
| `A7` | `json_escape(~s({"a":"&"}))` → `~S({"a":"\u0026"})` | `&` alone (not only inside `<!--&>`) |
| `A8` | `json_escape(~S({"a":"b"})) == {:safe, ~S({"a":"b"})}` | Identity path; no needless allocation/rewrite |
| `A9` | `json_escape(~S({"u":"café"}))` leaves non-ASCII bytes unchanged | Unicode must not be mangled |
| `A10` | `safe_to_string(json_escape(x))` contains no raw `<` when `x` is the breakout payload | End-state safety, not just exact table |

**Acceptance boundary:** pure function, ExUnit, no process state. Prefer exact output equality on the stated escape table (it is in the brief). Accept iolist vs binary after `safe_to_string/1` only.

---

## 5. Compiling incomplete + expected named failure

### Plausible incomplete A — escape `<`/`>` only, skip `&`

- Compiles. Fails `A2` (and `A7`): expected `\u0026` in `<!--&>`.
- Named failure: `json_escape/1` (or the curated name, e.g. `escapes ampersand`).

### Plausible incomplete B — HTML-escape instead of JSON-Unicode-escape

- Compiles. Produces `&lt;/script&gt;` style output.
- Fails `A2` exact-equality (and is wrong for JSON-in-script: `&lt;` is not a JSON escape).
- Named failure: `uses JSON Unicode escapes, not HTML entities`.

### Plausible incomplete C — escape quotes/slashes too (over-escape)

- Compiles. Fails `A3` (valid JSON sequences destroyed).
- Named failure: `preserves JSON string escapes`.

### Plausible incomplete D — return bare binary, not `{:safe, _}`

- Compiles. Fails `A1` return shape.
- Named failure: `returns HTML-safe tuple`.

### Not recommended as incomplete

Deleting half the scanner (compile error) — guidelines require a *compiling* partial solution.

---

## 6. Integrity / bypass control

| Bypass | Control |
| --- | --- |
| `def json_escape(data), do: {:safe, data}` (identity) | `A2` + `A7` exact-equality on breakout payload. |
| HTML-escape the payload (`Phoenix.HTML.html_escape/1` wrapper) | `A2` fails (entities ≠ `\u00XX`). |
| Hardcode the doctest strings only | `A2`/`A3`/`A7`/`A8` use independent inputs; keep at least one payload not in the brief. |
| Escape only `</script>` as a whole string | `A2` contains `</script><!--&>` — partial whole-string replace misses `<!--&>` and `&`. |
| Mutate tests / delete existing suites | Preservation: run full `mix test` including pre-existing `html_escape`, `javascript_escape`, `css_escape` suites. |

**Positive preservation examples required** (guidelines: pair rejection with preservation):
- Existing `javascript_escape/1` block (quotes, backticks, U+2028/U+2029, NUL, `{:safe, _}` inputs) must stay green.
- Existing `html_escape` describe-block must stay green.
- `A3` is the positive “legitimate data survives” example for JSON.

---

## 7. Preservation checks

1. `test "javascript_escape/1"` — full block unchanged.
2. `describe "html_escape"` — entities + iodata validation unchanged.
3. `css_escape` tests (other file / later in suite) unchanged.
4. Module compiles with `doctest Phoenix.HTML` still enabled (A4).
5. No arity/shape change to `html_escape/1` or `javascript_escape/1`.

---

## 8. Runtime / offline / services

| Item | Value |
| --- | --- |
| Mix project | `phoenix_html`, version **4.3.0** at merge SHA |
| Elixir requirement | `~> 1.7` |
| Runtime deps | **none** (`extra_applications: [:eex, :logger]`) |
| Dev/docs deps | `ex_doc`, `makeup_eex`, `makeup_syntect` (docs-only, `only: :docs`) |
| Test deps | none beyond ExUnit |
| Network / DB / browser | **None.** Pure library. |
| Test style | `use ExUnit.Case, async: true` + `import Phoenix.HTML` + `doctest Phoenix.HTML`. Unit assertions on return values. **Not** LiveView/browser. |
| Setup cost | `mix deps.get` (docs deps optional) + `mix test`. Very low. |
| Offline | Fully offline once the repo + hex cache (or vendored deps) are present. Docs deps can be omitted for `mix test`. |

**Historical `mix.exs` quote (at merge SHA):**
```elixir
app: :phoenix_html,
version: @version,          # "4.3.0"
elixir: "~> 1.7",
...
{:ex_doc, ">= 0.0.0", only: :docs},
```

---

## 9. License / provenance

| Item | Value |
| --- | --- |
| License | **MIT** (`LICENSE` at repo root) |
| Copyright line | `Copyright (c) 2014 Chris McCord` |
| `mix.exs` package | `licenses: ["MIT"]`, maintainers Chris McCord / José Valim |
| Feature author | José Valim (project founder) — public PR, empty body |
| Follow-up author | `preciz`, AI-assisted (disclosed in PR body) |
| Exposure | Fully public. May be in training data of any model. |

---

## 10. Reference challenges

### 10.1 Later commits to the same files after merge — **CRITICAL FINDING**

Queried GitHub commit history for each touched path (HTML commits pages; REST API was rate-limited).

| Path | Commits after merge | Finding |
| --- | --- | --- |
| `lib/phoenix_html.ex` | **None.** Latest commit on this file is `7cbed82` (#475, 2026-09-04). | **No later reference bugs.** As of 2026-10-19 the implementation is unchanged since #475. |
| `test/phoenix_html_test.exs` | **None.** Latest commit is `6548938` (#474, 2026-08-18). #475 did **not** touch tests. | No test backfill; no later contract corrections. |
| `CHANGELOG.md` | (checked at SHA `7cbed82`) | **`json_escape` is not listed.** CHANGELOG still headed `## 4.3.0 (2025-09-28)`. The feature landed after 4.3.0 without a changelog entry at these SHAs. |

**Implication:** there is no upstream “bug trail” to mine for hidden failure modes. The risk is the opposite: a young, lightly-tested API whose exact escape table is only pinned by 3 assertions + 1 doctest.

### 10.2 Ambiguous escape table (main grading hazard)

Multiple encodings are safe for JSON-in-`<script>`:

| Encoding | Safe for script breakout? | Matches reference? |
| --- | --- | --- |
| `\u003C` `\u003E` `\u0026` (uppercase hex) | yes | **yes — reference** |
| `\u003c` `\u003e` `\u0026` (lowercase hex) | yes | no (JSON allows both; reference uses uppercase) |
| `\x3C` style | no (not valid JSON) | no |
| HTML entities `&lt;` | **no** — still inside a JS string, and not JSON | no |
| `<\/script>` (escaping `/`) | yes | no (reference leaves `/` alone) |
| Percent-encoding | no | no |

**Curator rule:** either (a) put the exact table in the brief (recommended — it is the product decision), or (b) if the brief only says “safe for script embedding”, accept any encoding that survives an embedding smoke test and do **not** use exact-string equality. Do not mix the two.

### 10.3 #475 as a task component

Guidelines defer work whose only claimed result is lower latency. #475 is exactly that (no behavior change). **Do not include #475 in the solver ticket.** Record it as lineage only: if the case pins post-#475 source as the environment, the reference is the optimized scanner; solvers are free to write a clear non-optimized scanner as long as outputs match. If the case pins `6548938` (pre-#475), behavior is identical for grading purposes.

### 10.4 Doctest coupling

`doctest Phoenix.HTML` is enabled in the test file. If a solver writes a docstring example that fails, `mix test` fails for a reason not in the named acceptance set. **Mitigation:** either require a correct `@doc` example in the brief, or strip/neutralize doctest collection for the scored run and score only named ExUnit tests. Flagged as unresolved until qualification.

### 10.5 AI-assisted follow-up

#475 discloses “Assisted-by: Antigravity CLI:Gemini 3.8 Flash”. Not a quality defect by itself (merged by Valim), but record it in provenance if exposure accounting matters.

---

## 11. Curator record (fields from `docs/pr-selection-guidelines.md`)

```markdown
Source type / project / source revisions / PR or original request:
  historical PR pair; phoenixframework/phoenix_html;
  base 677e5720758ab1671ee33d0487ada07780b1d057 → merge 6548938fa8892699dbc17b7e93bd5801c7131ded (#474);
  follow-up merge 7cbed8256057aaa3e6b266d780c7cb7824610aca (#475).
  Request: PR #474 (body empty) + reviewer comment expressing prior demand.

Status: screened
Case version / release inventory / public or withheld exposure:
  none yet; would be v1; public (upstream PRs are public)

Task kind / family / maintenance report or clarified brief:
  bounded feature / HTML-JSON safety helper / clarified implementation brief
  (PR body empty → product contract must be frozen in the brief)

Full solver-visible ticket and appended instructions:
  see §2. Appended instructions must NOT restate the escape table a second
  time in prose; put it once in the brief or once in visible tests.

Implementation files and each file's role:
  lib/phoenix_html.ex — json_escape/1 public API + private binary scanner
  (1 substantive implementation file)

Test / documentation / generated / mechanical files (separate counts):
  test/phoenix_html_test.exs — 1 test + doctest (tests)
  CHANGELOG.md — NOT updated by either PR (docs: absent)
  no generated/mechanical files

Cross-component behavior to verify:
  - json_escape output is {:safe, iodata} consistent with Phoenix.HTML.Safe
  - safe_to_string/1 round-trip produces the stated escape table
  - sibling escape helpers (html_escape, javascript_escape, css_escape) unchanged

Visible source for each scored obligation:
  A1/A2/A3 from upstream tests at merge SHA (visible in reference tests;
  for the case, these become curated named assertions — see §4)
  A5/A6 from pre-existing suites in the same test file

Starting-state and reference-test evidence (inspected vs executed):
  inspected: full diffs of #474/#475, test file at merge, mix.exs, LICENSE,
  CHANGELOG at 7cbed82, commit histories of touched paths
  executed: NOT executed in this research pass (no mix run)

Plausible partial solution and expected named failure:
  incomplete A: escape <> but not & → fails "escapes ampersand" (A2/A7)
  incomplete B: HTML entities instead of \u00XX → fails exact escape-table assert
  incomplete C: over-escape quotes/slashes → fails A3
  incomplete D: return bare binary → fails A1 return shape

Preservation and alternative-solution risks:
  - doctest Phoenix.HTML couples doc examples to test outcome (see §10.4)
  - escape-table ambiguity (see §10.2) is the main unfairness risk
  - alternative scanners (regex, :binary.replace, iolist builders) must pass
    if outputs match; do not require the skip/len two-mode shape

Runtime / offline services / license evidence and unknowns:
  Mix library, Elixir ~> 1.7, zero runtime deps, no network/DB/browser.
  MIT LICENSE (Chris McCord 2014). Fully offline.
  Unknown: exact Elixir/OTP used in upstream CI at these SHAs (not fetched).

Three-round named control outcomes and frozen-input evidence:
  none yet (research pass only)

Blind model/settings policy and all attempt IDs (including failures/retries):
  none yet

Independent contract review / passing-patch reviews / unresolved findings:
  none yet. Unresolved: doctest policy (§10.4); whether to include A7–A10
  in the scored set; whether the brief should show one example input/output.

Coverage added / related or duplicate tasks:
  HTML-JSON safety API — small diversity case, not another LiveView task.
  #468 (structs as select option values) is a different form feature; do not combine.
  No other json_escape tasks in inventory (checked research folder names).

Admission or exclusion reason / conditions for reconsideration:
  provisional pending: freeze escape table in brief, decide doctest policy,
  write named assertions, run 3 qualification rounds + 2 blind successes.

Next action:
  Freeze §2 brief (escape table stated once). Choose source SHA 6548938
  (behavior-identical to post-#475 for grading). Strip or neutralize
  doctest collection OR require a correct @doc example. Draft named
  assertions A1–A6 minimum, A7–A10 recommended. Then qualify.
```

---

## 12. Next action

1. **Freeze the brief in §2** — escape table named once; `json_escape/1` / `{:safe, iodata}` named once.
2. **Pick the source SHA:** use `6548938` (post-#474, pre-#475) *or* `7cbed82` (post-#475); grading outcomes are identical. Prefer `677e572` base as the solver start state and apply the feature as the reference patch.
3. **Resolve doctest policy** before qualification (strip doctest from scored run, or require a correct example in the brief).
4. **Write named assertions A1–A6** (minimum) and consider A7–A10.
5. **Three fresh qualification rounds** with named outcomes, then two blind successes.

**Recommendation:** **admit as a focused one-file corpus diversity case** once the escape table is in the brief. Small, offline, deterministic, security-flavored. Do **not** merge #475 into the ticket. Do **not** grade on an unstated escape encoding.
