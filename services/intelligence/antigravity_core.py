"""Sovereign agent handler — official Google Antigravity SDK (not the YieldSwarm fork).

Replaces the unmaintained ``YieldSwarm/antigravity-sdk-python`` community fork
with ``pip install google-antigravity`` — the supported runtime used by
Antigravity 2.0.

Requires ``GEMINI_API_KEY`` (Gemini API) or Vertex ADC (``ANTIGRAVITY_VERTEX=1``).
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)

YIELDSWARM_SYSTEM_INSTRUCTIONS = """\
You are the YieldSwarm Sovereign Agent — orchestrator for a 521-agent DeFi swarm.

Responsibilities:
- Manage multi-chain wallet streams (EVM, Solana, IoTeX, TON).
- Balance cluster compute loads across Azure VMSS GPU nodes (A100 / NC-series).
- Monitor Akash lease health, treasury splits (50/30/15/5), and Helix cross-chain harvest.
- Never execute destructive shell commands. Prefer read-only inspection before mutation.
- Report structured JSON when asked for health or status summaries.
"""

DEFAULT_GPU_HEALTH_PROMPT = (
    "Check the health of our Standard_NC24ads_A100_v4 GPU nodes on Azure VMSS. "
    "Summarize GPU utilization, any failed leases, and recommend one rebalance action."
)

DESTRUCTIVE_FRAGMENTS = (
    "rm -rf",
    "rm -fr",
    "mkfs.",
    "mkfs ",
    "dd if=",
    ":(){ :|:& };:",
    "shutdown -h",
    "reboot",
)


def is_antigravity_available() -> bool:
    try:
        import google.antigravity  # noqa: F401

        return True
    except ImportError:
        return False


def _command_line(args: dict[str, Any]) -> str:
    return str(args.get("CommandLine") or args.get("command") or args.get("cmd") or "")


def _is_destructive_command(args: dict[str, Any]) -> bool:
    cmd = _command_line(args).lower()
    return any(fragment in cmd for fragment in DESTRUCTIVE_FRAGMENTS)


def _default_ask_user_handler(call: Any) -> bool:
    """Deny shell unless ANTIGRAVITY_AUTO_APPROVE=1 (production VMSS default: deny)."""
    if os.getenv("ANTIGRAVITY_AUTO_APPROVE", "").strip() in ("1", "true", "yes"):
        logger.warning("auto-approved run_command: %s", getattr(call, "name", "run_command"))
        return True
    logger.info("run_command denied (set ANTIGRAVITY_AUTO_APPROVE=1 to allow): %s", call)
    return False


def build_yieldswarm_policies(handler: Any | None = None) -> list[Any]:
    """Declarative safety policies — deny destructive shell, ask before other commands."""
    from google.antigravity.hooks import policy

    ask = handler or _default_ask_user_handler
    policies: list[Any] = [
        policy.deny(
            "run_command",
            when=_is_destructive_command,
            name="yieldswarm-block-destructive",
        ),
        policy.allow("view_file"),
        policy.allow("list_directory"),
        policy.allow("search_files"),
        policy.ask_user("run_command", handler=ask, name="yieldswarm-confirm-shell"),
    ]
    return policies


@dataclass
class YieldSwarmAntigravityConfig:
    """Runtime configuration for the sovereign Antigravity agent."""

    system_instructions: str = YIELDSWARM_SYSTEM_INSTRUCTIONS
    workspaces: list[str] = field(default_factory=lambda: [os.getcwd()])
    use_vertex: bool = False
    gcp_project: str | None = None
    gcp_location: str | None = None
    api_key: str | None = None
    high_reasoning: bool = True
    auto_approve_shell: bool = False

    @classmethod
    def from_env(cls) -> YieldSwarmAntigravityConfig:
        workspaces_raw = os.getenv("ANTIGRAVITY_WORKSPACES", os.getcwd())
        workspaces = [w.strip() for w in workspaces_raw.split(":") if w.strip()]
        return cls(
            use_vertex=os.getenv("ANTIGRAVITY_VERTEX", "").strip() in ("1", "true", "yes"),
            gcp_project=os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCP_PROJECT"),
            gcp_location=os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"),
            api_key=os.getenv("GEMINI_API_KEY"),
            high_reasoning=os.getenv("ANTIGRAVITY_HIGH_REASONING", "1").strip()
            not in ("0", "false", "no"),
            auto_approve_shell=os.getenv("ANTIGRAVITY_AUTO_APPROVE", "").strip()
            in ("1", "true", "yes"),
            workspaces=workspaces or [os.getcwd()],
        )

    def build_local_config(self) -> Any:
        """Build ``LocalAgentConfig`` for the official SDK."""
        from google.antigravity import CapabilitiesConfig, LocalAgentConfig, ThinkingLevel
        from google.antigravity.types import GeminiAPIEndpoint, GeminiModelOptions, ModelTarget, VertexEndpoint

        handler = None
        if self.auto_approve_shell:
            handler = lambda call: True  # noqa: E731

        policies = build_yieldswarm_policies(handler)

        kwargs: dict[str, Any] = {
            "system_instructions": self.system_instructions,
            "capabilities": CapabilitiesConfig(),
            "policies": policies,
            "workspaces": self.workspaces,
        }

        if self.use_vertex:
            kwargs["vertex"] = True
            kwargs["project"] = self.gcp_project
            kwargs["location"] = self.gcp_location
            if self.high_reasoning:
                kwargs["models"] = [
                    ModelTarget(
                        endpoint=VertexEndpoint(
                            options=GeminiModelOptions(thinking_level=ThinkingLevel.HIGH)
                        )
                    )
                ]
        else:
            if self.api_key:
                kwargs["api_key"] = self.api_key
            if self.high_reasoning:
                kwargs["models"] = [
                    ModelTarget(
                        endpoint=GeminiAPIEndpoint(
                            options=GeminiModelOptions(thinking_level=ThinkingLevel.HIGH)
                        )
                    )
                ]

        return LocalAgentConfig(**kwargs)


class SovereignAntigravityHandler:
    """Production handler wrapping ``google.antigravity.Agent`` for YieldSwarm ops."""

    def __init__(self, config: YieldSwarmAntigravityConfig | None = None) -> None:
        if not is_antigravity_available():
            raise RuntimeError(
                "google-antigravity is not installed. Run: pip install google-antigravity"
            )
        self.config = config or YieldSwarmAntigravityConfig.from_env()
        self._local_config = self.config.build_local_config()

    def status(self) -> dict[str, Any]:
        return {
            "runtime": "google-antigravity",
            "sdk": "official",
            "vertex": self.config.use_vertex,
            "high_reasoning": self.config.high_reasoning,
            "workspaces": self.config.workspaces,
            "gemini_key_set": bool(self.config.api_key or os.getenv("GEMINI_API_KEY")),
        }

    async def run(self, prompt: str) -> str:
        from google.antigravity import Agent

        async with Agent(self._local_config) as agent:
            response = await agent.chat(prompt)
            return await response.text()

    async def run_stream(self, prompt: str) -> AsyncIterator[str]:
        from google.antigravity import Agent

        async with Agent(self._local_config) as agent:
            response = await agent.chat(prompt)
            async for token in response:
                yield token

    async def gpu_health_check(self) -> str:
        return await self.run(DEFAULT_GPU_HEALTH_PROMPT)


async def _cli_main() -> int:
    logging.basicConfig(level=logging.INFO, format="[antigravity] %(message)s")
    handler = SovereignAntigravityHandler()
    print("status:", handler.status(), flush=True)

    prompt = " ".join(sys.argv[1:]).strip() or DEFAULT_GPU_HEALTH_PROMPT
    print(f"\n--- prompt ---\n{prompt}\n--- stream ---\n", flush=True)

    async for token in handler.run_stream(prompt):
        sys.stdout.write(token)
        sys.stdout.flush()
    print("\n--- done ---", flush=True)
    return 0


def main() -> None:
    raise SystemExit(asyncio.run(_cli_main()))


if __name__ == "__main__":
    main()
