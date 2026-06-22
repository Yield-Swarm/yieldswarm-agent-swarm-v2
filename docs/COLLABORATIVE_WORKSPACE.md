# Collaborative Workspace — Code-Server + optional Jitsi (RunPod / Termux)

Self-hosted browser IDE and optional video for distributed teams. **Default posture:** bind services to localhost on the RunPod master pod; access via **SSH tunnel** — do not expose code-server to the public internet without TLS + strong auth.

## Architecture

```
Browser (localhost:8080 / :8443)
        │ SSH -L tunnels
        ▼
RunPod master (thick_salmon_goat)
  ├── code-server :8080  (127.0.0.1)
  └── jitsi web :8443    (127.0.0.1, optional)
Termux / laptop ──ssh──► same tunnels
```

## Quick start (RunPod master)

```bash
# On pod (after SSH or web terminal)
cd /workspace
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2

cp deploy/collab/.env.collab.example deploy/collab/.env.collab
# Edit deploy/collab/.env.collab — set CODE_SERVER_PASSWORD (never commit)

./scripts/runpod/deploy-code-server.sh
```

## SSH tunnel (from laptop / Termux)

```bash
export RUNPOD_SSH_HOST=io3xh1krei03ju-644120be@ssh.runpod.io
export SSH_KEY=~/.ssh/id_ed25519

./scripts/collab/ssh-tunnel-workspace.sh
# Open http://localhost:8080 — code-server
# Open https://localhost:8443 — Jitsi (if enabled)
```

## Optional: Jitsi + code-server via Docker

```bash
cd deploy/collab
cp .env.collab.example .env.collab
# Set JITSI_* passwords in .env.collab

docker compose --profile jitsi up -d
```

## Git workflow between portals

All editors work on the **same clone** on the master pod:

```bash
cd ~/yieldswarm-agent-swarm-v2
git fetch origin
git checkout cursor/<your-branch>-9c82
# edit in code-server UI terminal
git commit -am "..." && git push origin HEAD
```

Use branch prefix `cursor/*-9c82` per repo convention. Never commit secrets from the browser IDE.

## Security checklist

| Rule | Why |
|------|-----|
| `bind-addr 127.0.0.1` | No public code-server without reverse proxy |
| SSH tunnel or WireGuard | Encrypts access to pod |
| Strong `CODE_SERVER_PASSWORD` | From Vault / password manager |
| Rotate if pasted in chat | Treat leaked passwords as compromised |
| Jitsi JWT in production | Default compose is dev-only |

## Related

- Akash / production deploy: `make akash-preflight` (separate track)
- DePIN edge: `docs/DEPIN_EDGE_INTEGRATION.md`
- TON MMORPG: `ton-mmorpg/`
