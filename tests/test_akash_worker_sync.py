"""Tests for Akash worker sync into model router."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from services.akash_worker_sync import (
    _parse_env_file,
    _worker_urls_from_env,
    sync_workers_from_akash,
)


class AkashWorkerSyncTests(unittest.TestCase):
    def test_parse_lease_env(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env_path = Path(tmp) / "akash-lease.env"
            env_path.write_text(
                'AKASH_WORKER_URLS=https://worker-a.akash.network,https://worker-b.akash.network\n',
                encoding="utf-8",
            )
            values = _parse_env_file(env_path)
            self.assertIn("AKASH_WORKER_URLS", values)
            self.assertIn("worker-a", values["AKASH_WORKER_URLS"])

    @patch.dict(os.environ, {"AKASH_WORKER_URLS": "https://gpu-test.akash.network"}, clear=False)
    @patch("services.akash_worker_sync._probe_worker")
    def test_sync_builds_worker_states(self, mock_probe) -> None:
        mock_probe.return_value = {"live": True, "health_score": 0.95, "queue_depth": 1}
        with patch("services.akash_worker_sync.LEASE_ENV_PATH", Path("/nonexistent")):
            workers = sync_workers_from_akash(probe=True)
        self.assertEqual(len(workers), 1)
        self.assertEqual(workers[0].gpu_model, "RTX 3090")
        self.assertGreater(workers[0].health_score, 0.9)

    def test_worker_urls_from_json_env(self) -> None:
        payload = json.dumps([{"provider_uri": "https://x.akash.network"}])
        with patch.dict(os.environ, {"YIELDSWARM_AKASH_WORKERS": payload}, clear=False):
            with patch("services.akash_worker_sync.LEASE_ENV_PATH", Path("/nonexistent")):
                urls = _worker_urls_from_env()
        self.assertEqual(urls, ["https://x.akash.network"])


if __name__ == "__main__":
    unittest.main()
