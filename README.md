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
3. Configure Odysseus ChromaDB memory for the shared agent mesh
4. Deploy to Vercel or Azure
5. Wire Unstoppable Domains via Cloudflare nameservers

## Odysseus Memory
Odysseus ChromaDB memory is the central long-term store for all 10,080 agents.
It stores agent mutations, performance history, Deity identities, and
cross-agent learnings.

Bootstrap identity memory:

```bash
python agents/bootstrap-deity-identities.py
```

Run peer sync on Akash or multi-cloud nodes:

```bash
python agents/odysseus-sync-service.py
```

See `ARCHITECTURE/odysseus-chromadb-memory.md` for the full memory and sync
contract.

## Business
Wise: cbrown03777@gmail.com
UD API Key included in .env.example

## Next
Fill .env on iPhone, push to GitHub, Vercel auto-deploys.