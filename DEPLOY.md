# YieldSwarm AgentSwarm OS — Production Deployment

The complete, ordered production deployment for the YieldSwarm swarm:
**10,080 agents · 120 crons · Kimiclaw Consensus · Akash-primary with
multi-cloud fallback**.

Everything is driven by one orchestrator. You can run the **entire** deploy with
a single command, or run each of the 5 steps individually.

```bash
make deploy        # full ordered deploy (steps 1 → 5)
# or
./deploy.sh        # identical, plain-bash entrypoint
```

The 5 steps, in order:

| # | Step | Command (Makefile) | Command (script) |
|---|------|--------------------|------------------|
| 1 | Build & push Docker images to GHCR | `make build` | `deploy/scripts/build-and-push.sh` |
| 2 | Akash lease creation + auto-healing | `make akash-lease akash-heal` | `deploy/akash/create-lease.sh` + `deploy/akash/auto-heal.sh --daemon` |
| 3 | Apply Terraform multi-cloud fallback | `make terraform-apply` | `deploy/scripts/apply-terraform.sh apply` |
| 4 | Update frontend with real worker URLs | `make frontend` | `deploy/scripts/update-frontend-urls.sh` |
| 5 | Start monitoring + sovereign loops | `make monitoring-up sovereign-up` | `deploy/scripts/start-monitoring.sh up` + `deploy/scripts/start-sovereign-loops.sh start` |

---

## 0. Prerequisites

### Tooling

| Tool | Used in | Install |
|------|---------|---------|
| Docker (+ buildx) | Step 1, Step 5 | <https://docs.docker.com/engine/install/> |
| Akash CLI (`provider-services`) | Step 2 | <https://akash.network/docs/deployments/akash-cli/installation/> |
| Terraform ≥ 1.5 | Step 3 | <https://developer.hashicorp.com/terraform/install> |
| Python 3.10+ | Steps 2–5 | preinstalled on most systems |
| `curl`, `make`, `git` | all | preinstalled on most systems |

Check everything at once:

```bash
make preflight
```

### Configuration

Two config files. **Neither is committed** (both are git-ignored).

1. **Deployment/infra settings** — `deploy/config.env`:

```bash
cp deploy/config.env.example deploy/config.env
$EDITOR deploy/config.env          # set GHCR_OWNER, AKASH_KEY_NAME, toggles, ...
```

2. **Application secrets** — root `.env` (API keys, wallet keys, etc.):

```bash
cp .env.example .env
$EDITOR .env                        # fill securely (TEE/air-gapped)
```

At minimum set in `deploy/config.env`:

```ini
GHCR_OWNER=your-github-username      # lowercase GitHub user/org
GHCR_USER=your-github-username
GHCR_TOKEN=ghp_xxx                   # PAT with write:packages
AKASH_KEY_NAME=yieldswarm            # your funded Akash wallet key
```

---

## Step 1 — Build & push Docker images to GHCR

Builds and pushes three images, tagged with the short git SHA **and** `latest`:

- `ghcr.io/<owner>/yieldswarm-worker` — frontend-facing health/metrics/status API
- `ghcr.io/<owner>/yieldswarm-agents` — the sovereign loop (Akash optimizer, OpenClaw scaler, vault manager, miners)
- `ghcr.io/<owner>/yieldswarm-dashboard` — OpenClaw admin dashboard (nginx)

```bash
# Authenticate to GHCR (or rely on GHCR_TOKEN in deploy/config.env)
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

# Build + push all three images
make build
# or:  deploy/scripts/build-and-push.sh
```

Useful variants:

```bash
DRY_RUN=1 deploy/scripts/build-and-push.sh          # print commands only
PUSH=0    deploy/scripts/build-and-push.sh           # build locally, do not push
PLATFORMS=linux/amd64,linux/arm64 deploy/scripts/build-and-push.sh worker   # multi-arch, single component
IMAGE_TAG=v1.0.0 deploy/scripts/build-and-push.sh    # pin an explicit tag
```

After this step your GHCR packages page shows the three images. Make them
**public** (or grant the Akash provider pull access) so Akash can pull them.

---

## Step 2 — Akash lease creation + auto-healing

### 2a. Create the lease

Renders the SDL with your GHCR image refs, ensures a client cert, creates the
deployment, waits for provider bids, accepts the **cheapest** bid, sends the
manifest, and writes lease metadata + worker URLs to `.run/akash-lease.env`.

```bash
# Prerequisite: a funded Akash wallet key imported under $AKASH_KEY_NAME
provider-services keys list --keyring-backend "$AKASH_KEYRING_BACKEND"

make akash-lease
# or:  deploy/akash/create-lease.sh
```

The lease URIs are printed and saved:

```bash
cat .run/akash-lease.env
# AKASH_OWNER=akash1...
# AKASH_DSEQ=1234567
# AKASH_PROVIDER=akash1...
# AKASH_WORKER_URLS=https://....akash.network,...
```

SDL: [`deploy/akash/deploy.sdl.yaml`](deploy/akash/deploy.sdl.yaml) (CPU/memory
and `uakt` pricing per service — raise pricing if you get no bids).

### 2b. Start auto-healing

The auto-heal loop keeps the lease **alive and funded**: it tops up the escrow
when the balance drops below `AKASH_MIN_BALANCE_UAKT`, re-sends the manifest if a
worker health check fails, and fully recreates the lease if it ever closes.

```bash
make akash-heal                       # start as a background daemon
# or:  deploy/akash/auto-heal.sh --daemon

# Other modes:
deploy/akash/auto-heal.sh             # run in the foreground
deploy/akash/auto-heal.sh --once      # single pass (good for cron)
make akash-heal-stop                  # stop the daemon
```

For production hosts, install the systemd units instead of the daemon:

```bash
sudo cp deploy/systemd/yieldswarm-akash-heal.service /etc/systemd/system/
sudo sed -i "s#__REPO__#$(pwd)#g" /etc/systemd/system/yieldswarm-akash-heal.service
sudo systemctl daemon-reload && sudo systemctl enable --now yieldswarm-akash-heal
```

---

## Step 3 — Apply Terraform multi-cloud fallback

Akash is the **primary (sovereign)** backend. Terraform provisions a managed-cloud
fallback **only when** a fallback is enabled *and* the Akash worker is unhealthy.
Preference order: **Fly.io → Render → Hetzner**.

Enable the fallbacks you want in `deploy/config.env`:

```ini
TF_ENABLE_FLY=true
FLY_API_TOKEN=fly_xxx
# TF_ENABLE_RENDER=true ; RENDER_API_KEY=...
# TF_ENABLE_HETZNER=true ; HCLOUD_TOKEN=...
```

Then:

```bash
make terraform-plan                   # preview
make terraform-apply                  # apply
# or:  deploy/scripts/apply-terraform.sh apply
```

The wrapper auto-generates `deploy/terraform/auto.tfvars.json` from your config
and the live Akash lease (it derives `primary_health_url` from the lease URIs).
The chosen backend is recorded in `deploy/terraform/active-backend.json`, and the
fallback's public URL (if created) in `deploy/terraform/fallback-url.txt`.

Tear down fallback infra with:

```bash
make terraform-destroy
```

> Terraform module: [`deploy/terraform/`](deploy/terraform/). It uses provider
> CLIs via `local-exec` so `terraform init/validate/plan` work without every
> cloud's Terraform provider; swap in native providers if you prefer.

---

## Step 4 — Update frontend with real worker URLs

Collects the live worker URLs (from CLI args → `WORKER_URLS` → the Akash lease →
the Terraform fallback), de-duplicates them, and writes the dashboard runtime
config `dashboard/config.js` (consumed by `dashboard/index.html`, which live-pings
each worker's `/healthz`). Optionally triggers a Vercel redeploy.

```bash
make frontend
# or:  deploy/scripts/update-frontend-urls.sh

# Override explicitly:
deploy/scripts/update-frontend-urls.sh https://worker-a.akash.network https://worker-b.fly.dev
```

Result:

```js
// dashboard/config.js  (auto-generated)
window.YIELDSWARM_CONFIG = {
  "buildTag": "576a329",
  "generatedAt": "2026-06-15T05:11:34Z",
  "workerUrls": ["https://....akash.network", "https://....fly.dev"],
  "primaryWorker": "https://....akash.network"
};
```

To push the static frontend to Vercel automatically, set a deploy hook in
`deploy/config.env`:

```ini
VERCEL_DEPLOY_HOOK=https://api.vercel.com/v1/integrations/deploy/prj_xxx/xxxxx
```

---

## Step 5 — Start monitoring + sovereign loops

### 5a. Monitoring stack

Brings up **Prometheus + Grafana + Alertmanager** via Docker Compose. Prometheus
targets are regenerated from the live worker URLs; alerts cover worker-down,
not-ready, and a stalled sovereign loop.

```bash
make monitoring-up
# or:  deploy/scripts/start-monitoring.sh up
```

- Prometheus:   <http://localhost:9090>
- Grafana:      <http://localhost:3001>  (admin / `yieldswarm`, override `GRAFANA_PASSWORD`)
- Alertmanager: <http://localhost:9093>

The **YieldSwarm Overview** Grafana dashboard is auto-provisioned. Stop with
`make monitoring-down`.

### 5b. Sovereign loops

Starts and supervises the long-running loops that keep the swarm sovereign:

- **sovereign-loop** — runs every agent/cron each `SOVEREIGN_LOOP_INTERVAL` (default 900s)
- **akash-auto-heal** — keeps the Akash lease funded & healthy (started in 2b; re-ensured here)

```bash
make sovereign-up
# or:  deploy/scripts/start-sovereign-loops.sh start

deploy/scripts/start-sovereign-loops.sh status      # check
deploy/scripts/start-sovereign-loops.sh stop        # stop
```

Production hosts: use systemd instead of the local supervisor:

```bash
sudo cp deploy/systemd/yieldswarm-sovereign.service /etc/systemd/system/
sudo sed -i "s#__REPO__#$(pwd)#g" /etc/systemd/system/yieldswarm-sovereign.service
sudo systemctl daemon-reload && sudo systemctl enable --now yieldswarm-sovereign
```

---

## One-shot full deploy

After `deploy/config.env` and `.env` are filled in:

```bash
# Everything, in order (steps 1 → 5):
make deploy
# or:
./deploy.sh
```

`deploy.sh` flags:

```bash
./deploy.sh --from 3        # resume from step 3
./deploy.sh --only 1        # run only step 1
./deploy.sh --dry-run       # show what each step would do
./deploy.sh --help
```

Expected tail of a successful run:

```text
==> Deployment complete in <N>s
[ ok ] Dashboard config: dashboard/config.js
[ ok ] Monitoring:       http://localhost:9090 (Prometheus) / http://localhost:3001 (Grafana)
[ ok ] Loop status:      deploy/scripts/start-sovereign-loops.sh status

  YieldSwarm is LIVE. Sovereign loops running. Akash auto-heal active.
```

---

## Post-deploy verification

```bash
# Worker liveness (use a URL from .run/akash-lease.env)
curl -fsS https://<worker>.akash.network/healthz        # -> ok
curl -fsS https://<worker>.akash.network/api/status     # -> JSON status
curl -fsS https://<worker>.akash.network/metrics        # -> Prometheus metrics

# Running loops + monitoring containers
make status

# Tail loop logs
make logs                                                # tail .run/*.log

# Grafana: open http://localhost:3001 -> "YieldSwarm Overview"
```

Then point your domain / Vercel frontend at the worker URLs written to
`dashboard/config.js` and wire Unstoppable Domains via Cloudflare nameservers
(see [`DOMAINS.md`](DOMAINS.md)).

---

## Akash + Vault Production Deploy (Codespace / CLI)

Repeatable GPU monolith deployment with HashiCorp Vault runtime secret injection.

### Prerequisites

```bash
# In GitHub Codespace or local shell:
sudo apt-get update && sudo apt-get install -y jq curl
# Akash CLI
curl -sSfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash
export PATH="$HOME/.akash/bin:$PATH"
# Vault CLI
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install -y vault
```

### 1. Bootstrap Vault (one-time)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<operator-root-or-bootstrap-token>
bash vault/setup/bootstrap.sh
SOURCE_ENV=.env bash vault/setup/05-seed-secrets.sh
```

### 2. Import Akash wallet

```bash
export AKASH_KEY_NAME=yieldswarm
provider-services keys add "$AKASH_KEY_NAME" --recover  # or --ledger
provider-services query bank balances $(provider-services keys show "$AKASH_KEY_NAME" -a)
```

### 3. Deploy GPU monolith with Vault

```bash
export AKASH_KEY_NAME=yieldswarm
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<ci-bootstrap-or-operator-token>
export AGENT_SHARD_ID=0
export AUTO_SELECT_BID=1

chmod +x scripts/akash-deploy.sh scripts/vault-mint-wrap.sh
bash scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

The script auto-mints a wrapped SecretID, injects `VAULT_ROLE_ID` + `VAULT_WRAPPED_SECRET_ID` + `AGENT_SHARD_ID` at deployment create, auto-selects the lowest bid, sends the manifest, and runs an initial health check.

### 4. Deploy Odysseus full stack (local or Akash)

```bash
# Local dev (ChromaDB + LiteLLM + SearXNG + Ollama):
docker compose up -d odysseus llm-router chromadb searxng ntfy
docker compose --profile gpu up -d ollama   # if GPU available

# Akash production Odysseus:
python scripts/render-akash-sdl.py deploy/akash-odysseus.sdl.yml > /tmp/odysseus.sdl.yml
bash scripts/akash-deploy.sh /tmp/odysseus.sdl.yml
```

### 5. CI deploy (GitHub Actions)

Workflow: [`.github/workflows/akash-deploy.yml`](.github/workflows/akash-deploy.yml)

Required GitHub secrets: `VAULT_ADDR`, `VAULT_CI_ROLE_ID`, `VAULT_CI_SECRET_ID`, `AKASH_KEY_NAME`, `AKASH_ACCOUNT_ADDRESS`

```bash
gh workflow run akash-deploy.yml -f sdl_file=deploy/deploy-swarm-monolith.yaml -f shard_id=0
```

### 6. Auto-healing

```bash
make akash-heal                    # background daemon
deploy/akash/auto-heal.sh --once   # single pass (cron-friendly)
```

---

## Operations cheat-sheet

```bash
make help                 # list every target
make preflight            # verify tooling
make deploy               # full ordered deploy
make status               # loops + monitoring status
make logs                 # tail sovereign + auto-heal logs
make monitoring-down      # stop monitoring
make sovereign-down       # stop sovereign loops
make akash-heal-stop      # stop auto-heal daemon
make terraform-destroy    # tear down fallback infra
make clean                # remove .run + generated tf/frontend artifacts
```

## Layout

```
DEPLOY.md                         # this file
Makefile                          # ordered targets (make deploy)
deploy.sh                         # plain-bash orchestrator (./deploy.sh)
deploy/
  config.env.example              # deployment/infra config template
  docker/                         # Dockerfiles (worker, agents, dashboard) + nginx
  runtime/                        # worker.py, swarm_runner.py (containerized)
  akash/                          # deploy.sdl.yaml, create-lease.sh, auto-heal.sh
  terraform/                      # multi-cloud fallback module + per-cloud deployers
  monitoring/                     # Prometheus/Grafana/Alertmanager + dashboards
  scripts/                        # build-and-push, apply-terraform, update-frontend, start-*
  systemd/                        # production supervision units
dashboard/                        # index.html + config.js (live worker view)
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `GHCR_OWNER is not set` | Set `GHCR_OWNER` in `deploy/config.env`. |
| `denied: permission_denied` on push | `docker login ghcr.io`; ensure PAT has `write:packages`. |
| Akash: no bids within timeout | Raise `uakt` pricing in `deploy/akash/deploy.sdl.yaml`; ensure wallet is funded. |
| Akash worker pull fails | Make GHCR images public or grant the provider pull access. |
| Terraform makes no fallback | Expected when `primary_healthy=true` or all `TF_ENABLE_*=false`. |
| Grafana/Prometheus won't start | Ensure Docker is running and ports 9090/3001/9093 are free. |
| Sovereign loop stalled alert | `deploy/scripts/start-sovereign-loops.sh start`; check `.run/sovereign-loop.log`. |
```
