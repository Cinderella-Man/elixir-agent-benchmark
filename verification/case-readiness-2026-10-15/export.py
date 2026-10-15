"""Validate and export functional evidence, without raw logs or timing fields."""
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / ".local/case-readiness-2026-10-15"
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else AUDIT / "runtime-data"
OUTPUT = ROOT / "docs/verification/existing-case-readiness-evidence-2026-10-15.json"


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def stage(value):
    if value is None:
        return None
    results = value.get("test_results", {})
    return {
        "passed": value.get("passed"),
        "completed": value.get("completed"),
        "returncode": value.get("returncode"),
        "test_counts": dict(sorted(Counter(results.values()).items())),
        "behavioral_failures": sorted(
            name for name, state in results.items()
            if state == "failed" and value.get("failure_phases", {}).get(name) == "test"
        ),
    }


def grade(value):
    coverage = value.get("regression_coverage") or {}
    return {
        "passed": value["passed"],
        "submission": stage(value.get("submission")),
        "acceptance": stage(value.get("hidden")),
        "preservation": stage(value.get("regression")),
        "submitted_tests_expose_starting_defect": coverage.get("passed"),
    }


ids = read(ROOT / "config/benchmark.json")["cases"]
job_path = DATA / "jobs/case-readiness-2026-10-15/job.json"
job = read(job_path)
require(job["status"] == "qualified" and job["cases"] == ids, "Incomplete/wrong qualification job")
require(all(row.get("valid") is True for row in job["results"]), "Invalid case qualification")
release = read(DATA / f"releases/{job['release']}/manifest.json")
require(release["protocol"]["inventory"] == read(ROOT / "config/benchmark.json"), "Inventory changed")
old_path = ROOT / "docs/verification/task-quality-promotion-evidence-2026-10-14.json"
old = {row["case"]: row for row in read(old_path)["cases"]}
inputs = {row["case"]: row for row in read(AUDIT / "input-snapshot.json")["cases"]}
grader_files = sorted(
    [f"lib/eab/{name}.ex" for name in ("command", "grader", "inventory", "sandbox", "task_contract", "test_adapter")]
    + ["mix.lock", "priv/fixtures/grade_formatter.exs", "priv/fixtures/node_runner.mjs"]
)
grader_hash = hashlib.sha256("".join(name + digest(ROOT / name) for name in grader_files).encode()).hexdigest()
rows = []
core = {"plausible-pr-6441", "plausible-pr-5956", "livebook-pr-2219", "livebook-pr-2527", "livebook-pr-2822"}
for case_id in ids:
    folder = ROOT / "cases" / case_id
    files = {p.name: digest(p) for p in folder.iterdir() if p.is_file()}
    require(files == inputs[case_id]["files"] == release["protocol"]["fixtures"][case_id], f"Case changed: {case_id}")
    changed = sorted(k for k in files.keys() | old[case_id]["fixture_sha256"].keys()
                     if files.get(k) != old[case_id]["fixture_sha256"].get(k))
    require(changed == ["ticket.md"], f"Unexpected historical difference: {case_id}")
    control_path = DATA / f"controls/{case_id}.json"
    control = read(control_path)
    runtime = read(DATA / f"runtimes/{case_id}.json")
    require(control["valid"] and control["identity"]["grader"] == grader_hash, f"Stale grader: {case_id}")
    require(control["identity"]["grader"] != old[case_id]["qualification_identity"]["grader"], "Expected fresh grader qualification")
    require(runtime["fixture_hashes"] == files, f"Stale runtime: {case_id}")
    for key in ("image", "services", "baseline"):
        require(control["identity"]["runtime"][key] == runtime[key], f"Runtime identity mismatch: {case_id}")
    for key, expected in (("empty_patch", False), ("reference_patch", True), ("early_exit", False), ("partial_repair", False)):
        require(control[key]["passed"] is expected, f"Wrong control: {case_id}/{key}")
    for key in ("empty_patch", "partial_repair"):
        require(stage(control[key]["hidden"])["behavioral_failures"], f"No behavioral rejection: {case_id}/{key}")
    source = inputs[case_id]["source"]
    archive = ROOT / inputs[case_id]["source_receipt"]
    require(digest(archive.with_suffix(".tar")) == source["archive_hash"], f"Archive changed: {case_id}")
    require(source["tree"] == read(folder / "provenance.json")["broken_tree"], f"Source mismatch: {case_id}")
    rows.append({
        "case": case_id,
        "curation_recommendation": "repair_contract" if case_id == "plausible-pr-6449" else "prioritize" if case_id in core else "retain_focused",
        "recommendation_is_admission": False,
        "fixture_sha256": files,
        "changed_since_historical_evidence": changed,
        "source": source,
        "qualification_identity": control["identity"],
        "qualification_evidence_sha256": digest(control_path),
        "controls": {key: grade(control[key]) for key in ("empty_patch", "reference_patch", "early_exit", "partial_repair")},
    })

policy_path = DATA / "readiness/policy-alternative.json"
policy = read(policy_path)
require(policy["expected_policy_rejection_observed"], "Policy alternative outcome unresolved")
require(policy["fixtures"] == inputs[policy["case"]]["files"], "Policy probe input mismatch")
require(policy["qualification"] == read(DATA / f"controls/{policy['case']}.json")["identity"], "Policy qualification mismatch")
require(policy["script"] == digest(Path(__file__).with_name("recheck.exs")), "Policy runner changed")
require(grade(policy["grade"])["submitted_tests_expose_starting_defect"] is True, "Policy alternative did not supply a discriminating test")
require(digest(DATA / "readiness/policy-alternative.patch") == policy["submission_sha256"], "Policy patch mismatch")
old_variant = next(v for v in old[policy["case"]]["variants"] if v["name"] == policy["variant"]["name"])
require(old_variant["submission_sha256"] == policy["submission_sha256"], "Historical alternative submission changed")

tracker_path = DATA / "readiness/tracker-alternative.json"
tracker = read(tracker_path)
require(tracker["grade"]["passed"] is True, "Tracker alternative not accepted")
require(tracker["fixtures"] == inputs[tracker["case"]]["files"], "Tracker probe input mismatch")
require(tracker["qualification"] == read(DATA / f"controls/{tracker['case']}.json")["identity"], "Tracker qualification mismatch")
require(tracker["script"] == digest(Path(__file__).with_name("check_alternative.exs")), "Tracker runner changed")
require(tracker["source_sha256"] == digest(Path(__file__).with_name("plausible-5956-alternative.patch")), "Tracker source mismatch")

runs = read(AUDIT / "run-metadata.json")
report = {
    "date": "2026-10-15",
    "scope": "Current-prompt case review, fresh functional qualification, one policy alternative and one smaller valid repair. No new model attempts or performance measurements.",
    "release": job["release"],
    "qualification_job_sha256": digest(job_path),
    "historical_evidence_sha256": digest(old_path),
    "grader_files": {name: digest(ROOT / name) for name in grader_files},
    "audit_files": {p.name: digest(p) for p in sorted(Path(__file__).parent.iterdir()) if p.is_file()},
    "cases": rows,
    "shared_link_policy_alternative": {
        "case": policy["case"], "submission_sha256": policy["submission_sha256"],
        "same_submission_as_historical_probe": True,
        "raw_evidence_sha256": digest(policy_path), "grade": grade(policy["grade"]),
        "interpretation": "Rejected policy alternative permitted by the current short ticket; it was forbidden by the older explicit ticket.",
    },
    "tracker_two_file_alternative": {
        "case": tracker["case"], "source_sha256": tracker["source_sha256"],
        "submission_sha256": tracker["submission_sha256"],
        "raw_evidence_sha256": digest(tracker_path), "grade": grade(tracker["grade"]),
        "interpretation": "Accepted curator-authored two-file CE repair, without the reference cache-module split; not a blind model attempt.",
    },
    "model_evidence_review": {
        "controller_runs_inspected": len(runs),
        "subscription_status": read(AUDIT / "subscription-status.json"),
        "current_ticket_matching_runs_per_case": {
            case_id: sum(run["tickets"].get(case_id) == inputs[case_id]["files"]["ticket.md"] for run in runs)
            for case_id in ids
        },
        "new_blind_attempts": 0,
        "limits": "Read-only inspection of saved controller runs; not a claim about unseen external experiments.",
    },
}
OUTPUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
print(f"Exported {len(rows)} current qualifications and two challenge results to {OUTPUT}")
