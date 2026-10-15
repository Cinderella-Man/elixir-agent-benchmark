"""Export two ordinary Astra runs from private local copies, excluding provider traces."""
import hashlib
import json
import runpy
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
PRIVATE = ROOT / '.local/astra-validation-2026-10-15'
FROZEN = ROOT / 'verification/frozen-cases-2026-10-15'


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def normalize(value):
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items() if k != 'output'}
    if isinstance(value, list):
        return [normalize(v) for v in value]
    return value


runpy.run_path(str(OUT / 'inspect_results.py'))
inspection = read(PRIVATE / 'inspection.json')
reviews = read(PRIVATE / 'reviews.json')
plan = read(FROZEN / 'validation-plan.json')
assert len(inspection['rounds']) == 2, 'Both fresh rounds must be retained'
assert inspection['model'] == plan['model'] and inspection['settings'] == plan['settings']
assert len({r['run_id'] for r in inspection['rounds']}) == 2
experiments = [read(PRIVATE / f'round-{n}' / 'run.json')['experiment_id'] for n in [1, 2]]
assert experiments[0] == experiments[1], 'The two rounds used different experiment identities'
inspection['same_experiment_identity'] = True

for result in inspection['rounds']:
    number = result['round']
    directory = PRIVATE / f'round-{number}'
    raw = read(directory / 'run.json')
    assert raw['status'] in ['completed', 'error', 'interrupted', 'cancelled']
    assert raw.get('cleanup_pending') is False, 'Wait for cleanup'
    result['started_at'] = raw['created_at']
    result['fresh_run'] = not raw.get('resume_count')
    assert result['fresh_run']
    for case in result['cases']:
        name = case['case']
        source = directory / name
        checks = case['frozen_input_checks']
        assert all(checks.values()), f'Frozen inputs changed: {number}/{name}'
        if case['passed'] is not None:
            assert len(checks) == 9, f'Incomplete input checks: {number}/{name}'
        patch = source / 'model.patch'
        if patch.exists():
            assert digest(patch) == case['patch_sha256']
            dest = OUT / f'round-{number}' / f'{name}.patch'
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(patch.read_bytes())
            case['patch'] = str(dest.relative_to(OUT))
        provider_error = source / 'provider-error.json'
        if provider_error.exists():
            error = read(provider_error)
            case['provider_error'] = {k: error.get(k) for k in ['status', 'code', 'param', 'message']}
            if isinstance(error.get('body'), dict):
                case['provider_error']['event_type'] = error['body'].get('type')
            case['provider_error_sha256'] = digest(provider_error)
        grade = source / 'grade.json'
        if grade.exists():
            assert digest(grade) == case['grade_sha256']
            case['grade'] = normalize(read(grade))
        review = reviews.get(f'{number}/{name}')
        if case['passed']:
            assert review and review['disposition'] == 'accepted', 'Passing patch review is not complete'
            assert review and review['patch_sha256'] == case['patch_sha256'], 'Missing patch review'
        if review:
            assert review['patch_sha256'] == case['patch_sha256'], f'Reviewed patch changed: {number}/{name}'
            case['review'] = review
        requests = sorted(source.glob('request-*.json'))
        usages = sorted(source.glob('usage-*.json'))
        case['request_artifact_count'] = len(requests)
        case['completed_response_count'] = len(usages)
        case['usage_complete_for_recorded_requests'] = len(requests) == len(usages)
        case['recorded_output_tokens'] = sum(read(p)['output_tokens'] for p in usages)
        if case['status'] == 'completed':
            assert len(requests) == len(usages) == case['calls'], f'Incomplete accounting: {number}/{name}'
            assert case['recorded_output_tokens'] == case['generated_tokens'], f'Token ledger mismatch: {number}/{name}'
    result['counts'] = {
        'passed': sum(c['passed'] is True for c in result['cases']),
        'failed': sum(c['passed'] is False for c in result['cases']),
        'error_or_unfinished': sum(c['passed'] is None for c in result['cases']),
    }

inspection['fresh_session_keys_distinct'] = {}
for case in inspection['rounds'][0]['cases']:
    name = case['case']
    paths = [PRIVATE / f'round-{number}' / name / 'request-0000.json' for number in [1, 2]]
    if all(p.exists() for p in paths):
        keys = [read(p).get('prompt_cache_key') for p in paths]
        assert all(keys) and keys[0] != keys[1], f'Session was reused: {name}'
        inspection['fresh_session_keys_distinct'][name] = True

inspection['freeze_manifest_sha256'] = digest(FROZEN / 'release.json')
inspection['frozen_plan_sha256'] = digest(FROZEN / 'validation-plan.json')
inspection['before_first_run'] = {
    'failed_session_or_catalog_checks': 2,
    'case_inference_requests_during_these_checks': 0,
    'note': 'Both failures occurred before Runs.start; no run, case attempt, or model generation was retried.',
}
inspection['attempt_policy'] = plan['attempt_policy']
inspection['execution'] = plan['execution']
inspection['two_success_gate'] = []
for first in inspection['rounds'][0]['cases']:
    matching = [c for r in inspection['rounds'] for c in r['cases'] if c['case'] == first['case']]
    successes = sum(c['passed'] is True and c.get('review', {}).get('disposition') == 'accepted' for c in matching)
    inspection['two_success_gate'].append({'case': first['case'], 'reviewed_successes': successes, 'met': successes == 2})
inspection['all_cases_passed_twice'] = all(c['passed'] is True for r in inspection['rounds'] for c in r['cases'])
inspection['limitations'] = [
    'Two attempts provide feasibility evidence, not proof of complete coverage or absence of flakiness.',
    'Public historical cases may have appeared in training data.',
    'The provider does not expose a fixed serving revision or deterministic sampling seed.',
    'Initial requests are compared exactly except for the fresh per-session prompt_cache_key.',
    'Infrastructure and provider errors are retained separately from failed graded repairs.',
    'Interrupted requests may have unreported usage; token totals include only recorded completed-response usage.',
    'Functional evaluation only; no speed or performance comparisons.',
]
write(OUT / 'results.json', inspection)
write(OUT / 'checksums.json', {str(p.relative_to(OUT)): digest(p) for p in sorted(OUT.rglob('*')) if p.is_file() and p.suffix in ['.py', '.json', '.patch', '.md'] and p.name != 'checksums.json'})
print(json.dumps({r['round']: r['counts'] for r in inspection['rounds']}))
