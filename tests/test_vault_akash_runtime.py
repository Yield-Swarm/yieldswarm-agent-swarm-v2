"""Tests for Vault secret loading and Akash bootstrap helpers."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

REPO_ROOT = Path(__file__).resolve().parents[1]


class TestVaultSecrets(unittest.TestCase):
    def test_approle_login_unwraps_secret_id(self):
        from lib.secrets import _approle_login, _unwrap_secret_id

        with patch("lib.secrets._unwrap_secret_id", return_value="plain-secret") as unwrap:
            with patch.dict(os.environ, {
                "VAULT_ADDR": "https://vault.test:8200",
                "VAULT_ROLE_ID": "role-abc",
                "VAULT_WRAPPED_SECRET_ID": "wrap-token",
            }, clear=False):
                os.environ.pop("VAULT_SECRET_ID", None)
                with patch("hvac.Client") as client_cls:
                    instance = client_cls.return_value
                    instance.auth.approle.login.return_value = {"auth": {"client_token": "tok"}}
                    token = _approle_login()
                    self.assertEqual(token, "tok")
                    unwrap.assert_called_once_with("wrap-token")
                    self.assertEqual(os.environ.get("VAULT_SECRET_ID"), "plain-secret")

    def test_unwrap_returns_none_without_hvac(self):
        from lib.secrets import _unwrap_secret_id

        with patch.dict(os.environ, {"VAULT_ADDR": "https://vault.test:8200"}):
            with patch("builtins.__import__", side_effect=lambda name, *a, **k: (_ for _ in ()).throw(ImportError())):
                self.assertIsNone(_unwrap_secret_id("wrap"))


class TestVaultAkashBootstrap(unittest.TestCase):
    def test_runtime_env_canonical_sections_follow_legacy(self):
        """Later sections win when sourced — legacy must render before canonical."""
        template = (REPO_ROOT / "akash/templates/runtime.env.ctmpl").read_text(encoding="utf-8")
        self.assertLess(
            template.index("# --- Legacy akash/runtime bundle"),
            template.index("# --- Runtime core (canonical)"),
        )
        self.assertLess(
            template.index('yieldswarm/data/llm/openai'),
            template.index('yieldswarm/data/runtime/llm'),
        )
        self.assertLess(
            template.index('yieldswarm/data/rpc/helius'),
            template.index('yieldswarm/data/rpc/solana'),
        )

    def test_sdl_needs_runtime_secrets_detects_placeholders(self):
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fh:
            fh.write("env:\n  - VAULT_WRAPPED_SECRET_ID\n  - AGENT_SHARD_ID\n")
            path = fh.name
        try:
            result = os.popen(
                f'bash -c \'source "{REPO_ROOT}/scripts/lib/vault-akash-bootstrap.sh" && vault_sdl_needs_runtime_secrets "{path}" && echo yes || echo no\''
            ).read().strip()
            self.assertEqual(result, "yes")
        finally:
            os.unlink(path)

    def test_sdl_without_vault_returns_false(self):
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fh:
            fh.write("env:\n  - WORKER_PORT=8080\n")
            path = fh.name
        try:
            result = os.popen(
                f'bash -c \'source "{REPO_ROOT}/scripts/lib/vault-akash-bootstrap.sh" && vault_sdl_needs_runtime_secrets "{path}" && echo yes || echo no\''
            ).read().strip()
            self.assertEqual(result, "no")
        finally:
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
