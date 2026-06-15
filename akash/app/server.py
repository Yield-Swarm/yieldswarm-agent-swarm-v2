"""akash/app/server.py

Minimal YieldSwarm runtime entrypoint. The point of this file in the context
of the Vault integration is to *prove* the secret-injection contract works:

  * Secrets arrive only through environment variables sourced from
    /run/secrets/env by entrypoint.sh (rendered by vault-agent).
  * The app never reads from Vault directly and never opens /run/secrets/env
    itself.
  * /healthz reports which expected secrets are present so the deployment
    pipeline can verify injection without leaking values.

Extend this with the real agent orchestration once the secret contract is
green.
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Iterable

from fastapi import FastAPI

LOG = logging.getLogger("yieldswarm")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), stream=sys.stdout,
                    format="%(asctime)s %(levelname)s %(name)s %(message)s")

REQUIRED_SECRETS: tuple[str, ...] = (
    "AGENTSWARM_MASTER_KEY",
    "KIMICLAW_CONSENSUS_KEY",
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "WALLET_ENCRYPTION_KEY",
    "SOLANA_RPC_URL",
)

OPTIONAL_SECRETS: tuple[str, ...] = (
    "GROK_API_KEY",
    "GEMINI_API_KEY",
    "HELIUS_API_KEY",
    "BIRDEYE_API_KEY",
    "JUPITER_API_KEY",
    "ETHEREUM_RPC_URL",
    "TON_API_KEY",
    "NG64_BITTENSOR_NODE_STAKING_KEY",
    "GITHUB_TOKEN",
    "VERCEL_API_TOKEN",
    "TELEGRAM_BOT_TOKEN",
)


def _present(names: Iterable[str]) -> dict[str, bool]:
    return {n: bool(os.environ.get(n)) for n in names}


def _assert_required_present() -> None:
    missing = [n for n in REQUIRED_SECRETS if not os.environ.get(n)]
    if missing:
        LOG.error("required secrets missing from environment: %s", missing)
        raise SystemExit(
            f"required secrets missing: {missing}. "
            "vault-agent failed to render /run/secrets/env — check ACL on "
            "yieldswarm/runtime/* and confirm the AppRole secret_id was unwrapped."
        )
    LOG.info("all %d required secrets present", len(REQUIRED_SECRETS))


_assert_required_present()

app = FastAPI(title="YieldSwarm Agent Runtime", version="2.0.0")


@app.get("/healthz")
def healthz() -> dict[str, object]:
    """Liveness + readiness. Reports presence flags (never values)."""
    return {
        "status": "ok",
        "required": _present(REQUIRED_SECRETS),
        "optional": _present(OPTIONAL_SECRETS),
    }


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "yieldswarm-agent-runtime", "status": "ready"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "8080")),
        log_level=os.environ.get("LOG_LEVEL", "info").lower(),
    )
