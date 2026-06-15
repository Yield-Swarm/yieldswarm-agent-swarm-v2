# Arena Mutation System

This package implements the `/agents` Arena stack:

- 169 **Single-Origin Deity** manifests (`agents/system/manifests/deities/*.json`)
- 10,080 spawned charting agents with 420-second heartbeat tracking
- Metal-skin mutation pipeline based on performance
- Schnorr-style ZK-proof archival ledger for snapshots
- Live HTTP leaderboard API

## Quickstart

Generate manifests only:

```bash
python -m agents.system.bootstrap --generate-only --root-dir /workspace/agents
```

Run live API:

```bash
python -m agents.system.bootstrap --root-dir /workspace/agents --host 0.0.0.0 --port 8420
```

## API Endpoints

- `GET /health`
- `GET /arena/leaderboard?limit=100`
- `GET /arena/stats`
- `GET /arena/agents/<agent_id>`
- `POST /arena/heartbeat` with `{ "agent_id": "chart-agent-00001" }`
- `POST /arena/performance` with `{ "agent_id": "...", "arena_score": 77, "signal_precision": 0.8, "pnl_bps": 25 }`
- `POST /arena/mutate` with `{ "ratio": 0.1, "batch_size": 256 }`
- `POST /arena/archive` with `{ "note": "checkpoint" }`
