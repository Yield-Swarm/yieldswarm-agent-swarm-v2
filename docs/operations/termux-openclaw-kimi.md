# Termux + OpenClaw + RunPod — Command Center Runbook

Mobile ops from Termux (aarch64) for RunPod GPU pods, Cherry Servers spec export, and OpenClaw mining.

## Phase 1 — Base setup (done if you ran `setup`)

```bash
pkg update -y
pkg install -y openssh git curl tmux rsync python jq
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 64 -f ~/.ssh/id_ed25519 -N "" \
  -C "termux-openclaw-$(date -u +%Y%m%dT%H%M%SZ)"
cat ~/.ssh/id_ed25519.pub
```

Or use the repo helper:

```bash
bash scripts/openclaw/termux-command-center.sh setup
bash scripts/openclaw/termux-command-center.sh pubkey
```

## Phase 2 — Register SSH key on RunPod

In the **RunPod web terminal** for your pod:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'PASTE_YOUR_TERMUX_PUBKEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Replace `PASTE_YOUR_TERMUX_PUBKEY_HERE` with output from `cat ~/.ssh/id_ed25519.pub`.

## Phase 3 — RunPod S3 env (never commit)

On Termux or the pod — **local file only**:

```bash
cat >> ~/.env.runpod << 'EOF'
AWS_ACCESS_KEY_ID=your_new_key_id_here
AWS_SECRET_ACCESS_KEY=your_new_secret_here
AWS_DEFAULT_REGION=us-ash-1
RUNPOD_S3_ENDPOINT=https://s3api-us-ash-1.runpod.io
EOF
chmod 600 ~/.env.runpod
set -a && source ~/.env.runpod && set +a
```

Rotate keys if they were ever pasted in chat.

## Phase 4 — Clone repo + avoid package.json conflicts

```bash
bash scripts/openclaw/termux-command-center.sh sync
```

This auto-stashes `package.json` edits before checking out `cursor/cherry-servers-cloud-specs-4f85`.

Manual fallback:

```bash
cd ~/yieldswarm-agent-swarm-v2
git stash
git fetch origin cursor/cherry-servers-cloud-specs-4f85
git checkout cursor/cherry-servers-cloud-specs-4f85
```

## Phase 5 — SSH test

```bash
export RUNPOD_SSH_USER='io3xh1krei03ju-644120be'   # your pod user@id
bash scripts/openclaw/termux-command-center.sh ssh
```

One-liner:

```bash
ssh -i ~/.ssh/id_ed25519 io3xh1krei03ju-644120be@ssh.runpod.io
```

## Phase 6 — Cherry Servers specs

**On Termux (phone specs):**

```bash
bash scripts/openclaw/termux-command-center.sh cherry-local
```

**On RunPod GPU pod (via SSH):**

```bash
bash scripts/openclaw/termux-command-center.sh cherry-remote
```

**Full packet** (needs `RUNPOD_API_KEY` + optional Vault):

```bash
export RUNPOD_API_KEY='your_api_key'
bash scripts/openclaw/termux-command-center.sh cherry-collect
```

Outputs land in `.run/cherry-servers-*.md` inside the repo.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Permission denied (publickey)` | Add Termux pubkey to pod `~/.ssh/authorized_keys` |
| `gh pr checkout` fails on `package.json` | `git stash` then checkout branch |
| `python3: can't open sys_profile.py` | Run `sync` command first |
| `nvidia-smi: not found` on Termux | Expected — run `cherry-remote` for GPU specs |
| Missing `jq` | `pkg install jq` |

## Security

- Never commit `~/.env.runpod`, `deploy/akash.env`, or API keys
- Rotate any key pasted into chat or logs
- Use `chmod 600` on all env files
