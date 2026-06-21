"""Autonomous agent deployment — OAuth2 + Vault AppRole hybrid."""

from __future__ import annotations

import os
from typing import Any, Dict


def agent_deploy_auth_summary() -> Dict[str, Any]:
    """Report deployment auth mode for operators."""
    vault = bool(os.environ.get("VAULT_ADDR"))
    role = bool(os.environ.get("VAULT_ROLE_ID"))
    oidc = bool(os.environ.get("VAULT_OIDC_CLIENT_ID"))
    tesla_oauth = bool(os.environ.get("TESLA_CLIENT_ID"))
    mode = os.environ.get("AGENT_DEPLOY_AUTH_MODE", "vault-approle")

    return {
        "mode": mode,
        "vault_configured": vault,
        "approle_configured": role,
        "oidc_available": oidc,
        "tesla_oauth_configured": tesla_oauth,
        "oauth2_ready": oidc or tesla_oauth,
        "production_pattern": "vault-approle-with-optional-oidc",
        "akash_inject": ["VAULT_ROLE_ID", "VAULT_WRAPPED_SECRET_ID"],
    }
