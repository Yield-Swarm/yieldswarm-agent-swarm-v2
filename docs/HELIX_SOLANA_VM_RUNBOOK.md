# Helix Solana — VM / Cloud Shell Runbook

## Fix: "No such file or directory" errors

Commands must run **inside the repo**, not from `/home/chris`:

```bash
cd ~/yieldswarm-agent-swarm-v2
pwd    # must end with yieldswarm-agent-swarm-v2
ls -la package.json Anchor.toml programs/ backend/
```

## Quick health (run from repo root)

```bash
git branch --show-current
git status --short | head -10
npm install --legacy-peer-deps
./scripts/helix-solana-smoke.sh
```

## Solana programs — already implemented

God Prompts 5 & 6 are **done** in this repo (production-grade, not placeholders):

| Instruction | Program | File |
|-------------|---------|------|
| `initialize_treasury` | cross_chain | `programs/cross_chain/src/lib.rs` |
| `trigger_remote_harvest` | cross_chain | CPI → swarm_ops |
| `receive_cross_chain_yield` | cross_chain | Ed25519 verified |
| `register_mining_root` | cross_chain | IoTeX / multi-chain roots |
| `register_agent` | swarm_ops | 521-agent registry |
| `authorize_harvest` | swarm_ops | Daily limits + permissions |

Program IDs (in `Anchor.toml`):

```
cross_chain  = 9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt
swarm_ops    = 6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz
coordinator  = DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p
arena        = F1cnaQtFrqyp6x4oejdqMULsvejcznkJryXd6SbVSmp3
```

## TypeScript hooks

```
integrations/solana/useCrossChainYield.ts  → sdk/helix HelixClient
integrations/solana/useSwarmAgent.ts       → /api/nexus/agents/register
integrations/solana/useYieldVault.ts       → sovereign + helix treasury
```

## Build & deploy (devnet)

```bash
cd ~/yieldswarm-agent-swarm-v2
anchor build
anchor deploy --provider.cluster devnet
```

## Start local dev

```bash
# Terminal 1 — backend
cd backend && npm install && npm start

# Terminal 2 — frontend (optional)
cd frontend && npm install && npm run dev
```

## Production path

```bash
./scripts/deploy-to-akash.sh deploy
# or
./scripts/run-solenoids-production.sh
```

## Cloud Shell note

Azure Cloud Shell is **ephemeral**. Use a persistent VM (`yieldswarm@4.147.152.142`) or Codespace for real deploys.

## Single recommended next command

```bash
cd ~/yieldswarm-agent-swarm-v2 && ./scripts/helix-solana-smoke.sh
```

If all pass, run first devnet harvest test:

```bash
anchor test -p cross_chain
```
