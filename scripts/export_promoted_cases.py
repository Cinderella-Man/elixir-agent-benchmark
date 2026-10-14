"""Export identity-checked functional v3 qualification, without timing statistics."""
import hashlib
import json
import pathlib
import re
import sys
from collections import Counter

root = pathlib.Path(__file__).resolve().parents[1]
data = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root / ".local/task-promotion")
destination = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else root / "docs/verification/task-quality-promotion-evidence-2026-10-14.json")


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def stage(value):
    if not value:
        return None
    output = value.get("output", "")
    first_failure = re.search(r"(?m)^\s+1\) .+", output)
    excerpt = None
    if first_failure:
        output = output[first_failure.start():].split("EAB_SUITE_FINISHED:")[0]
        excerpt = "\n".join(line for line in output.splitlines() if not line.startswith("EAB_") and not re.match(r"Finished in \d", line))[:5000]
    return {
        "passed": value.get("passed"),
        "completed": value.get("completed"),
        "returncode": value.get("returncode"),
        "test_counts": dict(sorted(Counter(value.get("test_results", {}).values()).items())),
        "test_results": value.get("test_results", {}),
        "failure_phases": value.get("failure_phases", {}),
        "failure_types": value.get("failure_types", {}),
        "exclusions": value.get("exclusion_tags", {}),
        "changed_control_states": value.get("changed_control_states", {}),
        "failure_excerpt": excerpt,
    }


def grade(value):
    coverage = value.get("regression_coverage") or {}
    return {
        "passed": value.get("passed"),
        "reason": value.get("reason"),
        "submission": stage(value.get("submission")),
        "acceptance": stage(value.get("hidden")),
        "preservation": stage(value.get("regression")),
        "submitted_test_files": value.get("submitted_test_files"),
        "regression_coverage": {
            "passed": coverage.get("passed"),
            "detected_tests": coverage.get("detected_tests", []),
            "starting_probe": stage(coverage.get("broken_test_probe")),
        } if coverage else None,
    }


job_path = data / "jobs/qualification-task-quality-v3/job.json"
job = read(job_path)
require(job["status"] == "qualified", "Final qualification job is incomplete")
manifest = read(data / f"releases/{job['release']}/manifest.json")
inventory = read(root / "config/benchmark.json")
require(manifest["protocol"]["inventory"] == inventory, "Inventory changed after qualification")
require(len(inventory["cases"]) == 11 and "plausible-pr-6300" not in inventory["cases"], "Wrong inventory")
require(job["cases"] == inventory["cases"], "Qualification inventory mismatch")
require(all(row.get("valid") is True for row in job["results"]), "An invalid qualification result remains")

runner = root / "scripts/replay_promoted_cases.exs"
audit_file = root / "docs/verification/task-quality-evidence-2026-10-14.json"
audits = {row["case"]: row for row in read(audit_file)["cases"]}
original = root / "verification/task-quality/original"
for filename, checksum in read(original / "sha256.json").items():
    require(digest(original / filename) == checksum, f"Changed archive: {filename}")

rows = []
for case_id in inventory["cases"]:
    case_dir = root / "cases" / case_id
    files = {p.name: digest(p) for p in case_dir.iterdir() if p.is_file()}
    require(files == manifest["protocol"]["fixtures"][case_id], f"Changed fixture: {case_id}")
    spec = read(case_dir / "case.json")
    plan = read(root / f"verification/task-quality/cases/{case_id}/audit.json")
    path = data / f"controls/{case_id}.json"
    control = read(path)
    require(control["valid"] is True, f"Invalid control: {case_id}")
    reference = control["reference_patch"]["hidden"]["test_results"]
    require(control["reference_patch"]["passed"] is True, f"Reference fails: {case_id}")
    for name in spec["required_acceptance_tests"]:
        require(reference.get(name) == "passed", f"Missing required check: {case_id}/{name}")
    for name, checksum in control["identity"]["case"]["files"].items():
        require(files.get(name) == checksum, f"Stale qualified input: {case_id}/{name}")
    for key in ["empty_patch", "early_exit", "partial_repair"]:
        require(control[key]["passed"] is False, f"Invalid negative control: {case_id}/{key}")
    for key in ["empty_patch", "partial_repair"]:
        result = control[key]["hidden"]
        require(result["completed"] and any(state == "failed" and result["failure_phases"].get(name) == "test" for name, state in result["test_results"].items()), f"Nonbehavioral control failure: {case_id}/{key}")

    expected_identity = {
        "release": manifest["id"],
        "qualification": control["identity"],
        "runner": digest(runner),
        "audit_evidence": digest(audit_file),
        "plan": plan,
    }
    provenance_path = data / f"promotion-results/{case_id}-provenance.json"
    provenance_record = read(provenance_path)
    provenance = provenance_record["provenance"]
    upstream = read(case_dir / "provenance.json")
    require(provenance_record["identity"] == expected_identity, f"Stale provenance receipt: {case_id}")
    require(provenance["verified"] is True and provenance["reconstructed_tree"] == upstream["fixed_tree"] and provenance["broken"]["tree"] == upstream["broken_tree"] and provenance["fixed"]["tree"] == upstream["fixed_tree"], f"Source reconstruction mismatch: {case_id}")
    require(provenance["broken"]["repository"] == spec["repository"] and provenance["fixed"]["repository"]["revision"] == upstream["fixed_revision"], f"Source revision mismatch: {case_id}")
    variants = []
    for variant in plan["mutants"] + plan.get("alternatives", []):
        name = variant["name"]
        variant_path = data / f"promotion-results/{case_id}-{name}.json"
        result = read(variant_path)
        identity = dict(expected_identity, submission=digest(data / f"promotion-patches/{case_id}/{name}.patch"))
        require(result["identity"] == identity, f"Stale replay: {case_id}/{name}")
        require(result["expectation_met"] is True, f"Replay expectation unmet: {case_id}/{name}")
        expected_pass = variant.get("expect") == "pass"
        audited = next(row for row in audits[case_id]["audit_variants"] if row["name"] == name)
        expected_failures = audited["distinguishing_behavioral_failures"]
        previous_grade = audited.get("full_original_grade")
        if previous_grade:
            require(identity["submission"] == audited["full_grade_identity"]["submission"], f"Previously accepted submission changed: {case_id}/{name}")
        require(result["expected_behavioral_failures"] == expected_failures, f"Changed intended failure identities: {case_id}/{name}")
        require(result["grade"]["passed"] is expected_pass, f"Wrong full grade: {case_id}/{name}")
        if not expected_pass:
            hidden = result["grade"]["hidden"]
            failures = result["distinguishing_behavioral_failures"]
            require(hidden["completed"] and failures, f"Nonbehavioral mutant rejection: {case_id}/{name}")
            require(set(failures) & set(expected_failures), f"Intended defect was not detected: {case_id}/{name}")
            require(all(reference.get(test) == "passed" and hidden["test_results"].get(test) == "failed" and hidden["failure_phases"].get(test) == "test" for test in failures), f"Unqualified distinguishing failure: {case_id}/{name}")
        variants.append({
            "name": name,
            "expected": result["expected"],
            "rationale": variant["rationale"],
            "expectation_met": True,
            "submission_sha256": identity["submission"],
            "original_full_grade_passed": previous_grade["passed"] if previous_grade else None,
            "same_submission_as_original_full_grade": True if previous_grade else None,
            "expected_behavioral_failures": expected_failures,
            "distinguishing_behavioral_failures": result["distinguishing_behavioral_failures"],
            "full_grade": grade(result["grade"]),
            "raw_evidence_sha256": digest(variant_path),
        })

    repeat_path = data / f"promotion-results/{case_id}-reference-seed101.json"
    repeat = read(repeat_path)
    require(repeat["identity"] == expected_identity, f"Stale reference repeat: {case_id}")
    require(repeat["expectation_met"] and repeat["result"]["passed"] and repeat["result"]["test_results"] == reference, f"Reference order mismatch: {case_id}")
    rows.append({
        "case": case_id,
        "fixture_sha256": files,
        "upstream": read(case_dir / "provenance.json"),
        "provenance_receipt": provenance,
        "provenance_evidence_sha256": digest(provenance_path),
        "qualification_identity": control["identity"],
        "qualification_valid": True,
        "qualification_evidence_sha256": digest(path),
        "required_acceptance_tests": spec["required_acceptance_tests"],
        "controls": {key: grade(control[key]) for key in ["empty_patch", "reference_patch", "early_exit", "partial_repair"]},
        "reference_seed101": stage(repeat["result"]),
        "reference_repeat_evidence_sha256": digest(repeat_path),
        "variants": variants,
    })

report = {
    "schema_version": 1,
    "date": "2026-10-14",
    "scope": "Eleven-case v3 functional qualification and full-grader challenges; no model evaluation or speed measurements.",
    "limits": "Finite selected regressions and two test orders are not exhaustive proof, a flake-rate estimate, or independent human review.",
    "release": manifest,
    "qualification_job_sha256": digest(job_path),
    "original_archive_manifest_sha256": digest(original / "sha256.json"),
    "original_audit_evidence_sha256": digest(audit_file),
    "scripts": {str(p.relative_to(root)): digest(p) for p in [root / "scripts/qualify_promoted_cases.exs", runner, pathlib.Path(__file__).resolve()]},
    "cases": rows,
}
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
print(f"Exported {len(rows)} qualified cases and {sum(len(row['variants']) for row in rows)} challenge replays to {destination}")
