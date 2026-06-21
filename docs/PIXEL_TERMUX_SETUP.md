# Pixel Termux Setup — YieldSwarm Operator Workstation

> Master terminal for global uptime, deploy commands, and swarm monitoring.

## Prerequisites

- [Termux](https://termux.dev/) on Google Pixel (or any Android device)
- Optional: `tmux` for multi-pane ops (backend + monitor + sovereign)

## Quick bootstrap (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/development/scripts/pixel-termux-bootstrap.sh | bash
```

## Manual setup (corrected commands)

Your snippet used a GitLab placeholder — the canonical repo is **GitHub**:

```bash
# Termux native package manager
pkg update && pkg upgrade -y
pkg install -y git curl htop tmux unzip python clang make openssl-tool

# OR Debian/proot with apt:
# sudo apt update && sudo apt upgrade -y
# sudo apt install -y curl git htop tmux unzip build-essential python3 python3-pip nodejs npm

# Project directory (note: ~/ not \~/)
mkdir -p ~/yieldswarm
cd ~/yieldswarm

# Clone actual repo
git clone --branch development https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git .

# Env + deps
cp deploy/env/layered.env.example .env
pip install -r kairo/requirements.txt
cd backend && npm install && cd ..

# Verify
DRY_RUN=1 ./scripts/full-stack-optimize.sh
python3 iteration-100/run.py --status
```

## tmux layout (recommended)

```bash
tmux new -s yieldswarm

# Pane 0: backend API
cd ~/yieldswarm/backend && npm run dev

# Pane 1: monitor (Ctrl+b then ")
START_MONITOR=1 ./scripts/full-stack-optimize.sh
tail -f ~/monitor.log

# Pane 2: sovereign + DePIN
python3 iteration-100/run.py --quiet --target-apy 40 --interval 30
python3 kairo/telemetry_daemon.py --helium --nexus --halo2-prove
```

## SSH / private repo

If the repo is private, use a personal access token or SSH:

```bash
git clone git@github.com:Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm
```

Or HTTPS with token (do not paste tokens in chat):

```bash
git clone https://<TOKEN>@github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm
```

## Post-setup verification

```bash
git status
git branch --show-current
python3 iteration-100/run.py --status
python3 akash/bid-optimizer.py --dry-run --gpu h100
curl -s http://127.0.0.1:8080/api/helix/health   # after backend starts
```

## Related

- `docs/FULL_STACK_OPTIMIZATION.md` — optimize commands
- `scripts/full-stack-optimize.sh` — master tune script
- `KAIRO_IDENTITY.md` — driver keys + YSLR (after merge)
