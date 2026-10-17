"""Functional publication checks. No model execution or timing measurements."""

import copy
import json
from pathlib import Path
import tempfile
import unittest

from publish import build, export, fixture_hashes, load_results, model_identity, read, validate


def complete_run():
    return {
        "id": "test-run", "created_at": "2026-10-17T12:00:00Z", "status": "completed",
        "model": {"model": "volta-a", "backend": "llama_cpp", "url": "http://private-host",
                  "account_id": "private-account", "profile": {"model_ftype": "Q4_K - Medium",
                  "model_path": "/models/Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf"},
                  "metadata": {"model": {"meta": {"size": 17431404544}}}},
        "release_id": "a" * 64, "cases": ["case-a", "case-b"],
        "protocol": {"inventory": {"id": "example-v1", "cases": ["case-a", "case-b"]},
                     "fixtures": {"case-a": {"case.json": "a" * 64}, "case-b": {"case.json": "b" * 64}}},
        "settings": {"max_tokens": 65536, "seed": 101, "compaction": False},
        "attempts": {"case-a": {"status": "completed", "grade": {"passed": True}, "trace": "private-trace"},
                     "case-b": {"status": "completed", "grade": {"passed": False}}},
    }


def current_run():
    run = complete_run()
    inventory = read(Path(__file__).resolve().parent.parent / "config/benchmark.json")
    run["cases"] = inventory["cases"]
    run["protocol"] = {"inventory": inventory, "fixtures": {case: fixture_hashes(case) for case in run["cases"]}}
    run["attempts"] = {case: {"status": "completed", "grade": {"passed": True}} for case in run["cases"]}
    return run


class PublicationTest(unittest.TestCase):
    def test_preserves_case_token_counts_and_only_explicit_measurements(self):
        run = complete_run()
        run["attempts"]["case-a"].update(generated_tokens=1234, calls=12)
        run["attempts"]["case-a"]["measurement"] = {
            "environment": "synthetic-fixture", "attempt_ms": 120000, "inference_ms": 45000}
        record = export(run)
        self.assertEqual(record["cases"][0]["generated_tokens"], 1234)
        self.assertEqual(record["cases"][0]["measurement"]["attempt_ms"], 120000)
        self.assertIsNone(record["cases"][1]["measurement"])
        self.assertIsNone(record["cases"][1]["generated_tokens"])
        run["attempts"]["case-a"]["measurement"]["inference_ms"] = 120001
        with self.assertRaisesRegex(ValueError, "exceeds attempt"):
            export(run)

    def test_memory_observations_are_bound_to_artifact_and_context(self):
        run = complete_run()
        run["settings"]["window_tokens"] = 262144
        resources = {"kind": "loaded_snapshot", "observed_at": "2026-10-17T12:00:00Z",
                     "model_artifact": "Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf", "backend": "llama_cpp",
                     "backend_version": "fixture", "context_tokens": 262144, "kv_cache": "f16", "cpu": "fixture",
                     "gpus": [{"name": "fixture GPU", "capacity_bytes": 32 * 2**30, "used_bytes": 22 * 2**30}],
                     "ram_rss_bytes": 2**30, "ram_lifetime_peak_bytes": 2 * 2**30,
                     "service_ram_bytes": None, "service_ram_lifetime_peak_bytes": None}
        self.assertEqual(export(run, resources=resources)["resources"], resources)
        for key, bad_value in [("context_tokens", 65536), ("model_artifact", "Other-Q4_K_M.gguf"),
                               ("backend", "strata"), ("kind", "benchmark_peak"), ("api_key", "private")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                export(run, resources=dict(resources, **{key: bad_value}))

    def test_automatically_exports_run_memory_without_private_host_or_gpu_ids(self):
        run = complete_run()
        run["settings"]["window_tokens"] = 262144
        identity = {"host": "private-machine", "service": "private.service", "backend": "llama_cpp",
                    "model_artifact": "Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf", "context_tokens": 262144,
                    "backend_version": "fixture", "kv_cache": "f16", "cpu": "fixture"}
        session = {"identity": identity, "started_at": "2026-10-18T00:00:00Z", "finished_at": "2026-10-18T00:00:02Z",
                   "sample_count": 2, "interval_ms": 1000, "gap_count": 0,
                   "gpus": [{"uuid": "private-gpu", "name": "fixture", "capacity_bytes": 1000, "used_bytes": 100}]}
        run["memory"] = {"kind": "run_samples", "status": "complete", "sessions": [session], "sample_count": 2,
                         "peaks": {"vram_bytes": 100, "service_ram_bytes": 80, "process_rss_bytes": 90, "combined_bytes": 120}}
        result = export(run)
        self.assertEqual(result["resources"]["peak_combined_bytes"], 120)
        for private in ("private-machine", "private.service", "private-gpu"):
            self.assertNotIn(private, json.dumps(result))
        run["memory"]["status"] = "partial"
        self.assertEqual(export(run)["resources"]["coverage"], "partial")
        other = copy.deepcopy(session)
        other["identity"]["host"] = "another-machine"
        run["memory"]["sessions"].append(other)
        with self.assertRaisesRegex(ValueError, "different deployments"):
            export(run)

    def test_exports_outcomes_identity_and_size_without_private_fields(self):
        record = export(complete_run())
        self.assertEqual([c["passed"] for c in record["cases"]], [True, False])
        for secret in ("private-host", "private-account", "private-trace", "/models/"):
            self.assertNotIn(secret, json.dumps(record))
        self.assertEqual(record["model"]["name"], "Swift-1.5-Qwen3.8-27B")
        self.assertEqual(record["model"]["quantization"], "Q4_K_M")
        self.assertEqual(record["model"]["size_bytes"], 17431404544)
        self.assertEqual(record["model"]["size_source"], "reported")

    def test_rejects_incomplete_partial_and_mismatched_runs(self):
        for change in ("run_error", "case_error", "missing_case", "missing_grade", "partial", "wrong_inventory", "duplicate_case"):
            with self.subTest(change=change):
                run = complete_run()
                if change == "run_error": run["status"] = "error"
                if change == "case_error": run["attempts"]["case-b"]["status"] = "error"
                if change == "missing_case": del run["attempts"]["case-b"]
                if change == "missing_grade": run["attempts"]["case-b"]["grade"] = {}
                if change == "partial": run["selection"] = {"kind": "case_repeat"}
                if change == "wrong_inventory": run["cases"] = ["case-a"]
                if change == "duplicate_case":
                    run["cases"] = ["case-a", "case-a"]
                    run["protocol"]["inventory"]["cases"] = run["cases"]
                with self.assertRaises(ValueError): export(run)

    def test_sharded_names_and_unknown_sizes(self):
        run = complete_run()
        run["model"] = {"model": "flash-next", "backend": "strata", "profile": {
            "model_path": "/models/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf"}}
        model = export(run)["model"]
        self.assertEqual(model["name"], "Qwen3.8-Flash-Next-GSQ-RCO-abliterated")
        self.assertEqual(model["quantization"], "IQ3_S")
        self.assertIsNone(model["size_bytes"])
        model = export(run, size_bytes=83863586496, size_source="artifact_files")["model"]
        self.assertEqual(model["size_bytes"], 83863586496)
        self.assertEqual(model["size_source"], "artifact_files")
        with self.assertRaises(ValueError): export(run, size_bytes=0)

    def test_unreported_quantization_is_not_inferred_from_an_alias(self):
        run = complete_run()
        run["model"] = {"model": "Name-that-mentions-Q8", "backend": "llama_cpp"}
        self.assertIsNone(export(run)["model"]["quantization"])
        self.assertEqual(export(run, quantization="Q6_K")["model"]["quantization_source"], "owner_supplied")

    def test_current_case_export_excludes_retired_cases_and_preserves_source(self):
        run = current_run()
        inventory = copy.deepcopy(run["protocol"]["inventory"])
        original = copy.deepcopy(run)
        original["cases"] = run["cases"] + ["retired-a", "retired-b"]
        original["protocol"]["inventory"] = {"id": "older-version", "cases": original["cases"]}
        for case in ("retired-a", "retired-b"):
            original["attempts"][case] = {"status": "completed", "grade": {"passed": False}}
            original["protocol"]["fixtures"][case] = {"case.json": "a" * 64}
        saved = copy.deepcopy(original)
        result = export(original, inventory=inventory)
        self.assertEqual(len(result["cases"]), 9)
        self.assertEqual(sum(c["passed"] for c in result["cases"]), 9)
        self.assertNotIn("retired-", json.dumps(result))
        self.assertEqual(original, saved)
        original["protocol"]["fixtures"][run["cases"][0]]["ticket.md"] = "b" * 64
        with self.assertRaisesRegex(ValueError, "fixtures differ"):
            export(original, inventory=inventory)

    def test_rejects_private_records_unsafe_links_and_unknown_settings(self):
        with self.assertRaises(ValueError): validate(complete_run())
        record = export(complete_run())
        record["account_id"] = "secret"
        with self.assertRaises(ValueError): validate(record)
        run = complete_run()
        run["settings"]["api_key"] = "secret"
        with self.assertRaises(ValueError): export(run)
        for url in ("javascript:alert(1)", "https://user:password@example.com/results"):
            with self.assertRaises(ValueError): export(complete_run(), evidence_url=url)

    def test_build_rejects_duplicates_and_stale_cases_and_escapes_data(self):
        record = export(current_run(), model_label="<img src=x onerror=alert(1)>")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "first.json").write_text(json.dumps(record))
            (root / "second.json").write_text(json.dumps(record))
            with self.assertRaises(ValueError): load_results(root)
            (root / "second.json").unlink()
            output = root / "dist"
            build(load_results(root), output)
            result = json.loads((output / "results.json").read_text())["results"][0]
            self.assertEqual((result["passed"], result["total"]), (9, 9))
            self.assertNotIn("<img", (output / "results.js").read_text())
            self.assertEqual({p.name for p in output.iterdir()},
                             {"index.html", "app.js", "styles.css", "results.js", "results.json", ".nojekyll"})
            altered = copy.deepcopy(record)
            altered["case_fixtures"][record["cases"][0]["id"]]["ticket.md"] = "b" * 64
            with self.assertRaisesRegex(ValueError, "does not match"):
                build([altered], output)


if __name__ == "__main__":
    unittest.main()
