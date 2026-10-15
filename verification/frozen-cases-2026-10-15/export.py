"""Export checked functional outcomes and frozen solver inputs; never export raw logs."""
import hashlib
import json
from collections import Counter
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
AUDIT = ROOT / ".local/case-freeze-2026-10-15"
DATA = AUDIT / "runtime-data"


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value, message):
    if not value:
        raise SystemExit(message)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def normalize(value, key=None):
    if isinstance(value, dict):
        return {k: normalize(v, k) for k, v in value.items() if k != "output"}
    if isinstance(value, list):
        if key in {"detected_tests", "submitted_test_files", "auxiliary_files"}:
            return sorted(value)
        return [normalize(v) for v in value]
    return value


def implementation_files():
    paths = set(ROOT.glob("lib/**/*.ex"))
    paths |= {p for p in (ROOT / "priv/pi").glob("*") if p.is_file()}
    paths.add(ROOT / "mix.lock")
    paths |= {p for p in (ROOT / "priv/fixtures").rglob("*")
              if p.is_file() and p.suffix in {".exs", ".mjs", ".json"}}
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def joined_hash(files):
    return hashlib.sha256("".join(k + v for k, v in sorted(files.items())).encode()).hexdigest()


def counts(grade):
    return {
        "passed": grade["passed"],
        "stages": {
            key: {
                "passed": stage.get("passed"),
                "completed": stage.get("completed"),
                "test_counts": dict(Counter(stage.get("test_results", {}).values())),
            }
            for key in ("submission", "hidden", "regression")
            if (stage := grade.get(key)) is not None
        },
        "submitted_tests_expose_starting_defect": (grade.get("regression_coverage") or {}).get("passed"),
    }


result = read(DATA / "repeatability/result.json")
require(result["status"] == "repeatable" and result["rounds"] == 3, "Incomplete repetitions")
require(result["expected_control_outcomes"] == 132, "Wrong control count")
ids = read(ROOT / "config/benchmark.json")["cases"]
require(result["cases"] == ids, "Inventory changed")
qualification_release = read(DATA / f"releases/{result['release']}/manifest.json")
capture = read(DATA / f"frozen-inputs/{ids[0]}.json")
release = read(DATA / f"releases/{capture['release']}/manifest.json")
require(release["protocol"]["inventory"] == read(ROOT / "config/benchmark.json"), "Wrong inventory")
require(release["protocol"]["fixtures"] == qualification_release["protocol"]["fixtures"], "Cases changed")
plan = read(OUT / "validation-plan.json")
connection = read(OUT / plan["readiness"]["inference_check"])
require(connection["status"] == "completed" and connection["http_status"] == 200, "Inference eligibility unverified")
require(connection["model"] == plan["model"] and connection["case_attempts"] == 0, "Wrong connection check")
require(any(row["slug"] == plan["model"] for row in connection["catalog"]), "Target absent from account catalog")
repeat_plan = read(DATA / "repeatability/plan.json")
require(repeat_plan["runner_sha256"] == digest(OUT / "repeat.exs"), "Repeat runner changed")

before = read(AUDIT / "pre-prompt-fix.json")
require(joined_hash(before["implementation_files"]) == before["implementation_hash"], "Invalid pre-fix manifest")
require(before["implementation_hash"] == qualification_release["protocol"]["implementation"], "Wrong pre-fix implementation")
current = implementation_files()
require(joined_hash(current) == release["protocol"]["implementation"], "Frozen implementation changed")
delta = sorted(k for k in current.keys() | before["implementation_files"].keys()
               if current.get(k) != before["implementation_files"].get(k))
reasons = {
    "lib/eab_web/dashboard_live.ex": "Expose ChatGPT as a provider choice; fixture qualification and solver prompts are unchanged",
    "priv/pi/bridge.mjs": "Make the Pi ticket path stable between attempts; executable fixture qualification is unchanged",
}
require(delta == sorted(reasons), "Unexpected implementation changes since qualification")
grader_paths = [f"lib/eab/{name}.ex" for name in
                ("command", "grader", "inventory", "sandbox", "task_contract", "test_adapter")]
grader_paths += ["mix.lock", "priv/fixtures/grade_formatter.exs", "priv/fixtures/node_runner.mjs"]
grader_hash = joined_hash({p: digest(ROOT / p) for p in grader_paths})
execution_environment = read(AUDIT / "execution-environment.json")
require(execution_environment["deployed_release"] == release["id"], "Deployed controller differs from the captured release")
for path, checksum in execution_environment["build_configuration_sha256"].items():
    require(digest(ROOT / path) == checksum, f"Build configuration changed: {path}")
require(digest(ROOT / "compose.yaml") == execution_environment["compose_configuration_sha256"], "Compose configuration changed")

rounds = []
first = None
for number in (1, 2, 3):
    path = DATA / f"repeatability/round-{number}/outcomes.json"
    outcomes = read(path)
    require(set(outcomes) == set(ids), f"Round {number} missing cases")
    job = read(DATA / f"jobs/case-freeze-round-{number}/job.json")
    require(job["status"] == "qualified" and job["release"] == qualification_release["id"], "Wrong qualification job")
    receipts = {}
    for case_id in ids:
        raw_path = DATA / f"repeatability/round-{number}/controls/{case_id}.json"
        raw = read(raw_path)
        require(normalize(raw) == outcomes[case_id], f"Normalized evidence mismatch: {case_id}")
        require(raw["valid"] and raw["identity"]["grader"] == grader_hash, "Stale grader")
        for control, expected in (("empty_patch", False), ("reference_patch", True),
                                  ("early_exit", False), ("partial_repair", False)):
            require(raw[control]["passed"] is expected, f"Wrong {control}: {case_id}")
        receipts[case_id] = digest(raw_path)
    if first is None:
        first = outcomes
    require(outcomes == first, f"Named outcomes differ in round {number}")
    rounds.append({"round": number, "expected_control_outcomes": 44,
                   "normalized_outcomes_sha256": digest(path), "raw_receipt_sha256": receipts})

rows = []
for case_id in ids:
    folder = ROOT / "cases" / case_id
    files = {p.name: digest(p) for p in folder.iterdir() if p.is_file()}
    require(files == release["protocol"]["fixtures"][case_id], f"Fixture changed: {case_id}")
    for name, checksum in files.items():
        require(digest(DATA / f"releases/{release['id']}/cases/{case_id}/{name}") == checksum, "Frozen fixture corrupt")
    record = read(DATA / f"frozen-inputs/{case_id}.json")
    runtime = read(DATA / f"runtimes/{case_id}.json")
    require(set(runtime.get("service_engines", {})) == set(runtime["services"]), "Service engine identities missing")
    require(record["release"] == release["id"] and record["provider_requests_sent"] == 0, "Wrong input capture")
    require(record["plan_sha256"] == digest(OUT / "validation-plan.json"), "Plan changed")
    require(record["capture_runner_sha256"] == digest(OUT / "capture.exs"), "Capture runner changed")
    require(record["agent_source_sha256"] == digest(ROOT / "lib/eab/agent.ex"), "Prompt builder changed")
    require(record["agent_image_inputs"]["bridge"] == digest(ROOT / "priv/pi/bridge.mjs"), "Wrong Pi bridge")
    require(record["prompt"] == (folder / "ticket.md").read_text(), "Captured ticket differs")
    require(record["pi"] == release["protocol"]["agent"], "Wrong Pi identity")
    require(record["environment"]["pi_cli"] == record["pi"]["version"], "Running Pi version differs from the pin")
    require(runtime["fixture_hashes"] == files, "Stale runtime")
    for key in ("image", "services", "baseline"):
        require(runtime[key] == first[case_id]["identity"]["runtime"][key], "Runtime changed")
    request = record["initial_request"]
    require(request["model"] == plan["model"] and request["reasoning"]["effort"] == plan["settings"]["reasoning_effort"], "Wrong model settings")
    require(request["store"] is False and request["stream"] is True, "Wrong transport settings")
    require("/tmp/eab-ticket.md" in json.dumps(request["input"]), "Unstable ticket path")
    require("/tmp/eab-pi-" not in json.dumps(request["input"]), "Random directory leaked into prompt")
    write(OUT / f"inputs/{case_id}.json", record)
    provenance = read(folder / "provenance.json")
    spec = read(folder / "case.json")
    require(runtime["source_receipt"]["tree"] == provenance["broken_tree"], "Wrong source tree")
    rows.append({
        "case": case_id,
        "fixture_sha256": files,
        "test_contract": {key: spec[key] for key in (
            "acceptance_command", "regression_command", "acceptance_patch", "required_acceptance_tests",
            "permitted_exclusion_tags", "require_regression_test", "test_timeout"
        ) if key in spec},
        "input_capture_sha256": digest(OUT / f"inputs/{case_id}.json"),
        "runtime": {**{k: runtime[k] for k in ("base_image", "toolchain_image", "node_image", "image",
                                              "services", "baseline", "source_receipt", "inputs")},
                    "service_engines": runtime.get("service_engines", {})},
        "agent_image": record["agent_image"],
        "qualification_identity": first[case_id]["identity"],
        "controls": {key: counts(first[case_id][key]) for key in
                     ("empty_patch", "reference_patch", "early_exit", "partial_repair")},
    })

write(OUT / "release.json", release)
write(OUT / "qualification-outcomes.json", first)
write(OUT / "evidence.json", {
    "date": "2026-10-15",
    "release": release["id"],
    "qualification_release": qualification_release["id"],
    "source_checkout_commit_before_prompt_fix": before["git_commit"],
    "implementation_files": current,
    "implementation_changes_after_qualification": [
        {"path": path, "before": before["implementation_files"][path], "after": current[path],
         "reason": reasons[path]} for path in delta
    ],
    "repeatability": {"fresh_rounds": 3, "cases": 11, "expected_control_outcomes": 132,
                      "named_test_outcomes_identical": True, "test_seed": 0,
                      "qualification_receipts_reused": False, "rounds": rounds},
    "resource_policy": {"scope": "fixture qualification and input capture", "case_concurrency": 1, "preparation_workers": 1,
                        "workspace": {"cpus": 2, "memory_bytes": 4294967296, "pids_limit": 512},
                        "postgres": {"cpus": 1, "memory_bytes": 536870912},
                        "clickhouse": {"cpus": 2, "memory_bytes": 3221225472},
                        "network": "isolated workspace/service namespace; model access only through controller gateway",
                        "clock": "Host clock remains live; no frozen-clock claim",
                        "watchdogs": "Hang detection only; no timing-based scoring"},
    "model_plan": plan,
    "execution_environment": execution_environment,
    "model_validation_complete": False,
    "model_attempts_performed": 0,
    "request_variability": {"prompt_cache_key": "Pi generates a fresh session cache-affinity key per attempt; the offline capture value is retained. Prompt text and tool schemas are stable; identical complete requests or cache behavior are not asserted."},
    "cases": rows,
    "artifacts_sha256": {p.name: digest(p) for p in [
        OUT / "repeat.exs", OUT / "capture.exs", OUT / "export.py", OUT / "verify.exs", OUT / "validation-plan.json",
        OUT / "release.json", OUT / "qualification-outcomes.json", OUT / "inference-check.json"]},
})
print(f"Exported {len(rows)} cases, 3 identical fresh rounds, 132 expected controls; subscription inference verified, blind model validation pending.")
