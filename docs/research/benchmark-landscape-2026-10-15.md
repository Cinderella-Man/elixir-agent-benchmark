# Software-engineering benchmark landscape

Research date: 2026-10-15. This is evidence for a proposed benchmark policy, not an admission decision or a change to existing cases. No benchmark was executed. Sources are benchmark authors' papers, repositories and release notes, plus research groups' original audits. Audit findings are attributed; this investigation did not reproduce them.

The strongest match for the unnamed benchmark with newly written tasks is **Datacurve's DeepSWE**. That identification is an inference from the description, not confirmation from the user. Its tasks and solutions are original, but its current repository publishes prompts, tests and reference patches. “Never merged upstream” and “hidden from the evaluated agent” do not mean “secret from the public.” [DeepSWE announcement](https://deepswe.datacurve.ai/blog/deepswe), [public task layout](https://github.com/datacurve-ai/deep-swe/blob/0b9fabbb63b9104d678fe965e1632f2dd9eaa2ea/README.md).

## Comparison

Counts describe the named evaluation split or release, not every training/development record in a dataset repository.

| Benchmark / version | Source of tasks | Distribution and exposure | Relevant lesson |
| --- | --- | --- | --- |
| SWE-bench, original 2023 test set | 2,294 resolved issue/PR pairs from 12 Python repositories | Public repositories, issue text, reference and test patches | A historical PR supplies a known solution and executable evidence, but not automatically a fair grader. [Paper](https://arxiv.org/html/2310.06770v3), [dataset schema](https://huggingface.co/datasets/princeton-nlp/SWE-bench) |
| SWE-bench Lite | 300 test cases selected from the original | Public; explicitly restricts reference changes to one file and at most three hunks | Its selection is unsuitable as a template for a benchmark targeting coordinated changes across several files. [Selection rules](https://www.swebench.com/lite.html) |
| SWE-bench Verified, August 2024 | 500 original SWE-bench tasks screened by developers | Public; inherited historical issues and fixes | Human review improves quality but is not a lasting correctness or contamination certificate. [Release](https://openai.com/index/introducing-swe-bench-verified/) |
| SWE-Bench Pro, 2025 paper; public V2 released September 2026 | Historical commits, with human-written requirements and test review | Original: 731 public, 858 held-out public-repository tasks, 276 private commercial-repository tasks. V2 public: 642; HARD: 51 | Public tasks, withheld tasks on public code, and private-code tasks are different exposure regimes. [Original paper](https://arxiv.org/html/2509.16941v1), [V2 dataset](https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro) |
| DeepSWE, v1 May 2026 / v1.1 June 2026 | 113 newly authored tasks in 91 public repositories | Current public release includes prompts, verifiers and reference solutions; grading withholds them from the agent | Original feature work is viable; authorship alone does not prevent future contamination or grading defects. [Announcement](https://deepswe.datacurve.ai/blog/deepswe), [repository](https://github.com/datacurve-ai/deep-swe) |
| SWE-bench-Live, 2025–2026 | Continuously collected resolved GitHub issues/PRs | Public datasets and environments; initial release 1,319 tasks / 93 repositories, later language/OS expansion | Fresh collection and frozen comparison subsets solve different problems. [Paper](https://arxiv.org/html/2505.23419v1), [current project](https://swe-bench-live.github.io/) |
| SWE-rebench / SWE-rebench V2, 2025–2026 | Automated collection from public GitHub changes | Public collection/data; V2 includes 32,079 executable tasks across 20 languages | Scalable collection is useful, but task metadata must still flag ambiguity and restrictive tests. [V2 paper](https://proceedings.mlr.press/v306/badertdinov26a.html), [evaluation design](https://swe-rebench.com/about) |

## What the original SWE-bench family establishes

Original SWE-bench retained merged PRs linked to an issue and contributing tests. It ran the PR's tests before and after the implementation patch, requiring a failing-to-passing transition and discarding installation/runtime failures. This is a useful construction baseline: the reference demonstrates that the environment can execute a solution. It does not establish that every valid implementation passes, or that all requested behavior is tested. [Construction pipeline](https://arxiv.org/html/2310.06770v3#S2.SS1).

The dataset's public fields include the base commit, issue text, source patch, test patch, and failing-to-passing and passing-to-passing test lists. Tests withheld during an evaluation are therefore not necessarily unpublished. This is the distinction between inference-time access control and protection from prior training exposure. [Dataset schema](https://huggingface.co/datasets/princeton-nlp/SWE-bench).

Lite deliberately removes multi-file patches, file creation/deletion, long edit sequences and some specification hazards. Its ease of running evaluations comes with a different task distribution. There is no reason to inherit its single-file limit for this project. [Lite rules](https://www.swebench.com/lite.html).

Verified used 93 developers to annotate 1,699 samples, screening problem clarity and whether tests reject valid solutions; 500 survived. The original release also cautioned that changing the task distribution toward easier cases partly explains higher scores. “Verified” identifies that review procedure, not a proof of the entire software specification. [2024 release](https://openai.com/index/introducing-swe-bench-verified/).

In February 2026, OpenAI audited 138 difficult Verified cases, a deliberately selected 27.6% of the set. It reported material prompt/test issues in 59.4% **of that audited subset**, and evidence of remembered task details or patches across tested frontier models. This must not be restated as “59.4% of all Verified tasks are broken.” OpenAI then stopped reporting the benchmark and recommended Pro at that time. [February audit](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/).

## Pro: distinguish the original release from V2

Pro still starts with repository history. Engineers build environments, augment descriptions with requirements/interfaces, and review tests. Its original paper describes three repeated test runs to remove unstable tests. The commercial split uses proprietary repositories; the separate held-out split uses public repositories whose task selection is withheld. Keeping the selection private does not make those underlying public fixes new. [Original methodology and splits](https://arxiv.org/html/2509.16941v1#S3.SS3).

OpenAI's July 2026 audit of the 731-task public release reported 200 broken tasks through its agent-assisted process and 249 through human annotation. It identified overly restrictive tests, missing requirements, insufficient coverage and misleading prompts, estimating roughly 30% problematic tasks. Those findings concern the release audited then, not an evaluation of September's V2. [July audit](https://openai.com/index/separating-signal-from-noise-coding-evaluations/).

Scale's September 22 V2 removes 89 tasks. Its current dataset card reports 529 rewritten statements, 214 revised test patches and 38 revised reference patches. Corrected instructions were solved blind by a second engineer. V2 publishes all 642 tasks and a 51-task HARD subset selected using failures across model families; these are separate reporting populations. The card also exposes reference and test patches. Pin the dataset revision, config and verifier before comparing scores. [V2 card and changelog](https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro).

The V2 release protocol requires reference-patch success and empty-patch failure, strips future Git history, restricts agent networking to its model endpoint, and re-grades submitted patches in a pristine environment. These are useful controls to adopt independently of Pro's tasks. The announcement acknowledges residual trust in the model relay and the execution of candidate-controlled build/test hooks. The landing page highlights 69 contradictory instructions, while the dataset card reports 529 statement rewrites; they describe different scopes of modification and should not be collapsed into one count. [V2 release note](https://labs.scale.com/leaderboard/swe_bench_pro_public_v2?tab=full).

## DeepSWE: original work, currently public artifacts

The May 26 announcement describes tasks written from scratch, sometimes inspired by unresolved issues, with solutions never merged upstream. Its reference patches average seven changed files and its prompts average 2,158 characters. These are author-reported descriptive averages, not proposed acceptance thresholds for an Elixir benchmark, and their file-count definition should not be assumed identical to this project's implementation-only count. [Launch methodology](https://deepswe.datacurve.ai/blog/deepswe).

DeepSWE's paper describes observable-behavior verifiers, three repeated authoring runs, regression checks, independent human review and diagnostic attempts from multiple frontier configurations. It explicitly calls the LLM trajectory audit a second opinion: the judge is fallible and may favor its own model family. Multiple passing attempts are useful evidence; they are not a substitute for inspecting the relationship between the prompt and the grader. [Paper, task construction, QA and limitations](https://arxiv.org/html/2607.07946v1).

Version 1.1, announced June 14, collects the agent's committed patch and applies it in a fresh verifier container. It adds structured per-test reports, hides future commits, fixes dependency drift and removes some flaky tests. This illustrates why the benchmark version includes its environment, collection rules and grading implementation, not only the ticket text. [v1.1 changes](https://deepswe.datacurve.ai/blog/deepswe-v1-1).

The public repository was inspected at commit `0b9fabbb63b9104d678fe965e1632f2dd9eaa2ea`. For example, `abs-module-cache-flags` publicly contains `instruction.md`, `solution/solution.patch`, `tests/test.patch` and the grader. Its provenance file separately identifies upstream licenses and the license on Datacurve's original material. Thus the public release cannot be treated as a permanently secret evaluation set, regardless of the absence of upstream merged solutions. [Pinned example task](https://github.com/datacurve-ai/deep-swe/tree/0b9fabbb63b9104d678fe965e1632f2dd9eaa2ea/tasks/abs-module-cache-flags), [provenance](https://github.com/datacurve-ai/deep-swe/blob/0b9fabbb63b9104d678fe965e1632f2dd9eaa2ea/PROVENANCE.md).

An independent September 7 audit by Samaritan Research reports at least 23 of 113 v1.1 tasks with false-negative issues. Most reported cases involve agent-authored tests colliding with hidden test symbols or losing helpers when the verifier replaces files; others concern unstated formatting or behavior. The auditors stopped after crossing their published defect threshold, so this is not a complete error census. This investigation did not reproduce the findings or establish which subsequent repository revisions repair them. The evidence supports reviewing test insertion and patch replay, even when verifiers were handwritten. [Audit and linked examples](https://samaritan-research.org/benchmarks/deepswe/review).

## What rolling collection contributes

SWE-bench-Live's initial paper covers issues from January 2024–April 2025; that historical release should not be described as perpetually fresh. The project now separates continuing collection from frozen Lite/Verified subsets and requires submission trajectories to check for withheld-field leakage. Freshness and run integrity need separate controls. [Initial paper](https://arxiv.org/html/2505.23419v1), [current updates](https://swe-bench-live.github.io/).

SWE-rebench similarly aims to hold the scaffold fixed while collecting fresh tasks. Its V2 paper releases instance metadata identifying restrictive tests and underspecified statements, rather than claiming automated collection eliminates those problems. [Evaluation design](https://swe-rebench.com/about), [V2 paper](https://proceedings.mlr.press/v306/badertdinov26a.html).

## Implications to carry into the policy proposal

These are recommendations from the evidence, not newly adopted project rules:

1. Use historical PRs as candidate material and original tasks as another source; subject both to the same prompt/behavior/test review.
2. For coordinated multi-file work, avoid copying Lite's selection limits. Measure responsibilities and interactions as well as reference size.
3. Treat a reference solution and two blind successes as solvability evidence, then separately challenge the grader with valid alternatives and plausible partial fixes.
4. Record whether artifacts are public, withheld only at inference, or held privately for future evaluation. Original authorship is not a secrecy guarantee.
5. Version prompts, tests, environments and evaluation rules together. An audit or score for one release should never silently describe another.

The user has paused case changes and admissions while this policy is decided. This note therefore changes no cases, inventory, scores, runtime behavior or publication policy.
