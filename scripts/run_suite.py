#!/usr/bin/env python3
"""Run a fixed case/seed matrix, one active attempt per endpoint. Remote only."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

from benchmark import ROOT, guard


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", required=True)
    parser.add_argument("--candidates", nargs="+", default=["coder390", "swift15", "flash-next"])
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--cases", nargs="+")
    selection.add_argument("--suite", default="pilot", choices=["pilot", "plausible"])
    parser.add_argument("--max-calls", type=int, default=32)
    parser.add_argument("--max-tokens", type=int, default=65536)
    parser.add_argument("--seeds", nargs="+", type=int, default=[101])
    args = parser.parse_args()
    guard()
    if Path(args.campaign).name != args.campaign:
        parser.error("Use one directory name for the campaign")
    known = {c["id"] for c in json.loads((ROOT / "config/candidates.json").read_text())["candidates"]}
    if set(args.candidates) - known or len(set(args.candidates)) != len(args.candidates):
        parser.error("Candidate IDs must be known and unique")
    suites = json.loads((ROOT / "config/suites.json").read_text())
    cases = args.cases or suites[args.suite]
    available = {path.parent.name for path in (ROOT / "cases").glob("*/case.json")}
    if set(cases) - available or len(set(cases)) != len(cases):
        parser.error("Case IDs must be known and unique")
    if len(set(args.seeds)) != len(args.seeds):
        parser.error("Seeds must be unique")
    campaign = ROOT / ".local/results" / args.campaign
    if campaign.exists():
        parser.error("Campaign already exists; choose a new ID to preserve all attempts")
    campaign.mkdir(parents=True)
    receipt = {"campaign": args.campaign, "candidates": args.candidates, "cases": cases, "seeds": args.seeds,
               "suite": None if args.cases else args.suite,
               "max_calls": args.max_calls, "max_completion_tokens": args.max_tokens,
               "context_policy": "no_compaction; context-window qualification is separate from completion-token allowance"}
    (campaign / "campaign.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def candidate_worker(candidate):
        for seed in args.seeds:
            for case in cases:
                out = campaign / candidate / case / f"seed-{seed}"
                command = [sys.executable, str(ROOT / "scripts/benchmark.py"), "run", "--case", case,
                           "--candidate", candidate, "--seed", str(seed), "--out", str(out),
                           "--max-calls", str(args.max_calls), "--max-tokens", str(args.max_tokens)]
                result = subprocess.run(command, text=True, capture_output=True)
                attempt = out / "attempt.json"
                if attempt.exists():
                    data = json.loads(attempt.read_text())
                    status = {"candidate": candidate, "case": case, "seed": seed, "status": data.get("status", "incomplete"),
                              "passed": data.get("grade", {}).get("passed"), "error": data.get("error")}
                else:
                    out.mkdir(parents=True, exist_ok=True)
                    status = {"candidate": candidate, "case": case, "seed": seed, "status": "setup_error", "diagnostic": result.stderr[-8000:]}
                    (out / "setup-error.json").write_text(json.dumps(status, indent=2) + "\n")
                print(json.dumps(status), flush=True)

    with ThreadPoolExecutor(max_workers=len(args.candidates)) as pool:
        list(pool.map(candidate_worker, args.candidates))
    guard()


if __name__ == "__main__":
    main()
