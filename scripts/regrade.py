#!/usr/bin/env python3
"""Regrade every completed saved patch after an evaluator fix; never regenerate answers."""
import argparse
import json
from pathlib import Path

from benchmark import ROOT, LOCAL, guard, grade, sha, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", required=True)
    parser.add_argument("--reason", default="Evaluator corrections: permit diagnostic files, check submitted regressions, and synchronize the upstream GenStage monitor test; no answers regenerated")
    args = parser.parse_args()
    guard()
    if Path(args.campaign).name != args.campaign:
        parser.error("Campaign must be one directory name")
    for path in sorted((LOCAL / "results" / args.campaign).glob("*/*/*/attempt.json")):
        attempt = json.loads(path.read_text())
        if attempt.get("status") != "completed":
            continue
        control = json.loads((LOCAL / "controls" / (attempt["case"] + ".json")).read_text())
        harness_hash = sha(ROOT / "scripts/benchmark.py")
        formatter_hash = sha(ROOT / "scripts/grade_formatter.exs")
        if not control["valid"] or control["runtime"] != attempt["runtime"] or control["harness_sha256"] != harness_hash or control["formatter_sha256"] != formatter_hash:
            raise RuntimeError("Fresh matching controls are required before regrading")
        output = path.parent / "regrade.json"
        patch_path = path.parent / "model.patch"
        identity = {"harness_sha256": harness_hash, "formatter_sha256": formatter_hash, "patch_sha256": sha(patch_path)}
        if output.exists():
            previous = json.loads(output.read_text())
            if all(previous.get(key) == value for key, value in identity.items()):
                continue
            archived = output.with_name("regrade-" + previous["harness_sha256"] + ".json")
            if archived.exists():
                raise RuntimeError(f"Prior regrade archive already exists: {archived}")
            output.rename(archived)
        result = {**identity, "case": attempt["case"], "candidate": attempt["candidate"]["id"],
                  "reason": args.reason,
                  "original_grade": attempt["grade"],
                  "grade": grade(attempt["case"], patch_path.read_text(), expected=control["reference_patch"]),
                  "power_envelope": guard()}
        write_json(output, result)
        print(json.dumps({"case": result["case"], "candidate": result["candidate"], "passed": result["grade"]["passed"]}), flush=True)


if __name__ == "__main__":
    main()
