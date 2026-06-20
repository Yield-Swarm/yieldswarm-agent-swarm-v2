# HQ Visual Splatter — God Task #10

Reference material for **Gamma pitch deck** layout optimization.

## Source assets (secure — do not commit secrets)

- Balcony ops recon photos (HQ sky/building views) — attach to Gamma deck manually
- `SecretProd_c0d9.pdf` — production config reference; keep in Vault/upload storage only

## Generated / repo assets

| Asset | Use |
|-------|-----|
| `assets/jacuzzi-helix-hero.png` | Site hero — energy flow metaphor |
| `assets/jacuzzi-helix-l3-revenue.png` | Z15 revenue fountain (L3) |
| `assets/helix-solenoid.svg` | 14-lane diagram for deck slides |
| `dashboard/depin-hq-sync.html` | HQ multi-display DePIN mock |

## Workflow

1. Import balcony photos into Gamma as "Admin HQ — Colorado Execution" slide
2. Overlay `helix-solenoid.svg` on DePIN yield slide
3. Export PDF → `docs/pitch/` (gitignored if contains sensitive layout notes)

```bash
./scripts/god-task.sh 10
```
