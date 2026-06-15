# YieldSwarm AgentSwarm OS v2.0

## Overview
10,080 AI Agents across 120 Cron Jobs
Kimiclaw Consensus Council + SuperGrok Strategy Layer
Helix Chain + Hydrogen Particle Accelerated Shading Tree
$APN on Pump.fun
Unstoppable Domains integration

## Deployment
- Vercel: https://v2-0-bay.vercel.app/
- Project: https://vercel.com/support-6930s-projects/v2-0/c64SWNEkWaF39C4GcjFPYoLxWgMg

## Setup
1. Copy .env.example to .env
2. Fill in values securely
3. Deploy to Vercel or Azure
4. Wire Unstoppable Domains via Cloudflare nameservers

## Odysseus YieldSwarm Tools
YieldSwarm tool definitions live in `agents/yieldswarm_tools/` and cover:
- Akash lease management
- Treasury 50/30/15/5 rebalancing
- On-chain emission router queries
- Multi-chain wallet operations through the unified wallet SDK
- Real-time Akash worker telemetry

Odysseus can consume them as native function tools:

```python
from agents.yieldswarm_tools.odysseus import register_yieldswarm_tools

register_yieldswarm_tools(
    function_tool_schemas=FUNCTION_TOOL_SCHEMAS,
    tool_handlers=TOOL_HANDLERS,
    tool_tags=TOOL_TAGS,
    builtin_tool_descriptions=BUILTIN_TOOL_DESCRIPTIONS,
)
```

Or register the built-in MCP server:

```python
"yieldswarm": ("mcp_servers/yieldswarm_server.py", "Built-in: YieldSwarm")
```

Mutating operations default to `dry_run=true`. Configure the adapter endpoints and
wallet SDK module in `.env` before enabling live lease, wallet, or treasury actions.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.