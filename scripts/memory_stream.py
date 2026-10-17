#!/usr/bin/env python3
"""Stream model-service memory over SSH. Reads counters only; never runs inference.

The first stdin line is a JSON request. A second line (or EOF) stops collection.
stdout is NDJSON; credentials, absolute model paths and HTTP payloads stay private.
"""
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import select
import socket
import subprocess
import sys
import time
from urllib.request import Request, urlopen

INTERVAL = 1.0


def now():
    return datetime.now(timezone.utc).isoformat()


def emit(value):
    print(json.dumps(value), flush=True)


def command(args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=5).stdout


def gpu_usage(pids, devices, processes):
    """Attribute allocations by PID and physical UUID, excluding other services."""
    cards = {uuid: (name, int(total) * 2**20) for uuid, name, total in devices}
    allocated = {}
    for uuid, pid, used in processes:
        if int(pid) in pids:
            if not used.isdigit():
                raise ValueError('GPU allocation is unavailable')
            allocated[uuid] = allocated.get(uuid, 0) + int(used) * 2**20
    return [{'uuid': uuid, 'name': cards[uuid][0], 'capacity_bytes': cards[uuid][1],
             'used_bytes': used} for uuid, used in sorted(allocated.items())]


def gpu_rows(query):
    return list(csv.reader(command(['nvidia-smi', query, '--format=csv,noheader,nounits']).splitlines(),
                           skipinitialspace=True))


def process_identity(pid):
    return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[19]


def listener(port):
    rows = command(['ss', '-H', '-ltnp', f'sport = :{port}']).splitlines()
    pids = set()
    for row in rows:
        fields = row.split()
        if len(fields) >= 5 and fields[3] in {f'127.0.0.1:{port}', f'0.0.0.0:{port}', f'*:{port}', f'[::]:{port}'}:
            pids.update(int(pid) for pid in re.findall(r'pid=(\d+)', row))
    if len(pids) != 1:
        raise ValueError('Expected one local model-server listener')
    return pids.pop()


def group_for(pid):
    group = next((line.split(':', 2)[2] for line in Path(f'/proc/{pid}/cgroup').read_text().splitlines()
                  if line.startswith('0::')), None)
    if not group or not group.endswith(('.service', '.scope')):
        raise ValueError('Model server needs a dedicated cgroup v2 service or scope')
    return group


class Sampler:
    def __init__(self, request):
        port = request['port']
        if type(port) is not int or not 1 <= port <= 65535:
            raise ValueError('Invalid model endpoint port')
        self.endpoint = f'http://127.0.0.1:{port}'
        self.key = Path(request['key_file']).read_text().strip() if request.get('key_file') else ''
        self.pid = listener(port)
        self.started = process_identity(self.pid)
        self.group = group_for(self.pid)
        self.cgroup = Path('/sys/fs/cgroup') / self.group.lstrip('/')
        self.expected = self.model()
        if self.expected['model_artifact'] != request['artifact'] or self.expected['context_tokens'] != request['context_tokens']:
            raise ValueError('Loaded model artifact or context differs from the benchmark endpoint')
        if self.expected['backend'] != request['backend']:
            raise ValueError('Loaded runtime differs from the benchmark endpoint')
        self.gpu_processes = None
        self.gpu_ids = None

    def get(self, route):
        headers = {'Authorization': 'Bearer ' + self.key} if self.key else {}
        with urlopen(Request(self.endpoint + route, headers=headers), timeout=5) as response:
            return json.load(response)

    def model(self):
        health, props = self.get('/health'), self.get('/props')
        if health.get('loaded') is False:
            raise ValueError('Model is not loaded')
        backend = 'strata' if health.get('service') == 'strata' else 'llama_cpp'
        return {'model_artifact': Path(props['model_path']).name, 'backend': backend,
                'backend_version': props.get('build_info'),
                'context_tokens': props['default_generation_settings']['n_ctx']}

    def identity(self):
        engine = self.get('/metrics').get('engine', {}) if self.expected['backend'] == 'strata' else {}
        cpu = next((row.split(':', 1)[1].strip() for row in Path('/proc/cpuinfo').read_text().splitlines()
                    if row.startswith('model name')), 'Unknown')
        return dict(self.expected, host=socket.gethostname(), service=Path(self.group).name,
                    kv_cache=engine.get('kv'), cpu=cpu)

    def sample(self):
        if process_identity(self.pid) != self.started or group_for(self.pid) != self.group or self.model() != self.expected:
            raise ValueError('Model server identity changed during collection')
        pids = {int(pid) for file in self.cgroup.rglob('cgroup.procs') for pid in file.read_text().split()}
        if self.pid not in pids:
            raise ValueError('Model server left its service')
        processes = gpu_rows('--query-compute-apps=gpu_uuid,pid,used_gpu_memory')
        engine_pids = {int(row[1]) for row in processes if int(row[1]) in pids}
        engines = {pid: process_identity(pid) for pid in engine_pids}
        if not engines or (self.gpu_processes is not None and engines != self.gpu_processes):
            raise ValueError('Inference GPU process disappeared or changed')
        devices = gpu_rows('--query-gpu=uuid,name,memory.total')
        gpus = gpu_usage(pids, devices, processes)
        ids = [gpu['uuid'] for gpu in gpus]
        if self.gpu_ids is not None and ids != self.gpu_ids:
            raise ValueError('Model GPU placement changed')
        rss = 0
        for pid in pids:
            try:
                status = dict(row.split(':', 1) for row in Path(f'/proc/{pid}/status').read_text().splitlines())
                rss += int(status.get('VmRSS', '0 kB').split()[0]) * 1024
            except FileNotFoundError:
                if pid in engines or pid == self.pid:
                    raise
        ram = int((self.cgroup / 'memory.current').read_text())
        stat = dict(row.split() for row in (self.cgroup / 'memory.stat').read_text().splitlines())
        host = dict(row.split(':', 1) for row in Path('/proc/meminfo').read_text().splitlines())
        host_total = int(host['MemTotal'].split()[0]) * 1024
        host_available = int(host['MemAvailable'].split()[0]) * 1024
        if process_identity(self.pid) != self.started or any(process_identity(pid) != start for pid, start in engines.items()):
            raise ValueError('Process restarted while sampling')
        self.gpu_processes, self.gpu_ids = engines, ids
        vram = sum(gpu['used_bytes'] for gpu in gpus)
        return {'type': 'sample', 'at': now(), 'monotonic_ms': round(time.monotonic() * 1000),
                'gpus': gpus, 'vram_bytes': vram, 'service_ram_bytes': ram,
                'process_rss_bytes': rss, 'ram_anon_bytes': int(stat.get('anon', 0)),
                'ram_file_bytes': int(stat.get('file', 0)), 'ram_kernel_bytes': int(stat.get('kernel', 0)),
                'combined_bytes': vram + ram, 'host_ram_total_bytes': host_total,
                'host_ram_used_bytes': host_total - host_available}


def main():
    # Read directly from the FD to avoid buffering a queued stop command past select().
    request = b''
    while not request.endswith(b'\n'):
        part = os.read(0, 1)
        if not part:
            return
        request += part
        if len(request) > 16384:
            raise ValueError('Oversized request')
    sampler = Sampler(json.loads(request))
    identity = sampler.identity()
    sample = sampler.sample()
    emit({'type': 'ready', 'identity': identity, 'interval_ms': int(INTERVAL * 1000)})
    emit(sample)
    deadline = time.monotonic() + INTERVAL
    while not select.select([sys.stdin], [], [], max(0, deadline - time.monotonic()))[0]:
        emit(sampler.sample())
        deadline = max(deadline + INTERVAL, time.monotonic())
    emit(sampler.sample())
    emit({'type': 'stopped', 'at': now()})


if __name__ == '__main__':
    try:
        main()
    except BrokenPipeError:
        pass  # SSH disappeared; nothing may keep sampling in the background.
    except Exception as error:
        # Never echo HTTP response bodies, credentials, command output or paths.
        emit({'type': 'error', 'at': now(), 'error': type(error).__name__,
              'message': str(error) if isinstance(error, ValueError) else 'Memory counter collection failed'})
        sys.exit(1)
