"""Audit and export two explicitly selected fresh attempts; no model or network calls."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
PRIVATE = ROOT / '.local/astra-confirmation-2026-10-15'
PREVIOUS_PRIVATE = ROOT / '.local/astra-retry-2026-10-15'
PREVIOUS = ROOT / 'verification/astra-retry-2026-10-15'
ORIGINAL = ROOT / '.local/astra-validation-2026-10-15'
FROZEN = ROOT / 'verification/frozen-cases-2026-10-15'
PRIOR = ROOT / 'verification/astra-validation-2026-10-15'
EXPECTED = ['plausible-pr-6763', 'plausible-pr-6441']


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def normalize(value, key=None):
    if isinstance(value, dict):
        return {k: normalize(v, k) for k, v in value.items() if k != 'output'}
    if isinstance(value, list):
        if key in {'detected_tests', 'submitted_test_files', 'auxiliary_files'}:
            return sorted(value)
        return [normalize(v) for v in value]
    return value


def without_session(body):
    return {k: v for k, v in body.items() if k != 'prompt_cache_key'}


plan = read(FROZEN / 'validation-plan.json')
evidence = read(FROZEN / 'evidence.json')
controls = read(FROZEN / 'qualification-outcomes.json')
prior = read(PRIOR / 'results.json')
previous = read(PREVIOUS / 'results.json')
source = read(PREVIOUS_PRIVATE / 'run/run.json')
run_dir = PRIVATE / 'run'
run = read(run_dir / 'run.json')
selection = run['selection']
assert run['status'] in ['completed', 'error', 'interrupted', 'cancelled']
assert run['cleanup_pending'] is False and not run.get('resume_count')
assert run['cases'] == selection['cases'] == EXPECTED
assert run['id'] != source['id'] and selection['source_run'] == source['id']
assert selection['kind'] == 'case_repeat'
assert selection['source_release'] == source['release_id'] == previous['execution_release']
assert selection['source_run_hash'] == sha(PREVIOUS_PRIVATE / 'run/run.json')
assert run['settings'] == source['settings'] == plan['settings']
assert run['model'] == source['model'] and run['model']['model'] == plan['model']
assert run['experiment_id'] != source['experiment_id']
assert run['score']['score_percent'] is None, 'A retry must not masquerade as a full score'
assert all(source['attempts'][c]['grade']['passed'] for c in EXPECTED)
assert {k: v for k, v in run['protocol'].items() if k != 'implementation'} == {
    k: v for k, v in source['protocol'].items() if k != 'implementation'}

# Verify the old controller records and the committed public report remain untouched.
manifest = read(PRIVATE / 'original-manifest.json')
for number in [1, 2]:
    original_dir = ORIGINAL / f'round-{number}'
    expected = {str(p.relative_to(original_dir)): sha(p) for p in original_dir.rglob('*') if p.is_file()}
    assert manifest[str(number)] == expected, f'Original round {number} changed'
previous_dir = PREVIOUS_PRIVATE / 'run'
assert manifest['retry'] == {str(p.relative_to(previous_dir)): sha(p) for p in previous_dir.rglob('*') if p.is_file()}, 'Previous retry artifacts changed'
for package in [PRIOR, PREVIOUS]:
    for name, digest in read(package / 'checksums.json').items():
        assert sha(package / name) == digest, f'Original public artifact changed: {package.name}/{name}'

changes = []
for name, before in evidence['implementation_files'].items():
    after = sha(ROOT / name)
    if before != after:
        changes.append({'path': name, 'before': before, 'after': after})
assert {c['path'] for c in changes} == {
    'lib/eab/runs.ex', 'lib/eab/release.ex', 'lib/eab/checkpoints.ex',
    'lib/eab/runner.ex', 'lib/eab/report.ex', 'lib/eab_web/dashboard_live.ex'}
current_impl = ''.join(name + sha(ROOT / name) for name in sorted(evidence['implementation_files']))
assert hashlib.sha256(current_impl.encode()).hexdigest() == run['protocol']['implementation']

receipts = read(PRIVATE / 'completions.json')
assert receipts['run_id'] == run['id'] and receipts['status'] == run['status']
assert receipts['cleanup_pending'] is False
reviews = read(PRIVATE / 'reviews.json')
cases = []
for name in EXPECTED:
    d = run_dir / name
    attempt = read(d / 'attempt.json')
    frozen = read(FROZEN / 'inputs' / f'{name}.json')
    reference = next(c for c in evidence['cases'] if c['case'] == name)
    request = read(d / 'request-0000.json')
    runtime = read(d / 'runtime.json')
    qualification = read(d / 'qualification.json')
    checks = {
        'prompt': (d / 'prompt.md').read_text() == frozen['prompt'],
        'instructions': (d / 'instructions.md').read_text() == frozen['instructions'],
        'pi': attempt['agent'] == frozen['pi'],
        'agent_image': attempt['agent_image'] == frozen['agent_image'],
        'settings': attempt['settings'] == plan['settings'],
        'initial_request_except_cache_key': without_session(request) == without_session(frozen['initial_request']),
        'runtime': all(runtime.get(k) == v for k, v in reference['qualification_identity']['runtime'].items()),
        'qualification': qualification['valid'] and qualification['identity'] == reference['qualification_identity'],
        'qualification_outcomes': normalize(qualification) == controls[name],
    }
    assert all(checks.values()), (name, checks)
    keys = [request['prompt_cache_key']] + [read(ORIGINAL / f'round-{n}' / name / 'request-0000.json')['prompt_cache_key'] for n in [1, 2]]
    keys.append(read(PREVIOUS_PRIVATE / 'run' / name / 'request-0000.json')['prompt_cache_key'])
    assert all(keys) and len(set(keys)) == 4, 'Session must be fresh'
    patches = OUT / 'patches'
    patches.mkdir(exist_ok=True)
    (patches / f'{name}.patch').write_bytes((d / 'model.patch').read_bytes())
    row = {
        'case': name, 'status': attempt['status'], 'passed': attempt.get('grade', {}).get('passed'),
        'calls': attempt.get('calls'), 'generated_tokens': attempt.get('generated_tokens'),
        'stop_reason': attempt.get('stop_reason'), 'error': attempt.get('error'),
        'patch': f'patches/{name}.patch', 'patch_sha256': sha(d / 'model.patch'),
        'initial_request_sha256': sha(d / 'request-0000.json'),
        'frozen_input_checks': checks, 'fresh_session_key': True,
    }
    usages = sorted(d.glob('usage-*.json'))
    requests = sorted(d.glob('request-*.json'))
    row.update(request_artifact_count=len(requests), completed_response_count=len(usages),
               recorded_output_tokens=sum(read(p)['output_tokens'] for p in usages),
               usage_complete_for_recorded_requests=len(requests) == len(usages))
    if attempt['status'] == 'completed':
        assert len(requests) == len(usages) == attempt['calls']
        assert row['recorded_output_tokens'] == attempt['generated_tokens']
        grade = read(d / 'grade.json')
        assert grade['passed'] == row['passed']
        row.update(grade=normalize(grade), grade_sha256=sha(d / 'grade.json'))
        receipt = next(c for c in receipts['completions'] if c['case'] == name)
        assert receipt['verified_completion'] and receipt['passed'] == row['passed']
        # Controller verifies sealed receipts; exported hashes retain their original identity.
        row['controller_verified_receipts'] = True
        row['completion_receipt_sha256'] = sha(run_dir / 'checkpoints' / f'{name}.json')
        row['submission_receipt_sha256'] = sha(d / 'submission.json')
    if (d / 'provider-error.json').exists():
        error = read(d / 'provider-error.json')
        row['provider_error'] = {k: error.get(k) for k in ['status', 'code', 'param', 'message']}
        row['provider_error_sha256'] = sha(d / 'provider-error.json')
    review = reviews[name]
    assert review['patch_sha256'] == row['patch_sha256']
    if row['passed']:
        assert review['disposition'] == 'accepted'
    row['review'] = review
    cases.append(row)

counts = {'passed': sum(c['passed'] is True for c in cases),
          'failed': sum(c['passed'] is False for c in cases),
          'error_or_unfinished': sum(c['passed'] is None for c in cases)}
gate = []
for old in previous['two_success_gate_cumulative']:
    extra = sum(c['case'] == old['case'] and c['passed'] is True and c['review']['disposition'] == 'accepted' for c in cases)
    successes = old['reviewed_successes'] + extra
    gate.append({'case': old['case'], 'reviewed_successes': successes, 'met': successes >= 2})
all_cases = []
records = [(r['run_id'], c) for r in prior['rounds'] for c in r['cases']]
records += [(previous['run_id'], c) for c in previous['cases']]
records += [(run['id'], c) for c in cases]
for entry in gate:
    attempts = [{'run_id': run_id, 'status': c['status'], 'passed': c['passed']}
                for run_id, c in records if c['case'] == entry['case']]
    successes = sum(a['passed'] is True for a in attempts)
    assert successes == entry['reviewed_successes']
    all_cases.append({**entry, 'failed_repairs': sum(a['passed'] is False for a in attempts),
                      'infrastructure_interruptions': sum(a['passed'] is None for a in attempts),
                      'attempts': attempts})
previous_hashes = {c['path']: c['after'] for c in previous['implementation_changes']}
delta = [{'path': c['path'], 'before': previous_hashes.get(c['path'], c['before']), 'after': c['after']}
         for c in changes if previous_hashes.get(c['path'], c['before']) != c['after']]
result = {
    'run_id': run['id'], 'started_at': run['created_at'], 'status': run['status'],
    'source_run': source['id'], 'selection': selection, 'cases': cases, 'counts': counts,
    'source_release': source['release_id'], 'execution_release': run['release_id'],
    'frozen_release': evidence['release'],
    'implementation_changes': changes, 'implementation_changes_since_source': delta, 'implementation_commit': '508020c',
    'controller_image': (PRIVATE / 'controller-image.txt').read_text().strip(),
    'model': plan['model'], 'provider': plan['provider'], 'settings': plan['settings'],
    'same_model_account_and_settings': True, 'execution': plan['execution'],
    'original_runs_unchanged': True, 'original_public_report_unchanged': True, 'previous_retry_unchanged': True,
    'full_benchmark_score': None, 'two_success_gate_cumulative': gate, 'all_cases_summary': all_cases,
    'case_quality_concerns': [{'case': 'plausible-pr-6763', 'recommendation': 'hold_for_csv_schema_clarification',
                             'note': 'case-quality-note.md', 'baseline_source_receipt': 'baseline-source-checksums.json'}],
    'attempt_policy': 'One fresh attempt each for Plausible 6763 and 6441; no automatic retries or additional attempts.',
    'limitations': prior['limitations'],
}
write(OUT / 'release.json', read(run_dir / 'release.json'))
write(OUT / 'results.json', result)
write(OUT / 'checksums.json', {str(p.relative_to(OUT)): sha(p) for p in sorted(OUT.rglob('*'))
      if p.is_file() and p.suffix in ['.py', '.json', '.patch', '.md'] and p.name != 'checksums.json'})
print(json.dumps({'run_id': run['id'], 'counts': counts, 'two_success_gate_met': sum(g['met'] for g in gate)}))
