"""Report selection correctness; synthetic metadata only, no execution."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import report


class CampaignReportTest(unittest.TestCase):
    def test_reports_only_cases_selected_for_the_campaign(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in (".local/results/selected", "config", "scripts", "cases/unselected"):
                (root / name).mkdir(parents=True)
            (root / ".local/results/selected/campaign.json").write_text(json.dumps({"cases": ["selected-case"]}))
            (root / "config/candidates.json").write_text(json.dumps({"candidates": [{"id": "candidate"}]}))
            (root / "cases/unselected/case.json").write_text("{}")
            for name in ("benchmark.py", "grade_formatter.exs"):
                (root / "scripts" / name).write_text("fixture")
            with patch.object(report, "ROOT", root), \
                 patch("sys.argv", ["report.py", "--campaign", "selected", "--document", "selected.md"]), \
                 contextlib.redirect_stdout(io.StringIO()):
                report.main()
            text = (root / "results/reports/selected.md").read_text()
            self.assertIn("| selected-case | Not run |", text)
            self.assertNotIn("unselected", text)
            self.assertIn("Added coverage", text)


if __name__ == "__main__":
    unittest.main()
