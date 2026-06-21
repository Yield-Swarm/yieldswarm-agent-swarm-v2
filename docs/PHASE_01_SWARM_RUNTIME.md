# Phase 1: Core Orchestration & Runtime

**Branch:** `cursor/swarm-runtime-core-93dd` (maps to `feature/01-swarm-runtime-core`)

Production Rust engine for high-throughput multi-agent orchestration.

## Prompt coverage

| Prompt | Module | Path |
|--------|--------|------|
| 1 | Swarm OS orchestrator (50+ LLM instances) | `orchestrator/mod.rs` |
| 4 | Sharded agent registry (10k+) | `registry/mod.rs` |
| 5 | ElizaOS integration layer | `orchestrator/elizaos.rs` |
| 36 | 14-elevator parallel scheduler | `orchestrator/elevator.rs` |
| 37 | YSLR language parser | `parser/yslr.rs` |
| 38 | 14-Council governance | `governance/council.rs` |
| 43 | Apollo Nexus orchestration core | `orchestrator/apollo.rs` |

## Layout

```text
crates/yieldswarm-core/
├── Cargo.toml
└── src/
    ├── lib.rs              # SwarmMessage + module exports
    ├── id.rs               # Message id generation
    ├── registry/           # Prompt 4
    ├── orchestrator/       # Prompts 1, 5, 36, 43
    ├── parser/             # Prompt 37
    └── governance/         # Prompt 38
```

## Build & test

```bash
cargo run -p swarm-core              # particle accelerator (primary)
cargo build -p yieldswarm-core
cargo test -p yieldswarm-core
make swarm-accelerator
```

## Integration with existing stack

| Layer | Integration |
|-------|-------------|
| Python YSLR queue | `services/yslr/queue.py` — enqueue from Node; parse/route in Rust |
| Neural mesh elevators | `services/neural_mesh/elevators.py` — Python mirror; Rust is canonical scheduler |
| 14-Council | Aligns with `config/helix/pillars.yaml` (14 pillars) |
| Backend API | Future: FFI or gRPC from `backend/src/adapters/` |

## Apollo Nexus flow

```text
YSLR frame → parse_yslr() → ElevatorScheduler (14 parallel)
          → CouncilEngine.decide() → SwarmOrchestrator.dispatch()
          → ElizaOsBridge.execute_turn()
```

## Next phases (branches)

See `docs/MASTER_BLUEPRINT_PHASES.md` for Phases 2–5 branch map.
