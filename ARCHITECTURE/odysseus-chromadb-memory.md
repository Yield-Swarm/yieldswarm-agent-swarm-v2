# Odysseus ChromaDB Memory Mesh

Odysseus is the central long-term memory layer for YieldSwarm AgentSwarm OS.
All 10,080 mutated agents read and write durable state through the same memory
contract, whether they run in OpenClaw, Akash leases, Vercel/Azure workers, or
local admin nodes.

## Memory Collections

The `agents/odysseus_memory.py` adapter creates four ChromaDB collections:

- `yieldswarm_odysseus_agent_mutations` - mutation events, versions, strategies,
  and outcomes for mutated agents.
- `yieldswarm_odysseus_performance_history` - per-agent and per-shard metrics.
- `yieldswarm_odysseus_deity_identities` - 169 Deity identity and authority
  records, including the 14-Council.
- `yieldswarm_odysseus_cross_agent_learnings` - reusable learnings that any
  agent can recall before acting.

`ODYSSEUS_CHROMA_COLLECTION_PREFIX` can be changed per environment, but every
worker in the same mesh should use the same prefix.

## Agent Access Contract

Each sharded agent uses the canonical ID format:

```text
ys-shard-{shard_id:03d}-agent-{shard_index:03d}
```

With the default shard settings:

```text
120 shards x 84 agents = 10,080 agents
```

Agents should call the adapter methods instead of writing local-only memory:

```python
from odysseus_memory import build_agent_id, get_memory

memory = get_memory()
agent_id = build_agent_id(shard_id=7, shard_index=12)

memory.record_mutation(agent_id=agent_id, mutation={...}, outcome={...})
memory.record_performance(agent_id=agent_id, metric_name="roi", metric_value=1.18)
learnings = memory.recall("akash provider migration", agent_id=agent_id)
```

## Deity Identity Bootstrap

Run the bootstrapper once per memory namespace:

```bash
python agents/bootstrap-deity-identities.py
```

It upserts Kimiclaw, the 14-Council seats, and all 169 Deity identities into
`deity_identities`.

## Cross-Worker Synchronization

Every Odysseus instance keeps an append-only sync outbox. Workers can run a peer
endpoint and gossip changes with `ODYSSEUS_SYNC_PEERS`.

Start the sync endpoint on each Akash or multi-cloud node:

```bash
python agents/odysseus-sync-service.py
```

The service exposes:

```text
POST /odysseus/memory/sync
```

Requests and responses contain new outbox events plus cursors. Imported events
are upserted idempotently into ChromaDB and appended locally so multi-hop peers
can receive the same learnings. Set `ODYSSEUS_SYNC_TOKEN` on every node to
require a bearer token for sync writes.

## ChromaDB Modes

- `ODYSSEUS_CHROMA_MODE=http` connects to a shared ChromaDB server.
- `ODYSSEUS_CHROMA_MODE=persistent` uses local ChromaDB persistence for a single
  node or local OpenClaw instance.
- `ODYSSEUS_CHROMA_MODE=jsonl` keeps the same adapter API with JSONL storage for
  tests and bootstrap environments.

Production Akash workers should use `http` mode against the shared ChromaDB
service and enable sync peers for resilience across clouds.
