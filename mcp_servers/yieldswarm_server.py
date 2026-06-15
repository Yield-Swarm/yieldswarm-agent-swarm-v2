"""MCP server exposing YieldSwarm tools to Odysseus agents.

Odysseus can register this file as a built-in MCP server with a mapping like:

    "yieldswarm": ("mcp_servers/yieldswarm_server.py", "Built-in: YieldSwarm")

When the MCP Python SDK is available this module runs as a standard stdio MCP
server. A small newline-delimited JSON fallback is included for local smoke
testing in environments that have not installed the SDK yet.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Any, Dict


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from agents.yieldswarm_tools.registry import dispatch_tool, dispatch_tool_json, mcp_tool_schemas


try:  # pragma: no cover - exercised in Odysseus environments with MCP installed.
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import TextContent, Tool
except ImportError:  # pragma: no cover - local fallback below.
    Server = None
    TextContent = None
    Tool = None
    stdio_server = None


if Server is not None:
    server = Server("yieldswarm")

    @server.list_tools()
    async def list_mcp_tools() -> list[Any]:
        return [
            Tool(
                name=schema["name"],
                description=schema["description"],
                inputSchema=schema["inputSchema"],
            )
            for schema in mcp_tool_schemas()
        ]

    @server.call_tool()
    async def call_mcp_tool(name: str, arguments: Dict[str, Any] | None = None) -> list[Any]:
        return [
            TextContent(
                type="text",
                text=dispatch_tool_json(name, arguments or {}),
            )
        ]


async def run_mcp() -> None:
    if Server is None or stdio_server is None:
        raise RuntimeError("The mcp Python package is not installed.")

    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


def run_json_lines_fallback() -> None:
    """Minimal local fallback for smoke testing without the MCP SDK.

    Supported requests:
    - {"method": "tools/list"}
    - {"method": "tools/call", "params": {"name": "...", "arguments": {...}}}
    """

    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            method = request.get("method")
            if method == "tools/list":
                response = {"tools": mcp_tool_schemas()}
            elif method == "tools/call":
                params = request.get("params") or {}
                response = dispatch_tool(params.get("name"), params.get("arguments") or {})
            else:
                response = {"status": "error", "message": f"Unsupported method: {method}"}
        except Exception as exc:  # Keep the fallback robust for operator terminals.
            response = {"status": "error", "message": str(exc)}
        print(json.dumps(response), flush=True)


if __name__ == "__main__":
    if Server is None:
        run_json_lines_fallback()
    else:
        asyncio.run(run_mcp())
