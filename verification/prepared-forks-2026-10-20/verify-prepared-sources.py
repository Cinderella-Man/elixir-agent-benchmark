"""Read-only verification of the restored prepared-fork inventory and preserved refs."""
import hashlib, json, pathlib, re, subprocess

root = pathlib.Path.cwd()
evidence = root / "verification/prepared-forks-2026-10-20"
original = json.loads((evidence / "initial-source-audit.json").read_text())
excluded = json.loads((evidence / "excluded-source-audit.json").read_text())
expected = {row["case"]: row["fork"] for row in original}
expected["ash-pr-3031"] = "https://github.com/Cinderella-Man/ash"
directories = {p.parent.name: p.parent for p in (root / "cases").glob("*/case.json")}
assert set(directories) == set(expected)
assert not list((root / "cases_approved").glob("*/case.json"))

def read(path):
    return json.loads(path.read_text())

def hashes(directory):
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.iterdir() if p.is_file()}

heads = {}
for fork in sorted(set(expected.values())):
    output = subprocess.check_output(["git", "ls-remote", "--heads", fork + ".git"], text=True)
    heads[fork] = {line.split()[1].removeprefix("refs/heads/"): line.split()[0]
                   for line in output.splitlines()}

cases = []
for case, directory in sorted(directories.items()):
    spec = read(directory / "case.json")
    source = read(directory / "provenance.json")
    fork = expected[case]
    assert spec["repository"]["url"].removesuffix(".git") == fork == source["repository"]
    assert spec["repository"]["revision"] == source["broken_revision"]
    assert not (directory / "environment.patch").exists()
    for role, branch_key in [("broken", "preparation_branch"), ("fixed", "reference_branch")]:
        assert re.fullmatch("[0-9a-f]{40}", source[role + "_revision"])
        assert re.fullmatch("[0-9a-f]{40}", source[role + "_tree"])
        assert heads[fork][source[branch_key]] == source[role + "_revision"]
    assert source["pull_request"].startswith(fork + "/pull/")
    case_evidence = (root / "verification/case-curation-2026-10-20/ash-pr-3031"
                     if case == "ash-pr-3031" else evidence / case)
    assert hashes(directory) == read(case_evidence / "bundle-sha256.json")
    results = read(case_evidence / "astra-results.json")
    assert results["two_fresh_blind_runs"] and results["matching_frozen_inputs"]
    assert len(results["runs"]) == 2
    review = read(case_evidence / "model-review.json")
    assert review["decision"] == "approve"
    assert review["patch_hashes"] == {row["run_id"]: row["patch_sha256"] for row in results["runs"]}
    for number, result in enumerate(results["runs"], 1):
        patch = case_evidence / f"astra-success-{number}.patch"
        assert hashlib.sha256(patch.read_bytes()).hexdigest() == result["patch_sha256"]
    cases.append({"case": case, "repository": fork,
                  **{key: source[key] for key in [
                      "preparation_branch", "reference_branch", "broken_revision",
                      "fixed_revision", "broken_tree", "fixed_tree", "pull_request"]},
                  "bundle_hashes": hashes(directory), "environment_patch_absent": True,
                  "reviewed_model_runs": [row["run_id"] for row in results["runs"]]})

for row in original:
    assert all(heads[row["fork"]].get(branch) == commit
               for branch, commit in row["existing_branches"].items())
for row in excluded:
    assert hashes(root / row["historical_bundle"]) == row["files"]
    assert row["case"] not in directories
    assert all(heads["https://github.com/Cinderella-Man/plausible-analytics"].get(branch) == commit
               for branch, commit in row["matching_existing_fork_branches"].items())

record = {"case_count": len(cases), "cases": cases,
          "all_preexisting_remote_branches_preserved": True,
          "excluded_bundles_and_branches_preserved": True,
          "excluded_cases": [row["case"] for row in excluded],
          "remote_heads": heads}
(evidence / "restored-source-audit.json").write_text(json.dumps(record, indent=2) + "\n")
print("ALL_PREPARED_FORK_SOURCES_AND_PRESERVED_BRANCHES_VERIFIED")
