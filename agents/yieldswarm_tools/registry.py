"""YieldSwarm tool registry.

This module provides the stable API used by Odysseus adapters, MCP servers,
and local YieldSwarm agents.
"""

from __future__ import annotations

import json
from typing import Any, Dict, Mapping

from .definitions import (
    TOOL_DEFINITIONS,
    TOOL_DEFINITIONS_BY_NAME,
    ToolDefinition,
    mcp_tool_schemas,
    openai_function_schemas,
)
from .handlers import TOOL_HANDLERS, YieldSwarmToolError, execute_tool


def list_tools() -> tuple[ToolDefinition, ...]:
    """Return all YieldSwarm tool definitions."""

    return TOOL_DEFINITIONS


def get_tool(name: str) -> ToolDefinition:
    """Return a single YieldSwarm tool definition by name."""

    try:
        return TOOL_DEFINITIONS_BY_NAME[name]
    except KeyError as exc:
        raise YieldSwarmToolError(f"Unknown YieldSwarm tool: {name}") from exc


def dispatch_tool(name: str, arguments: Mapping[str, Any] | None = None) -> Dict[str, Any]:
    """Execute a YieldSwarm tool and return a JSON-serializable result."""

    try:
        return execute_tool(name, arguments or {})
    except YieldSwarmToolError as exc:
        return {"status": "error", "message": str(exc), "data": {"tool": name}}


def dispatch_tool_json(name: str, arguments: Mapping[str, Any] | None = None) -> str:
    """Execute a tool and return pretty JSON for agent text outputs."""

    return json.dumps(dispatch_tool(name, arguments), indent=2, sort_keys=True)


BUILTIN_TOOL_DESCRIPTIONS: Dict[str, str] = {
    definition.name: definition.description for definition in TOOL_DEFINITIONS
}


__all__ = [
    "BUILTIN_TOOL_DESCRIPTIONS",
    "TOOL_DEFINITIONS",
    "TOOL_HANDLERS",
    "YieldSwarmToolError",
    "dispatch_tool",
    "dispatch_tool_json",
    "get_tool",
    "list_tools",
    "mcp_tool_schemas",
    "openai_function_schemas",
]
