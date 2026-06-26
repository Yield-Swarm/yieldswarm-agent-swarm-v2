# Termux + Akash + Own Hardware Deploy

Optimized replacement for the legacy Poseidon v4.0 manifest. **Does not** patch `node_modules`, overwrite `next.config.mjs`, or require `next build` on Android.

## One-shot on Termux (copy-paste)

```bash
cd $HOME/yieldswarm-agent-swarm-v2

# Sync repo (SSH)
git remote set-url origin git@github.com:Yield-Swarm/yieldswarm-agent-swarm-v2.git
git fetch origin && git checkout main && git pull origin main

# Env + wallets
mkdir -p deploy/env reports
cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
# nano deploy/env/trident-mainnet.env  # WALLET_LTC, AKASH_KEY_NAME, etc.

# Deploy edge stack (backend :8080 + optional mining + consensus)
chmod +x scripts/termux/*.sh scripts/mining/tandem-pow-launch.sh
npm run termux:deploy
```

## Role split

| Layer | Where | Command |
|-------|-------|---------|
| Integration API | Termux / own hardware | `npm run termux:backend` or `npm run termux:deploy` |
| Mining (xmrig) | Lucky Miner / phone (CPU) | `MINING_DRY_RUN=0 npm run mining:tandem` |
| Akash GPU workers | Cloud SDL | `AKASH_KEY_NAME=... npm run akash:backend` |
| Next.js dashboard | proot Ubuntu / HP / desktop | `npm run termux:dev` |
| Consensus audit | Any host | `npm run termux:consensus` |

## Environment

Copy `deploy/env/trident-mainnet.env.example` → `deploy/env/trident-mainnet.env`.

Key variables:

- `POSEIDON_MODE` — `edge` (default), `full`, `akash`, `all`
- `MINING_DRY_RUN=0` — enable xmrig (set `WALLET_LTC` etc. first)
- `AKASH_KEY_NAME` — enables Akash SDL deploy in `all` / `akash` modes
- `PORT=8080` — backend listen port

## Verify

```bash
curl -s http://127.0.0.1:8080/api/health | jq
curl -s http://127.0.0.1:8080/api/trident/marketplace-bridge | jq
curl -s http://127.0.0.1:8080/api/arena/overview | jq
ls -la reports/consensus_run_*.md
```

## proot Ubuntu (full Next.js)

```bash
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
# inside Ubuntu:
cd $HOME/yieldswarm-agent-swarm-v2
POSEIDON_MODE=full npm run termux:deploy
```

## What changed from v4.0

| Legacy v4.0 | v4.1 (this repo) |
|-------------|------------------|
| `pkill -f node` | Scoped port release only |
| Overwrites `next.config.js` | Keeps `next.config.mjs` |
| `sed` patches in `node_modules/next` | `NEXT_DISABLE_SWC=1` + webpack dev |
| `pages/api/marketplace-bridge.js` | `GET /api/trident/marketplace-bridge` on backend |
| `npx next dev` on raw Termux | Backend-first; Next only in proot/desktop |
