# Physical Control Center

Unified **single pane of glass** for local hardware: mining ASICs, phone-wall PoE grid, Mac Mini orchestrator, Termux edges, and push telemetry from laptops.

**Stack:** Python 3 · asyncio · FastAPI · WebSockets

## Quick start

```bash
cd yieldswarm-agent-swarm-v2

# Install daemon deps
npm run control-center:install
# or: pip3 install -r services/control_center/requirements.txt --break-system-packages

# Configure devices (edit LAN IPs)
mkdir -p config/control-center
cp config/control-center/devices.yaml.example config/control-center/devices.yaml

# Start daemon :8095
npm run control-center:dev

# Open dashboard (Samsung primary display — maximize browser)
# http://127.0.0.1:8095/
```

## API

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/` | Multi-display dashboard (WebSocket client) |
| `GET` | `/health` | Liveness |
| `GET` | `/api/state` | Full infrastructure snapshot JSON |
| `POST` | `/api/telemetry/device-stats` | Edge worker push (phone farm, laptop) |
| `WS` | `/api/ws/stream` | Real-time broadcast |

### Push telemetry from edge stub

```bash
curl -s -X POST http://127.0.0.1:8095/api/telemetry/device-stats \
  -H 'Content-Type: application/json' \
  -d '{
    "device_id": "phone-shelf-b-03",
    "cpu_percent": 38.2,
    "memory_percent": 55.0,
    "network_ok": true,
    "hash_rate_mhs": 0,
    "latency_ms": 12,
    "kind": "edge-phone"
  }' | jq .
```

## Physical layout

### Dual-display (Samsung + Vizio)
- Route **video** to Samsung via HDMI/dual-head GPU.
- Route **audio** to Vizio via 3.5mm/optical or system sound output selector.
- Open `http://<mac-mini-ip>:8095/` fullscreen on Samsung.

### Phone wall + TP-Link PoE
- PoE switch → PoE-to-USB adapters per shelf.
- Each phone pushes `POST /api/telemetry/device-stats` or appears in `devices.yaml` for ICMP poll.

### Central station
- Run daemon on always-on Mac Mini / laptop.
- Set `SWARM_ID_ENCRYPTION_KEY` in `.env` for production encrypted PoW/PoWUI IDs.

## Failsafe behavior

- Each device poll is isolated — timeout → `OFFLINE`, daemon continues.
- WebSocket clients auto-reconnect in dashboard UI.
- Aggregation loop catches all exceptions per tick.

## Test

```bash
npm run control-center:test
python3 -m unittest tests.test_control_center -v
```
