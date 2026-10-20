"""Execute reviewed migration gates for one case; never publish refs or approve models."""
import argparse, hashlib, json, pathlib, shutil, subprocess, time

parser = argparse.ArgumentParser()
parser.add_argument("case")
parser.add_argument("stage", choices=["qualify", "validate"])
args = parser.parse_args()
root = pathlib.Path.cwd()
work = root / ".local/fork-migration"
job = work / "jobs" / args.case
container = "elixir-agent-benchmark-benchmark-1"
remote = "/tmp/fork-migration-" + args.case
evidence = root / "verification/prepared-forks-2026-10-20" / args.case

def run(argv, **kwargs):
    return subprocess.run(argv, check=True, text=True, **kwargs)

def rpc(code):
    return run(["docker", "compose", "exec", "-T", "benchmark", "bin/eab", "rpc", code])

def require_idle():
    rpc('s=Eab.Runs.snapshot(); '
        'unless is_nil(s.active) and not s.cleaning and is_nil(s.cleanup_error), do: raise("Controller busy"); '
        'unless Eab.Retention.leased_runs() == [] and '
        'Registry.lookup(Eab.Commands, {:cache_users, Eab.Store.root()}) == [] and '
        'Registry.lookup(Eab.Commands, {:cache_removal, Eab.Store.root()}) == [], '
        'do: raise("Standalone work or retained leases present; inspect without deleting them")')

def hashes(directory):
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.iterdir() if p.is_file()}

def copy_from(name, destination):
    if destination.exists():
        raise RuntimeError("Destination already exists: " + str(destination))
    run(["docker", "cp", container + ":" + remote + "/" + name, str(destination)])

def wait_ready():
    for _ in range(20):
        result = subprocess.run(["docker", "compose", "exec", "-T", "benchmark",
            "bin/eab", "rpc", 'IO.puts("CONTROLLER_READY")'],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode == 0 and "CONTROLLER_READY" in result.stdout:
            return
        time.sleep(3)
    raise RuntimeError("Controller readiness failed; no model launched")

def copy_job():
    run(["docker", "exec", container, "mkdir", "-p", remote])
    run(["docker", "cp", str(job) + "/.", container + ":" + remote + "/"])

record = json.loads((work / "preparation-records" / (args.case + ".json")).read_text())
review = json.loads((work / "reviews" / (args.case + ".json")).read_text())
assert record["status"] == "draft_ready_for_independent_review"
assert review["decision"] == "approve" and review["author"] != review["reviewer"]
assert review["reviewed_draft_hashes"] == record["draft_hashes"]
assert review["requirements_read_before_checks"] and review["assertion_mapping_checked"]
draft = work / "drafts" / args.case
assert hashes(draft) == record["draft_hashes"]
require_idle()

if args.stage == "qualify":
    if job.exists() or evidence.exists():
        raise RuntimeError("Qualification destination exists; inspect retained work before resuming")
    rpc('unless Eab.Inventory.all() == [], do: raise("Expected empty active inventory")')
    assert not list((root / "cases").glob("*/case.json"))
    job.mkdir(parents=True)
    utilities = sorted(p for p in (work / "utilities").iterdir() if p.suffix in [".ex", ".exs"])
    assert any(p.name == "validation-measurement.ex" for p in utilities)
    for source in utilities:
        shutil.copy2(source, job / source.name)
    shutil.copytree(draft, job / "draft")
    (job / "job.json").write_text(json.dumps({
        "case": args.case, "draft_hashes": record["draft_hashes"],
        "utility_hashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in utilities}},
        indent=2) + "\n")
    (job / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    copy_job()
    with (job / "qualification.log").open("w") as log:
        run(["docker", "compose", "exec", "-T", "benchmark", "bin/eab", "rpc",
             'Code.eval_file("' + remote + '/qualify-case.exs")'],
            stdout=log, stderr=subprocess.STDOUT)
    evidence.mkdir(parents=True)
    copy_from("export", job / "export")
    copy_from("evidence", job / "qualification-evidence")
    for source in (job / "qualification-evidence").iterdir():
        shutil.copy2(source, evidence / source.name)
    shutil.copy2(work / "preparation-records" / (args.case + ".json"), evidence / "source-preparation.json")
    shutil.copy2(job / "review.json", evidence / "source-review.json")
    print("THREE_ROUNDS_EXPORTED " + args.case, flush=True)
else:
    assert job.exists() and evidence.exists()
    manifest = json.loads((job / "job.json").read_text())
    assert manifest["case"] == args.case and manifest["draft_hashes"] == record["draft_hashes"]
    for name, expected in manifest["utility_hashes"].items():
        assert hashlib.sha256((job / name).read_bytes()).hexdigest() == expected
    assert "validation-measurement.ex" in manifest["utility_hashes"]
    assert not list((root / "cases").glob("*/case.json"))
    rpc('unless Eab.Inventory.all() == [], do: raise("Expected empty active inventory")')
    for number in range(1, 4):
        receipt = json.loads((evidence / f"qualification-round-{number}.json").read_text())
        assert receipt["valid"] and receipt["fresh_controls"]
    exported = job / "export" / args.case
    assert {k: v for k, v in hashes(exported).items() if k != "admission.json"} == record["draft_hashes"]
    active = root / "cases" / args.case
    shutil.copytree(exported, active)
    require_idle()
    with (job / "singleton-build.log").open("w") as log:
        run(["docker", "compose", "up", "--build", "-d"], stdout=log, stderr=subprocess.STDOUT)
    wait_ready()
    copy_job()
    rpc('unless Eab.Inventory.all() == ["' + args.case + '"], do: raise("Not singleton"); '
        'Code.eval_file("' + remote + '/install-validation-observer.exs")')
    with (job / "astra-pair.log").open("w") as log:
        run(["docker", "compose", "exec", "-T", "benchmark", "bin/eab", "rpc",
             'Code.eval_file("' + remote + '/run-fresh-pair.exs")'],
            stdout=log, stderr=subprocess.STDOUT)
    copy_from("model-evidence", job / "model-evidence")
    for source in (job / "model-evidence").iterdir():
        if (evidence / source.name).exists():
            raise RuntimeError("Model evidence collision")
        shutil.copy2(source, evidence / source.name)
    print("TWO_OFFICIAL_PASSES_PENDING_INDEPENDENT_REVIEW " + args.case, flush=True)
