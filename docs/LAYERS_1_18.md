# Layers 1–18 Architecture Map

Production layout for the 18-layer YieldSwarm stack.

```text
yieldswarm-agent-swarm-v2/
├── Cargo.toml                          # Workspace: swarm-core, yieldswarm-defi, data-ingestion
├── apps/
│   ├── swarm-core/                     # L1, L3–8, L10–12
│   └── web-dashboard/                  # L9 Kimi Klaw console
├── packages/
│   ├── contracts/
│   │   ├── Layer2_Solenoid.sol         # L2 Nexus / Helix / Shadow (EVM)
│   │   └── Layer13_HajiDeploy.sh       # L13 Haji Cloud deploy
│   └── infra/
│       ├── azure.tf                    # L14–15 Kyle AKS
│       └── data-ingestion/             # L16–18 Gold, crawler, Immunefi
├── crates/yieldswarm-defi/             # Phase 4 Jupiter + Orca + crawler
└── programs/                           # Solana: coordinator, cross_chain, arena
```

## Layer index

| Layer | Component | Path |
|-------|-----------|------|
| 1 | Rust Swarm OS orchestrator | `apps/swarm-core/src/main.rs` |
| 2 | Solenoid Solidity | `packages/contracts/Layer2_Solenoid.sol` |
| 3 | Multi-LLM connectors | `apps/swarm-core/src/connectors.rs` |
| 4 | Sharded agent registry (10k+) | `apps/swarm-core/src/main.rs` |
| 5 | ElizaOS runtime context | `apps/swarm-core/src/main.rs` |
| 6 | HuggingFace router | `apps/swarm-core/src/router.rs` |
| 7 | OpenAI retry wrapper | `apps/swarm-core/src/router.rs` |
| 8 | Kimi Klaw connector | `apps/swarm-core/src/connectors.rs` |
| 9 | Kimi Klaw dashboard | `apps/web-dashboard/pages/index.tsx` |
| 10 | SuperGrok integration | `apps/swarm-core/src/connectors.rs` |
| 11 | Gemini structured output | `apps/swarm-core/src/connectors.rs` |
| 12 | Iclash connector | `apps/swarm-core/src/connectors.rs` |
| 13 | Haji Cloud deploy | `packages/contracts/Layer13_HajiDeploy.sh` |
| 14 | Azure RM Terraform | `packages/infra/azure.tf` |
| 15 | Kyle Azure config | `packages/infra/azure.tf` (tags/vars) |
| 16 | Gold API feed | `packages/infra/data-ingestion/src/lib.rs` |
| 17 | Web crawler | `packages/infra/data-ingestion/src/lib.rs` |
| 18 | Immunefi scraper | `packages/infra/data-ingestion/src/lib.rs` |

## Build

```bash
git checkout feature/layers-1-to-18
cargo build --workspace
cargo test --workspace
```

## Run swarm-core

```bash
cargo run -p swarm-core
```

## Layer 9 dashboard

```bash
cd apps/web-dashboard && npm install && npm run dev
# POST /api/kimi-proxy on integration backend (port 8080)
```

## Layer 13 Haji deploy

```bash
export HAJI_DEPLOY_SECRET_TOKEN=...
chmod +x packages/contracts/Layer13_HajiDeploy.sh
./packages/contracts/Layer13_HajiDeploy.sh
```

## Layer 14–15 Azure

```bash
cd packages/infra
terraform init && terraform plan
```

Secrets: Vault paths per `docs/VAULT_ENV_INJECTION.md` — never commit tokens.
