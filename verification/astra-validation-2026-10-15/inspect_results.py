"""Read local run copies; never contact a model or export credentials."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / '.local/astra-validation-2026-10-15'
FROZEN = ROOT / 'verification/frozen-cases-2026-10-15'
plan = json.loads((FROZEN / 'validation-plan.json').read_text())
evidence = json.loads((FROZEN / 'evidence.json').read_text())
expected_cases = [c['case'] for c in evidence['cases']]
expected = {c['case']: c for c in evidence['cases']}

def read(path):
    return json.loads(path.read_text()) if path.exists() else None

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None

def normalize(value, key=None):
    if isinstance(value, dict):
        return {k: normalize(v, k) for k, v in value.items() if k != 'output'}
    if isinstance(value, list):
        if key in {'detected_tests', 'submitted_test_files', 'auxiliary_files'}:
            return sorted(value)
        return [normalize(v) for v in value]
    return value

def request_key(body):
    return {k: v for k, v in body.items() if k != 'prompt_cache_key'}

rounds = []
for directory in sorted(AUDIT.glob('round-[12]')):
    run = read(directory / 'run.json')
    if not run:
        continue
    assert run['release_id'] == evidence['release'], 'Release mismatch'
    assert run['cases'] == expected_cases, 'Inventory mismatch'
    assert run['settings'] == plan['settings'], 'Settings mismatch'
    assert run['model']['model'] == plan['model'], 'Model mismatch'
    assert not run.get('resume_count'), 'Resumed run is not a fresh round'
    cases = []
    for case in expected_cases:
        d = directory / case
        a = read(d / 'attempt.json') or {}
        frozen = read(FROZEN / 'inputs' / (case + '.json'))
        actual = read(d / 'request-0000.json')
        runtime = read(d / 'runtime.json')
        qualification = read(d / 'qualification.json')
        checks = {}
        if a.get('agent_image'):
            checks['agent_image'] = a['agent_image'] == frozen['agent_image']
            checks['pi'] = a['agent'] == frozen['pi']
            checks['settings'] = a['settings'] == plan['settings']
        for name in ['prompt', 'instructions']:
            p = d / (name + '.md')
            if p.exists():
                checks[name] = p.read_text() == frozen[name]
        if actual:
            checks['initial_request_except_cache_key'] = request_key(actual) == request_key(frozen['initial_request'])
        if runtime:
            checks['runtime'] = all(runtime.get(k) == v for k, v in expected[case]['qualification_identity']['runtime'].items())
        if qualification:
            checks['qualification'] = qualification['identity'] == expected[case]['qualification_identity'] and qualification['valid']
            checks['qualification_outcomes'] = normalize(qualification) == read(FROZEN / 'qualification-outcomes.json')[case]
        cases.append({
            'case': case, 'status': a.get('status'), 'passed': (a.get('grade') or {}).get('passed'),
            'calls': a.get('calls'), 'generated_tokens': a.get('generated_tokens'),
            'stop_reason': a.get('stop_reason'), 'error': a.get('error'), 'frozen_input_checks': checks,
            'patch_sha256': sha(d / 'model.patch'), 'grade_sha256': sha(d / 'grade.json'),
            'initial_request_sha256': sha(d / 'request-0000.json'),
        })
    rounds.append({'round': int(directory.name[-1]), 'run_id': run['id'], 'status': run['status'], 'cases': cases})
result = {'release': evidence['release'], 'model': plan['model'], 'settings': plan['settings'], 'rounds': rounds}
(AUDIT / 'inspection.json').write_text(json.dumps(result, indent=2) + '\n')
for r in rounds:
    print('ROUND', r['round'], r['run_id'], r['status'])
    for c in r['cases']:
        if c['status']:
            print(c['case'], c['status'], c['passed'], c['calls'], c['generated_tokens'], 'input mismatches:', [k for k, v in c['frozen_input_checks'].items() if not v], c['error'])
