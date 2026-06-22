# Post-sleep / forensic recovery checklist

Actionable fixes from Termux, RunPod, and LAN diagnostics. **Ignore** pasted scripts that chain `llama3.3:70b` + multiple `ollama run` shards on one GPU, or fabricated AWS domain URLs.

## 1. WiFi — forget rogue AP (Shark vacuum)

Symptom: device on `10.221.203.x` cannot reach Render/Singapore/AWS.

1. Settings → WiFi → **Forget** `Shark_RV750P-NA-*`
2. Connect to primary gateway (**FS-IoT** / Verizon `192.168.1.x`)
3. Confirm gateway `192.168.1.1`, not `10.221.203.1`

```bash
ip route | head -5
ping -c 2 192.168.1.1
curl -sI https://yieldswarm-agent-swarm-v2-mainnet.onrender.com | head -3
```

## 2. Termux vs RunPod — use the right package manager

| Environment | Package manager | User |
|-------------|-----------------|------|
| **Termux** (phone) | `pkg install` | not root |
| **RunPod Ubuntu** | `apt-get install` | root (no `sudo`) |

RunPod bootstrap:

```bash
apt-get update -y && apt-get install -y git curl wget nodejs npm
npm install -g pnpm
export NODE_OPTIONS="--max-old-space-size=4096"
```

Termux bootstrap:

```bash
pkg update && pkg install -y git openssh termux-api
```

## 3. SSH — RunPod public key (fix Permission denied)

```bash
# On Termux / laptop
ssh-keygen -t ed25519 -f ~/.ssh/id_runpod_nexus -N ""
cat ~/.ssh/id_runpod_nexus.pub
```

Paste **public** key into RunPod console → Pod → **Public Key**.

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_runpod_nexus
ssh -i ~/.ssh/id_runpod_nexus io3xh1krei03ju-644120be@ssh.runpod.io
```

## 4. Shell syntax — one command per line

**Wrong:** `ll -g pnpm git clone ... cd ... pnpm install`

**Right:**

```bash
cd /opt/openclaw-pod-0 || mkdir -p /opt/openclaw-pod-0 && cd /opt/openclaw-pod-0
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2
pnpm install
```

## 5. Inference — one model per pod

```bash
export INFERENCE_MODEL=qwen2.5-coder:32b
./scripts/runpod/hotload-inference.sh
nvidia-smi
curl -s http://127.0.0.1:11434/api/tags
```

See `docs/RUNPOD_INFERENCE.md` and `config/inference/pod-model-matrix.yaml`.

## 6. Consensus smoke test (repo script)

```bash
cd ~/yieldswarm-agent-swarm-v2
python3 scripts/run-governance-consensus.py --models 100 --output .run/governance-consensus-report.json
```

Do **not** use pasted `helix-consensus-runner.ts` (syntax errors, incomplete).

## 7. Track 2 Akash (parallel path)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...   # local only
make akash-preflight
# GO → make deploy-akash-europlots && make akash-verify
```

## 8. Seventeen domains

```bash
./scripts/wire-production-domains.sh --dry-run
# Real zones from HELIX_SINGLE_PANE — not config/domains.json placeholders
```

## 9. Collaborative workspace

```bash
make collab-code-server   # on master pod
make collab-tunnel        # from laptop
```
