# Cursor Cloud Agent — Environment Install Fix

## What failed

The auto-generated install script at `/tmp/cursor/async-install/install-user.sh` runs:

```bash
npm update && npm install && npm upgrade && npm start
```

That fails with **`npm error Missing script: "start"`** when npm runs in the wrong directory (often `/exec-daemon`, which has no `scripts` block). With `set -euo pipefail`, the hook exits **before** dependencies are installed.

Symptom in this repo: no `node_modules`, backend crashes with `Cannot find package 'node-cron'`.

## Fix (Cursor project settings)

Replace the environment install script with:

```bash
bash scripts/cursor-environment-install.sh
```

Or inline:

```bash
set -euo pipefail
cd /workspace
npm ci
cd backend && npm ci && cd ..
cd frontend && npm ci && cd ..
pip install -r requirements.txt
```

**Do not** include `npm start`, `npm run dev`, or `npm update` / `npm upgrade`.

## Manual recovery (any machine)

```bash
cd /workspace
bash scripts/cursor-environment-install.sh
```

## Verify

```bash
cd backend && npm test
PYTHONPATH=/workspace python3 -m mining hashpower --json
```
