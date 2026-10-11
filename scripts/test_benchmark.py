"""Bounded controller correctness checks; no model calls or measurements."""
import base64
import json
from pathlib import Path
import shlex
import tempfile
import unittest
from unittest.mock import patch

import benchmark


def encoded(value):
    return base64.b64encode(value.encode()).decode()


def result(states, exclusions=None, code=0, finish=True):
    lines = [f"EAB_TEST:{state}:{encoded(name)}" for name, state in states]
    lines += [f"EAB_FAILURE_PHASE:{encoded(name)}:test" for name, state in states if state == "failed"]
    for name, tags in (exclusions or {}).items():
        lines.append(f"EAB_EXCLUDED_TAGS:{encoded(name)}:{encoded(','.join(tags))}")
    if finish:
        lines.append(f"EAB_SUITE_FINISHED:{len(states)}")
    return {"returncode": code, "output": "\n".join(lines), "output_truncated": False}


class GraderContractTest(unittest.TestCase):
    def test_zero_exit_without_completed_tests_is_rejected(self):
        self.assertFalse(benchmark.parse_test_result(result([], finish=False))["passed"])
        self.assertFalse(benchmark.parse_test_result(result([]))["passed"])

    def test_only_declared_edition_exclusions_are_accepted(self):
        rows = [("required", "passed"), ("enterprise", "excluded")]
        raw = result(rows, {"enterprise": ["ee_only"]})
        self.assertTrue(benchmark.parse_test_result(raw, ["ee_only"])["passed"])
        self.assertFalse(benchmark.parse_test_result(result(rows), ["ee_only"])["passed"])
        self.assertFalse(benchmark.parse_test_result(result(rows, {"enterprise": ["unreviewed"]}), ["ee_only"])["passed"])

    def test_skipped_and_all_excluded_suites_fail(self):
        self.assertFalse(benchmark.parse_test_result(result([("a", "passed"), ("b", "skipped")]))["passed"])
        self.assertFalse(benchmark.parse_test_result(result([("a", "excluded")], {"a": ["ee_only"]}), ["ee_only"])["passed"])

    def test_duplicate_identities_and_truncated_output_fail(self):
        self.assertFalse(benchmark.parse_test_result(result([("same", "passed"), ("same", "passed")]))["passed"])
        raw = result([("a", "passed")]); raw["output_truncated"] = True
        self.assertFalse(benchmark.parse_test_result(raw)["passed"])

    def test_a_required_pass_cannot_be_changed_to_an_allowed_exclusion(self):
        expected = benchmark.parse_test_result(result([("a", "passed"), ("b", "passed")]))
        actual = benchmark.parse_test_result(result([("a", "passed"), ("b", "excluded")], {"b": ["ee_only"]}), ["ee_only"])
        benchmark.check_control_tests(actual, expected)
        self.assertFalse(actual["passed"])
        self.assertIn("b", actual["changed_control_states"])

    def test_deleted_control_test_is_detected(self):
        expected = benchmark.parse_test_result(result([("a", "passed"), ("b", "passed")]))
        actual = benchmark.parse_test_result(result([("a", "passed")]))
        benchmark.check_control_tests(actual, expected)
        self.assertEqual(actual["missing_control_tests"], ["b"])
        self.assertFalse(actual["passed"])

    def test_new_test_files_are_added_to_an_explicit_selection(self):
        args = shlex.split(benchmark.test_command("mix test test/original_test.exs", ["test/new_test.exs", "test/original_test.exs"]))
        self.assertIn("test/new_test.exs", args)
        self.assertEqual(args.count("test/original_test.exs"), 1)
        self.assertIn("--seed", args)

    def test_bare_mix_test_keeps_full_discovery(self):
        args = shlex.split(benchmark.test_command("mix test", ["test/new_test.exs"]))
        self.assertNotIn("test/new_test.exs", args)
        args = shlex.split(benchmark.test_command("mix test --seed 7", ["test/new_test.exs"]))
        self.assertNotIn("test/new_test.exs", args)

    def test_non_mix_commands_are_rejected(self):
        with self.assertRaises(RuntimeError):
            benchmark.test_command("echo success")

    def test_runtime_contains_only_source_inputs_not_evaluator(self):
        case = {"runtime": {"profile": "plausible_ce", "environment": {"MIX_ENV": "ce_test"},
                            "setup_commands": ["npm run deploy --prefix tracker", "mix compile"]}}
        recipe = benchmark.dockerfile(case, "elixir@sha256:base", "node@sha256:node")
        self.assertLess(recipe.index('ENV MIX_ENV="ce_test"'), recipe.index("npm run deploy"))
        self.assertLess(recipe.index("npm run deploy"), recipe.index("RUN mix compile"))
        self.assertNotIn("reference.patch", recipe)
        self.assertNotIn("acceptance.patch", recipe)
        self.assertIn("git init", recipe)


class SubmittedCoverageTest(unittest.TestCase):
    def grade_with_probe(self, probe):
        case = {"id": "fixture", "allowed_edit_prefixes": ["lib/", "test/"],
                "regression_command": "mix test test/original_test.exs",
                "hidden_test_path": "test/hidden_test.exs", "require_regression_test": True}
        calls = []
        patch_text = "diff --git a/test/new_test.exs b/test/new_test.exs\nnew file mode 100644\n"

        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "hidden_test.exs").write_text('test "acceptance" do\nend\n')

            class Box:
                def __init__(self, _id):
                    self.case, self.directory, self.name = case, directory, "fake"
                def __enter__(self): return self
                def __exit__(self, *_): pass
                def apply(self, patch): calls.append(("apply", patch))
                def command(self, command, **_kwargs):
                    output = "test/new_test.exs\n" if "--name-only" in command else ""
                    if "git diff --cached --binary" in command: output = patch_text
                    return {"returncode": 0, "output": output, "output_truncated": False}

            passed = benchmark.parse_test_result(result([("new regression", "passed")]))
            def run_tests(box, command, extra=()):
                calls.append(("tests", command, extra))
                return probe if command == "mix test test/new_test.exs" else dict(passed)

            with patch.object(benchmark, "case_data", return_value=(directory, case)), \
                 patch.object(benchmark, "Sandbox", Box), \
                 patch.object(benchmark, "shell"), \
                 patch.object(benchmark, "install_formatter"), \
                 patch.object(benchmark, "run_tests", side_effect=run_tests):
                grade = benchmark.grade("fixture", patch_text)
        self.assertIn(("tests", case["regression_command"], ["test/new_test.exs"]), calls)
        return grade

    def test_new_test_runs_on_submission_and_broken_source(self):
        probe = benchmark.parse_test_result(result([("new regression", "failed")], code=2))
        grade = self.grade_with_probe(probe)
        self.assertTrue(grade["passed"])
        self.assertEqual(grade["regression_coverage"]["detected_tests"], ["new regression"])

    def test_compile_failure_does_not_count_as_regression_coverage(self):
        probe = benchmark.parse_test_result(result([], code=1, finish=False))
        self.assertFalse(self.grade_with_probe(probe)["passed"])

    def test_setup_failure_does_not_count_as_regression_coverage(self):
        probe = benchmark.parse_test_result(result([("new regression", "failed")], code=2))
        probe["failure_phases"]["new regression"] = "setup"
        self.assertFalse(self.grade_with_probe(probe)["passed"])

    def test_test_that_passes_on_broken_source_does_not_count(self):
        probe = benchmark.parse_test_result(result([("new regression", "passed")]))
        self.assertFalse(self.grade_with_probe(probe)["passed"])


class SandboxCleanupTest(unittest.TestCase):
    def test_clickhouse_start_failure_cleans_only_owned_containers(self):
        box = object.__new__(benchmark.Sandbox)
        box.name = "eab-test-owned"
        box.db = None
        box.sidecars = []
        box.runtime = {"services": {"postgres": "pg@pin", "clickhouse": "ch@pin"}, "image": "app@pin"}
        box.case = {"runtime": {}}
        calls = []

        def shell(args, **kwargs):
            calls.append(args)
            if args[:3] == ["docker", "exec", "eab-test-owned-ch"]:
                raise RuntimeError("readiness failure")

        with patch.object(benchmark, "shell", side_effect=shell):
            with self.assertRaisesRegex(RuntimeError, "readiness"):
                box.__enter__()
        removals = [args[-1] for args in calls if args[:3] == ["docker", "rm", "-f"]]
        self.assertEqual(removals, ["eab-test-owned", "eab-test-owned-ch", "eab-test-owned-db"])
        starts = [args for args in calls if args[:3] == ["docker", "run", "-d"]]
        self.assertIn("--network=none", starts[0])
        self.assertIn("--network=container:eab-test-owned-db", starts[1])


class FixtureRefreshTest(unittest.TestCase):
    def test_grader_refresh_cannot_relabel_changed_source_as_the_old_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            directory = root / "fixture"
            directory.mkdir()
            case = {"repository": {"revision": "a" * 40}, "runtime": {"image": "base"}}
            (directory / "case.json").write_text(json.dumps(case))
            (directory / "starter.patch").write_text("")
            (directory / "ticket.md").write_text("original")
            record = {"image": "sha256:app", "case_sha256": benchmark.sha(directory / "case.json"),
                      "fixture_hashes": {p.name: benchmark.sha(p) for p in directory.iterdir()},
                      "preparation_inputs": benchmark.preparation_inputs(directory, case)}
            benchmark.write_json(root / "runtimes/fixture.json", record)
            with patch.object(benchmark, "LOCAL", root), patch.object(benchmark, "guard"), \
                 patch.object(benchmark, "case_data", return_value=(directory, case)), \
                 patch.object(benchmark, "image_id", return_value="sha256:app"):
                (directory / "ticket.md").write_text("clarified")
                refreshed = benchmark.refresh_fixture("fixture")
                self.assertEqual(refreshed["fixture_hashes"]["ticket.md"], benchmark.sha(directory / "ticket.md"))
                case["repository"]["revision"] = "b" * 40
                with self.assertRaisesRegex(RuntimeError, "Image inputs changed"):
                    benchmark.refresh_fixture("fixture")


if __name__ == "__main__":
    unittest.main()
