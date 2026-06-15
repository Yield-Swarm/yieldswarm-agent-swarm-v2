# YieldSwarm on Akash

This directory contains the runtime artefacts for shipping a YieldSwarm
agent shard to the Akash Network. Every secret a shard needs is fetched
from HashiCorp Vault at container start - **nothing sensitive is baked
into the image or the SDL**.

## Files

| File                             | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| `Dockerfile`                     | Hardened image (non-root, pinned Vault, tini, tmpfs secrets) |
| `entrypoint.sh`                  | Unwraps SecretID → starts Vault Agent → execs the workload  |
| `vault-agent.hcl`                | AppRole auto-auth + KVv2 template rendering                  |
| `templates/agent.env.ctmpl`      | Consul-Template that renders `/run/secrets/agent.env`        |
| `deploy.yaml`                    | Akash SDL (no secrets, only `VAULT_*` bootstrap env vars)    |

## Secret flow

```
operator / CI
    │  vault write -wrap-ttl=600s -force auth/approle/role/akash-runtime/secret-id
    ▼  → WRAPPED_SECRET_ID (one-shot, ~10 min)
provider-services tx deployment create deploy.yaml \
    --env VAULT_ROLE_ID=<role_id> \
    --env VAULT_WRAPPED_SECRET_ID=<WRAPPED_SECRET_ID> \
    --env AGENT_SHARD_ID=<0..119>
    │
    ▼
Akash provider starts container
    │
    ▼
entrypoint.sh
  1. validate env
  2. vault unwrap WRAPPED_SECRET_ID  → /run/secrets/secret-id (tmpfs, 0400)
  3. exec vault agent (AppRole login + KV template)
  4. wait for /run/secrets/agent.env
  5. source it, exec workload
    │
    ▼
yieldswarm.agent process
```

## What lives where

- `/run/secrets/role-id`              – the AppRole role_id (non-sensitive)
- `/run/secrets/secret-id`            – removed by Vault Agent after first use
- `/run/secrets/vault-token`          – tmpfs, mode 0400, in-memory only
- `/run/secrets/agent.env`            – tmpfs, mode 0400, sourced by entrypoint
- `/run/secrets/vault-agent.pid`      – PID file
- `127.0.0.1:8100`                    – Vault Agent API proxy for the workload

## Updating secrets

Rotate a secret in Vault (`vault kv put yieldswarm/rpc/helius api_key=...`).
Vault Agent re-renders `agent.env` within `static_secret_render_interval`
(5 minutes) and sends SIGHUP to the workload, which reloads its env.

## Local development

```bash
# 1. Run a dev Vault.
docker run --rm -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.18.2

# 2. Seed it.
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/02-enable-engines.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/03-write-policies.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/04-enable-auth.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root SOURCE_ENV=./.env \
  ./vault/setup/05-seed-secrets.sh

# 3. Build the image.
docker build -t yieldswarm-agent:dev -f akash/Dockerfile .

# 4. Get a wrapped SecretID.
ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
WRAP=$(vault write -wrap-ttl=600s -force -format=json \
        auth/approle/role/akash-runtime/secret-id \
        | jq -r '.wrap_info.token')

# 5. Run.
docker run --rm -it \
  -e VAULT_ADDR=http://host.docker.internal:8200 \
  -e VAULT_ROLE_ID="${ROLE_ID}" \
  -e VAULT_WRAPPED_SECRET_ID="${WRAP}" \
  -e AGENT_SHARD_ID=0 \
  --tmpfs /run/secrets:size=8m,mode=0700 \
  yieldswarm-agent:dev
```

---

## Lease Manager (merged from cursor/akash-lease-manager-f88c)


Production supervisor that keeps a fleet of **RTX 3090** GPU workers alive on the
[Akash Network](https://akash.network). It health-checks workers every 60s and,
when one dies, it automatically leases a replacement on the best available
RTX 3090 provider and republishes the new worker URLs to the frontend telemetry.

This is the concrete implementation behind `agents/akash-optimizer.py` and the
"Akash Hardware" card on the council status dashboard.

## Components

| File | Purpose |
| --- | --- |
| `akash-deploy.sh` | Akash CLI wrapper: create deployment, collect bids, pick the best RTX 3090 provider, open lease, send manifest, resolve worker URL, close leases. Each subcommand emits JSON. |
| `lease-manager.py` | The supervisor loop: health checks, auto-failover, fleet scale-up, and telemetry updates. Runs as a daemon or a one-shot (`--once`) for cron. |
| `worker.sdl.yml` | Akash SDL manifest requesting 1× RTX 3090. The GPU placement attribute constrains bidding to matching providers. |
| `telemetry/telemetry.json` | Machine-readable fleet state (worker URLs, health). Rewritten every cycle. |
| `telemetry/index.html` | Live dashboard that renders the telemetry. |
| `run.sh` | start/stop/status wrapper for running as a background process without systemd. |
| `akash-lease-manager.service` | systemd unit for running as a managed service. |
| `crontab.example` | Cron entry to run a reconcile pass every minute. |
| `akash-lease-manager.env.example` | All configuration options. |

## How it works

```
                 every HEALTH_CHECK_INTERVAL (default 60s)
                                │
                 ┌─────────────▼──────────────┐
                 │  lease-manager.py reconcile │
                 └─────────────┬──────────────┘
        health probe each      │
        worker (HTTP+TCP)      │
                 ┌─────────────▼──────────────┐
          dead?  │  failures >= threshold ?   │── no ──► update telemetry
                 └─────────────┬──────────────┘
                          yes  │
            ┌────────────────────────────────────────┐
            │ akash-deploy.sh deploy                  │
            │  1. tx deployment create (worker.sdl)   │
            │  2. wait for bids                       │
            │  3. select cheapest RTX 3090 provider   │
            │  4. tx lease create + send-manifest     │
            │  5. lease-status -> worker URL          │
            └───────────────────┬─────────────────────┘
                                │ new worker_url
            close old lease ◄───┤
                                ▼
          update telemetry.json + index.html (+ optional webhook)
```

## Prerequisites

- Python 3.9+
- The Akash CLI (`provider-services`) installed and on `PATH`
- `jq`
- A funded Akash account with a key in the keyring (`provider-services keys ...`)
- A GPU worker container image referenced in `worker.sdl.yml`

## Setup

```bash
cd akash
cp akash-lease-manager.env.example .env
# edit .env: AKASH_KEY_NAME, image in worker.sdl.yml, pricing, etc.

# sanity-check the environment / chain config
./akash-deploy.sh check
```

If you already have a running worker, register it so the manager supervises it:

```bash
./lease-manager.py --add-worker https://my-worker.provider.akash.io \
  --add-dseq 1234567 --add-provider akash1...
```

Otherwise the manager will provision up to `DESIRED_WORKERS` automatically on the
first cycle.

## Running it

### As a background process (simplest)

```bash
./run.sh start      # launches in the background, writes state/lease-manager.pid
./run.sh status     # shows fleet state
./run.sh logs       # tail the log
./run.sh stop
```

### As a cron job (one pass per minute)

```bash
crontab akash/crontab.example   # edit paths first
```

`lease-manager.py --once` runs a single health-check + failover pass and exits,
which is the right shape for cron.

### As a systemd service

```bash
sudo cp akash-lease-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now akash-lease-manager
journalctl -u akash-lease-manager -f
```

## Testing without spending AKT

Set `DRY_RUN=true` (or pass `--dry-run`) to exercise the full loop —
health checks, "provisioning", telemetry rewrite — without touching the chain:

```bash
./lease-manager.py --once --dry-run
cat telemetry/telemetry.json
```

## Telemetry / frontend integration

Every cycle the manager rewrites `telemetry/telemetry.json` (the canonical
machine-readable fleet state) and regenerates `telemetry/index.html`. The HTML
also fetches the JSON client-side, so the dashboard stays current whether it is
served statically or regenerated server-side.

Point any existing frontend at `telemetry/telemetry.json` to consume the live
worker URLs (`worker_urls` is the flat list of healthy endpoints), or set
`TELEMETRY_WEBHOOK` to have the payload POSTed to your ingest endpoint as well.

## Configuration

See `akash-lease-manager.env.example` for every option. The most important:

- `HEALTH_CHECK_INTERVAL` (default `60`) — cadence in seconds.
- `FAILURE_THRESHOLD` (default `2`) — consecutive failures before replacement.
- `DESIRED_WORKERS` (default `1`) — fleet size the manager maintains.
- `AKASH_GPU_MODEL` (default `rtx3090`) — GPU model to lease.
- `AKASH_MAX_BID_PRICE` — price ceiling (uakt/block) for provider selection.
- `CLOSE_DEAD_LEASES` (default `true`) — stop paying for dead leases.
