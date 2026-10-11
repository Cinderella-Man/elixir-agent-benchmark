#!/usr/bin/env python3
"""Standalone, remote-only Elixir agent pilot. No throughput or latency scoring."""
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
    if socket.gethostname().split(".")[0].lower() != "ratx570":
        raise RuntimeError("Execution is authorized only on ratx570; the shared workstation is excluded")
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
    return {"unit_sha256": state["sha256"], "gpu_rows": rows}


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
    setup = case["runtime"].get("setup_commands", ["mix deps.get", "mix deps.compile"])
    env = {"MIX_ENV": "test", "MIX_HOME": "/opt/mix", "HEX_HOME": "/opt/hex",
           "ERL_FLAGS": "+S 2:2", **case["runtime"].get("environment", {})}
    lines = [f"FROM {base}", "RUN (command -v git && command -v python3 && test -f /etc/ssl/certs/ca-certificates.crt) || (apt-get update && apt-get install -y --no-install-recommends git python3 ca-certificates && rm -rf /var/lib/apt/lists/*)",
             "RUN useradd -m -u 1000 agent", "WORKDIR /workspace"]
    lines.extend(f"ENV {key}={json.dumps(value)}" for key, value in env.items())
    lines += ["COPY source/ /workspace/", "RUN mix local.hex --force && mix local.rebar --force"]
    lines += ["RUN " + command for command in setup]
    lines += ["RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && git commit -m 'Initial task workspace'",
              "RUN chown -R agent:agent /workspace /opt/mix /opt/hex", "USER agent", 'CMD ["sleep", "infinity"]']
    (dest / "Dockerfile").write_text("\n".join(lines) + "\n")
    tag = f"elixir-agent-benchmark:{case_id}"
    result = shell(["docker", "build", "-t", tag, str(dest)], check=False, timeout=1800)
    (dest / "build.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f"Image build failed: {dest / 'build.log'}")
    services = {}
    for name, config in case.get("services", {}).items():
        services[name] = pin_image(config["image"])
    runtime = {"image": image_id(tag), "tag": tag, "base_image": base,
               "source_revision": revision, "archive_sha256": sha(archive),
               "case_sha256": sha(directory / "case.json"), "services": services,
               "fixture_hashes": {p.name: sha(p) for p in directory.iterdir() if p.is_file()},
               "dockerfile": "\n".join(lines)}
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

    def __enter__(self):
        network = "none"
        try:
            if "postgres" in self.runtime["services"]:
                self.db = self.name + "-db"
                shell(["docker", "run", "-d", "--name", self.db, "--network=none", "--memory=512m", "--cpus=1",
                       "-e", "POSTGRES_PASSWORD=postgres", self.runtime["services"]["postgres"]])
                shell(["docker", "exec", self.db, "sh", "-c", "for i in $(seq 1 60); do pg_isready -U postgres && exit 0; sleep 1; done; exit 1"], timeout=90)
                network = "container:" + self.db
            shell(["docker", "run", "-d", "--name", self.name, "--network=" + network,
                   "--cap-drop=ALL", "--security-opt=no-new-privileges", "--memory=3g", "--cpus=2", "--pids-limit=512",
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
        shell(["docker", "rm", "-f", self.name], check=False)
        if self.db:
            shell(["docker", "rm", "-f", self.db], check=False)

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


def grade(case_id, patch, expected=None):
    _, case = case_data(case_id)
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
        box.command("git add -A")
        names = box.command("git diff --cached --name-only --diff-filter=ACDMRT HEAD")["output"].splitlines()
        disallowed = [name for name in names if not allowed(name)]
        if disallowed:
            return {"passed": False, "reason": "disallowed_edits", "paths": disallowed}
        def stabilize_upstream_tests():
            if case_id != "core-genstage-cancelled-demand":
                return
            # The upstream callback sends its notification before GenStage installs
            # the monitor. Wait for that callback/message to finish before killing
            # the consumer, so :killed cannot race into :noproc. No assertion changes.
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
        shell(["docker", "exec", "-u", "0", box.name, "mkdir", "-p", "/opt/eab-grade"])
        shell(["docker", "cp", str(ROOT / "scripts/grade_formatter.exs"), box.name + ":/opt/eab-grade/formatter.exs"])
        def tests(command):
            if not command.startswith("mix test"):
                raise RuntimeError("Pilot grader requires an explicit mix test command")
            command = "elixir -r /opt/eab-grade/formatter.exs -S " + command
            if "--seed" not in shlex.split(command):
                command += " --seed 0"
            command += " --formatter ExUnit.CLIFormatter --formatter ElixirAgentBenchmark.TrustedFormatter"
            result = box.command(command, timeout=240, truncate=False)
            found = re.findall(r"^EAB_TEST:([a-z]+):([A-Za-z0-9+/=]+)$", result["output"], re.M)
            completed = re.findall(r"^EAB_SUITE_FINISHED:(\d+)$", result["output"], re.M)
            identities = {base64.b64decode(name).decode(): state for state, name in found}
            result["test_results"] = identities
            result["completed"] = len(completed) == 1 and int(completed[0]) == len(found) == len(identities) and len(found) > 0
            result["passed"] = result["returncode"] == 0 and result["completed"] and all(state == "passed" for state in identities.values())
            return result
        # First check the delivered workspace, including changes to tracked tests.
        # Restoring immutable tests alone would hide broken agent-added coverage.
        stabilize_upstream_tests()
        submission = tests(box.case["regression_command"])
        # Original tests are trusted controls, and cannot be weakened by a submitted patch.
        restored = box.command("git ls-tree -r --name-only HEAD test | xargs -r git restore --source=HEAD --")
        if restored["returncode"]:
            return {"passed": False, "reason": "test_restore_failed", "details": restored, "submission": submission}
        stabilize_upstream_tests()
        hidden_path = box.case["hidden_test_path"]
        shell(["docker", "cp", str(box.directory / "hidden_test.exs"), box.name + ":/workspace/" + hidden_path])
        hidden = tests("mix test " + shlex.quote(hidden_path) + " --seed 0")
        authored_hidden_count = len(re.findall(r"^\s*test\s+\"", (box.directory / "hidden_test.exs").read_text(), re.M))
        if len(hidden["test_results"]) != authored_hidden_count:
            hidden["passed"] = False
            hidden["count_mismatch"] = {"expected": authored_hidden_count, "actual": len(hidden["test_results"])}
        # Remove the hidden test before the original regression suite to keep the two measurements distinct.
        box.command("rm -- " + shlex.quote(hidden_path))
        regression = tests(box.case["regression_command"])
        if expected:
            for name, result in (("hidden", hidden), ("regression", regression)):
                required = set(expected[name]["test_results"])
                result["missing_control_tests"] = sorted(required - set(result["test_results"]))
                if result["missing_control_tests"]:
                    result["passed"] = False
        return {"passed": submission["passed"] and hidden["passed"] and regression["passed"],
                "submission": submission, "hidden": hidden, "regression": regression, "auxiliary_files": sorted(auxiliary),
                "test_adaptations": ["GenStage upstream consumer-down monitor barrier"] if case_id == "core-genstage-cancelled-demand" else []}


def controls(case_id, out):
    guard()
    directory, _ = case_data(case_id)
    result = {"case": case_id, "empty_patch": grade(case_id, ""),
              "reference_patch": grade(case_id, (directory / "reference.patch").read_text())}
    halt_patch = "diff --git a/lib/eab_halt.ex b/lib/eab_halt.ex\nnew file mode 100644\n--- /dev/null\n+++ b/lib/eab_halt.ex\n@@ -0,0 +1 @@\n+System.halt(0)\n"
    result["early_exit"] = grade(case_id, (directory / "reference.patch").read_text() + halt_patch)
    result["valid"] = (not result["empty_patch"]["passed"] and result["empty_patch"].get("hidden", {}).get("completed")
                       and result["reference_patch"]["passed"] and not result["early_exit"]["passed"])
    result["runtime"] = json.loads((LOCAL / "runtimes" / f"{case_id}.json").read_text())
    result["harness_sha256"] = sha(Path(__file__))
    result["formatter_sha256"] = sha(ROOT / "scripts/grade_formatter.exs")
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
        detail = error.read(12000).decode(errors="replace").replace(key, "[REDACTED]")
        raise RuntimeError(f"Endpoint HTTP {error.code}: {detail}") from error


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
    key = (LOCAL / "api-key").read_text().strip()
    messages = [{"role": "system", "content": "You are an Elixir coding agent working in an existing project at /workspace. Investigate the ticket, edit source, add regression tests, and verify your work using terminal tools. Every bash call starts in /workspace with a fresh shell. External network access is unavailable. Existing project and dependency source documentation is available locally. Do not change the task's contract or weaken tests. You may ask a clarification by topic. When finished, use submit. Your patch will be independently checked in a fresh environment."},
                {"role": "user", "content": (directory / "ticket.md").read_text()}]
    tools = [
        {"type": "function", "function": {"name": "bash", "description": "Execute a shell command in the project. Output may be truncated; read narrower ranges if needed.", "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"], "additionalProperties": False}}},
        {"type": "function", "function": {"name": "ask_clarification", "description": "Ask about a requirement. Available topics: " + ", ".join(case.get("clarifications", {})), "parameters": {"type": "object", "properties": {"topic": {"type": "string"}}, "required": ["topic"], "additionalProperties": False}}},
        {"type": "function", "function": {"name": "submit", "description": "Finish and submit the current project edits.", "parameters": {"type": "object", "properties": {}, "additionalProperties": False}}}
    ]
    record = {"case": case_id, "candidate": candidate, "seed": seed,
              "limits": {"model_calls": max_calls, "server_reported_completion_tokens": max_tokens, "per_call": 8192},
              "accounting_note": "Uses server-reported completion_tokens; retain raw usage and qualify backend reasoning-token semantics before a model-quality campaign",
              "candidate_metadata": {"models": request(candidate, key, route="/v1/models"), "props": request(candidate, key, route="/props")},
              "harness_sha256": sha(Path(__file__)), "case_sha256": sha(directory / "case.json"),
              "power_before": before, "generated_tokens": 0, "calls": 0, "stop_reason": "call_budget"}
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
                           "max_tokens": min(8192, remaining), "reasoning_effort": candidate["reasoning_effort"],
                           "chat_template_kwargs": {"enable_thinking": True}, "stream": False}
                write_json(out / f"request-{step:03}.json", payload)
                response = request(candidate, key, payload)
                response.pop("timings", None)
                write_json(out / f"response-{step:03}.json", response)
                usage = response.get("usage", {}).get("completion_tokens")
                if not isinstance(usage, int) or usage < 0:
                    raise RuntimeError("Missing completion-token accounting")
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
    parser.add_argument("action", choices=["init", "prepare", "controls", "run", "grade"])
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
