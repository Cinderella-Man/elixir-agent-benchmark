#!/usr/bin/env python3
"""Export credential-free campaign evidence and a case matrix; runs no model or tests."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
from score import markdown_scores, score_campaign

ROOT = Path(__file__).resolve().parents[1]


def scrub(value, secret):
    if isinstance(value, dict):
        return {key: "[REDACTED]" if key.lower() in {"authorization", "api_key", "api-key", "access_token"}
                else scrub(item, secret) for key, item in value.items()}
    if isinstance(value, list):
        return [scrub(item, secret) for item in value]
    if isinstance(value, str) and secret:
        return value.replace(secret, "[REDACTED]")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", nargs="+", required=True)
    parser.add_argument("--document", default="benchmark-results.md", help="Markdown filename inside results/reports/")
    args = parser.parse_args()
    if any(Path(name).name != name or name in {".", ".."} for name in args.campaign):
        parser.error("Campaign must be a directory name")
    if Path(args.document).name != args.document or not args.document.endswith(".md"):
        parser.error("Document must be a Markdown filename")
    sources = [ROOT / ".local/results" / name for name in args.campaign]
    if any(not source.is_dir() for source in sources):
        parser.error("Every requested campaign must exist")
    key_file = ROOT / ".local/api-key"
    secret = key_file.read_text().strip() if key_file.exists() else ""
    # Historical campaigns retain their candidate columns even after config changes.
    candidates = []
    for source in sources:
        receipt_path = source / "campaign.json"
        if receipt_path.exists():
            candidates.extend(json.loads(receipt_path.read_text()).get("candidates", []))
        for path in source.glob("*/*/*/attempt.json"):
            candidates.append(json.loads(path.read_text())["candidate"]["id"])
        for path in source.glob("*/*/*/setup-error.json"):
            candidates.append(json.loads(path.read_text())["candidate"])
    candidates = list(dict.fromkeys(candidates)) or [c["id"] for c in json.loads((ROOT / "config/candidates.json").read_text())["candidates"]]
    cases = set()
    rows = defaultdict(lambda: defaultdict(list))
    evidence = defaultdict(list)
    details = []
    checks = []
    controller_hash = hashlib.sha256((ROOT / "scripts/benchmark.py").read_bytes()).hexdigest()
    formatter_hash = hashlib.sha256((ROOT / "scripts/grade_formatter.exs").read_bytes()).hexdigest()

    def export(directory, source):
        target = ROOT / "results" / source.name / directory.relative_to(source)
        target.mkdir(parents=True, exist_ok=True)
        for path in sorted(directory.iterdir()):
            if path.is_file() and path.suffix in {".json", ".patch", ".txt"}:
                if path.suffix == ".json":
                    data = (json.dumps(scrub(json.loads(path.read_text()), secret), indent=2, ensure_ascii=False) + "\n").encode()
                else:
                    data = scrub(path.read_text(), secret).encode()
                output = target / path.name
                output.write_bytes(data)
                evidence[source.name].append({"path": str(output.relative_to(ROOT)), "sha256": hashlib.sha256(data).hexdigest()})

    for source, attempt_path in [(source, path) for source in sources for path in sorted(source.glob("*/*/*/attempt.json"))]:
        record = json.loads(attempt_path.read_text())
        cases.add(record["case"])
        label = f"{source.name}, seed {record['seed']}"
        if record.get("status") not in {"completed", "error"}:
            rows[record["case"]][record["candidate"]["id"]].append(f"Running ({label})")
            continue
        relative_dir = attempt_path.parent.relative_to(source)
        export(attempt_path.parent, source)
        regrade_path = attempt_path.parent / "regrade.json"
        verdict = json.loads(regrade_path.read_text()) if regrade_path.exists() else record
        assessed = verdict.get("grade", {})
        status = "Error" if record["status"] == "error" else "Pass" if assessed["passed"] else "Fail"
        control_path = ROOT / ".local/controls" / (record["case"] + ".json")
        control = json.loads(control_path.read_text()) if control_path.exists() else {}
        if record["status"] == "completed" and (verdict.get("harness_sha256") != controller_hash or
                not control.get("valid") or control.get("harness_sha256") != controller_hash or
                control.get("formatter_sha256") != formatter_hash or record.get("runtime") != control.get("runtime")):
            status = "Needs current grading"
        artifact = "regrade.json" if regrade_path.exists() else "attempt.json"
        link = f"../{source.name}/{relative_dir}/{artifact}"
        rows[record["case"]][record["candidate"]["id"]].append(f"[{status}: {label}]({link})")
        if record["status"] == "completed":
            def check_status(phase):
                result = assessed.get(phase)
                if result is None:
                    return "Not evaluated"
                failed = sum(state == "failed" for state in result.get("test_results", {}).values())
                return "Pass" if result.get("passed") else f"Fail ({failed} test failures)" if failed else "Fail (execution/completion)"
            checks.append((source.name, record["candidate"]["id"], record["case"], record["seed"],
                           *(check_status(phase) for phase in ("submission", "hidden", "regression", "regression_coverage"))))
        payload_path = attempt_path.parent / "request-000.json"
        effort = json.loads(payload_path.read_text()).get("reasoning_effort", "unspecified") if payload_path.exists() else "no request"
        context = record.get("candidate_metadata", {}).get("props", {}).get("default_generation_settings", {}).get("n_ctx", "unknown")
        details.append((source.name, record["candidate"]["id"], record["case"], record["seed"], effort, context,
                        record["calls"], record.get("stop_reason", "unknown") if record["status"] == "completed" else "error"))
    for source in sources:
        for path in sorted(source.glob("*/*/*/setup-error.json")):
            if (path.parent / "attempt.json").exists():
                continue
            record = json.loads(path.read_text())
            cases.add(record["case"])
            export(path.parent, source)
            link = f"../{source.name}/{path.relative_to(source)}"
            rows[record["case"]][record["candidate"]].append(f"[Setup error: {source.name}, seed {record['seed']}]({link})")
        if (source / "campaign.json").exists():
            cases.update(json.loads((source / "campaign.json").read_text())["cases"])
            export(source, source)
    controls = []
    control_dest = ROOT / "results/controls"
    control_dest.mkdir(parents=True, exist_ok=True)
    for path in sorted((ROOT / ".local/controls").glob("*.json")):
        if path.stem not in cases:
            continue
        data = scrub(json.loads(path.read_text()), secret)
        (control_dest / path.name).write_text(json.dumps(data, indent=2) + "\n")
        controls.append((path.stem, data["valid"], len(data["reference_patch"]["hidden"]["test_results"]), len(data["reference_patch"]["regression"]["test_results"])))
    lines = ["# End-to-end benchmark evidence", "", "Campaigns: " + ", ".join(f"`{name}`" for name in args.campaign) + ". Executed on the authorized `ratx570` rig. Each entry is one attempt with its seed shown, not a stable model success rate. Missing and errored attempts are not zero scores.", "",
             "The matrix contains only cases selected or attempted in these campaigns. Case breadth, shared source projects and public solutions limit general model-quality conclusions.", "",
             "| Scenario | " + " | ".join(candidates) + " |", "| --- | " + " | ".join("---" for _ in candidates) + " |"]
    for case in sorted(cases):
        lines.append("| " + case + " | " + " | ".join("; ".join(rows[case][candidate]) or "Not run" for candidate in candidates) + " |")
    for source in sources:
        receipt_path = source / "campaign.json"
        if receipt_path.exists() and json.loads(receipt_path.read_text()).get("schema_version") == 2:
            try:
                scored = score_campaign(source, ROOT)
                lines += ["", f"Campaign: `{source.name}`", "", *markdown_scores(scored)]
                (ROOT / "results" / source.name / "scores.json").write_text(json.dumps(scored, indent=2) + "\n")
            except ValueError as error:
                lines += ["", f"Score unavailable for `{source.name}`: {error}"]
    lines += ["", "## Attempt completion and request profiles", "",
              "Pass means the final saved patch passes the executable checks. It does not mean the agent submitted a finished answer: a budget-ended attempt can leave a correct repair while still investigating. Completion is shown separately below. Reasoning values are the actual first request payloads, not inferred from the current configuration.", "",
              "| Campaign | Candidate | Case | Seed | Reasoning | Configured context | Calls | Ended by |", "| --- | --- | --- | ---: | --- | ---: | ---: | --- |"]
    lines += ["| " + " | ".join(map(str, detail)) + " |" for detail in details]
    lines += ["", "## Checks on completed saved patches", "",
              "Submitted checks include changed and newly added regression tests. Protected checks restore the original test tree. Required regression coverage must fail in the test body on broken source and pass after repair. Passing acceptance while failing another required check is an overall failure. Not evaluated means the case did not request that check or execution did not reach it.", "",
              "| Campaign | Candidate | Case | Seed | Submitted | Acceptance | Protected regression | Added coverage |", "| --- | --- | --- | ---: | --- | --- | --- | --- |"]
    lines += ["| " + " | ".join(map(str, row)) + " |" for row in checks]
    lines += ["", "## Fixture controls", "", "Each valid fixture rejects its broken start and an early-exit bypass, while accepting the reference repair. Controls are bound to runtime, fixture and harness identities.", "",
              "| Fixture | Valid | Hidden tests | Original regression tests |", "| --- | --- | ---: | ---: |"]
    for case, valid, hidden, regression in controls:
        lines.append(f"| [{case}](../controls/{case}.json) | {valid} | {hidden} | {regression} |")
    lines += ["", "## Interpretation and preserved failures", "",
              "Request payloads and runtime identities, rather than directory names alone, define an attempt's profile. Endpoint and context/tool-protocol errors remain explicit incomplete attempts. Historical diagnostic campaigns and evaluator corrections are explained in docs/pilot-results.md and docs/pilot-protocol.md.", "",
              "The runner records existing endpoint context configurations; it does not normalize window sizes or compact history. Cumulative completion-token limits are not context-window limits. Context capacity and compaction policy must be fixed explicitly before a comparative quality campaign.", "",
              "Evaluator corrections permit harmless new top-level diagnostic scripts and require submitted regression tests to pass before original tests are restored. Where a regrade is linked, it evaluates the same saved patch; original verdicts remain in attempt.json and earlier regrade artifacts. No model answer was regenerated to repair grading issues.", "",
              "The GenStage grader also synchronizes an upstream consumer-down test before killing its consumer. This removes a demonstrated monitor-installation race without changing its expected assertion; the failed reference control is retained in controls-history. A result needs current validated controls and the current evaluator before it is displayed as Pass or Fail.", "",
              "The verifier checks executable behavior and original regression tests in fresh containers. It does not grade code elegance, establish useful 256k context or measure speed. Reference solutions are public upstream behavior, so potential prior model exposure remains a limitation. See the protocol and expansion plan before using these results to select a model.", ""]
    report_dir = ROOT / "results/reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / args.document).write_text("\n".join(lines))
    for name in args.campaign:
        dest = ROOT / "results" / name
        dest.mkdir(parents=True, exist_ok=True)
        (dest / "evidence-index.json").write_text(json.dumps(evidence[name], indent=2) + "\n")
    print(json.dumps({"campaigns": args.campaign, "completed_artifact_files": sum(map(len, evidence.values())), "controls": len(controls)}))


if __name__ == "__main__":
    main()
