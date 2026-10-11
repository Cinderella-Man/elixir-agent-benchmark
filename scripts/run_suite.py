#!/usr/bin/env python3
"""Run all benchmark cases, one active attempt per configured endpoint."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

from benchmark import ROOT, LOCAL, guard, sha, api_key, endpoint_metadata, endpoint_profile, context_policy
from check_endpoints import check_endpoint
from inventory import inventory, protocol, select_cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", required=True)
    parser.add_argument("--candidates", nargs="+", help="Default: every candidate in config/candidates.json")
    parser.add_argument("--cases", nargs="+", help="Optional diagnostic subset; default is the entire benchmark")
    parser.add_argument("--max-calls", type=int, default=32)
    parser.add_argument("--max-tokens", type=int, default=65536)
    parser.add_argument("--seeds", nargs="+", type=int, default=[101])
    args = parser.parse_args()
    host = guard()
    if Path(args.campaign).name != args.campaign or args.campaign in {".", ".."}:
        parser.error("Use one directory name for the campaign")
    candidate_config = json.loads((ROOT / "config/candidates.json").read_text())["candidates"]
    if not candidate_config or len({c['id'] for c in candidate_config}) != len(candidate_config):
        parser.error("Configure at least one candidate with a unique ID")
    args.candidates = args.candidates or [c["id"] for c in candidate_config]
    known = {c["id"] for c in candidate_config}
    if (set(args.candidates) - known or len(set(args.candidates)) != len(args.candidates) or
            any(Path(c).name != c or c in {".", ".."} for c in args.candidates)):
        parser.error("Candidate IDs must be known and unique")
    try:
        cases = select_cases(args.cases)
    except ValueError as error:
        parser.error(str(error))
    if len(set(args.seeds)) != len(args.seeds):
        parser.error("Seeds must be unique")
    if args.max_calls <= 0 or args.max_tokens <= 0:
        parser.error("Budgets must be positive")
    # Validate the complete selected inventory before contacting any model.
    for case in cases:
        control_path = LOCAL / "controls" / (case + ".json")
        runtime_path = LOCAL / "runtimes" / (case + ".json")
        if not control_path.exists() or not runtime_path.exists():
            parser.error(f"Qualify every selected fixture first: {case}")
        control, runtime = json.loads(control_path.read_text()), json.loads(runtime_path.read_text())
        if (not control.get("valid") or control.get("runtime") != runtime or
                control.get("harness_sha256") != sha(ROOT / "scripts/benchmark.py") or
                control.get("formatter_sha256") != sha(ROOT / "scripts/grade_formatter.exs") or
                runtime.get("fixture_hashes") != {p.name: sha(p) for p in (ROOT / "cases" / case).iterdir() if p.is_file()}):
            parser.error(f"Stale fixture qualification: {case}")
    campaign = ROOT / ".local/results" / args.campaign
    if campaign.exists():
        parser.error("Campaign already exists; choose a new ID to preserve all attempts")
    campaign.mkdir(parents=True)
    frozen = protocol(cases, args.seeds, args.max_calls, args.max_tokens)
    snapshots = {c["id"]: c for c in candidate_config if c["id"] in args.candidates}
    receipt = {"schema_version": 3, "campaign": args.campaign, "candidates": args.candidates, "cases": cases, "seeds": args.seeds,
               "scope": "full" if cases == inventory()["cases"] else "diagnostic_subset",
               "protocol": frozen, "candidate_snapshots": snapshots,
               "max_calls": args.max_calls, "max_completion_tokens": args.max_tokens,
               "context_policy": context_policy(), "execution_host": host, "endpoint_checks": {}}
    (campaign / "campaign.json").write_text(json.dumps(receipt, indent=2) + "\n")
    # Fail before the scored matrix if any endpoint cannot honor the protocol.
    # Preserve failed preflights in this campaign rather than silently retrying.
    for candidate, config in snapshots.items():
        print(json.dumps({"candidate": candidate, "stage": "endpoint_preflight"}), flush=True)
        try:
            receipt["endpoint_checks"][candidate] = check_endpoint(config)
        except Exception as error:
            receipt["endpoint_checks"][candidate] = {"valid": False, "error": str(error)}
            raise
        finally:
            (campaign / "campaign.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def candidate_worker(candidate):
        for seed in args.seeds:
            for case in cases:
                if protocol(cases, args.seeds, args.max_calls, args.max_tokens) != frozen:
                    raise RuntimeError("Benchmark inputs changed during the campaign; preserve this run and start a new campaign")
                current = {c["id"]: c for c in json.loads((ROOT / "config/candidates.json").read_text())["candidates"]}
                if any(current.get(name) != snapshot for name, snapshot in snapshots.items()):
                    raise RuntimeError("Candidate configuration changed during the campaign")
                if endpoint_profile(endpoint_metadata(snapshots[candidate], api_key(snapshots[candidate]))) != receipt["endpoint_checks"][candidate]["profile"]:
                    raise RuntimeError("Endpoint profile changed since the campaign preflight")
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

    endpoint_queues = {}
    for candidate in args.candidates:
        endpoint = snapshots[candidate]["base_url"].rstrip("/")
        endpoint_queues.setdefault(endpoint, []).append(candidate)

    def endpoint_worker(queue):
        for candidate in queue:
            candidate_worker(candidate)

    with ThreadPoolExecutor(max_workers=len(endpoint_queues)) as pool:
        list(pool.map(endpoint_worker, endpoint_queues.values()))
    guard()


if __name__ == "__main__":
    main()
