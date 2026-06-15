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

## Frontend workspaces
- Arena: `frontend/arena/index.html` provides a unified telemetry dashboard for Akash workers and the Odysseus agent/memory system.
- Portal: `frontend/portal/index.html` embeds or links the Odysseus workspace for advanced agent interaction and deep research.
- Shared modules in `frontend/shared/` resolve runtime config, request a YieldSwarm session, create Odysseus SSO handoff URLs, and normalize telemetry feeds.

### Required backend contracts
- `GET ${AKASH_TELEMETRY_URL:-/api/telemetry/akash}` returns Akash worker, lease, deployment, or node metrics.
- `GET ${ODYSSEUS_TELEMETRY_URL:-/api/telemetry/odysseus}` returns Odysseus agents, research queue, and memory/vector metrics.
- `GET ${YIELDSWARM_AUTH_SESSION_URL:-/api/auth/session}` returns the current YieldSwarm session when a user is signed in.
- `POST ${YIELDSWARM_AUTH_HANDOFF_URL:-/api/auth/odysseus/handoff}` returns either `redirectUrl` or a short-lived `handoffToken`/`sessionId` accepted by Odysseus.

Set matching meta tags or `window.YIELDSWARM_CONFIG` values when these endpoints are hosted somewhere other than the same origin.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.