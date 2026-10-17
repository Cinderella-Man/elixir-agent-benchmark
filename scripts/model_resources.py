#!/usr/bin/env python3
"""Read a loaded model's memory allocation. No inference or speed measurement."""
import argparse
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen


def gpu_rows(query):
    result = subprocess.run(['nvidia-smi', query, '--format=csv,noheader,nounits'],
                            check=True, capture_output=True, text=True)
    return list(csv.reader(result.stdout.splitlines(), skipinitialspace=True))


def process_gpus(pid, devices, processes):
    cards = {row[0]: row for row in devices}
    gpus = []
    for uuid, process_id, used in processes:
        if int(process_id) == pid:
            _, name, total = cards[uuid]
            gpus.append({'name': name, 'capacity_bytes': int(total) * 2**20,
                         'used_bytes': int(used) * 2**20})
    return gpus


def capture(pid, endpoint, key=''):
    proc = Path('/proc') / str(pid)
    identity = proc.joinpath('stat').read_text().rsplit(')', 1)[1].split()[19]
    status = dict(line.split(':', 1) for line in proc.joinpath('status').read_text().splitlines())
    def kib(name):
        value = status.get(name)
        return int(value.split()[0]) * 1024 if value else None
    def get(route):
        request = Request(endpoint.rstrip('/') + route, headers={'Authorization': 'Bearer ' + key} if key else {})
        with urlopen(request, timeout=10) as response:
            return json.load(response)
    health, props = get('/health'), get('/props')
    if health.get('loaded') is False:
        raise ValueError('Model is not loaded')
    artifact = Path(props['model_path']).name
    context = props['default_generation_settings']['n_ctx']
    backend = 'strata' if health.get('service') == 'strata' else 'llama_cpp'
    engine = get('/metrics').get('engine', {}) if backend == 'strata' else {}
    gpus = process_gpus(pid, gpu_rows('--query-gpu=uuid,name,memory.total'),
                        gpu_rows('--query-compute-apps=gpu_uuid,pid,used_gpu_memory'))
    if not gpus:
        raise ValueError('No NVIDIA GPU allocation found for the selected process')
    cgroup = next((line.split(':', 2)[2] for line in proc.joinpath('cgroup').read_text().splitlines()
                   if line.startswith('0::')), None)
    def cgroup_bytes(file):
        if not cgroup or cgroup == '/':
            return None
        path = Path('/sys/fs/cgroup') / cgroup.lstrip('/') / file
        return int(path.read_text()) if path.is_file() else None
    cpu = next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                if line.startswith('model name')), 'Unknown')
    if identity != proc.joinpath('stat').read_text().rsplit(')', 1)[1].split()[19]:
        raise ValueError('Process changed while sampling')
    return {'kind': 'loaded_snapshot', 'observed_at': datetime.now(timezone.utc).isoformat(),
            'model_artifact': artifact, 'backend': backend, 'backend_version': props.get('build_info'),
            'context_tokens': context, 'kv_cache': engine.get('kv'), 'cpu': cpu,
            'gpus': gpus, 'ram_rss_bytes': kib('VmRSS'), 'ram_lifetime_peak_bytes': kib('VmHWM'),
            'service_ram_bytes': cgroup_bytes('memory.current'),
            'service_ram_lifetime_peak_bytes': cgroup_bytes('memory.peak')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid', required=True, type=int, help='Inference engine PID on this host')
    parser.add_argument('--endpoint', required=True)
    parser.add_argument('--key-file', type=Path, help='Existing API key file; its contents are never exported')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    key = args.key_file.read_text().strip() if args.key_file else ''
    result = capture(args.pid, args.endpoint, key)
    body = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(body)
    else:
        print(body, end='')


if __name__ == '__main__':
    main()
