# Fleet Provisioning — `.env.fleet` + `swarm_provision.sh`

Distribute hardware-identified nodes (Pixel, IoTeX Pebble, Helium, RunPod) across Termux phones and cloud GPUs from a single fleet matrix.

## Quick start

```bash
cp .env.fleet.example .env.fleet
# Edit nodes 4–8 from sticker scans (13625.jpg → 13604.jpg)

chmod +x swarm_provision.sh scripts/fleet/*.sh

./swarm_provision.sh 0    # Pixel 10a → Grass (Termux)
./swarm_provision.sh 1    # IoTeX Pebble → IoT Hub
./swarm_provision.sh 7    # RunPod compute
```

## Fleet matrix (`.env.fleet`)

| Index | Model | Role | Source |
|-------|-------|------|--------|
| 0 | Pixel_10a | grass | Verified device |
| 1 | IoTeX_Pebble_V1 | iotex | Sticker 13628.jpg |
| 2 | IoTeX_Pebble_V1 | iotex | Sticker 13627.jpg |
| 3 | IoTeX_Pebble_V1 | iotex | Sticker 13629.jpg |
| 4–8 | CHANGEME | helium/grass/compute | Stickers 13625–13604 |

Each node supports: `NODE_N_ROLE`, `MODEL`, `SERIAL`, `MAC`, `PLATFORM`, `STICKER`, optional `SSID`, `WALLET`.

## Sync to Termux / RunPod

```bash
# From laptop (Cursor terminal)
./scripts/fleet/sync-fleet.sh termux u0_a123@192.168.1.50
./scripts/fleet/sync-fleet.sh runpod root@runpod-pod-id

# Manual rsync
rsync -avz .env.fleet swarm_provision.sh phone:~/yieldswarm-agent-swarm-v2/
ssh phone 'cd ~/yieldswarm-agent-swarm-v2 && ./swarm_provision.sh 0'
```

## What `swarm_provision.sh` does

1. Loads `.env.fleet` and resolves `NODE_{N}_*` variables
2. Detects context: `termux` | `runpod` | `azure` | `local`
3. Installs Hugging Face agent skills (`scripts/fleet/install-hf-agent-skills.sh`) when present
4. Clears stale `screen` sessions (`yieldswarm*`, `helix*`, `mining*`)
5. Writes `deploy/fleet/node-{N}.env` + exports `GRASS_NODE_KEYS` / `DEPIN_HELIUM_HOTSPOT_KEYS`
6. Boots role-specific payload:
   - **grass** → `start-termux.sh` or `mining start --miner grass`
   - **helium** → `deploy-helium-hotspot.sh`
   - **iotex** → `register-devices.sh`
   - **compute** → `start-mining.sh` / Bittensor

## Export helper

```bash
python3 scripts/fleet/fleet_export.py --node 0 --json
eval "$(python3 scripts/fleet/fleet_export.py --node 0)"
```

## Path safety (Termux)

Always use `~/yieldswarm-agent-swarm-v2` — **never** `\~` (see `docs/MINING_QUICKSTART_TERMUX.md`).

## Related

- `docs/MINING_INFRASTRUCTURE.md` — Grass / Helium env formats
- `docs/HF_AGENT_SKILLS.md` — `hf` CLI + global agent skills
- `scripts/mining/start-termux.sh` — Termux orchestrator
- `services/iot_hub/` — device registry
