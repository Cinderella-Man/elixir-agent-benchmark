#!/usr/bin/env python3
"""Verify historical source artifacts without building or executing the application.

Usage: python3 scripts/verify_historical_candidates.py --repository PATH
The repository must already contain the candidate commits. No network calls,
working-tree changes, application tests, or performance measurements are made.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def git(repository, *args, env=None):
    return subprocess.check_output(
        ["git", "-C", str(repository), *args], env=env, stderr=subprocess.PIPE
    )


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(directory, repository):
    data = json.loads((directory / "candidate.json").read_text())
    require(data["id"] == directory.name, "Candidate ID differs from directory")
    source = data["source"]
    broken, fixed = source["broken_revision"], source["fixed_revision"]
    commit = git(repository, "cat-file", "-p", fixed).decode()
    parents = [line[7:] for line in commit.split("\n\n", 1)[0].splitlines()
               if line.startswith("parent ")]
    require(parents == [broken], f"{data['id']}: expected a single repair parent")
    require(source["broken_tree"] == git(repository, "rev-parse", broken + "^{tree}").decode().strip(),
            "Broken tree differs")
    expected_tree = git(repository, "rev-parse", fixed + "^{tree}").decode().strip()
    require(source["fixed_tree"] == expected_tree, "Fixed tree differs")

    for name, digest in data["artifact_sha256"].items():
        require(Path(name).name == name, "Artifact must be a direct child")
        actual = hashlib.sha256((directory / name).read_bytes()).hexdigest()
        require(actual == digest, f"{data['id']}: artifact changed: {name}")

    diff_args = ["diff", "--binary", "--full-index", "--no-renames", broken, fixed]
    require((directory / "upstream.patch").read_bytes() == git(repository, *diff_args),
            "Full patch differs from upstream repair")
    changed = set(git(repository, "diff", "--no-renames", "--name-only", broken, fixed).decode().splitlines())
    groups = data["patch_paths"]
    all_paths = [path for paths in groups.values() for path in paths]
    require(len(all_paths) == len(set(all_paths)), "Patch groups overlap")
    require(set(all_paths) == changed, "Patch groups do not cover the upstream change")
    for name, paths in groups.items():
        expected = git(repository, *diff_args, "--", *paths) if paths else b""
        require((directory / name).read_bytes() == expected, f"Partition differs: {name}")

    # A private temporary index proves both representations reconstruct the exact
    # accepted source tree. It does not demonstrate a behavioral failure or pass.
    with tempfile.TemporaryDirectory(prefix="historical-source-check-") as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": str(Path(tmp) / "index")}
        for patches in [["upstream.patch"], list(groups)]:
            git(repository, "read-tree", broken, env=env)
            for name in patches:
                patch = directory / name
                if patch.stat().st_size:
                    git(repository, "apply", "--cached", str(patch), env=env)
            actual_tree = git(repository, "write-tree", env=env).decode().strip()
            require(actual_tree == expected_tree, "Patch replay differs from fixed tree")

    return {"id": data["id"], "source_artifacts": "pass",
            "application_tests": "not_run_by_this_check", "runtime_qualification": "not_assessed_by_this_check"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True, type=Path)
    parser.add_argument("--project", choices=["plausible", "livebook"], default="plausible")
    args = parser.parse_args()
    directories = sorted((ROOT / "candidates").glob(args.project + "-pr-*/candidate.json"))
    require(bool(directories), "No historical candidates found")
    results = [verify(path.parent, args.repository.resolve()) for path in directories]
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
