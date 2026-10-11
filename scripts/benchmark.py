#!/usr/bin/env python3
"""Containerized Elixir repair benchmark. No throughput or latency scoring."""
import argparse
import base64
import hashlib
import json
import os
import re
import selectors
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import tarfile
import tempfile
import time
import urllib.request
import urllib.error
import uuid

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / ".local"


def shell(args, *, cwd=None, check=True, timeout=900, input=None):
    return subprocess.run(args, cwd=cwd, input=input, text=True, capture_output=True,
                          check=check, timeout=timeout)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bounded_output(args, limit=20000, timeout=140):
    """Drain child output into bounded head/tail buffers; timeout is only a hang guard."""
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    first, tail, total = b"", b"", 0
    deadline = time.monotonic() + timeout
    try:
        while selector.get_map():
            if time.monotonic() >= deadline:
                process.kill()
                raise TimeoutError("Command watchdog expired")
            for key, _ in selector.select(timeout=1):
                block = os.read(key.fileobj.fileno(), 65536)
                if not block:
                    selector.unregister(key.fileobj)
                    continue
                total += len(block)
                needed = max(0, limit // 2 - len(first))
                first += block[:needed]
                tail = (tail + block[needed:])[-limit // 2:]
        code = process.wait(timeout=5)
    finally:
        selector.close()
        process.stdout.close()
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
    data = first + (b"\n[output elided]\n" if total > limit else b"") + tail
    return {"returncode": code, "output": data.decode(errors="replace"), "output_truncated": total > limit}


def guard(initialize=False):
    host = socket.gethostname().split(".")[0].lower()
    if host == "crosshaira16":
        raise RuntimeError("Benchmark execution is prohibited on the shared workstation CrosshairA16")
    if host != "ratx570":
        # A fresh clone opts in once on its execution host. The original rig
        # retains its stricter, immutable power-service checks below.
        state = {"host": host}
        if shutil.which("nvidia-smi"):
            state["gpu_rows"] = shell(["nvidia-smi", "--query-gpu=index,uuid,power.limit",
                                        "--format=csv,noheader,nounits"]).stdout.strip().splitlines()
        path = LOCAL / "execution-host.json"
        if initialize and not path.exists():
            write_json(path, state)
        if not path.exists() or json.loads(path.read_text()) != state:
            raise RuntimeError("Missing or changed execution host/GPU baseline; run init once on the intended host")
        return state
    unit = Path(shell(["systemctl", "show", "gpu-power-limit.service", "-p", "FragmentPath", "--value"]).stdout.strip())
    if shell(["systemctl", "is-active", "gpu-power-limit.service"]).stdout.strip() != "active":
        raise RuntimeError("GPU power-limit service must remain active")
    rows = shell(["nvidia-smi", "--query-gpu=index,uuid,power.limit", "--format=csv,noheader,nounits"]).stdout.strip().splitlines()
    caps = {int(r.split(",")[0]): float(r.split(",")[2]) for r in rows}
    if caps != {0: 220., 1: 220., 2: 220., 3: 140., 4: 140., 5: 220., 6: 220.}:
        raise RuntimeError("GPU power caps differ from the authorized envelope")
    state = {"unit": str(unit), "sha256": sha(unit), "gpu_rows": rows,
             "unit_definition": shell(["systemctl", "cat", "gpu-power-limit.service"]).stdout}
    path = LOCAL / "power-envelope.json"
    if initialize and not path.exists():
        write_json(path, state)
    if not path.exists() or json.loads(path.read_text()) != state:
        raise RuntimeError("Missing or changed power baseline; use init once on the authorized rig")
    return {"host": host, "unit_sha256": state["sha256"], "gpu_rows": rows}


def case_data(case_id):
    directory = ROOT / "cases" / case_id
    data = json.loads((directory / "case.json").read_text())
    assert data["id"] == case_id
    assert len(data["repository"]["revision"]) == 40
    return directory, data


def image_id(name):
    return shell(["docker", "image", "inspect", name, "--format", "{{.Id}}"]).stdout.strip()


def pin_image(name):
    shell(["docker", "pull", name], timeout=1200)
    info = json.loads(shell(["docker", "image", "inspect", name]).stdout)[0]
    return info["RepoDigests"][0]


def dockerfile(case, base, node=None):
    runtime = case["runtime"]
    env = {"MIX_ENV": "test", "MIX_HOME": "/opt/mix", "HEX_HOME": "/opt/hex",
           "ERL_FLAGS": "+S 2:2", **runtime.get("environment", {})}
    lines = ([f"FROM {node} AS nodejs"] if node else []) + [f"FROM {base}", "USER root"]
    lines += ["RUN if command -v apk; then apk add --no-cache git python3 bash ca-certificates build-base brotli libstdc++ cmake; "
              "else apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git python3 bash ca-certificates build-essential brotli cmake && rm -rf /var/lib/apt/lists/*; fi",
              "RUN if command -v useradd; then existing=$(getent passwd 1000 | cut -d: -f1); groupadd -f agent; "
              "if [ -n \"$existing\" ]; then usermod -l agent -d /home/agent -m -g agent \"$existing\"; "
              "else useradd -m -u 1000 -g agent agent; fi; else adduser -D -u 1000 agent; fi"]
    if node:
        lines += ["COPY --from=nodejs /usr/local/bin/node /usr/local/bin/node",
                  "COPY --from=nodejs /usr/local/lib/node_modules /usr/local/lib/node_modules",
                  "RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx"]
    lines += ["WORKDIR /workspace",
              "RUN mkdir -p /opt/mix /opt/hex && chown agent:agent /workspace /opt/mix /opt/hex",
              "USER agent"]
    lines.extend(f"ENV {key}={json.dumps(value)}" for key, value in env.items())
    lines += ["RUN mix local.hex --force && mix local.rebar --force"]
    if runtime.get("profile") == "plausible_ce":
        # Cache dependencies independently of the application source. These layers
        # contain no reference repair, evaluator, or compiled application modules.
        lines += ["COPY --chown=agent:agent source/mix.exs source/mix.lock ./", "COPY --chown=agent:agent source/config/ config/",
                  "RUN mix deps.get --only ce_test && mix deps.compile",
                  "COPY --chown=agent:agent source/tracker/package.json source/tracker/package-lock.json tracker/",
                  "RUN npm ci --prefix tracker --no-audit --no-fund"]
    lines += ["COPY --chown=agent:agent source/ /workspace/"]
    lines += ["RUN " + command for command in runtime.get("setup_commands", ["mix deps.get", "mix deps.compile"])]
    lines += ["RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && git commit -m 'Initial task workspace'",
              'CMD ["sleep", "infinity"]']
    return "\n".join(lines) + "\n"


def preparation_inputs(directory, case):
    return {"repository": case["repository"], "runtime": case["runtime"],
            "services": case.get("services", {}),
            "source_patches": {name: sha(directory / name) if (directory / name).exists() else None
                               for name in ("environment.patch", "starter.patch")}}


def refresh_fixture(case_id):
    """Refresh grader/ticket identities only; refuse changes to image inputs."""
    guard()
    directory, case = case_data(case_id)
    path = LOCAL / "runtimes" / f"{case_id}.json"
    runtime = json.loads(path.read_text())
    inputs = preparation_inputs(directory, case)
    recorded = runtime.get("preparation_inputs")
    if recorded is None:
        # Older runtime records can acquire an input snapshot only while their
        # original manifest AND source patches are still byte-for-byte intact.
        if runtime["case_sha256"] != sha(directory / "case.json"):
            raise RuntimeError("Runtime has no preparation snapshot; prepare again")
        for name, digest in inputs["source_patches"].items():
            if runtime["fixture_hashes"].get(name) != digest:
                raise RuntimeError("Source patch changed; prepare again")
        recorded = inputs
    if recorded != inputs or image_id(runtime["image"]) != runtime["image"]:
        raise RuntimeError("Image inputs changed or image unavailable; prepare again")
    runtime["preparation_inputs"] = recorded
    runtime["case_sha256"] = sha(directory / "case.json")
    runtime["fixture_hashes"] = {p.name: sha(p) for p in directory.iterdir() if p.is_file()}
    write_json(path, runtime)
    guard()
    return runtime


def prepare(case_id):
    guard()
    directory, case = case_data(case_id)
    dest = LOCAL / "build" / case_id
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    revision = case["repository"]["revision"]
    repo_url = case["repository"]["url"].removesuffix(".git").rstrip("/")
    owner_repo = repo_url.removeprefix("https://github.com/")
    if repo_url != "https://github.com/" + owner_repo or len(owner_repo.split("/")) != 2:
        raise ValueError("Only explicit GitHub source archives are supported in this pilot")
    archive = dest / "source.tar.gz"
    urllib.request.urlretrieve(f"https://codeload.github.com/{owner_repo}/tar.gz/{revision}", archive)
    with tarfile.open(archive) as tf:
        tf.extractall(dest / "extract", filter="data")
    entries = list((dest / "extract").iterdir())
    assert len(entries) == 1
    source = dest / "source"
    entries[0].rename(source)
    for patch in ("environment.patch", "starter.patch"):
        if (directory / patch).exists() and (directory / patch).stat().st_size:
            shell(["git", "apply", "--unsafe-paths", str(directory / patch)], cwd=source)
    # Only bugged source enters the image. Gold patches and graders never do.
    base = pin_image(case["runtime"]["image"])
    node = pin_image(case["runtime"]["node_image"]) if case["runtime"].get("node_image") else None
    recipe = dockerfile(case, base, node)
    (dest / "Dockerfile").write_text(recipe)
    tag = f"elixir-agent-benchmark:{case_id}"
    with (dest / "build.log").open("w") as log:
        result = subprocess.run(["docker", "build", "-t", tag, str(dest)],
                                stdout=log, stderr=subprocess.STDOUT, timeout=3600)
    if result.returncode:
        raise RuntimeError(f"Image build failed: {dest / 'build.log'}")
    services = {}
    for name, config in case.get("services", {}).items():
        services[name] = pin_image(config["image"])
    runtime = {"image": image_id(tag), "tag": tag, "base_image": base,
               "source_revision": revision, "archive_sha256": sha(archive),
               "case_sha256": sha(directory / "case.json"), "services": services,
               "fixture_hashes": {p.name: sha(p) for p in directory.iterdir() if p.is_file()},
               "preparation_inputs": preparation_inputs(directory, case),
               "node_image": node, "dockerfile": recipe}
    write_json(LOCAL / "runtimes" / f"{case_id}.json", runtime)
    guard()
    return runtime


class Sandbox:
    def __init__(self, case_id):
        self.directory, self.case = case_data(case_id)
        self.runtime = json.loads((LOCAL / "runtimes" / f"{case_id}.json").read_text())
        for name, expected in self.runtime["fixture_hashes"].items():
            if sha(self.directory / name) != expected:
                raise RuntimeError(f"Fixture changed since prepare: {name}")
        self.name = "eab-" + uuid.uuid4().hex[:12]
        self.db = None
        self.sidecars = []

    def __enter__(self):
        network = "none"
        try:
            if "postgres" in self.runtime["services"]:
                self.db = self.name + "-db"
                shell(["docker", "run", "-d", "--name", self.db, "--network=none", "--memory=512m", "--cpus=1",
                       "-e", "POSTGRES_PASSWORD=postgres", self.runtime["services"]["postgres"]])
                shell(["docker", "exec", self.db, "sh", "-c", "for i in $(seq 1 60); do pg_isready -U postgres && exit 0; sleep 1; done; exit 1"], timeout=90)
                network = "container:" + self.db
            if "clickhouse" in self.runtime["services"]:
                if self.db is None:
                    raise RuntimeError("ClickHouse fixtures require the isolated PostgreSQL network namespace")
                name = self.name + "-ch"
                self.sidecars.append(name)
                shell(["docker", "run", "-d", "--name", name, "--network=" + network,
                       "--memory=3g", "--cpus=2", "--ulimit", "nofile=262144:262144",
                       "-e", "CLICKHOUSE_SKIP_USER_SETUP=1", self.runtime["services"]["clickhouse"]])
                shell(["docker", "exec", name, "sh", "-c",
                       "for i in $(seq 1 90); do clickhouse-client --query 'SELECT 1' && exit 0; sleep 1; done; exit 1"], timeout=120)
            shell(["docker", "run", "-d", "--name", self.name, "--network=" + network,
                   "--cap-drop=ALL", "--security-opt=no-new-privileges", "--memory=4g", "--cpus=2", "--pids-limit=512",
                   "--tmpfs=/tmp:rw,nosuid,size=512m", self.runtime["image"]])
            self.base = self.command("git rev-parse HEAD")["output"].strip()
            for command in self.case["runtime"].get("before_test_commands", []):
                result = self.command(command, timeout=240)
                if result["returncode"]:
                    raise RuntimeError(f"Fixture startup failed: {result}")
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        if hasattr(self, "capture_out"):
            try:
                (self.capture_out / "model.patch").write_text(self.patch())
            except Exception as error:
                (self.capture_out / "patch-capture-error.txt").write_text(str(error))
        shell(["docker", "rm", "-f", "-v", self.name], check=False)
        for name in reversed(self.sidecars):
            shell(["docker", "rm", "-f", "-v", name], check=False)
        if self.db:
            shell(["docker", "rm", "-f", "-v", self.db], check=False)

    def command(self, command, timeout=120, truncate=True):
        return bounded_output(["docker", "exec", "-w", "/workspace", self.name,
                               "timeout", "-k", "5", str(timeout), "bash", "-lc", command],
                              limit=20000 if truncate else 2 * 1024 * 1024, timeout=timeout + 15)

    def apply(self, patch):
        if not patch.strip():
            return
        result = shell(["docker", "exec", "-i", "-w", "/workspace", self.name,
                        "git", "apply", "--whitespace=nowarn", "-"], input=patch, check=False)
        if result.returncode:
            raise RuntimeError("Patch does not apply: " + result.stderr)

    def patch(self):
        result = self.command("git add -A && git diff --cached --binary " + shlex.quote(self.base), timeout=60)
        if result["returncode"]:
            raise RuntimeError("Unable to capture patch: " + result["output"])
        # Do not use the truncated tool-output path for patch capture.
        result = bounded_output(["docker", "exec", "-w", "/workspace", self.name, "git", "diff", "--cached", "--binary", self.base], limit=1024 * 1024, timeout=60)
        if result["returncode"] or result["output_truncated"]:
            raise RuntimeError("Patch capture failed or exceeded the one-MiB pilot limit")
        return result["output"]


def parse_test_result(result, permitted_exclusions=()):
    found = re.findall(r"^EAB_TEST:([a-z]+):([A-Za-z0-9+/=]+)$", result["output"], re.M)
    completed = re.findall(r"^EAB_SUITE_FINISHED:(\d+)$", result["output"], re.M)
    identities = {base64.b64decode(name).decode(): state for state, name in found}
    exclusions = {base64.b64decode(name).decode(): base64.b64decode(tags).decode().split(",")
                  for name, tags in re.findall(r"^EAB_EXCLUDED_TAGS:([A-Za-z0-9+/=]+):([A-Za-z0-9+/=]*)$", result["output"], re.M)}
    failure_types = {base64.b64decode(name).decode(): base64.b64decode(types).decode().split(",")
                     for name, types in re.findall(r"^EAB_FAILURE_TYPES:([A-Za-z0-9+/=]+):([A-Za-z0-9+/=]*)$", result["output"], re.M)}
    result["test_results"] = identities
    result["exclusion_tags"] = exclusions
    result["failure_types"] = failure_types
    result["failure_phases"] = {base64.b64decode(name).decode(): phase for name, phase in
                                re.findall(r"^EAB_FAILURE_PHASE:([A-Za-z0-9+/=]+):(test|setup)$", result["output"], re.M)}
    result["completed"] = (not result.get("output_truncated", False) and len(completed) == 1
                           and int(completed[0]) == len(found) == len(identities) and len(found) > 0)
    result["passed"] = (result["returncode"] == 0 and result["completed"]
                        and "passed" in identities.values()
                        and all(state == "passed" or (state == "excluded" and
                                set(exclusions.get(name, ())) & set(permitted_exclusions))
                                for name, state in identities.items()))
    return result


def behavioral_failures(result):
    return [name for name, state in result.get("test_results", {}).items()
            if state == "failed" and result.get("failure_phases", {}).get(name) == "test"]


def install_formatter(box):
    shell(["docker", "exec", "-u", "0", box.name, "mkdir", "-p", "/opt/eab-grade"])
    shell(["docker", "cp", str(ROOT / "scripts/grade_formatter.exs"), box.name + ":/opt/eab-grade/formatter.exs"])


def test_command(command, additional_files=()):
    args = shlex.split(command)
    if args[:2] != ["mix", "test"]:
        raise RuntimeError("Grader requires an explicit mix test command")
    # A bare mix test already discovers every *_test.exs file. Explicit file
    # selections need agent-added/changed test files included as well.
    if any(arg == "test" or arg.startswith("test/") or arg.endswith(".exs") for arg in args[2:]):
        args += sorted(set(additional_files) - set(args))
    if "--seed" not in args:
        args += ["--seed", "0"]
    args += ["--formatter", "ExUnit.CLIFormatter", "--formatter", "ElixirAgentBenchmark.TrustedFormatter"]
    return "elixir -r /opt/eab-grade/formatter.exs -S " + shlex.join(args)


def run_tests(box, command, additional_files=()):
    result = box.command(test_command(command, additional_files),
                         timeout=box.case.get("test_timeout", 240), truncate=False)
    return parse_test_result(result, box.case.get("permitted_exclusion_tags", ()))


def check_control_tests(result, expected):
    actual = result["test_results"]
    result["missing_control_tests"] = sorted(set(expected["test_results"]) - set(actual))
    result["changed_control_states"] = {name: {"expected": state, "actual": actual.get(name)}
                                        for name, state in expected["test_results"].items()
                                        if actual.get(name) != state}
    if result["missing_control_tests"] or result["changed_control_states"]:
        result["passed"] = False


def stabilize_upstream_tests(box):
    if box.case["id"] != "core-genstage-cancelled-demand":
        return
    # The upstream notification precedes monitor installation. This barrier
    # preserves the assertion while eliminating the callback/kill race.
    before = ('      assert_receive {:producer_subscribed, {^consumer, ^ref}}\n'
              '      Process.unlink(consumer)\n      Process.exit(consumer, :kill)')
    after = before.replace('      Process.unlink(consumer)',
                           '      _ = :sys.get_state(producer)\n      Process.unlink(consumer)')
    script = ("from pathlib import Path\np=Path('test/gen_stage_test.exs')\ns=p.read_text()\n"
              f"before={before!r}\nafter={after!r}\n"
              "assert s.count(before) == 1, 'Upstream race adaptation no longer applies exactly'\n"
              "p.write_text(s.replace(before, after))\n")
    fixed = box.command("python3 - <<'EAB_ADAPT'\n" + script + "EAB_ADAPT")
    if fixed["returncode"]:
        raise RuntimeError("Grader test adaptation failed: " + fixed["output"])


def restore_tests(box):
    result = box.command("git restore --source=HEAD --staged --worktree -- test && git clean -fd -- test")
    if result["returncode"]:
        raise RuntimeError("Protected test restoration failed: " + result["output"])
    stabilize_upstream_tests(box)


def grade(case_id, patch, expected=None, check_coverage=True):
    _, case = case_data(case_id)
    if len(patch.encode()) > 1024 * 1024:
        return {"passed": False, "reason": "patch_too_large"}
    auxiliary = set()
    for block in patch.split("diff --git ")[1:]:
        lines = block.splitlines()
        if "new file mode 100644" in lines[:4] or "new file mode 100755" in lines[:4]:
            paths = shlex.split(lines[0])
            if len(paths) == 2:
                name = paths[1][2:]
                path = Path(name)
                if len(path.parts) == 1 and not name.startswith(".") and path.suffix in {".ex", ".exs", ".md", ".txt", ".json"}:
                    auxiliary.add(name)

    def allowed(name):
        return name in auxiliary or any(name.startswith(prefix) for prefix in case["allowed_edit_prefixes"])

    for line in patch.splitlines():
        if line.startswith("diff --git "):
            parts = shlex.split(line)
            if len(parts) != 4:
                return {"passed": False, "reason": "unsupported_patch_header"}
            for item in parts[2:]:
                name = item[2:]
                if item[:2] not in ("a/", "b/") or ".." in Path(name).parts or not allowed(name):
                    return {"passed": False, "reason": "disallowed_edits", "path": name}
        if line in ("new file mode 120000", "new mode 120000"):
            return {"passed": False, "reason": "symlink_patch_not_supported"}
    with Sandbox(case_id) as box:
        box.apply(patch)
        staged = box.command("git add -A")
        if staged["returncode"]:
            raise RuntimeError("Cannot stage submitted patch")
        paths_result = box.command("git diff --cached --name-only --diff-filter=ACDMRT HEAD", truncate=False)
        if paths_result["returncode"] or paths_result["output_truncated"]:
            raise RuntimeError("Cannot enumerate submitted files")
        names = paths_result["output"].splitlines()
        disallowed = [name for name in names if not allowed(name)]
        if disallowed:
            return {"passed": False, "reason": "disallowed_edits", "paths": disallowed}
        test_paths = box.command("git diff --cached --name-only --diff-filter=ACMRT HEAD -- test", truncate=False)
        if test_paths["returncode"] or test_paths["output_truncated"]:
            raise RuntimeError("Cannot enumerate submitted test files")
        changed_tests = test_paths["output"].splitlines()
        changed_tests = sorted(name for name in changed_tests if name.endswith("_test.exs"))
        test_patch_result = box.command("git diff --cached --binary HEAD -- test", truncate=False)
        if test_patch_result["returncode"] or test_patch_result["output_truncated"]:
            raise RuntimeError("Cannot capture submitted tests")
        test_patch = test_patch_result["output"]
        install_formatter(box)
        stabilize_upstream_tests(box)
        submission = run_tests(box, case["regression_command"], changed_tests)
        restore_tests(box)
        if case.get("acceptance_patch"):
            box.apply((box.directory / case["acceptance_patch"]).read_text())
            hidden = run_tests(box, case["acceptance_command"])
            for identity in case.get("required_acceptance_tests", ()):
                if hidden["test_results"].get(identity) != "passed":
                    hidden["passed"] = False
                    hidden.setdefault("unsatisfied_required_tests", []).append(identity)
            # The overlay can include support helpers; restore the entire test
            # tree, including deletions/new files, before protected regressions.
            box.command("git add -A -- test")
            restore_tests(box)
        else:
            hidden_path = case["hidden_test_path"]
            shell(["docker", "cp", str(box.directory / "hidden_test.exs"), box.name + ":/workspace/" + hidden_path])
            hidden = run_tests(box, "mix test " + shlex.quote(hidden_path) + " --seed 0")
            count = len(re.findall(r"^\s*test\s+\"", (box.directory / "hidden_test.exs").read_text(), re.M))
            if len(hidden["test_results"]) != count:
                hidden["passed"] = False
                hidden["count_mismatch"] = {"expected": count, "actual": len(hidden["test_results"])}
            box.command("rm -- " + shlex.quote(hidden_path))
        regression = run_tests(box, case["regression_command"])
        if expected:
            for name, result in (("hidden", hidden), ("regression", regression)):
                check_control_tests(result, expected[name])
        result = {"passed": submission["passed"] and hidden["passed"] and regression["passed"],
                  "submission": submission, "hidden": hidden, "regression": regression,
                  "submitted_test_files": changed_tests, "auxiliary_files": sorted(auxiliary),
                  "test_adaptations": ["GenStage upstream consumer-down monitor barrier"] if case_id == "core-genstage-cancelled-demand" else []}
    if case.get("require_regression_test") and check_coverage:
        coverage = {"passed": False, "reason": "no_added_or_changed_regression_test"}
        if changed_tests and submission["passed"]:
            with Sandbox(case_id) as broken:
                broken.apply(test_patch)
                install_formatter(broken)
                probe = run_tests(broken, "mix test " + shlex.join(changed_tests))
                detected = sorted(name for name in behavioral_failures(probe)
                                  if submission["test_results"].get(name) == "passed")
                coverage = {"passed": bool(probe["completed"] and detected and probe["returncode"] != 0),
                            "detected_tests": detected, "broken_test_probe": probe}
        elif changed_tests:
            coverage["reason"] = "submitted_tests_do_not_pass_after_repair"
        result["regression_coverage"] = coverage
        result["passed"] = bool(result["passed"] and coverage["passed"])
    return result


def controls(case_id, out):
    guard()
    harness_before = sha(Path(__file__))
    formatter_before = sha(ROOT / "scripts/grade_formatter.exs")
    directory, case = case_data(case_id)
    reference = (directory / "reference.patch").read_text()
    if (directory / "reference-tests.patch").exists():
        reference += (directory / "reference-tests.patch").read_text()
    result = {"case": case_id, "valid": False}
    for name, patch, coverage in [("empty_patch", "", False), ("reference_patch", reference, True)]:
        result[name] = grade(case_id, patch, check_coverage=coverage)
        write_json(out, result)
    halt_patch = "diff --git a/lib/eab_halt.ex b/lib/eab_halt.ex\nnew file mode 100644\n--- /dev/null\n+++ b/lib/eab_halt.ex\n@@ -0,0 +1 @@\n+System.halt(0)\n"
    result["early_exit"] = grade(case_id, reference + halt_patch)
    result["valid"] = bool(not result["empty_patch"]["passed"] and result["empty_patch"].get("hidden", {}).get("completed")
                       and behavioral_failures(result["empty_patch"].get("hidden", {}))
                       and result["reference_patch"]["passed"] and not result["early_exit"]["passed"])
    if probe := case.get("partial_repair_probe"):
        partial = (directory / "reference.patch").read_text()
        if probe["kind"] == "replace":
            if partial.count(probe["before"]) != probe["occurrences"]:
                raise RuntimeError("Partial-repair probe no longer matches the reference patch")
            partial = partial.replace(probe["before"], probe["after"])
        elif probe["kind"] == "file_only":
            header = "a/" + probe["path"] + " b/" + probe["path"] + "\n"
            blocks = [block for block in partial.split("diff --git ")[1:] if block.startswith(header)]
            if len(blocks) != 1:
                raise RuntimeError("Partial-repair file is not unique")
            partial = "diff --git " + blocks[0]
        else:
            raise RuntimeError("Unknown partial-repair probe kind")
        partial_result = grade(case_id, partial, expected=result["reference_patch"], check_coverage=False)
        rejected_behaviorally = bool(partial_result.get("hidden", {}).get("completed") and
                                     behavioral_failures(partial_result["hidden"]))
        result["partial_repair"] = {"description": probe["description"], "grade": partial_result,
                                    "rejected_behaviorally": rejected_behaviorally}
        result["valid"] = bool(result["valid"] and rejected_behaviorally)
    result["runtime"] = json.loads((LOCAL / "runtimes" / f"{case_id}.json").read_text())
    result["harness_sha256"] = harness_before
    result["formatter_sha256"] = formatter_before
    if harness_before != sha(Path(__file__)) or formatter_before != sha(ROOT / "scripts/grade_formatter.exs"):
        result["valid"] = False
        result["error"] = "Evaluator changed while controls were running; rerun with one frozen version"
    result["power_envelope"] = guard()
    write_json(out, result)
    write_json(LOCAL / "controls" / f"{case_id}.json", result)
    return result


def request(candidate, key, payload=None, route="/v1/chat/completions"):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(candidate["base_url"].rstrip("/") + route, data=body,
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    try:
        with urllib.request.urlopen(req, timeout=1200) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read(12000).decode(errors="replace")
        if key:
            detail = detail.replace(key, "[REDACTED]")
        raise RuntimeError(f"Endpoint HTTP {error.code}: {detail}") from error


def api_key(candidate):
    if name := candidate.get("api_key_env"):
        return os.environ[name]
    path = LOCAL / "api-key"
    return path.read_text().strip() if path.exists() else ""


def context_policy():
    policy = json.loads((ROOT / "config/benchmark.json").read_text())["context_policy"]
    if (policy.get("compaction") is not False or
            any(type(policy.get(k)) is not int or policy[k] <= 0
                for k in ("window_tokens", "response_tokens", "safety_tokens")) or
            policy["response_tokens"] + policy["safety_tokens"] >= policy["window_tokens"]):
        raise ValueError("Invalid shared context policy")
    return policy


def endpoint_metadata(candidate, key):
    models = request(candidate, key, route="/v1/models")
    props = request(candidate, key, route="/props")
    if (candidate["model"] not in {m["id"] for m in models.get("data", [])} or
            props.get("model_alias") != candidate["model"]):
        raise RuntimeError("Endpoint is not serving the configured model alias")
    capacity = props.get("default_generation_settings", {}).get("n_ctx")
    if type(capacity) is not int or capacity < context_policy()["window_tokens"]:
        raise RuntimeError(f"Endpoint context {capacity} is below the shared {context_policy()['window_tokens']}-token window")
    if candidate.get("expected_build") and props.get("build_info") != candidate["expected_build"]:
        raise RuntimeError("Endpoint build differs from the candidate configuration")
    return {"models": models, "props": props}


def endpoint_profile(metadata):
    # Exclude uptime, random media markers and transient health fields.
    props = metadata["props"]
    return {k: props.get(k) for k in ("model_alias", "model_path", "model_ftype", "build_info",
             "default_generation_settings", "chat_template", "chat_template_caps", "total_slots")}


def input_tokens(candidate, key, payload, capacity):
    mode = candidate.get("token_counter", "llama_cpp")
    if mode == "llama_cpp":
        count = request(candidate, key, payload, "/v1/chat/completions/input_tokens").get("input_tokens")
    elif mode == "strata_owned_overflow_v1":
        # Only the reviewed owned Strata launcher guarantees rejection BEFORE
        # generation: fit_max_tokens=False, no native MCP/resume/prefix handling.
        # This opt-in adapter is not safe for an arbitrary compatible server.
        if any(payload.get(k) for k in ("strata_mcp", "strata_resume", "strata_prefix")):
            raise RuntimeError("Native prompt rewriting is unsupported")
        probe = dict(payload, max_tokens=capacity + 1, max_completion_tokens=capacity + 1, stream=False)
        try:
            request(candidate, key, probe)
        except RuntimeError as error:
            match = re.fullmatch(r"Endpoint HTTP 400: (.*)", str(error), re.DOTALL)
            detail = json.loads(match[1]).get("error", {}) if match else {}
            found = re.search(r"prompt \((\d+) tokens\).*exceeds the context \((\d+)\)", detail.get("message", ""))
            if detail.get("type") != "invalid_request_error" or not found or int(found[2]) != capacity:
                raise RuntimeError("Unexpected Strata token-count response") from error
            count = int(found[1])
        else:
            raise RuntimeError("Strata count probe generated unexpectedly; reject this endpoint")
    else:
        raise ValueError(f"Unsupported token counter: {mode}")
    if type(count) is not int or count <= 0:
        raise RuntimeError("Missing exact input-token count")
    return count


def check_usage(response, prompt_tokens, allowance):
    usage = response.get("usage", {})
    count = usage.get("completion_tokens")
    if type(count) is not int or not 0 <= count <= allowance:
        raise RuntimeError("Missing or out-of-budget completion-token accounting")
    if usage.get("prompt_tokens") != prompt_tokens:
        raise RuntimeError("Preflight input-token count differs from generation accounting")
    reasoning = usage.get("completion_tokens_details", {}).get("reasoning_tokens", 0)
    if type(reasoning) is not int or not 0 <= reasoning <= count:
        raise RuntimeError("Reasoning-token count is inconsistent with completion usage")
    return count


def run_agent(case_id, candidate_id, out, seed, max_calls, max_tokens):
    before = guard()
    control = json.loads((LOCAL / "controls" / f"{case_id}.json").read_text())
    runtime = json.loads((LOCAL / "runtimes" / f"{case_id}.json").read_text())
    if not control["valid"] or control["runtime"] != runtime or control["harness_sha256"] != sha(Path(__file__)) or control["formatter_sha256"] != sha(ROOT / "scripts/grade_formatter.exs"):
        raise RuntimeError("Run matching successful fixture controls before model attempts")
    if out.exists():
        raise RuntimeError("Refusing to overwrite an attempt")
    out.mkdir(parents=True)
    directory, case = case_data(case_id)
    candidate = next(c for c in json.loads((ROOT / "config/candidates.json").read_text())["candidates"] if c["id"] == candidate_id)
    key = api_key(candidate)
    policy = context_policy()
    messages = [{"role": "system", "content": "You are an Elixir coding agent working in an existing project at /workspace. Investigate the ticket, edit source, add regression tests, and verify your work using terminal tools. Every bash call starts in /workspace with a fresh shell. External network access is unavailable. Existing project and dependency source documentation is available locally. Do not change the task's contract or weaken tests. You may ask a clarification by topic. When finished, use submit. Your patch will be independently checked in a fresh environment."},
                {"role": "user", "content": (directory / "ticket.md").read_text()}]
    messages[0]["content"] += (" Allowed source/test edit prefixes: " + ", ".join(case["allowed_edit_prefixes"]) + "."
                               " The project test command is: " + case["regression_command"] + "."
                               f" Limits: {max_calls} model calls and {max_tokens} cumulative completion tokens."
                               f" The working context window is {policy['window_tokens']} tokens, including the response."
                               f" Each response may use at most {policy['response_tokens']} tokens."
                               " Conversation history is not compacted; when a budget is exhausted, the current patch is graded.")
    if case.get("require_regression_test"):
        messages[0]["content"] += (" Add or update at least one *_test.exs file under test/. Your regression tests must"
                                   " fail behaviorally on the original broken source and pass with your repair;"
                                   " a compilation or setup failure does not count as detecting the defect.")
    tools = [
        {"type": "function", "function": {"name": "bash", "description": "Execute a shell command in the project. Output may be truncated; read narrower ranges if needed.", "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"], "additionalProperties": False}}},
        {"type": "function", "function": {"name": "ask_clarification", "description": "Ask about a requirement. Available topics: " + ", ".join(case.get("clarifications", {})), "parameters": {"type": "object", "properties": {"topic": {"type": "string"}}, "required": ["topic"], "additionalProperties": False}}},
        {"type": "function", "function": {"name": "submit", "description": "Finish and submit the current project edits.", "parameters": {"type": "object", "properties": {}, "additionalProperties": False}}}
    ]
    record = {"case": case_id, "candidate": candidate, "seed": seed,
              "limits": {"model_calls": max_calls, "server_reported_completion_tokens": max_tokens, "per_call": policy['response_tokens']},
              "context_policy": policy,
              "accounting_note": "Completion usage includes reasoning and tool syntax; exact input counts are checked against each response. No compaction.",
              "candidate_metadata": endpoint_metadata(candidate, key),
              "harness_sha256": sha(Path(__file__)), "case_sha256": sha(directory / "case.json"),
              "power_before": before, "generated_tokens": 0, "calls": 0, "stop_reason": "call_budget"}
    record["endpoint_profile"] = endpoint_profile(record["candidate_metadata"])
    record["input_token_counts"] = []
    write_json(out / "attempt.json", record)
    try:
        with Sandbox(case_id) as box:
            box.capture_out = out
            record["runtime"] = box.runtime
            for step in range(max_calls):
                remaining = max_tokens - record["generated_tokens"]
                if remaining <= 0:
                    record["stop_reason"] = "token_budget"
                    break
                payload = {"model": candidate["model"], "messages": messages, "tools": tools,
                           "temperature": 0.6, "top_p": 0.95, "seed": seed,
                           "max_tokens": min(policy['response_tokens'], remaining), "reasoning_effort": candidate["reasoning_effort"],
                           "top_k": 20, "min_p": 0.05, "repeat_penalty": 1.0,
                           "chat_template_kwargs": {"enable_thinking": True}, "stream": False}
                capacity = record["candidate_metadata"]["props"]["default_generation_settings"]["n_ctx"]
                count = input_tokens(candidate, key, payload, capacity)
                record["input_token_counts"].append(count)
                if count + payload["max_tokens"] + policy['safety_tokens'] > policy['window_tokens']:
                    record["stop_reason"] = "context_budget"
                    break
                write_json(out / f"request-{step:03}.json", payload)
                response = request(candidate, key, payload)
                response.pop("timings", None)
                write_json(out / f"response-{step:03}.json", response)
                usage = check_usage(response, count, payload["max_tokens"])
                record["generated_tokens"] += usage
                record["calls"] += 1
                message = response["choices"][0]["message"]
                messages.append(message)
                submitted = False
                for call in message.get("tool_calls", []):
                    try:
                        function = call["function"]
                        args = json.loads(function["arguments"])
                        if function["name"] == "bash":
                            result = box.command(args["command"])
                        elif function["name"] == "ask_clarification":
                            result = {"answer": case.get("clarifications", {}).get(args["topic"], "No additional information is available. Follow the ticket and documented existing behavior.")}
                        elif function["name"] == "submit":
                            result = {"submitted": True}
                            submitted = True
                        else:
                            result = {"error": "Unknown tool"}
                    except (KeyError, ValueError, TypeError) as error:
                        result = {"error": "Invalid tool arguments: " + str(error)}
                    messages.append({"role": "tool", "tool_call_id": call["id"], "content": json.dumps(result)})
                write_json(out / "messages.json", messages)
                write_json(out / "attempt.json", record)
                if submitted:
                    record["stop_reason"] = "submitted"
                    break
                if not message.get("tool_calls"):
                    messages.append({"role": "user", "content": "Continue using the tools to implement and verify the ticket, or call submit when done."})
            patch = box.patch()
            (out / "model.patch").write_text(patch)
        record["grade"] = grade(case_id, patch, expected=control["reference_patch"])
        record["endpoint_profile_after"] = endpoint_profile(endpoint_metadata(candidate, key))
        if record["endpoint_profile_after"] != record["endpoint_profile"]:
            raise RuntimeError("Endpoint profile changed during the attempt")
        record["status"] = "completed"
    except Exception as error:
        record["status"] = "error"
        record["error"] = f"{type(error).__name__}: {error}"
    finally:
        record["power_after"] = guard()
        write_json(out / "attempt.json", record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["init", "prepare", "refresh", "controls", "run", "grade"])
    parser.add_argument("--case")
    parser.add_argument("--candidate", default="flash-next")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--patch", type=Path)
    parser.add_argument("--seed", type=int, default=101)
    parser.add_argument("--max-calls", type=int, default=32)
    parser.add_argument("--max-tokens", type=int, default=65536)
    args = parser.parse_args()
    if args.action == "init":
        result = guard(initialize=True)
    elif not args.case:
        parser.error("--case is required")
    elif args.action == "prepare":
        result = prepare(args.case)
    elif args.action == "refresh":
        result = refresh_fixture(args.case)
    elif args.action == "controls":
        if not args.out: parser.error("--out is required")
        result = controls(args.case, args.out)
    elif args.action == "grade":
        guard()
        if not args.patch: parser.error("--patch is required")
        result = grade(args.case, args.patch.read_text())
    else:
        if not args.out: parser.error("--out is required")
        result = run_agent(args.case, args.candidate, args.out, args.seed, args.max_calls, args.max_tokens)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
