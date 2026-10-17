"""Synthetic memory attribution checks; never queries hardware."""
import unittest
from unittest.mock import patch
import memory_stream as memory


class MemoryStreamTest(unittest.TestCase):
    def test_multiple_service_processes_share_gpu_without_counting_other_work(self):
        result = memory.gpu_usage({10, 11}, [('b', '3090', '24576'), ('a', '3090', '24576')],
                                  [('b', '10', '100'), ('a', '10', '200'), ('a', '11', '30'), ('a', '99', '500')])
        self.assertEqual([(gpu['uuid'], gpu['used_bytes']) for gpu in result], [('a', 230 * 2**20), ('b', 100 * 2**20)])

    def test_unknown_allocation_is_not_silently_zero(self):
        with self.assertRaises(ValueError):
            memory.gpu_usage({10}, [('a', '3090', '24576')], [('a', '10', '[N/A]')])

    def test_listener_excludes_tailscale_forwarding_and_rejects_ambiguity(self):
        rows = 'LISTEN 0 2048 127.0.0.1:8414 0.0.0.0:* users:(("python3",pid=3849,fd=11))\nLISTEN 0 4096 100.70.151.84:8414 0.0.0.0:* users:(("tailscaled",pid=1881,fd=27))'
        with patch.object(memory, 'command', return_value=rows):
            self.assertEqual(memory.listener(8414), 3849)
        with patch.object(memory, 'command', return_value=rows + '\nLISTEN 0 2048 0.0.0.0:8414 0.0.0.0:* users:(("python3",pid=111,fd=11))'):
            with self.assertRaises(ValueError):
                memory.listener(8414)


if __name__ == '__main__':
    unittest.main()
