# Akash GPU Lease Manager

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
