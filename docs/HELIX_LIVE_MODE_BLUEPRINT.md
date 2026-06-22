# Helix DNA v2.1 — Production Live-Mode Blueprint

Transition from **dry-run** (`REWARDS_DRY_RUN=1`) to live Great Delta settlement across Azure VMSS, treasury roots, and edge IoT.

## Architecture (Azure VMSS)

```text
                  ┌────────────────────────────────────────┐
                  │     Custom Frontend Domain             │
                  │  (e.g. mainnet.yieldswarm.network)     │
                  └────────────────────────────────────────┘
                                       │
                                       ▼
                  ┌────────────────────────────────────────┐
                  │         Azure Load Balancer            │
                  │             4.249.252.26               │
                  └────────────────────────────────────────┘
                                  │        │
                   Port 50000     │        │  Port 50001
             ┌────────────────────┘        └────────────────────┐
             ▼                                                  ▼
┌───────────────────────────┐                      ┌───────────────────────────┐
│     VMSS Instance 0       │                      │     VMSS Instance 1       │
│  (vmss_3cf043e Ubuntu)    │                      │  (vmss_3cf043e Ubuntu)    │
├───────────────────────────┤                      ├───────────────────────────┤
│ tmux: yieldswarm-backend  │                      │ tmux: yieldswarm-backend  │
│ Local :8080               │                      │ Local :8080               │
│ Solenoid engine active    │                      │ Solenoid engine active    │
└───────────────────────────┘                      └───────────────────────────┘
```

| Component | Value |
|-----------|-------|
| Resource group | `YieldSwarm` |
| NSG | `basicNsgvnet-centralus-nic01` |
| Load balancer | `4.249.252.26` |
| Backend port | `8080` |
| Swarm P2P ports | `50000–50003` |

## Step 1 — Elevate NSG rules

```bash
export AZURE_RESOURCE_GROUP=YieldSwarm
export AZURE_NSG_NAME=basicNsgvnet-centralus-nic01
./scripts/azure/configure-swarm-nsg.sh
```

Or manually:

```bash
az network nsg rule create \
  --resource-group YieldSwarm \
  --nsg-name basicNsgvnet-centralus-nic01 \
  --name AllowSwarmP2P \
  --priority 1010 \
  --destination-port-ranges 50000-50003 \
  --protocol Tcp \
  --access Allow
```

## Step 2 — Disengage dry-run (on each VMSS instance)

```bash
cd ~/yieldswarm-agent-swarm-v2
git pull origin production

export IOT_HUB_DRY_RUN=0
export REWARDS_DRY_RUN=0
export MARKETING_DRY_RUN=0   # optional — campaigns
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=your_vault_approle_token
```

**Automated (requires confirmation):**

```bash
HELIX_GO_LIVE=1 ./scripts/production/go-live.sh
```

Preview only:

```bash
./scripts/production/go-live.sh --dry-run
```

## Step 3 — Full multi-chain sweeper

```bash
./scripts/rewards/sweep-rewards.sh --full
# equivalent combined form:
./scripts/rewards/sweep-rewards.sh --full --reshard --assemble --sweep
```

Pipeline:

1. **Reshard** — 120 shards across 10 mining roots (`config/TREASURY_MANIFEST.json`)
2. **Assemble** — per-wallet batches
3. **Sweep** — Great Delta **50/30/15/5** via `services/rewards/sweeper.py`

State files: `.run/rewards-reshard.json`, `.run/rewards-assemble.json`, `.run/rewards-sweep.json`

## Step 4 — Monitor

| Surface | URL |
|---------|-----|
| Command center | `http://<lb-or-vm>:8080/command-center` |
| Single pane API | `http://<lb-or-vm>:8080/api/single-pane/overview` |
| Rewards status | `http://<lb-or-vm>:8080/api/rewards/status` |
| Nexus | `http://<lb-or-vm>:8080/api/nexus/health` |
| RPC mesh | `http://<lb-or-vm>:8080/api/rpc/alchemy/health` |

## VMSS tmux (both instances)

```bash
tmux attach -t yieldswarm-backend
# Ctrl+B D to detach
```

Start if missing:

```bash
tmux new-session -d -s yieldswarm-backend -c ~/yieldswarm-agent-swarm-v2/backend \
  'PORT=8080 HOST=0.0.0.0 npm start'
```

## Safety defaults

| Flag | Dry-run default | Live |
|------|-----------------|------|
| `REWARDS_DRY_RUN` | `1` | `0` |
| `IOT_HUB_DRY_RUN` | `1` | `0` |
| `MARKETING_DRY_RUN` | `1` | `0` |

`HELIX_GO_LIVE=1` is required for `go-live.sh` to execute live sweeps.

## Related

- `System_Config.md` — operator env reference
- `README.txt` — assimilation summary
- `docs/REWARDS_RESHARD_SWEEP.md` — rewards pipeline detail
- `docs/AZURE_VM_DASHBOARD.md` — single-VM bootstrap
