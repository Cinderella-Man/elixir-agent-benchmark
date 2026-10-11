"""Synthetic scoring and inventory correctness; never calls models or applications."""
import json
from pathlib import Path
import tempfile
import unittest

from inventory import digest, protocol, select_cases
from score import score_campaign


class ScoringTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.directory = self.root / ".local/results/comparison"
        for name in ("config", "scripts", "cases/first", "cases/second", ".local/controls", ".local/results/comparison"):
            (self.root / name).mkdir(parents=True, exist_ok=True)
        self.policy = {'window_tokens': 262144, 'response_tokens': 8192, 'safety_tokens': 8, 'compaction': False}
        self.write(self.root / "config/benchmark.json", {"id": "test-v1", "cases": ["first", "second"], 'context_policy': self.policy})
        for name in ("benchmark.py", "grade_formatter.exs", "run_suite.py", "score.py", "inventory.py", "check_endpoints.py"):
            (self.root / "scripts" / name).write_text("fixed evaluator")
        for case in ("first", "second"):
            self.write(self.root / "cases" / case / "case.json", {"project": "example"})
            self.write(self.root / ".local/runtimes" / (case + ".json"),
                       {"fixture_hashes": {"case.json": digest(self.root / "cases" / case / "case.json")}, "image": "sha256:fixed"})
        self.candidates = {name: {"id": name, "model_family": "same-model", "quantization": quant}
                           for name, quant in (("model-q3", "Q3"), ("model-q4", "Q4"))}
        self.frozen = protocol(["first", "second"], [1, 2], 32, 65536, self.root)
        self.receipt = {"schema_version": 3, "campaign": "comparison", "scope": "full",
                        "cases": ["first", "second"], "seeds": [1, 2], "candidates": list(self.candidates),
                        "max_calls": 32, "max_completion_tokens": 65536,
                        "protocol": self.frozen, "candidate_snapshots": self.candidates,
                        'context_policy': self.policy,
                        'endpoint_checks': {name: {'valid': True, 'candidate': c, 'context_policy': self.policy,
                                                   'profile': {'model_alias': name}} for name, c in self.candidates.items()}}
        self.write(self.directory / "campaign.json", self.receipt)
        for case in self.receipt["cases"]:
            runtime = {"fixture_hashes": self.frozen["fixtures"][case], "image": "sha256:fixed"}
            self.write(self.root / ".local/controls" / (case + ".json"),
                       {"valid": True, "runtime": runtime, "harness_sha256": self.frozen["controller_sha256"],
                        "formatter_sha256": self.frozen["formatter_sha256"]})
            for candidate, snapshot in self.candidates.items():
                for seed in self.receipt["seeds"]:
                    self.write(self.attempt(candidate, case, seed), {
                        "candidate": snapshot, "case": case, "seed": seed,
                        "harness_sha256": self.frozen["controller_sha256"],
                        "case_sha256": self.frozen["fixtures"][case]["case.json"],
                        "limits": {"model_calls": 32, "server_reported_completion_tokens": 65536, "per_call": 8192},
                        'context_policy': self.policy, 'endpoint_profile': {'model_alias': candidate},
                        'endpoint_profile_after': {'model_alias': candidate},
                        "runtime": runtime, "status": "completed", "grade": {"passed": True}})

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def attempt(self, candidate="model-q3", case="first", seed=1):
        return self.directory / candidate / case / f"seed-{seed}" / "attempt.json"

    def change_attempt(self, **updates):
        path = self.attempt()
        data = json.loads(path.read_text())
        data.update(updates)
        self.write(path, data)

    def result(self):
        return score_campaign(self.directory, self.root)["candidates"]

    def test_default_inventory_is_all_cases_and_unknown_subsets_are_rejected(self):
        self.assertEqual(select_cases(root=self.root), ["first", "second"])
        with self.assertRaises(ValueError):
            select_cases(["draft"], self.root)

    def test_quantizations_are_separate_and_all_seeds_count(self):
        self.change_attempt(grade={"passed": False})
        result = self.result()
        self.assertEqual(result["model-q3"]["score_percent"], 75)
        self.assertEqual(result["model-q4"]["score_percent"], 100)
        self.assertNotEqual(result["model-q3"]["candidate_sha256"], result["model-q4"]["candidate_sha256"])

    def test_errors_do_not_disappear_from_denominator_or_receive_final_score(self):
        self.change_attempt(status="error")
        result = self.result()["model-q3"]
        self.assertEqual(result["expected_attempts"], 4)
        self.assertEqual(result["counts"], {"error": 1, "pass": 3})
        self.assertIsNone(result["score_percent"])

    def test_missing_attempt_is_preserved(self):
        self.attempt().unlink()
        result = self.result()["model-q3"]
        self.assertEqual(result["counts"]["missing"], 1)
        self.assertFalse(result["complete"])

    def test_changed_candidate_or_budgets_invalidate_the_attempt(self):
        self.change_attempt(candidate=self.candidates["model-q4"])
        self.assertEqual(self.result()["model-q3"]["counts"]["identity_mismatch"], 1)

    def test_stale_evaluator_or_fixture_prevents_scoring(self):
        (self.root / "scripts/benchmark.py").write_text("changed evaluator")
        with self.assertRaises(ValueError):
            self.result()

    def test_invalid_controls_prevent_scoring(self):
        self.write(self.root / ".local/controls/first.json", {"valid": False})
        self.assertEqual(self.result()["model-q3"]["counts"]["unqualified"], 2)

    def test_rebuilt_runtime_changes_protocol_even_with_identical_fixture_files(self):
        path = self.root / ".local/runtimes/first.json"
        value = json.loads(path.read_text())
        value["image"] = "sha256:different"
        self.write(path, value)
        with self.assertRaises(ValueError):
            self.result()

    def test_subset_gets_no_full_benchmark_score(self):
        self.receipt["scope"] = "diagnostic_subset"
        self.write(self.directory / "campaign.json", self.receipt)
        self.assertIsNone(self.result()["model-q3"]["score_percent"])

    def test_context_or_endpoint_changes_block_comparative_score(self):
        self.change_attempt(endpoint_profile_after={'model_alias': 'different'})
        self.assertEqual(self.result()['model-q3']['counts']['endpoint_mismatch'], 1)
        self.assertIsNone(self.result()['model-q3']['score_percent'])
        self.change_attempt(context_policy={**self.policy, 'window_tokens': 65536})
        self.assertEqual(self.result()['model-q3']['counts']['identity_mismatch'], 1)


if __name__ == "__main__":
    unittest.main()
