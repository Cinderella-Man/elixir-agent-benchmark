#!/usr/bin/env python3
"""Reject deliberately incomplete repairs. Correctness controls on ratx570 only."""
import json
from pathlib import Path
import re

from benchmark import ROOT, LOCAL, guard, grade, sha, write_json


def main():
    guard()
    trials = []
    for case in ("core-nimble-normalization", "web-settings-validation", "web-playlist-isolation"):
        reference = (ROOT / "cases" / case / "reference.patch").read_text()
        if case.startswith("core-"):
            first_hunk = reference.index("@@")
            header = reference[:first_hunk]
            hunks = re.split(r"(?=^@@ )", reference[first_hunk:], flags=re.M)
            patches = [header + hunk for hunk in hunks if hunk.strip()]
        else:
            patches = ["diff --git " + block for block in reference.split("diff --git ")[1:]]
        assert len(patches) == 2, "These controls expect exactly two independent repair locations"
        trials.extend((case, f"repair-location-{index}-only", patch) for index, patch in enumerate(patches, 1))
    case = "core-genstage-cancelled-demand"
    reference = (ROOT / "cases" / case / "reference.patch").read_text()
    assert "current + pending" in reference
    trials.append((case, "replace-credit-instead-of-accumulate", reference.replace("current + pending", "current")))
    records = []
    for case, name, patch in trials:
        control = json.loads((LOCAL / "controls" / f"{case}.json").read_text())
        assert control["valid"] and control["harness_sha256"] == sha(ROOT / "scripts/benchmark.py")
        result = grade(case, patch, expected=control["reference_patch"])
        records.append({"case": case, "mutation": name, "patch": patch, "rejected": not result["passed"], "grade": result})
        print(json.dumps({"case": case, "mutation": name, "rejected": not result["passed"]}), flush=True)
    output = ROOT / "results/partial-repair-controls.json"
    write_json(output, {"harness_sha256": sha(ROOT / "scripts/benchmark.py"), "power_envelope": guard(),
                        "all_rejected": all(record["rejected"] for record in records), "trials": records})
    if not all(record["rejected"] for record in records):
        raise SystemExit("At least one incomplete repair passed; inspect coverage before scoring")


if __name__ == "__main__":
    main()
