# IoT Hub — FWA_37KN9S-IoT Device Management

Central IoT management layer for physical devices on the home LAN, integrated with the Nexus swarm coordinator.

## Network

| Field | Value |
|-------|-------|
| Network ID | `FWA_37KN9S-IoT` |
| Gateway | Xfinity router @ `192.168.1.1` |
| Subnet | `192.168.1.0/24` |

## Registered Devices

| Device | ID | Address | Type |
|--------|-----|---------|------|
| Xfinity Router | `xfinity-gateway-001` | 192.168.1.1 | HTTP + ICMP |
| Apple TV | `appletv-living-room` | 192.168.1.161 | ICMP |
| Helium Hotspot | `helium-hnt-odu-0012` | HNT-ODU-0012 | Helium API / env keys |
| WiFi Extender (East) | `wifi-extender-east` | 192.168.1.171 | ICMP |
| WiFi Extender (West) | `wifi-extender-west` | 192.168.1.172 | ICMP |

Catalog: `config/iot-hub/devices.yaml`  
Network: `config/iot-hub/network.yaml`

## Scripts

### Register devices to FWA_37KN9S-IoT

```bash
export IOT_NETWORK_ID=FWA_37KN9S-IoT
export IOT_HUB_DRY_RUN=0   # set 0 on LAN for live probes
./scripts/iot-hub/register-devices.sh
```

Registers all catalog devices and enrolls each as a Nexus swarm agent (`iot_hub` solenoid).

### Monitor device status

```bash
# All devices
./scripts/iot-hub/monitor-devices.sh

# Single device
./scripts/iot-hub/monitor-devices.sh appletv-living-room
```

### Sync with swarm coordinator

```bash
./scripts/iot-hub/sync-coordinator.sh
```

Runs a full monitor sweep, publishes `device_status` to the Nexus bus, heartbeats the `iot_hub` solenoid, and writes overlay to `dashboard/state.json`.

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/iot/health` | GET | Liveness probe |
| `/api/iot/status` | GET | Registry + coordinator sync state |
| `/api/iot/devices` | GET | List registered devices |
| `/api/iot/devices/:id/check` | GET | Probe single device |
| `/api/iot/register` | POST | Register catalog + swarm agents |
| `/api/iot/monitor` | POST | Monitor all devices |
| `/api/iot/sync` | POST | Monitor + coordinator sync |

## Python CLI

```bash
python3 services/iot_hub/cli.py status
python3 services/iot_hub/cli.py register
python3 services/iot_hub/cli.py monitor
python3 services/iot_hub/cli.py sync
python3 services/iot_hub/cli.py device check appletv-living-room
```

## Swarm Coordinator Integration

- **Nexus solenoid** `iot_hub` (id 4) in `config/nexus/solenoids.yaml`
- **Messaging bus** topics: `device_heartbeat`, `device_status`
- **Agent slots**: each IoT device registers via `POST /api/nexus/agents/register` equivalent
- **State files**: `.run/iot-registry.json`, `.run/iot-coordinator-sync.json`

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `IOT_NETWORK_ID` | `FWA_37KN9S-IoT` | Network identifier |
| `IOT_HUB_DRY_RUN` | `1` | Simulate probes when off-LAN |
| `IOT_HUB_URL` | — | Hub endpoint for Vault injection |
| `DEPIN_HELIUM_HOTSPOT_KEYS` | `[]` | JSON array for HNT-ODU-0012 status |
| `IOT_APPLETV_IP` | `192.168.1.161` | Apple TV address |
| `IOT_XFINITY_GATEWAY_IP` | `192.168.1.1` | Gateway address |

## Vault

Policy: `vault/policies/iot-hub-runtime.hcl`  
Paths: `yieldswarm/data/iot/devices`, `yieldswarm/data/iot/network`

```bash
export IOT_NETWORK_ID=FWA_37KN9S-IoT
export IOT_APPLETV_IP=192.168.1.161
export IOT_XFINITY_GATEWAY_IP=192.168.1.1
./vault/scripts/seed-secrets.sh
```

## Architecture

```
Physical LAN (FWA_37KN9S-IoT)
  ├── 192.168.1.1    Xfinity Router
  ├── 192.168.1.161  Apple TV
  ├── HNT-ODU-0012   Helium Hotspot
  └── .171 / .172    WiFi Extenders
           │
           ▼
    services/iot_hub/
      registry → monitor → coordinator
           │
           ├── Nexus bus (device_status)
           ├── Nexus registry (iot_hub agents)
           └── dashboard/state.json overlay
```
