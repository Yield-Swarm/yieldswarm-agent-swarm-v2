# Cursor Cloud Instance God Prompts (v1.1)

Reusable copy-paste prompts for parallel Cursor Cloud agents. Each instance owns a solenoid layer; both must run `npm install --legacy-peer-deps` after code generation.

> **Security:** Never commit `SecretProd.pdf` or raw API keys. Load secrets from `process.env`, `.env` (local only), and HashiCorp Vault (`docs/VAULT_ENV_INJECTION.md`). Cloud agents should use Cursor-injected env vars + Vault MCP.

---

## Instance split

| Instance | Solenoid | Owns | Already in repo |
|----------|----------|------|-----------------|
| **1** | Solenoid 1 — Nexus Chain | Secrets, orchestration, multi-cloud, 521 agents | `backend/`, `deploy/`, `src/infrastructure/entropy-core.js`, `programs/swarm_ops/`, Vault scripts |
| **2** | Solenoid 2 Helix + Solenoid 3 Shadow | Treasury routing, ZK mutation, Arena, on-chain | `programs/cross_chain/`, `programs/shard_coordinator/`, `circuits/`, `src/app/arena/`, `packages/cross-chain-sdk/`, `app/dashboard/` |

---

## Prompt 1/2 — Nexus + Orchestration (Instance 1)

```markdown
You are building the full YieldSwarm system using the real secrets from Cursor's environment variables and HashiCorp Vault. Use all keys from SecretProd.pdf (QuickNode, Helius, Pinata, Resend, Grok, OpenAI, Gemini, etc.).

Create Solenoid 1 (Nexus Chain) as the central brain. It must:
- Pull all secrets from process.env and HashiCorp Vault
- Coordinate Helix and Shadow Chain
- Manage multi-cloud deployments (Azure, Akash, Vast.ai)
- Support 521 agents

After generating code, always run: npm install --legacy-peer-deps
```

**Start here in repo:** `backend/src/adapters/solenoid.js`, `deploy/deploy-full-stack.sh`, `programs/swarm_ops/`, `deploy/templates/`, `vault/`

---

## Prompt 2/2 — Helix + Shadow Chain (Instance 2)

```markdown
You are building Solenoid 2 (Helix/Reverberator) and Solenoid 3 (Shadow Chain) using the real secrets from Cursor's environment variables and HashiCorp Vault. Use all keys from SecretProd.pdf.

Focus on:
- Multi-chain treasury routing using all addresses from SecretProd.pdf
- ZK-Swarm Mutation for batched proofs
- Arena competition and reward system
- Full integration with swarm_ops and coordinator

After generating any code, always run: npm install --legacy-peer-deps
```

**Start here in repo:** `programs/cross_chain/`, `programs/shard_coordinator/`, `docs/TREASURY.md`, `circuits/entropy_proof.circom`, `src/app/arena/`, `app/dashboard/`

---

## Prompt 3/3 — Dashboard Frontend (optional third instance)

```markdown
ROLE: Lead Frontend Engineer — YieldSwarm Unified Dashboard

TASK: Build and wire the production dashboard inside `app/dashboard/` and `src/app/` using live on-chain + API data.

CONTEXT:
- Use `@yieldswarm/cross-chain-sdk` hooks: useYieldVault, useTreasuryBalances, useCrossChainBridge
- Solana Wallet Adapter for deposits/withdraw/claim
- Poll Kamino, Drift, JitoSOL for routing panel APY
- Surface Nexus Treasury + Mining Roots from docs/TREASURY.md
- Integrate /api/revenue/metrics and /api/arena/overview

REQUIREMENTS:
1. Wallet connect + live vault stats
2. Multi-chain treasury panel (Nexus + 7 Mining Roots)
3. Yield routing engine UI with optimal route highlight
4. Transaction panel with loading states and tx log
5. Mobile-friendly layout for Pixel Termux browser

After generating code, always run: npm install --legacy-peer-deps && npm run dashboard:build
```

---

## Termux — start local server now

```bash
cd ~/yieldswarm
git pull

# One-time setup
cp deploy/env/layered.env.example .env   # fill secrets from Vault / env
npm install --legacy-peer-deps
cd backend && npm install && cd ..
cd app/dashboard && npm install && cd ../..

# Sovereign + optimize (optional background)
START_SOVEREIGN=1 START_MONITOR=1 bash deploy/optimize-all.sh

# API + Next.js (two panes or sequential)
cd ~/yieldswarm/backend && npm run dev &          # :8080
cd ~/yieldswarm && npm run dev &                  # :3000 Next.js

# YieldSwarm dashboard (Vite)
cd ~/yieldswarm && npm run dashboard:dev          # :5174

# Quick health
curl -s http://127.0.0.1:8080/api/solenoid/status | head
curl -s http://127.0.0.1:3000/api/helix/status | head
python3 iteration-100/run.py --status
```

**Single-pane shortcut (Next.js only):**

```bash
cd ~/yieldswarm && npm install --legacy-peer-deps && npm run dev
```

---

## Post-generation checklist (both instances)

```bash
npm install --legacy-peer-deps
npm run build
npm run test:helix
anchor build                    # if touching programs/
npm run dashboard:build         # Instance 2 / dashboard
```
