# Swarm Mainnet — Termux + Azure (No Paste Scripts)

Gemini's `cat << 'EOF'` paste approach breaks on Termux (shell mangling, ESM errors, wrong file casing). **Everything is now in the repo** — pull once, run npm scripts.

## Termux (phones 1–8)

```bash
termux-wake-lock
cd $HOME/yieldswarm-agent-swarm-v2

git fetch origin
git checkout cursor/open-metal-inference-93dd
git pull

# Clean rebuild after hard reset
npm run swarm:remediate

# Set unique node id per phone
export SWARM_NODE_ID=1

# Dry-run orchestrator
npm run run-all-onchain -- --dry-run

# Full mainnet matrix (mesh + RunPod + shadow chain)
npm run swarm:mainnet

# Full consensus audit (writes reports/consensus_run_*.md with real STATUS)
npm run swarm:consensus
```

## Azure (node 9+)

```bash
# After SSH into VM
export SWARM_NODE_ID=9
curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/cursor/open-metal-inference-93dd/scripts/azure/bootstrap-swarm-node.sh | bash
```

Or manually:

```bash
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2
git checkout cursor/open-metal-inference-93dd
export SWARM_NODE_ID=9
npm run swarm:remediate
npm run swarm:mainnet
```

## Do NOT use these (broken on Termux)

| Bad (Gemini paste) | Use instead |
|--------------------|-------------|
| `npx ts-node ./src/index.ts` | `npm run swarm:mainnet` |
| `cat << 'EOF' > ./src/meshDriver.ts` | Files in `scripts/swarm/lib/` |
| `./run-consensus-audit.sh` in repo root | `npm run swarm:consensus` |
| Base64 one-liners | `git pull` |

## Read latest report

```bash
cat "$(ls -t reports/consensus_run_*.md | head -1)"
```

## Env fallbacks (optional)

```bash
export RPC_URL="https://localhost:8545"
export RUNPOD_API_KEY=""          # mock mode when empty
export SWARM_TELEMETRY_URL="http://127.0.0.1:8080/api/great-delta/telemetry"
```

## Architecture

```
npm run swarm:mainnet
  ├── meshDriver.ts      (35-dim ingest, triangular/pentagonal layers)
  ├── runpodBridge.ts    (RunPod API or mock accelerator)
  ├── syncNetwork.ts     (telemetry broadcast)
  └── reports/           (consensus_run_*.md, shadow_chain_*.json)
```
