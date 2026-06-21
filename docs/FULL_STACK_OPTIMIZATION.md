# Full Stack Optimization — v1.0 Sitemap → Production

> Operator runbook for Pixel Termux, MacBook, and Akash deploy hosts.  
> First-time Pixel setup: `docs/PIXEL_TERMUX_SETUP.md`

## Sitemap layer map

| Layer | Route / System | Optimizer |
|-------|----------------|-----------|
| L0 Genesis | `/` Helix jacuzzi | `deploy/optimize-all.sh` → Helix health |
| L1 Council | `/council/status` | Helix + governance consensus |
| L2 Arena | `/arena` | Telemetry refresh |
| L3 Revenue | `/payments`, treasury | Great Delta + treasury adapters |
| L4 DePIN | Kairo drivers | `kairo/telemetry_daemon.py` |
| L5 Blockchain | Sovereign + Akash | `iteration-100/run.py`, `akash/bid-optimizer.py` |
| L6 Tech stack | Odysseus + Vault | `scripts/full-stack-optimize.sh` |

## One-command optimize (Pixel Termux)

```bash
cd ~/yieldswarm

# Full validate + tune (dry-run first)
DRY_RUN=1 ./scripts/full-stack-optimize.sh

# Live
./scripts/full-stack-optimize.sh
```

## Individual commands

```bash
# 1. Full stack
./scripts/full-stack-optimize.sh || bash deploy/optimize-all.sh

# 2. Akash H100 bid tune
python3 akash/bid-optimizer.py --gpu h100 --target-apr 40 --max-bid 85000 --auto

# 3. Sovereign core (daemon)
python3 iteration-100/run.py --quiet --target-apy 40 --seed-vault --interval 30 &

# 4. Helium + Nexus bridge
python3 kairo/telemetry_daemon.py --helium --nexus --halo2-prove &

# 5. Heat / VRAM monitor
nohup ./deploy/entrypoint.monitor.sh $$ > ~/monitor.log 2>&1 &
tail -f ~/monitor.log
```

## Verification

```bash
git status
python3 iteration-100/run.py --status
python3 akash/bid-optimizer.py --dry-run --gpu h100
akash query market lease list   # requires akash CLI + key
curl -s http://127.0.0.1:8080/api/helix/health | jq .
```

## Outputs

| Artifact | Path |
|----------|------|
| Bid recommendation | `akash/telemetry/bid-state.json` |
| Sovereign state | `dashboard/state.json` |
| Monitor log | `~/monitor.log` |
| Akash bid env | `akash/.env.bid-optimizer` |

## Environment flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `DRY_RUN` | `0` | Print commands only |
| `SKIP_AKASH` | `0` | Skip bid optimizer |
| `SKIP_SOVEREIGN` | `0` | Skip sovereign status |
| `START_MONITOR` | `0` | Launch hardware monitor |
| `TARGET_APY` | `40` | APR target % |
| `MAX_BID` | `85000` | uakt/block ceiling |

## v1.0 → now delta (optimized)

| Area | v1.0 | Optimized |
|------|------|-----------|
| Git | 50+ duplicate branches | `sync-environment-branches.sh` + clean main |
| Sovereign | Seed only | Iteration-100 self-healing + reinvest |
| Akash | Static bids | `bid-optimizer.py` dynamic 85k uakt |
| Kairo | Identity only | `telemetry_daemon.py` DePIN bridge |
| Security | Classical ECC | YSLR + Orchard ZK (when merged) |
| Monitor | None | `entrypoint.monitor.sh` thermal/VRAM |

## Related

- `scripts/yieldswarm-deploy.sh` — God Tasks 1-55 deploy
- `deploy/deploy-full-stack.sh` — phased D→A→C→B
- `STACK_STATUS.md` — health board
