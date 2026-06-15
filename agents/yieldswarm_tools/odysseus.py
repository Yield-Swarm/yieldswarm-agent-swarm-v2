"""Odysseus integration helpers for YieldSwarm tools.

Odysseus can load tools either as native function tools or through MCP. This
adapter exposes both the schema constants and a registration helper that can be
called from Odysseus startup code when this package is vendored or installed.
"""

from __future__ import annotations

from typing import Any, Callable, Dict, MutableMapping

from .definitions import TOOL_DEFINITIONS, mcp_tool_schemas, openai_function_schemas
from .handlers import TOOL_HANDLERS
from .registry import BUILTIN_TOOL_DESCRIPTIONS, dispatch_tool


FUNCTION_TOOL_SCHEMAS = openai_function_schemas()
MCP_TOOL_SCHEMAS = mcp_tool_schemas()
TOOL_TAGS: Dict[str, tuple[str, ...]] = {
    definition.name: definition.tags for definition in TOOL_DEFINITIONS
}


def register_yieldswarm_tools(
    *,
    function_tool_schemas: Any | None = None,
    tool_handlers: MutableMapping[str, Callable[..., Any]] | None = None,
    tool_tags: MutableMapping[str, Any] | None = None,
    builtin_tool_descriptions: MutableMapping[str, str] | None = None,
) -> Dict[str, Any]:
    """Register YieldSwarm tools into Odysseus-style mutable registries.

    Parameters are optional so callers can register only the collections their
    Odysseus version exposes:

    - ``function_tool_schemas``: list or dict of OpenAI-compatible schemas.
    - ``tool_handlers``: map from tool name to callable handler.
    - ``tool_tags``: map from tool name to tags.
    - ``builtin_tool_descriptions``: map used by Odysseus tool indexing/RAG.
    """

    if function_tool_schemas is not None:
        _register_schemas(function_tool_schemas)

    if tool_handlers is not None:
        tool_handlers.update(TOOL_HANDLERS)

    if tool_tags is not None:
        tool_tags.update(TOOL_TAGS)

    if builtin_tool_descriptions is not None:
        builtin_tool_descriptions.update(BUILTIN_TOOL_DESCRIPTIONS)

    return {
        "registered_tools": [definition.name for definition in TOOL_DEFINITIONS],
        "mcp_server": "mcp_servers/yieldswarm_server.py",
    }


def _register_schemas(target: Any) -> None:
    if isinstance(target, list):
        existing_names = {
            schema.get("function", {}).get("name")
            for schema in target
            if isinstance(schema, dict)
        }
        target.extend(
            schema
            for schema in FUNCTION_TOOL_SCHEMAS
            if schema.get("function", {}).get("name") not in existing_names
        )
        return

    if isinstance(target, dict):
        for schema in FUNCTION_TOOL_SCHEMAS:
            function = schema["function"]
            target[function["name"]] = schema
        return

    raise TypeError("function_tool_schemas must be a list or dict")


def execute_yieldswarm_tool(name: str, arguments: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """Small wrapper used by Odysseus dispatchers that prefer a single callable."""

    return dispatch_tool(name, arguments or {})


__all__ = [
    "BUILTIN_TOOL_DESCRIPTIONS",
    "FUNCTION_TOOL_SCHEMAS",
    "MCP_TOOL_SCHEMAS",
    "TOOL_HANDLERS",
    "TOOL_TAGS",
    "execute_yieldswarm_tool",
    "register_yieldswarm_tools",
]
