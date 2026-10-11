"""The single admitted benchmark inventory and frozen execution inputs."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(root=ROOT):
    data = json.loads((root / "config/benchmark.json").read_text())
    cases = data["cases"]
    if not cases or len(cases) != len(set(cases)):
        raise ValueError("Benchmark cases must be nonempty and unique")
    for name in cases:
        if Path(name).name != name or not (root / "cases" / name / "case.json").is_file():
            raise ValueError(f"Unknown case: {name}")
    return data


def select_cases(requested=None, root=ROOT):
    admitted = inventory(root)["cases"]
    selected = requested if requested is not None else admitted
    if not selected or len(selected) != len(set(selected)) or set(selected) - set(admitted):
        raise ValueError("Case IDs must be admitted and unique")
    return selected


def protocol(cases, seeds, max_calls, max_tokens, root=ROOT):
    return {
        "benchmark": inventory(root),
        "cases": cases, "seeds": seeds,
        "max_calls": max_calls, "max_completion_tokens": max_tokens,
        "controller_sha256": digest(root / "scripts/benchmark.py"),
        "formatter_sha256": digest(root / "scripts/grade_formatter.exs"),
        "driver_sha256": digest(root / "scripts/run_suite.py"),
        "scorer_sha256": digest(root / "scripts/score.py"),
        "inventory_code_sha256": digest(root / "scripts/inventory.py"),
        "runtimes": {case: digest(root / ".local/runtimes" / (case + ".json")) for case in cases},
        "fixtures": {case: {p.name: digest(p) for p in sorted((root / "cases" / case).iterdir()) if p.is_file()}
                     for case in cases},
    }
