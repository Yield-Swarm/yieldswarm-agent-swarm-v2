# RunPod SSH Setup — Fix Permission Denied (publickey)

## Step 1 — Termux: get your public key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Copy the full `ssh-ed25519 AAAA...` line.

## Step 2 — RunPod web terminal (each pod)

1. RunPod console → pod → **Connect** → **Start Web Terminal**
2. Run:

```bash
mkdir -p ~/.ssh
echo "PASTE_YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Repeat for every pod in `config/mining/runpod-fleet.json`.

## Step 3 — Test from Termux

```bash
ssh -i ~/.ssh/id_ed25519 io3xh1krei03ju-644120be@ssh.runpod.io
```

## Step 4 — Deploy miners

```bash
export KASPA_WALLET_ADDRESS=...
export MONERO_WALLET_ADDRESS=...
./scripts/runpod_fleet_deploy.sh
```

## Common mistakes

- Pasting markdown/`&&` into shell (use scripts only)
- Running `nvidia-smi` on Termux (ARM — no NVIDIA driver)
- Hardcoding secrets in scripts — use Vault + env vars
