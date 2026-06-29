"""Tests for encrypted swarm IDs (PoW / PoS / PoWUI)."""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class EncryptedSwarmIdTest(unittest.TestCase):
    def test_node_mint_roundtrip(self) -> None:
        script = """
import { mintPowId, mintPosId, mintPowUiId, resolveEncryptedId } from './lib/encrypted-swarm-id.mjs';
const p = mintPowId('worker-1');
const s = mintPosId('stake-1');
const u = mintPowUiId('ui-1');
console.log(JSON.stringify({
  pow: resolveEncryptedId(p).plaintext.id,
  pos: resolveEncryptedId(s).plaintext.id,
  powui: resolveEncryptedId(u).plaintext.id,
}));
"""
        out = subprocess.check_output(
            ["node", "--input-type=module", "-e", script],
            cwd=REPO,
            text=True,
        )
        data = json.loads(out.strip().splitlines()[-1])
        self.assertEqual(data["pow"], "worker-1")
        self.assertEqual(data["pos"], "stake-1")
        self.assertEqual(data["powui"], "ui-1")


if __name__ == "__main__":
    unittest.main()
