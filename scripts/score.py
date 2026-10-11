#!/usr/bin/env python3
"""Score one frozen campaign using executable verdicts. No model or test execution."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from inventory import ROOT, protocol


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def score_campaign(directory, root=ROOT):
    receipt = json.loads((directory / "campaign.json").read_text())
    if receipt.get("schema_version") != 2:
        raise ValueError("Legacy campaign has no frozen protocol; retain its evidence matrix without a comparable score")
    frozen = receipt["protocol"]
    current = protocol(receipt["cases"], receipt["seeds"], receipt["max_calls"], receipt["max_completion_tokens"], root)
    if frozen != current:
        raise ValueError("Campaign inputs differ from the current benchmark; score with its archived revision")
    expected = len(receipt["cases"]) * len(receipt["seeds"])
    output = {"campaign": receipt["campaign"], "benchmark": frozen["benchmark"]["id"],
              "protocol_sha256": fingerprint(frozen), "scope": receipt["scope"],
              "scoring": "Each case has equal weight; average all declared seeds, never choose the best attempt.",
              "comparison_status": "Context capacity and backend token accounting still require common-profile qualification.",
              "candidates": {}}
    for candidate in receipt["candidates"]:
        snapshot = receipt["candidate_snapshots"][candidate]
        counts, projects, cells, profiles = Counter(), {}, [], set()
        for case in receipt["cases"]:
            spec = json.loads((root / "cases" / case / "case.json").read_text())
            project = spec.get("project") or spec["repository"]["url"].removesuffix(".git").rstrip("/").rsplit("/", 1)[-1]
            project_counts = projects.setdefault(project, Counter())
            control_path = root / ".local/controls" / (case + ".json")
            control = json.loads(control_path.read_text()) if control_path.exists() else {}
            runtime = json.loads((root / ".local/runtimes" / (case + ".json")).read_text())
            for seed in receipt["seeds"]:
                attempt_dir = directory / candidate / case / f"seed-{seed}"
                path = attempt_dir / "attempt.json"
                state = "missing"
                if path.exists():
                    record = json.loads(path.read_text())
                    correct_identity = (record.get("candidate") == snapshot and record.get("case") == case and
                                        record.get("seed") == seed and record.get("harness_sha256") == frozen["controller_sha256"] and
                                        record.get("case_sha256") == frozen["fixtures"][case]["case.json"] and
                                        record.get("limits") == {"model_calls": receipt["max_calls"],
                                            "server_reported_completion_tokens": receipt["max_completion_tokens"], "per_call": 8192})
                    qualified = (control.get("valid") and control.get("harness_sha256") == frozen["controller_sha256"] and
                                 control.get("formatter_sha256") == frozen["formatter_sha256"] and
                                 control.get("runtime", {}).get("fixture_hashes") == frozen["fixtures"][case] and
                                 record.get("runtime") == control.get("runtime") == runtime)
                    if not correct_identity:
                        state = "identity_mismatch"
                    elif record.get("status") == "error":
                        state = "error"
                    elif record.get("status") == "completed" and qualified:
                        grade = record.get("grade", {})
                        state = "pass" if grade.get("passed") is True else "fail" if grade.get("passed") is False else "invalid_grade"
                    elif record.get("status") == "completed":
                        state = "unqualified"
                    else:
                        state = "incomplete"
                    props = record.get("candidate_metadata", {}).get("props", {})
                    profiles.add(str(props.get("default_generation_settings", {}).get("n_ctx", "unknown")))
                elif (attempt_dir / "setup-error.json").exists():
                    state = "setup_error"
                counts[state] += 1
                project_counts[state] += 1
                cells.append({"case": case, "seed": seed, "state": state})
        complete = counts["pass"] + counts["fail"] == expected
        output["candidates"][candidate] = {
            "candidate": snapshot, "candidate_sha256": fingerprint(snapshot),
            "expected_attempts": expected, "counts": dict(counts), "complete": complete,
            "score_percent": 100 * counts["pass"] / expected if complete and receipt["scope"] == "full" else None,
            "observed_context_sizes": sorted(profiles),
            "projects": {name: dict(values) for name, values in projects.items()}, "attempts": cells}
    return output


def markdown_scores(data):
    lines = ["## Deterministic case scores", "", data["scoring"], "",
             "A final score requires the complete benchmark matrix and valid grading for every declared attempt. Errors and missing attempts stay visible and block a final score; a diagnostic subset never receives a full-benchmark score. These are executable correctness scores, not an assessment of style or maintainability.", "",
             data["comparison_status"], "",
             "| Candidate | Quantization | Passed / planned | Failed | Errors or pending | Score |",
             "| --- | --- | ---: | ---: | ---: | ---: |"]
    for name, result in data["candidates"].items():
        counts = result["counts"]
        passed, failed = counts.get("pass", 0), counts.get("fail", 0)
        pending = result["expected_attempts"] - passed - failed
        value = result["score_percent"]
        score = ("Diagnostic subset" if data["scope"] != "full" else "Incomplete") if value is None else f"{value:.2f}%"
        lines.append(f"| {name} | {result['candidate'].get('quantization', 'unspecified')} | {passed} / {result['expected_attempts']} | {failed} | {pending} | {score} |")
    lines += ["", f"Frozen protocol: `{data['protocol_sha256']}`. Scores from different protocol fingerprints must not be merged or ranked together."]
    lines += ["", "| Candidate | Project | Passed | Failed | Errors or pending |",
              "| --- | --- | ---: | ---: | ---: |"]
    for name, result in data["candidates"].items():
        for project, counts in result["projects"].items():
            passed, failed = counts.get("pass", 0), counts.get("fail", 0)
            pending = sum(counts.values()) - passed - failed
            lines.append(f"| {name} | {project} | {passed} | {failed} | {pending} |")
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", required=True)
    args = parser.parse_args()
    if Path(args.campaign).name != args.campaign or args.campaign in {".", ".."}:
        parser.error("Campaign must be a directory name")
    result = score_campaign(ROOT / ".local/results" / args.campaign)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
