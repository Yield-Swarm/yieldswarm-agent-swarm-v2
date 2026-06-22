# Swarm Elevator Launch — 14 Book Roots

Spawns persistent elevator daemons for each structural book root and binds the Elisazos swarm network layer across all 14 neural-mesh lanes.

## Environment

Bind keys in Cursor ENV or `.env` (see `.env.example`):

```bash
SWARM_API_KEY_PRIMARY=your_primary_cursor_env_key_here
SWARM_API_KEY_BACKEND=your_secondary_cursor_env_key_here   # optional
```

Fallbacks (documented only — prefer explicit `SWARM_API_KEY_*`):

| Variable | Fallback |
|----------|----------|
| `SWARM_API_KEY_PRIMARY` | `AGENTSWARM_MASTER_KEY` |
| `SWARM_API_KEY_BACKEND` | `YIELDSWARM_ROUTER_API_KEY` |

Vault path after `vault/scripts/seed-secrets.sh`: `yieldswarm/runtime/swarm`.

## Launch

```bash
chmod +x launch_swarm_elevators.sh
./launch_swarm_elevators.sh
```

Commands:

| Command | Action |
|---------|--------|
| `./launch_swarm_elevators.sh` | Start 14 elevators + Elisazos swarm |
| `./launch_swarm_elevators.sh status` | List processes and PID files |
| `./launch_swarm_elevators.sh stop` | SIGTERM all elevator/swarm PIDs |

## Book roots

Registry: `config/yieldswarm/book_roots.json`  
State mounts: `data/book_roots/<root_key>/state.json`

| Node | Book root | Neural-mesh pillar |
|------|-----------|-------------------|
| 1 | `root_01_genesis` | ingress |
| 2 | `root_02_ledger` | tee_verify |
| 3 | `root_03_consensus` | horizons |
| 4 | `root_04_telemetry` | precessional_oracle |
| 5 | `root_05_state` | agent_index |
| 6 | `root_06_networking` | depin_synth |
| 7 | `root_07_validation` | tesla_fleet |
| 8 | `root_08_memepool` | vault_inject |
| 9 | `root_09_execution` | akash_lease |
| 10 | `root_10_witness` | solenoid_anchor |
| 11 | `root_11_crypt` | renaissance |
| 12 | `root_12_solenoid` | great_delta |
| 13 | `root_13_mandelor` | sovereign_loop |
| 14 | `root_14_mainnet` | omni_apex |

## Python entrypoints

```bash
export PYTHONPATH=.
python3 -m yieldswarm.core --root root_01_genesis --node-id 1 --auth "$SWARM_API_KEY_PRIMARY" --once
python3 -m yieldswarm.network --swarm-mode elisazos --key "$SWARM_API_KEY_PRIMARY" --once
```

## Logs

| Process | Log file |
|---------|----------|
| Each elevator | `logs/elevator_<root>.log` |
| Elisazos swarm | `logs/elisazos_swarm.log` |
| PID files | `logs/pids/*.pid` |

## Integration

- Python mirror: `services/neural_mesh/elevators.py` (`NeuralMeshElevators.run_matrix`)
- Rust canonical scheduler: `crates/yieldswarm-core/src/orchestrator/elevator.rs`
- Single Pane prompt 7: `services/single_pane/registry.py`

## Verify

```bash
python3 -m unittest tests.test_swarm_elevators -v
ps aux | grep yieldswarm
```
