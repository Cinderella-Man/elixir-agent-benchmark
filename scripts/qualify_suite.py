#!/usr/bin/env python3
"""Prepare and qualify a named suite on the authorized rig; never run models."""
import argparse
import json

from benchmark import ROOT, LOCAL, controls, guard, prepare, refresh_fixture, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=["pilot", "plausible"], required=True)
    preparation = parser.add_mutually_exclusive_group()
    preparation.add_argument("--prepare", action="store_true", help="Build every case from its source pin")
    preparation.add_argument("--refresh", action="store_true", help="Refresh grader-only changes; source/runtime changes require --prepare")
    args = parser.parse_args()
    guard()
    cases = json.loads((ROOT / "config/suites.json").read_text())[args.suite]
    summary = {"suite": args.suite, "cases": {}, "valid": False}
    output = LOCAL / "results/controls" / (args.suite + "-suite.json")
    for case in cases:
        print(json.dumps({"case": case, "stage": "qualification_started"}), flush=True)
        try:
            if args.prepare:
                prepare(case)
            elif args.refresh:
                refresh_fixture(case)
            result = controls(case, LOCAL / "results/controls" / (case + ".json"))
            summary["cases"][case] = {"valid": result["valid"],
                                     "harness_sha256": result["harness_sha256"],
                                     "formatter_sha256": result["formatter_sha256"]}
        except Exception as error:
            summary["cases"][case] = {"valid": False, "error": f"{type(error).__name__}: {error}"}
        write_json(output, summary)
        print(json.dumps({"case": case, **summary["cases"][case]}), flush=True)
    summary["valid"] = all(value["valid"] for value in summary["cases"].values())
    summary["power_envelope"] = guard()
    write_json(output, summary)
    if not summary["valid"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
