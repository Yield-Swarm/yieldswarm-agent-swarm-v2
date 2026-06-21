import json
import os
import tempfile
import unittest
from pathlib import Path

from services.helix.deploy_ledger import append_entry, sign_payload, verify_receipt


class DeployLedgerTests(unittest.TestCase):
    def setUp(self):
        os.environ["HELIX_LEDGER_HMAC_KEY"] = "test-ledger-key"

    def test_sign_and_verify_receipt(self):
        payload = {
            "runId": "BLOCKCHAIN-IPFS-DEPLOY-001",
            "domain": "yieldswarm.blockchain",
            "event": "ipfs_upload_complete",
            "cidV0": "QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz",
            "recordedAt": "2026-05-22T00:00:00Z",
        }
        receipt = sign_payload(payload)
        self.assertTrue(verify_receipt(receipt, payload))

    def test_append_entry_writes_jsonl(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ledger.jsonl"
            row = append_entry(
                "ipfs_upload_complete",
                run_id="BLOCKCHAIN-IPFS-DEPLOY-001",
                domain="yieldswarm.blockchain",
                cid_v0="QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz",
                ledger_path=path,
            )
            self.assertIn("helixHmac", row)
            lines = path.read_text(encoding="utf-8").strip().splitlines()
            self.assertEqual(len(lines), 1)
            parsed = json.loads(lines[0])
            self.assertEqual(parsed["domain"], "yieldswarm.blockchain")


if __name__ == "__main__":
    unittest.main()
