#!/usr/bin/env python3
"""Qualify the complete benchmark on the authorized rig; never run models."""
import argparse
import hashlib
import json

from benchmark import ROOT, LOCAL, controls, guard, prepare, refresh_fixture, write_json
from inventory import inventory, select_cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", nargs="+", help="Optional focused fixture diagnostics; default is every case")
    preparation = parser.add_mutually_exclusive_group()
    preparation.add_argument("--prepare", action="store_true", help="Build every case from its source pin")
    preparation.add_argument("--refresh", action="store_true", help="Refresh grader-only changes; source/runtime changes require --prepare")
    args = parser.parse_args()
    guard()
    cases = select_cases(args.cases)
    summary = {"benchmark": inventory()["id"], "selected_cases": cases, "cases": {}, "valid": False}
    selection_id = hashlib.sha256("\0".join(cases).encode()).hexdigest()[:12]
    output = LOCAL / "results/controls" / (f"selected-{selection_id}.json" if args.cases else "benchmark.json")
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
