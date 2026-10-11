"""Bounded controller checks using fake endpoints/sandboxes; no inference."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import benchmark


class ContextPolicyTest(unittest.TestCase):
    def test_smaller_server_is_rejected_before_generation(self):
        metadata = [{'data': [{'id': 'model'}]}, {'model_alias': 'model',
                    'default_generation_settings': {'n_ctx': 65536}}]
        with patch.object(benchmark, 'request', side_effect=metadata):
            with self.assertRaisesRegex(RuntimeError, 'below the shared 262144'):
                benchmark.endpoint_metadata({'model': 'model'}, '')

    def test_usage_must_include_reasoning_and_match_preflight_and_cap(self):
        response = {'usage': {'prompt_tokens': 100, 'completion_tokens': 32,
                             'completion_tokens_details': {'reasoning_tokens': 30}}}
        self.assertEqual(benchmark.check_usage(response, 100, 32), 32)
        for count, allowance in [(99, 32), (100, 31)]:
            with self.assertRaises(RuntimeError):
                benchmark.check_usage(response, count, allowance)
        response['usage']['completion_tokens_details']['reasoning_tokens'] = 33
        with self.assertRaises(RuntimeError):
            benchmark.check_usage(response, 100, 32)

    def test_owned_strata_count_requires_exact_rejection(self):
        candidate = {'token_counter': 'strata_owned_overflow_v1'}
        detail = {'error': {'type': 'invalid_request_error', 'message':
                  'prompt (123 tokens) + max tokens (262145) exceeds the context (262144)'}}
        with patch.object(benchmark, 'request', side_effect=RuntimeError('Endpoint HTTP 400: ' + json.dumps(detail))):
            self.assertEqual(benchmark.input_tokens(candidate, '', {}, 262144), 123)
        with patch.object(benchmark, 'request', return_value={'choices': []}):
            with self.assertRaisesRegex(RuntimeError, 'generated unexpectedly'):
                benchmark.input_tokens(candidate, '', {}, 262144)
        with patch.object(benchmark, 'request', side_effect=RuntimeError('Endpoint HTTP 401: unauthorized')):
            with self.assertRaisesRegex(RuntimeError, 'Unexpected Strata'):
                benchmark.input_tokens(candidate, '', {}, 262144)

    def test_context_exhaustion_grades_current_patch_without_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            local = root / '.local'
            case_dir = root / 'cases/fixture'
            case_dir.mkdir(parents=True)
            (case_dir / 'ticket.md').write_text('Fix the symptom')
            benchmark.write_json(root / 'config/candidates.json', {'candidates': [
                {'id': 'model', 'model': 'model', 'reasoning_effort': 'xhigh'}]})
            benchmark.write_json(local / 'runtimes/fixture.json', {})
            benchmark.write_json(local / 'controls/fixture.json', {'valid': True, 'runtime': {},
                'harness_sha256': 'hash', 'formatter_sha256': 'hash', 'reference_patch': {}})
            spec = {'allowed_edit_prefixes': ['lib/', 'test/'], 'regression_command': 'mix test'}
            policy = {'window_tokens': 262144, 'response_tokens': 8192, 'safety_tokens': 8, 'compaction': False}

            class Box:
                def __init__(self, _): self.runtime = {}
                def __enter__(self): return self
                def __exit__(self, *_): pass
                def patch(self): return 'saved patch'

            with patch.object(benchmark, 'ROOT', root), patch.object(benchmark, 'LOCAL', local), \
                 patch.object(benchmark, 'guard', return_value={}), patch.object(benchmark, 'sha', return_value='hash'), \
                 patch.object(benchmark, 'case_data', return_value=(case_dir, spec)), \
                 patch.object(benchmark, 'context_policy', return_value=policy), \
                 patch.object(benchmark, 'endpoint_metadata', return_value={'props': {'default_generation_settings': {'n_ctx': 262144}}}), \
                 patch.object(benchmark, 'input_tokens', return_value=255000), \
                 patch.object(benchmark, 'request') as request, patch.object(benchmark, 'Sandbox', Box), \
                 patch.object(benchmark, 'grade', return_value={'passed': True}) as grade:
                result = benchmark.run_agent('fixture', 'model', local / 'attempt', 101, 32, 65536)
            request.assert_not_called()
            grade.assert_called_once_with('fixture', 'saved patch', expected={})
            self.assertEqual((result['status'], result['stop_reason'], result['calls']), ('completed', 'context_budget', 0))


class ExecutionHostTest(unittest.TestCase):
    def test_shared_workstation_cannot_opt_in(self):
        with patch.object(benchmark.socket, 'gethostname', return_value='CrosshairA16'):
            with self.assertRaisesRegex(RuntimeError, 'prohibited'):
                benchmark.guard(initialize=True)

    def test_fresh_clone_initializes_once_and_binds_execution_host(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(benchmark, 'LOCAL', Path(tmp)), \
             patch.object(benchmark.shutil, 'which', return_value=None), \
             patch.object(benchmark.socket, 'gethostname', return_value='dedicated-runner'):
            with self.assertRaisesRegex(RuntimeError, 'Missing'):
                benchmark.guard()
            self.assertEqual(benchmark.guard(initialize=True), {'host': 'dedicated-runner'})
            self.assertEqual(benchmark.guard(), {'host': 'dedicated-runner'})
            with patch.object(benchmark.socket, 'gethostname', return_value='other-runner'):
                with self.assertRaisesRegex(RuntimeError, 'changed'):
                    benchmark.guard(initialize=True)


if __name__ == '__main__':
    unittest.main()
