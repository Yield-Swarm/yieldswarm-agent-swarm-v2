# YieldSwarm Master Blueprint — 50 Prompts / 5 Phases

Canonical mapping of all 50 prompts into non-conflicting feature branches aligned with `yieldswarm-agent-swarm-v2` modules.

## Phase 1: Core Orchestration & Runtime

**Branch:** `cursor/swarm-runtime-core-93dd` · `feature/01-swarm-runtime-core`

| Prompt | Title |
|--------|-------|
| 1 | Rust core Swarm OS orchestrator (50+ LLM) |
| 4 | Rust agent registry with sharding (10k+) |
| 5 | ElizaOS integration layer |
| 36 | 14-elevator parallel pipeline scheduler |
| 37 | YSLR language parser (Rust) |
| 38 | 14-Council governance engine |
| 43 | Apollo Nexus orchestration core |

**Crate:** `crates/yieldswarm-core`

## Phase 2: On-Chain Architecture

**Branch:** `feature/02-solenoid-contracts`

| Prompt | Title |
|--------|-------|
| 2 | Nexus, Helix, Shadow solenoid Solidity |
| 20 | Abbey protocol integration |
| 39 | White Hat security audit layer |

**Paths:** `contracts/`, `backend/src/adapters/greatDelta.js`

## Phase 3: Global Multi-LLM API Connectors

**Branch:** `feature/03-llm-router-connectors`

| Prompt | Title |
|--------|-------|
| 3 | TypeScript connector library (Kimi, Gemini, SuperGrok, Haji) |
| 6 | HuggingFace model router |
| 7 | OpenAI wrapper + retry |
| 8 | Kimi Klaw connector |
| 10 | SuperGrok integration |
| 11 | Gemini structured output |
| 12 | Iclash connector |

**Paths:** `deploy/templates/llm-router/`, `src/infrastructure/odysseus-router.js`

## Phase 4: Cross-Chain DeFi & Data Ingestion

**Branch:** `feature/04-defi-ingestion-layer`

| Prompts | Title |
|---------|-------|
| 16–18 | Gold API, web crawler, Immunefi scraper |
| 21–27 | Solana DEX/Lending (Orca, Jupiter, Raydium, Meteora, Marinade, Solend, Maple) |
| 28–31 | CeFi (Nexo, Kraken, Coinbase, Blockchain.com) |
| 40–42 | Mining manager, TAO Bittensor, cross-chain bridge |

**Paths:** `services/cross_chain/`, `mining/`, `backend/src/adapters/dex.js`

## Phase 5: Math, DevOps & Recovery

**Branch:** `feature/05-math-infra-recovery`

| Prompts | Title |
|---------|-------|
| 9, 49 | Next.js frontend, monitoring dashboard |
| 14–15, 46–48 | Terraform, Azure, Linear+Cursor, Render+Vercel, Akash |
| 32–35 | Mandelbrot, Zeta resonance, harmonic field, neural viz |
| 44–45, 50 | Vault secrets, Unstoppable Domains, health + auto-recovery |

**Paths:** `deploy/`, `vault/`, `dashboard/`, `services/neon_store.py`

## Single Pane status

`GET /api/single-pane/prompts` reports artifact readiness per prompt.

Phase 1 prompts are **ready** when `cargo test -p yieldswarm-core` passes.
