"""Export named correctness outcomes and identities, without timing statistics."""
import hashlib
import json
import pathlib
import re
import sys
from collections import Counter

root = pathlib.Path(__file__).resolve().parents[1]
data = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root / ".local/task-audit")
destination = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else root / "docs/verification/task-quality-evidence-2026-10-14.json")
runner_sources = [root / "scripts/audit_cases.exs", root / "verification/task-quality/executed-audit-runner.exs"]


def read(path):
    return json.loads(path.read_text()) if path.exists() else None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(value):
    if not value:
        return None
    tests = value.get("test_results", {})
    failures = {
        name: {
            "phase": value.get("failure_phases", {}).get(name),
            "types": value.get("failure_types", {}).get(name, []),
        }
        for name, state in sorted(tests.items()) if state == "failed"
    }
    output = value.get("output", "")
    excerpt = re.search(r"(?m)^\s+1\) .+", output)
    if excerpt:
        output = output[excerpt.start():]
        output = output.split("EAB_SUITE_FINISHED:")[0]
        output = "\n".join(
            line for line in output.splitlines()
            if not line.startswith("EAB_") and not re.match(r"Finished in \d", line)
        )[:5000]
    else:
        output = None
    return {
        "passed": value.get("passed"),
        "completed": value.get("completed"),
        "returncode": value.get("returncode"),
        "test_counts": dict(sorted(Counter(tests.values()).items())),
        "failures": failures,
        "exclusions": value.get("exclusion_tags", {}),
        "changed_control_states": value.get("changed_control_states", {}),
        "failure_excerpt": output,
    }


def grade(value):
    if not value:
        return None
    coverage = value.get("regression_coverage", {})
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


rows = []
original = root / "verification/task-quality/original"
for filename, checksum in read(original / "sha256.json").items():
    if digest(original / filename) != checksum:
        raise SystemExit(f"Changed archived audit input: {filename}")
ids = read(original / "config/benchmark.json")["cases"]
for case_id in ids:
    case_dir = original / "cases" / case_id
    plan_dir = root / "verification/task-quality/cases" / case_id
    spec = read(case_dir / "case.json")
    plan = read(plan_dir / "audit.json")
    baseline_path = data / "audit-results" / f"{case_id}-baseline.json"
    baseline = read(baseline_path)
    if not baseline:
        raise SystemExit(f"Missing baseline evidence: {case_id}")
    control = baseline["control"]
    original_tests = control["reference_patch"]["hidden"]["test_results"]
    reference = read(data / "audit-results" / f"{case_id}-reference.json")
    if not reference:
        raise SystemExit(f"Missing custom reference evidence: {case_id}")
    reference_tests = reference.get("result", {}).get("test_results", {})
    variants = []
    definitions = [{"name": "starting", "expect": "fail"}, {"name": "reference", "expect": "pass"}]
    definitions += plan["mutants"] + plan.get("alternatives", [])
    for definition in definitions:
        name = definition["name"]
        path = data / "audit-results" / f"{case_id}-{name}.json"
        result = read(path)
        if not result:
            raise SystemExit(f"Missing audit evidence: {case_id}/{name}")
        execution = result.get("result", {})
        identity = result["identity"]
        if identity["plan"] != plan:
            raise SystemExit(f"Stale audit plan: {case_id}/{name}")
        for filename, checksum in identity["case_files"].items():
            if digest(case_dir / filename) != checksum:
                raise SystemExit(f"Changed original input: {case_id}/{filename}")
        for filename, checksum in identity["files"].items():
            if digest(plan_dir / filename) != checksum:
                raise SystemExit(f"Changed audit input: {case_id}/{filename}")
        if identity["runner"] not in [digest(path) for path in runner_sources]:
            raise SystemExit(f"Changed audit runner: {case_id}/{name}")
        legacy = execution.get("legacy_oracle") or {}
        expectation_met = bool(result.get("expectation_met"))
        distinguishing_failures = [
            test for test in result.get("behavioral_failures", [])
            if reference_tests.get(test) == "passed"
        ]
        if definition in plan["mutants"]:
            # A reference's independent failure cannot qualify a mutant.
            expectation_met = expectation_met and bool(distinguishing_failures)
        if definition in plan.get("alternatives", []):
            expectation_met = expectation_met and bool(legacy.get("preservation", {}).get("passed"))
        replay_path = data / "audit-results" / f"{case_id}-{name}-full-grade.json"
        replay = read(replay_path)
        audited_names = execution.get("test_results", {})
        original_preserved = all(audited_names.get(test) == state for test, state in original_tests.items())
        if definition in plan["mutants"] and expectation_met and original_preserved and not replay:
            raise SystemExit(f"Missing full-grader replay: {case_id}/{name}")
        if replay:
            submission = (data / "audit-patches" / case_id / f"{name}.patch").read_bytes()
            submission += (case_dir / "reference-tests.patch").read_bytes()
            if hashlib.sha256(submission).hexdigest() != replay["identity"]["submission"]:
                raise SystemExit(f"Changed replay submission: {case_id}/{name}")
            if replay["identity"]["qualification"] != control["identity"]:
                raise SystemExit(f"Different replay qualification: {case_id}/{name}")
        variants.append({
            "name": name,
            "expect": definition.get("expect", "fail"),
            "rationale": definition.get("rationale"),
            "expectation_met": expectation_met,
            "distinguishing_behavioral_failures": distinguishing_failures,
            "original_acceptance_identities_preserved": original_preserved,
            "additional_check_results": {test: state for test, state in sorted(audited_names.items()) if test not in original_tests},
            "result": stage(execution),
            "error": result.get("error"),
            "legacy_preservation": stage(legacy.get("preservation")),
            "legacy_acceptance": stage(legacy.get("acceptance")),
            "full_original_grade": grade(replay.get("grade")) if replay else None,
            "full_original_grade_error": replay.get("error") if replay else None,
            "full_grade_evidence_sha256": digest(replay_path) if replay else None,
            "full_grade_identity": replay.get("identity") if replay else None,
            "identity": result["identity"],
            "raw_evidence": str(path.relative_to(root)) if path.is_relative_to(root) else str(path),
            "raw_evidence_sha256": digest(path),
        })
    repeat_path = data / "audit-results" / f"{case_id}-reference-seed101.json"
    repeat = read(repeat_path)
    if not repeat:
        raise SystemExit(f"Missing fresh reference repeat: {case_id}")
    rows.append({
        "case": case_id,
        "title": spec["title"],
        "upstream": read(case_dir / "provenance.json"),
        "provenance_verified": baseline["provenance"]["verified"],
        "runtime": {k: baseline["runtime"].get(k) for k in ["image", "base_image", "node_image", "services"]},
        "original_qualification_valid": control["valid"],
        "original_qualification_identity": control["identity"],
        "original_controls": {key: grade(control[key]) for key in ["empty_patch", "reference_patch", "early_exit", "partial_repair"]},
        "original_baseline_evidence_sha256": digest(baseline_path),
        "fresh_reference_seed101": stage(repeat),
        "fresh_reference_evidence_sha256": digest(repeat_path),
        "additional_reference_check_results": {test: state for test, state in sorted(reference_tests.items()) if test not in original_tests},
        "audit_command": spec["acceptance_command"] + " " + " ".join(plan.get("test_files", [])) + " --seed 0 [controller formatters]",
        "replaces_original_acceptance_overlay": (plan_dir / "replacement-acceptance.patch").exists(),
        "audit_variants": variants,
        "all_audit_expectations_met": all(v["expectation_met"] for v in variants),
    })

report = {
    "schema_version": 1,
    "date": "2026-10-14",
    "scope": "Functional fixture and oracle audit; no model evaluations, speed measurements, or timing conclusions.",
    "original_control_execution": "Existing matching receipts validated and reused; seed101 reference replays and custom audit probes executed freshly in separate offline workspaces.",
    "limitations": "Finite hand-written controls are not exhaustive proof; source reviews are agent reviews, not independent human attestations. Audit overlays are not yet the scored inventory.",
    "audit_runner_sources": {str(path.relative_to(root)): digest(path) for path in runner_sources},
    "cases": rows,
}
challenge_path = data / "audit-results/livebook-pr-2663-additional-fairness-probe.json"
challenge = read(challenge_path)
if challenge:
    challenge_source = root / "verification/task-quality/supplemental-probes/list-formatting-challenge.exs"
    report["additional_exploratory_challenge"] = {
        "case": "livebook-pr-2663",
        "hypothesis": "One extra continuation space for every multi-digit parent might be a valid formatting alternative.",
        "conclusion": "Disproved for the covered fenced-code structure: the parser retains an extra leading space in code contents. This is not a valid positive control or a demonstrated false negative.",
        "evidence_status": "Exploratory execution outside the identity-bound 41-variant matrix; exact script and raw-output hashes retained separately.",
        "script": str(challenge_source.relative_to(root)),
        "script_sha256": digest(challenge_source),
        "raw_evidence_sha256": digest(challenge_path),
        "stages": {name: stage(value) for name, value in challenge.items()},
    }
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, indent=2) + "\n")
print(f"Exported {len(rows)} case records to {destination}")
