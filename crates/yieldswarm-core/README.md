# yieldswarm-core (Phase 1)

Rust Swarm OS runtime — orchestrator, sharded agent registry, YSLR parser, 14-Council governance, Apollo Nexus.

Maps to master blueprint **feature/01-swarm-runtime-core** (Prompts 1, 4, 5, 36, 37, 38, 43).

## Build

```bash
cargo build -p yieldswarm-core
cargo test -p yieldswarm-core
```

## Modules

| Module | Prompt | Role |
|--------|--------|------|
| `orchestrator` | 1, 36, 43 | Swarm OS + 14-elevator scheduler + Apollo Nexus |
| `registry` | 4 | Sharded agent registry (10k+) |
| `orchestrator::elizaos` | 5 | ElizaOS integration trait |
| `parser` | 37 | YSLR language parser |
| `governance` | 38 | 14-Council governance engine |

## Run

```bash
cargo run -p yieldswarm-core
```
