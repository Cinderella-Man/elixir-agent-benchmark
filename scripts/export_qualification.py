#!/usr/bin/env python3
"""Export reviewed control facts and pins, without raw logs or measurements."""
import argparse
from collections import Counter
import json
from pathlib import Path

from benchmark import ROOT, LOCAL, sha, write_json


def checks(result):
    return {"passed": result["passed"], "completed": result["completed"],
            "counts": dict(Counter(result["test_results"].values())),
            "failed_tests": sorted(name for name, state in result["test_results"].items() if state == "failed"),
            "excluded_tests": result.get("exclusion_tags", {}),
            "failure_types": result.get("failure_types", {}),
            "failure_phases": result.get("failure_phases", {})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["pilot", "plausible"], required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    ids = json.loads((ROOT / "config/suites.json").read_text())[args.suite]
    output = {"suite": args.suite, "host": "ratx570", "model_attempts_in_this_qualification": 0,
              "harness_sha256": sha(ROOT / "scripts/benchmark.py"),
              "formatter_sha256": sha(ROOT / "scripts/grade_formatter.exs"), "cases": {}}
    for case in ids:
        control = json.loads((LOCAL / "controls" / (case + ".json")).read_text())
        assert control["valid"], f"Invalid controls: {case}"
        for key in ("harness_sha256", "formatter_sha256"):
            assert control[key] == output[key], f"Stale {key}: {case}"
        for name, digest in control["runtime"]["fixture_hashes"].items():
            assert sha(ROOT / "cases" / case / name) == digest, f"Changed fixture: {case}/{name}"
        entry = {"valid": True, "runtime": control["runtime"],
                 "power_service_sha256": control["power_envelope"]["unit_sha256"]}
        for kind in ("empty_patch", "reference_patch", "early_exit"):
            verdict = control[kind]
            entry[kind] = {"passed": verdict["passed"],
                           **{phase: checks(verdict[phase]) for phase in ("submission", "hidden", "regression")}}
        if coverage := control["reference_patch"].get("regression_coverage"):
            entry["reference_regression_coverage"] = {
                "passed": coverage["passed"], "detected_tests": coverage["detected_tests"],
                "broken_test_probe": checks(coverage["broken_test_probe"])}
        if partial := control.get("partial_repair"):
            entry["partial_repair"] = {"description": partial["description"],
                                       "rejected_behaviorally": partial["rejected_behaviorally"],
                                       "acceptance": checks(partial["grade"]["hidden"])}
        output["cases"][case] = entry
    write_json(args.out, output)
    print(json.dumps({"suite": args.suite, "valid_cases": len(ids), "output": str(args.out)}))


if __name__ == "__main__":
    main()
