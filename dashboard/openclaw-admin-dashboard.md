# OpenClaw Local Admin Dashboard

## Features
- Real-time view of all Akash leases and mining activity
- Unified Arena telemetry from Akash workers plus Odysseus agents, research queue, and memory/vector index
- Portal launcher for embedded or linked Odysseus deep research workspace
- Shared YieldSwarm/Odysseus auth through short-lived SSO handoff tokens
- Shard harvesting cron status
- Marketing campaign performance
- Immunefi bug bounty dashboard
- Wallet connection status for all equipment
- Runic Language execution logs
- GEOD crons and geospatial data

## Local Instance
Run locally on user hardware or via cloud credits. Accessible via browser or Telegram.

## Arena + Portal Integration
- Serve `frontend/arena/index.html` as the Arena telemetry dashboard.
- Serve `frontend/portal/index.html` as the Portal entry point for Odysseus advanced agent interaction.
- Configure:
  - `AKASH_TELEMETRY_URL` for worker/lease/deployment metrics
  - `ODYSSEUS_TELEMETRY_URL` for agent, memory, vector, and research queue metrics
  - `YIELDSWARM_AUTH_SESSION_URL` for shared session lookup
  - `YIELDSWARM_AUTH_HANDOFF_URL` for Odysseus SSO token exchange
- If Odysseus is embedded, set Odysseus frame policy to allow the YieldSwarm Portal origin.

## Connected Equipment
- Bminer instances
- lolMiner instances
- SRBMiner-MULTI
- Current coins being mined (to be detected via pool/API)
- Payout wallet configuration