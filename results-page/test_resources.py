"""Synthetic GPU attribution check; no hardware measurements."""
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
from model_resources import process_gpus


class ResourceTest(unittest.TestCase):
    def test_counts_only_engine_pid_and_resolves_physical_gpu_by_uuid(self):
        devices = [('gpu0', 'unrelated', '10000'), ('gpu2', '3090', '24576'), ('gpu5', '3090', '24576')]
        processes = [('gpu0', '555', '1000'), ('gpu5', '123', '21000'),
                     ('gpu2', '123', '22000'), ('gpu2', '555', '1000')]
        gpus = process_gpus(123, devices, processes)
        self.assertEqual(len(gpus), 2)
        self.assertEqual(sum(gpu['used_bytes'] for gpu in gpus), 43000 * 2**20)
        self.assertTrue(all(gpu['name'] == '3090' for gpu in gpus))
        self.assertEqual(process_gpus(999, devices, processes), [])
