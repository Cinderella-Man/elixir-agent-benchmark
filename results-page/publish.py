#!/usr/bin/env python3
"""Export the current benchmark cases and build a static results page."""

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
FIELDS = {"schema_version", "run_id", "created_at", "model", "benchmark", "source_release_id",
          "settings", "cases", "case_fixtures", "resources", "evidence_url", "note"}
MODEL_FIELDS = {"name", "backend", "quantization", "quantization_source", "size_bytes", "size_source", "parameter_count"}
RESOURCE_FIELDS = {"kind", "observed_at", "model_artifact", "backend", "backend_version", "context_tokens",
                   "kv_cache", "cpu", "gpus", "ram_rss_bytes", "ram_lifetime_peak_bytes",
                   "service_ram_bytes", "service_ram_lifetime_peak_bytes"}
RUN_RESOURCE_FIELDS = {"kind", "started_at", "finished_at", "model_artifact", "backend", "backend_version",
                       "context_tokens", "kv_cache", "cpu", "gpus", "peak_vram_bytes", "peak_ram_bytes",
                       "peak_rss_bytes", "peak_combined_bytes", "sample_count", "interval_ms",
                       "session_count", "coverage", "gap_count"}
MEASUREMENT_FIELDS = {"environment", "attempt_ms", "inference_ms"}
SETTING_TYPES = {
    "window_tokens": (int, type(None)), "response_tokens": (int, type(None)),
    "safety_tokens": (int,), "max_tokens": (int,), "seed": (int, type(None)),
    "compaction": (bool,), "budget_policy": (str,), "context_policy": (str,),
    "reasoning_effort": (str,),
}
QUANT = re.compile(r"(?:^|[-.])((?:UD-)?(?:IQ|Q|TQ|MXFP|NVFP|BF|FP|F)\d[A-Z0-9_]*)$", re.I)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(value, name):
    require(isinstance(value, str) and bool(value.strip()), f"{name} must be nonempty text")
    return value


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def fixture_hashes(case_id, case_root=None):
    root = case_root or ROOT.parent / "cases"
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((root / case_id).iterdir()) if p.is_file()}


def validate(record):
    require(isinstance(record, dict) and set(record) == FIELDS,
            "Expected a public v3 result; export the original run.json with 'add'")
    require(type(record["schema_version"]) is int and record["schema_version"] == 3,
            "Unsupported result schema")
    require(re.fullmatch(r"[A-Za-z0-9_-]+", text(record["run_id"], "run_id")), "Invalid run ID")
    date = datetime.fromisoformat(text(record["created_at"], "created_at").replace("Z", "+00:00"))
    require(date.tzinfo is not None, "created_at must include its timezone")
    text(record["benchmark"], "benchmark")
    require(re.fullmatch(r"[a-f0-9]{64}", text(record["source_release_id"], "source_release_id")),
            "A frozen source release ID is required")
    model = record["model"]
    require(isinstance(model, dict) and set(model) == MODEL_FIELDS, "Unexpected model fields")
    text(model["name"], "model.name")
    text(model["backend"], "model.backend")
    require(model["quantization_source"] in {"reported", "owner_supplied", "not_reported"},
            "Invalid quantization source")
    if model["quantization_source"] == "not_reported":
        require(model["quantization"] is None, "Unreported quantization must be null")
    else:
        text(model["quantization"], "quantization")
    for key in ("size_bytes", "parameter_count"):
        require(model[key] is None or type(model[key]) is int and model[key] > 0,
                f"{key} must be a positive integer or null")
    require(model["size_source"] in {"reported", "artifact_files", "owner_supplied", "not_reported"},
            "Invalid size source")
    require((model["size_bytes"] is None) == (model["size_source"] == "not_reported"),
            "Size and its source must agree")
    settings = record["settings"]
    require(isinstance(settings, dict) and settings, "Effective settings are required")
    require(not (set(settings) - SETTING_TYPES.keys()), "Unknown settings: review before publishing")
    for key, value in settings.items():
        require(type(value) in SETTING_TYPES[key], f"Invalid setting type: {key}")
    cases = record["cases"]
    require(isinstance(cases, list) and cases, "At least one case is required")
    for case in cases:
        require(isinstance(case, dict) and set(case) == {"id", "passed", "generated_tokens", "model_calls", "measurement"}, "Unexpected case fields")
        text(case["id"], "case.id")
        require(type(case["passed"]) is bool, "Every case needs a final pass/fail outcome")
        for key in ("generated_tokens", "model_calls"):
            require(case[key] is None or type(case[key]) is int and case[key] >= 0,
                    f"{key} must be a nonnegative integer or null")
        measurement = case["measurement"]
        if measurement is not None:
            require(isinstance(measurement, dict) and set(measurement) == MEASUREMENT_FIELDS, "Unexpected measurement fields")
            text(measurement["environment"], "measurement.environment")
            for key in ("attempt_ms", "inference_ms"):
                require(type(measurement[key]) is int and measurement[key] >= 0, "Invalid measured duration")
            require(measurement["inference_ms"] <= measurement["attempt_ms"], "Inference duration exceeds attempt duration")
    ids = [case["id"] for case in cases]
    require(len({case["measurement"]["environment"] for case in cases if case["measurement"]}) <= 1,
            "Do not aggregate timings from different measurement environments")
    require(len(set(ids)) == len(ids), "Duplicate case IDs")
    fixtures = record["case_fixtures"]
    require(isinstance(fixtures, dict) and set(fixtures) == set(ids), "Case fixture identities are required")
    for files in fixtures.values():
        require(isinstance(files, dict) and files, "Missing fixture hashes")
        for name, digest in files.items():
            require(Path(name).name == name and isinstance(digest, str) and re.fullmatch(r"[a-f0-9]{64}", digest),
                    "Invalid fixture identity")
    require(isinstance(record["note"], str), "note must be text")
    resources = record["resources"]
    if resources is not None:
        require(isinstance(resources, dict), "Expected resource object")
        sampled = resources.get("kind") == "run_samples"
        require(set(resources) == (RUN_RESOURCE_FIELDS if sampled else RESOURCE_FIELDS), "Unexpected resource fields")
        require(resources["kind"] in {"loaded_snapshot", "run_samples"}, "Unsupported resource observation")
        for key in (["started_at", "finished_at"] if sampled else ["observed_at"]):
            observed = datetime.fromisoformat(text(resources[key], key).replace("Z", "+00:00"))
            require(observed.tzinfo is not None, "Observation needs a timezone")
        if sampled:
            require(resources["coverage"] in {"complete", "partial"}, "Memory collection has not finished")
            for key in ("sample_count", "interval_ms", "session_count"):
                require(type(resources[key]) is int and resources[key] > 0, f"Invalid {key}")
            require(type(resources["gap_count"]) is int and resources["gap_count"] >= 0, "Invalid gap count")
            require(resources["coverage"] != "complete" or resources["gap_count"] == 0, "Complete coverage cannot contain gaps")
            for key in ("peak_vram_bytes", "peak_ram_bytes", "peak_rss_bytes", "peak_combined_bytes"):
                require(type(resources[key]) is int and resources[key] > 0, f"Invalid {key}")
            require(max(resources["peak_vram_bytes"], resources["peak_ram_bytes"]) <= resources["peak_combined_bytes"] <=
                    resources["peak_vram_bytes"] + resources["peak_ram_bytes"], "Invalid simultaneous memory peak")
        require(resources["backend"] == model["backend"], "Resource backend differs from run")
        require(type(resources["context_tokens"]) is int and (resources["context_tokens"] >= settings.get("window_tokens", 0) if sampled else resources["context_tokens"] == settings.get("window_tokens")),
                "Resource observation must use the run's context limit")
        artifact = text(resources["model_artifact"], "model_artifact")
        require(Path(artifact).name == artifact, "Only the artifact filename is public")
        identity = model_identity({"profile": {"model_path": artifact}})
        require(identity["name"] == model["name"] and identity["quantization"] == model["quantization"],
                "Resource observation is for a different model artifact")
        for key in ("cpu", "backend_version"):
            text(resources[key], key)
        require(resources["kv_cache"] is None or isinstance(resources["kv_cache"], str), "Invalid KV cache type")
        require(isinstance(resources["gpus"], list) and resources["gpus"], "Missing process GPU allocation")
        for gpu in resources["gpus"]:
            require(set(gpu) == {"name", "capacity_bytes", "used_bytes"}, "Unexpected GPU fields")
            text(gpu["name"], "GPU name")
            require(all(type(gpu[k]) is int and gpu[k] > 0 for k in ("capacity_bytes", "used_bytes")) and
                    gpu["used_bytes"] <= gpu["capacity_bytes"], "Invalid GPU allocation")
        for key in (() if sampled else ("ram_rss_bytes", "ram_lifetime_peak_bytes", "service_ram_bytes", "service_ram_lifetime_peak_bytes")):
            require(resources[key] is None or type(resources[key]) is int and resources[key] > 0, "Invalid RAM observation")
    url = record["evidence_url"]
    if url is not None:
        parts = urlsplit(text(url, "evidence_url"))
        require(parts.scheme in {"https", "http"} and parts.hostname and not parts.username and not parts.password,
                "Evidence must be a public HTTP(S) link without embedded credentials")
    return record


def model_identity(model):
    """Read saved normalized identity, or recover it from legacy artifact metadata."""
    if model.get("identity", {}).get("version") == 1:
        return model["identity"]
    profile = model.get("profile") or {}
    metadata = (model.get("metadata") or {}).get("model") or {}
    props = (model.get("metadata") or {}).get("props") or {}
    meta = metadata.get("meta") or {}
    path = profile.get("model_path") or props.get("model_path")
    stem = re.sub(r"-\d{5}-of-\d{5}$", "", re.sub(r"\.gguf$", "", Path(path).name, flags=re.I)) if path else None
    quant_match = QUANT.search(stem) if stem else None
    quant = quant_match.group(1).upper() if quant_match else meta.get("ftype") or metadata.get("ftype") or profile.get("model_ftype")
    if isinstance(quant, str):
        quant = quant.upper()
        for word, suffix in (("MEDIUM", "M"), ("SMALL", "S"), ("LARGE", "L")):
            quant = re.sub(r"\s*-\s*" + word + "$", "_" + suffix, quant)
    else:
        quant = None
    return {
        "name": QUANT.sub("", stem) if stem and stem not in {"model", "weights"} else
                meta.get("name") or props.get("model_name") or model.get("model"),
        "quantization": quant,
        "size_bytes": meta.get("size") or metadata.get("size") or props.get("model_size_bytes"),
        "parameter_count": meta.get("n_params") or metadata.get("n_params"),
    }


def export(run, *, inventory=None, case_root=None, model_label=None, quantization=None,
           size_bytes=None, size_source="owner_supplied", resources=None, evidence_url=None, note=""):
    require(isinstance(run, dict), "Expected a run.json object")
    require(run.get("status") == "completed", "Only completed runs can be published")
    require(run.get("selection") is None, "Selected-case repeats and error retries are not full-run results")
    original_ids = run.get("cases")
    original_inventory = run.get("protocol", {}).get("inventory", {})
    require(isinstance(original_ids, list) and original_ids and original_ids == original_inventory.get("cases"),
            "Run cases must match the full frozen inventory, in order")
    require(len(set(original_ids)) == len(original_ids), "Duplicate case IDs")
    for case_id in original_ids:
        attempt = run.get("attempts", {}).get(case_id) or {}
        grade = attempt.get("grade") or {}
        require(attempt.get("status") == "completed" and type(grade.get("passed")) is bool,
                f"{case_id}: missing, interrupted or errored outcome cannot be scored")
    selected = inventory or original_inventory
    ids = selected["cases"]
    fixtures = run.get("protocol", {}).get("fixtures", {})
    require(set(ids) <= set(original_ids), "The run has not evaluated every current case")
    if inventory is not None:
        for case_id in ids:
            require(fixtures.get(case_id) == fixture_hashes(case_id, case_root),
                    f"{case_id}: recorded fixtures differ from the current case")
    model = run.get("model") or {}
    identity = model_identity(model)
    quant = quantization if quantization is not None else identity.get("quantization")
    weight_size = size_bytes if size_bytes is not None else identity.get("size_bytes")
    record = {
        "schema_version": 3, "run_id": run.get("id"), "created_at": run.get("created_at"),
        "model": {"name": model_label or identity.get("name"), "backend": model.get("backend"),
                  "quantization": quant,
                  "quantization_source": "owner_supplied" if quantization is not None else "reported" if quant else "not_reported",
                  "size_bytes": weight_size,
                  "size_source": size_source if size_bytes is not None else "reported" if weight_size else "not_reported",
                  "parameter_count": identity.get("parameter_count")},
        "benchmark": selected.get("id"), "source_release_id": run.get("release_id"),
        "settings": run.get("settings"),
        "cases": [{"id": case_id, "passed": run["attempts"][case_id]["grade"]["passed"],
                   "generated_tokens": run["attempts"][case_id].get("generated_tokens"),
                   "model_calls": run["attempts"][case_id].get("calls"),
                   "measurement": run["attempts"][case_id].get("measurement")} for case_id in ids],
        "case_fixtures": {case_id: fixtures.get(case_id, {}) for case_id in ids},
        "resources": resources if resources is not None else run_resources(run.get("memory")), "evidence_url": evidence_url, "note": note,
    }
    return validate(record)


def run_resources(memory):
    """Publish only hardware/context and measured peaks, never hostnames or process IDs."""
    if not memory:
        return None
    require(memory.get("kind") == "run_samples" and memory.get("status") in {"complete", "partial"},
            "Run memory collection has not finished")
    sessions = memory["sessions"]
    observed = [session for session in sessions if session["sample_count"] > 0]
    if not observed:
        return None
    identity = observed[0]["identity"]
    require(all(session["identity"] == identity for session in observed),
            "Memory sessions used different deployments; do not combine hardware requirements")
    gpu_ids = [gpu["uuid"] for gpu in observed[0]["gpus"]]
    require(all([gpu["uuid"] for gpu in session["gpus"]] == gpu_ids for session in observed),
            "Memory sessions used different physical GPUs")
    gpus = []
    for i, _ in enumerate(gpu_ids):
        cards = [session["gpus"][i] for session in observed]
        require(len({(gpu["name"], gpu["capacity_bytes"]) for gpu in cards}) == 1, "GPU hardware changed")
        gpus.append({"name": cards[0]["name"], "capacity_bytes": cards[0]["capacity_bytes"],
                     "used_bytes": max(gpu["used_bytes"] for gpu in cards)})
    peaks = memory["peaks"]
    return dict({key: identity[key] for key in ("model_artifact", "backend", "backend_version", "context_tokens", "kv_cache", "cpu")},
                kind="run_samples", started_at=sessions[0]["started_at"], finished_at=sessions[-1]["finished_at"],
                gpus=gpus, peak_vram_bytes=peaks["vram_bytes"], peak_ram_bytes=peaks["service_ram_bytes"],
                peak_rss_bytes=peaks["process_rss_bytes"], peak_combined_bytes=peaks["combined_bytes"],
                sample_count=memory["sample_count"], interval_ms=observed[0]["interval_ms"],
                session_count=len(sessions), coverage=memory["status"],
                gap_count=sum(session["gap_count"] for session in sessions))


def load_results(directory):
    records, seen = [], set()
    for path in sorted(Path(directory).glob("*.json")):
        try:
            record = validate(read(path))
            require(record["run_id"] not in seen, "Duplicate run ID")
        except (ValueError, TypeError, KeyError) as error:
            raise ValueError(f"{path.name}: {error}") from error
        seen.add(record["run_id"])
        records.append(record)
    return records


def build(records, destination, *, inventory=None, case_root=None):
    inventory = inventory or read(ROOT.parent / "config/benchmark.json")
    expected = {case_id: fixture_hashes(case_id, case_root) for case_id in inventory["cases"]}
    for record in records:
        validate(record)
        require(record["benchmark"] == inventory["id"] and
                [case["id"] for case in record["cases"]] == inventory["cases"] and
                record["case_fixtures"] == expected,
                f"{record['run_id']}: result does not match the current cases; re-export or archive it")
    payload = {
        "schema_version": 3,
        "benchmark": {"id": inventory["id"], "case_count": len(inventory["cases"])},
        "results": [dict(record, passed=sum(case["passed"] for case in record["cases"]), total=len(record["cases"]))
                    for record in records],
    }
    destination.mkdir(parents=True, exist_ok=True)
    repository = os.environ.get("GITHUB_REPOSITORY", "Cinderella-Man/elixir-agent-benchmark")
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository), "Invalid repository name")
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    (destination / "index.html").write_text(html.replace("__REPOSITORY_URL__", f"https://github.com/{repository}"), encoding="utf-8")
    for name in ("styles.css", "app.js"):
        shutil.copyfile(ROOT / name, destination / name)
    body = json.dumps(payload, ensure_ascii=True, indent=2)
    (destination / "results.json").write_text(body + "\n", encoding="utf-8")
    (destination / "results.js").write_text("window.BENCHMARK_DATA = " + body.replace("<", "\\u003c") + ";\n", encoding="utf-8")
    (destination / ".nojekyll").touch()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="Export a complete run's outcomes for the current cases")
    add.add_argument("run", type=Path, help="Path to private run.json (never copied into the site)")
    add.add_argument("--model-label")
    add.add_argument("--quantization", help="Owner-supplied quant label")
    add.add_argument("--size-gb", type=float, help="Model weights in decimal GB, if not reported by the endpoint")
    add.add_argument("--resources", type=Path, help="A model_resources.py memory observation for this artifact and context")
    add.add_argument("--evidence-url")
    add.add_argument("--note", default="")
    commands.add_parser("check", help="Validate public result records")
    commands.add_parser("build", help="Validate current cases and assemble dist/")
    args = parser.parse_args()
    try:
        if args.command == "add":
            size = round(args.size_gb * 1_000_000_000) if args.size_gb is not None else None
            record = export(read(args.run), inventory=read(ROOT.parent / "config/benchmark.json"),
                            model_label=args.model_label, quantization=args.quantization, size_bytes=size,
                            resources=read(args.resources) if args.resources else None,
                            evidence_url=args.evidence_url, note=args.note)
            existing = load_results(ROOT / "results")
            require(record["run_id"] not in {item["run_id"] for item in existing}, "Run already added")
            path = ROOT / "results" / (record["run_id"] + ".json")
            with path.open("x", encoding="utf-8") as handle:
                handle.write(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
            print(f"Added {path.name}")
        records = load_results(ROOT / "results")
        if args.command in {"add", "build"}:
            build(records, ROOT / "dist")
            print(f"Built {ROOT / 'dist/index.html'} ({len(records)} results)")
        else:
            print(f"Validated {len(records)} results")
    except (OSError, ValueError, TypeError, KeyError, OverflowError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
