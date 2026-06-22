# YieldSwarm Environment Setup — Termux Troubleshooting

This guide addresses common setup issues on **Android Termux** when working with `yieldswarm-agent-swarm-v2`.

---

## Part 1: pipx installation failure (`pkg install pipx` not found)

### Why it failed

Termux's `pkg` / `apt` does not ship a standalone `pipx` package. Install it with Python's `pip` instead.

### Solution

```bash
pkg update && pkg upgrade -y
pkg install python -y

pip install --upgrade pip
pip install pipx
pipx ensurepath
```

Close and reopen Termux (or `source ~/.bashrc`) so PATH updates apply.

Verify:

```bash
pipx --version
```

---

## Part 2: Next.js directory error (`Couldn't find any pages or app directory`)

### Why it failed

Running:

```bash
npm run dev deploy
```

expands to:

```bash
next dev deploy
```

In Next.js, the signature is `next dev [directory]`. The word `deploy` is interpreted as the **project root directory**, so Next.js looks for `deploy/app` or `deploy/pages` — which is not where this repo's web app lives.

### Where the app actually lives

This monorepo has **three** dev surfaces:

| Command | Stack | App root |
|---------|-------|----------|
| `npm run dev` | Next.js (payments, API routes) | `src/app/` |
| `npm run dev:frontend` | Vite + React (Arena dashboard) | `frontend/src/` |
| `npm run dev:backend` | Express API | `backend/src/` |

The root Next.js app uses the App Router under **`src/app/`** (not `./app/` at repo root). Running `npm run dev` from the repository root is correct — do **not** pass extra arguments.

### How to fix it

#### Option A: Run the local dev server

```bash
cd ~/yieldswarm-agent-swarm-v2

# Install dependencies (first time)
npm install
cd frontend && npm install && cd ..
cd backend && npm install && cd ..

# Next.js root app (default)
npm run dev

# Or Arena dashboard (Vite)
npm run dev:frontend

# Or integration backend API
npm run dev:backend
```

#### Option B: Build or deploy

There is **no** bare `npm run deploy` script. Use the named deploy targets:

```bash
# List all scripts
npm run

# Build
npm run build              # Next.js production build
npm run build:all          # Next.js + Vite frontend

# Deploy targets
npm run deploy:stack       # Full stack shell deploy
npm run deploy:bifrost     # IPFS pin + manifest
npm run deploy:azure:fleet # Azure VMSS fleet + SSH bootstrap
npm run deploy:azure:autoscale
```

See `docs/DEPLOYMENT_GUIDE.md` and `docs/AZURE_VMSS_FLEET_DEPLOY.md` for full runbooks.

---

## Part 3: Termux prerequisites for YieldSwarm

```bash
pkg install -y git nodejs-lts python openssh
node --version    # need >= 18.18.0 (see package.json engines)
npm --version
```

If `nodejs-lts` is too old, use `nvm` or build from source — Termux package versions vary by mirror.

### Recommended workflow on mobile

Termux is fine for **git, scripts, and light editing**. For stable dev servers and GPU work, use:

- **Azure VMSS** — `docs/AZURE_VM_DASHBOARD.md`
- **GitHub Codespaces** — `docs/CURSOR_CLOUD_SETUP.md`

---

## Verification checklist

- [ ] `pipx --version` works in a fresh shell
- [ ] `ls src/app` shows `page.tsx`, `layout.tsx`, `api/`
- [ ] `npm run dev` starts without the `deploy` argument
- [ ] `curl -s localhost:3000` returns HTML (Next.js default port)
- [ ] `npm run test:helix` passes (no Azure login required)

---

## Quick reference — common mistakes

| Mistake | Fix |
|---------|-----|
| `npm run dev deploy` | `npm run dev` |
| `pkg install pipx` | `pip install pipx && pipx ensurepath` |
| Looking for `./app/` at repo root | App is in `src/app/` |
| `npm run deploy` | Use `npm run deploy:stack` or a specific `deploy:*` script |
| Running Vite from repo root | `npm run dev:frontend` (or `cd frontend && npm run dev`) |
