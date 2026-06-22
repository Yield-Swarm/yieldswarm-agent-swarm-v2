# Azure VMSS Autoscale — YieldSwarm Strategy

Implements the recommended YieldSwarm autoscale stack: **predictive + reactive metric rules**, **OldestVM scale-in**, **scheduled business-hours profiles**, and optional **GPU custom metrics**.

## Quick start

```bash
az login
cp deploy/azure-mainnet.env.example deploy/azure-mainnet.env
# Edit thresholds, min/max, predictive mode

./scripts/azure/configure-vmss-autoscale.sh --env deploy/azure-mainnet.env
```

Preview without Azure changes:

```bash
./scripts/azure/configure-vmss-autoscale.sh --dry-run
```

## What gets configured

| Layer | Setting | Default |
|-------|---------|---------|
| Reactive | Scale out when CPU > 75% (10m avg) | +1 instance, 5m cooldown |
| Reactive | Scale in when CPU < 30% (10m avg) | −1 instance, 10m cooldown |
| Predictive | Forecast-only mode | 15m lookahead (`PT15M`) |
| Schedule | Business hours Mon–Fri 08:00–18:00 CST | 4 instances (2–8 range) |
| Scale-in | `OldestVM` policy | Protects newest agent sessions |
| Bounds | CPU VMSS min/max | 2 / 10 |
| GPU VMSS | Separate autoscale setting | 1 / 6 (if VMSS exists) |

### Predictive autoscale lifecycle

1. **Week 1** — Run with `AZURE_AUTOSCALE_PREDICTIVE_MODE=ForecastOnly` (default). Compare portal forecast charts to actual load.
2. **After ~7–15 days** — Switch to `Enabled` once predictions match your daily agent queue pattern.
3. **Scale-in** — Still handled by reactive rules; predictive only scales **out**.

```bash
# Enable proactive scaling after validation
AZURE_AUTOSCALE_PREDICTIVE_MODE=Enabled ./scripts/azure/configure-vmss-autoscale.sh
```

## Instance protection (long-running agents)

Mark VMs running inference/training so they are never scaled in:

```bash
az vmss vm update \
  -g YieldSwarm \
  -n vmss_gpu_yieldswarm \
  --instance-id 0 \
  --protect-from-scale-in true
```

Combine with **OldestVM** scale-in policy so idle oldest nodes are removed first.

## GPU custom metrics

Host-level `Percentage CPU` is insufficient for GPU/agent workloads. Install in-guest metrics:

```bash
# On each GPU node (or fleet-wide)
./scripts/azure/gpu-metrics-agent.sh --fleet --env deploy/azure-mainnet.env
```

Then create a **Data Collection Rule** in Azure Monitor to ingest DCGM Prometheus metrics (`DCGM_FI_DEV_GPU_UTIL`, memory, power) into namespace `YieldSwarm/GPU`.

Add custom-metric autoscale rules in the portal or ARM — CLI support for custom metric conditions is limited. Recommended fallback metrics:

- Agent queue depth from your orchestration API
- `DCGM_FI_DEV_GPU_UTIL` average > 80% for 5m → scale out
- Queue depth = 0 for 15m → scale in

## Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print planned `az` commands |
| `--replace` | Delete and recreate autoscale settings + rules |
| `--cpu-only` | Skip GPU VMSS autoscale |
| `--gpu-only` | Skip CPU VMSS autoscale |
| `--skip-schedule` | Skip business-hours profile |

## Integration with fleet deploy

```bash
# Full deploy + autoscale
./scripts/azure/deploy-vmss-fleet.sh --env deploy/azure-mainnet.env --autoscale

# Autoscale only (after fleet is running)
npm run deploy:azure:autoscale
```

## Environment variables

See `deploy/azure-mainnet.env.example` — Autoscale section.

Key tunables:

```bash
AZURE_AUTOSCALE_SCALE_OUT_CPU=75
AZURE_AUTOSCALE_SCALE_IN_CPU=30      # wide gap prevents flapping
AZURE_AUTOSCALE_MAX=10                 # hard cost cap
AZURE_VMSS_SCALE_IN_POLICY=OldestVM
AZURE_AUTOSCALE_PREDICTIVE_MODE=ForecastOnly  # Disabled | ForecastOnly | Enabled
```

## Portal validation

After configuration:

1. VMSS → **Scaling** → verify custom autoscale rules and predictive chart
2. **Monitor** → **Autoscale** → confirm `autoscale-vmss_3cf043e` is enabled
3. Set alerts on autoscale actions and failed scale operations

```bash
az monitor autoscale show-predictive-metric \
  -g YieldSwarm -n autoscale-vmss_3cf043e
```

## Related

- `docs/AZURE_VMSS_FLEET_DEPLOY.md` — SSH + scale + bootstrap
- `docs/AZURE_MAINNET_VMSS_TOPOLOGY.md` — network topology
- [Predictive autoscale docs](https://learn.microsoft.com/azure/azure-monitor/autoscale/autoscale-predictive)
