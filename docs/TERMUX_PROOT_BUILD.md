# Termux / Android Build Recovery (PRoot)

Fixes the **Unsupported OS: android** crash from native Node modules (e.g.
`@matrix-org/matrix-sdk-crypto-nodejs`), cascading **vite: not found** /
**spawn tsgo ENOENT** errors, and shell paste mistakes.

## What went wrong

| Symptom | Cause |
|---------|--------|
| `Unsupported OS: android` during `pnpm install` | Matrix crypto (and similar) postinstall rejects Termux/Bionic |
| `vite: not found`, `spawn tsgo ENOENT` | Install aborted mid-tree — dev binaries never linked |
| `syntax error near unexpected token '&&'` | Markdown heading (`### ...`) pasted after `&&` in the shell |

**Important:** Copy only the lines inside fenced `bash` blocks — never paste markdown headings (`#`, `###`) into Termux.

## Quick fix (recommended): PRoot Ubuntu

Run on **raw Termux** (one-time):

```bash
cd ~/yieldswarm-agent-swarm-v2
bash scripts/termux/proot-bootstrap.sh
```

Enter Ubuntu and build:

```bash
proot-distro login ubuntu
```

Inside `root@ubuntu:~#`:

```bash
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm-agent-swarm-v2
cd ~/yieldswarm-agent-swarm-v2
bash scripts/termux/install-node-ubuntu.sh
bash scripts/termux/build-workspace.sh
```

PRoot presents a glibc Ubuntu userspace, so native Rust/Node bindings compile as **linux**, not **android**.

## Mining-only (no Node build)

If you only need Akash/Bittensor/Python miners on the phone:

```bash
cd ~/yieldswarm-agent-swarm-v2
bash scripts/termux/mining-only.sh
```

No `pnpm`, Vite, or Matrix crypto required.

## Manual steps (equivalent to scripts)

### Step 1 — Termux host

```bash
pkg update && pkg install proot-distro -y
proot-distro install ubuntu
```

### Step 2 — Ubuntu toolchain

```bash
proot-distro login ubuntu
apt update && apt install -y curl build-essential python3 git
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pnpm typescript
```

### Step 3 — Clean install + build

```bash
cd ~/yieldswarm-agent-swarm-v2
npm ci
cd backend && npm ci && cd ..
cd frontend && npm ci && cd ..
npm run build:all
```

## Forks with Matrix / OpenClaw / pnpm

If your workspace uses `pnpm` and `@matrix-org/matrix-sdk-crypto-nodejs`:

1. **Always build inside proot Ubuntu** (not raw Termux).
2. If you must stay on Termux temporarily:
   ```bash
   export MATRIX_SDK_CRYPTO_NODEJS_SKIP_INSTALL=1
   pnpm install --ignore-scripts
   ```
   Then install Vite/tsgo explicitly inside proot before `npm run build`.

## npm scripts (from repo root)

| Script | Action |
|--------|--------|
| `npm run termux:proot-bootstrap` | Install proot-distro Ubuntu on Termux |
| `npm run termux:build` | Full install + build inside proot Ubuntu |
| `npm run termux:mining` | Python/Akash path without Node native deps |

## Network note

Local Wi‑Fi (e.g. `10.x` on a device AP) does not affect Termux compile errors — those are userspace/platform issues, fixed by proot.

## See also

- [`docs/MINING_INFRASTRUCTURE.md`](MINING_INFRASTRUCTURE.md) — fleet CLI
- [`docs/AZURE_VM_DASHBOARD.md`](AZURE_VM_DASHBOARD.md) — move off Termux to Azure VM for production
