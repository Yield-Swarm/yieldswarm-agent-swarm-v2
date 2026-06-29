# SWARM 1: Physical Core & Edge Hardware Infrastructure

**Codename:** Sovereign Data Ranch  
**Site:** 10-acre Carrizozo, NM (`carrizozo-nm-10ac`)

## Subsystems

| Component | Driver | Config |
|-----------|--------|--------|
| 27 kW Tesla Solar | `drivers/solar_starlink.py` | `TESLA_SOLAR_API_URL` |
| Dual Starlink failover | `drivers/solar_starlink.py` | `STARLINK_*_API_URL` |
| 30× Z15 Pro Equihash ASICs | `drivers/z15_asic_monitor.py` | `Z15_HOST_01` … `Z15_HOST_30` |
| 4× Tesla vehicles (post-2016) | `drivers/tesla_fleet.py` | `TESLA_CLIENT_ID`, `TESLA_REFRESH_TOKEN`, `TESLA_FLEET_VINS` |
| Mac Mini + edge cluster | `engines/telemetry_engine.py` | `config/fleet-registry.json` |

## Quick start

```bash
make physical-core-monitor
# or
bash swarms/physical_core/scripts/monitor-matrix.sh
```

Output: `.data/physical-core/latest.json` (headless terminal broadcast + optional `PHYSICAL_CORE_INGEST_URL`).

## Helical handoff

Physical-core snapshots conform to `schemas/helical/physical-core.v1.json`. Vehicle `mmorpgBridge` fields feed SWARM 4; ASIC `aggregateHashrateGh` feeds SWARM 2.
