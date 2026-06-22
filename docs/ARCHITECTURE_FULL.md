# YieldSwarm + Kairo — Full Stack Architecture (Helix DNA v2.1)

**Canonical architecture diagram** for the entire YieldSwarm + Kairo stack. Unifies ingress, integration, intelligence, DePIN, compute, on-chain economics, Vault injection, and the Tri-Layer helical model across all production branches.

| Audience | Section |
|----------|---------|
| Operators / deploy | [Deployment topology](#deployment-topology) · [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md) |
| Investors | [Investor view](#investor-view-simplified) |
| Engineers | [Full diagram](#canonical-diagram) · [Code map](#code--config-map) |

Related: [`SINGLE_PANE_OF_GLASS.md`](../SINGLE_PANE_OF_GLASS.md) (v2.1 RPC + Tri-Solenoid detail) · [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) · [`docs/TRI_LAYER_HELICAL_ARCHITECTURE.md`](TRI_LAYER_HELICAL_ARCHITECTURE.md) · [`DOMAINS.md`](../DOMAINS.md)

---

## Layer status

| Layer | Status | Notes |
|-------|--------|-------|
| **Users** | Active | Kairo drivers, traders, operators |
| **Edge / Presentation** | Staging ready | Vercel Next.js + Vite Arena/Portal + static dashboards |
| **Integration** | Live (code) | Express `:8080` + Kairo API `:8091` — needs live Akash lease for prod traffic |
| **Intelligence** | Needs GPU + Vault | Odysseus + Model Router + Sovereign Core need RTX 3090 lease |
| **Helix Chain** | Activated | YSLR phase — `./scripts/activate-helix.sh` |
| **Data / DePIN** | Alpha | Signed Kairo telemetry → Mandelbrot pipeline (dry-run capable) |
| **Compute** | Needs wallet | Akash: fund wallet + `deploy-bittensor.sh` or monolith SDL |
| **On-Chain** | Pre-mainnet | $APN + Great Delta 50/30/15/5 in code; contracts need mainnet deploy |
| **Secrets** | Bootstrap ready | Vault HCP seed + Akash Agent runtime injection — [`SECRETS.md`](../SECRETS.md) |
| **Tri-Layer Architecture** | Implemented | Greek D¹ · Eastern E¹ · Paradigm Shift PDs¹ env + pillar map |

---

## Six canonical data flows

| # | Flow | Path |
|---|------|------|
| **1** | Kairo driver telemetry | Driver app → signed payload → Mandelbrot / Tree of Life → Sovereign Core |
| **2** | Customer traffic | Customer → Vercel / UD → Express `:8080` → Akash workers + Model Router |
| **3** | Agent intelligence | 10,080 agents → Odysseus (LiteLLM + ChromaDB) → Mutation Engine → 169 Deities |
| **4** | Treasury emission | Sovereign loops → Great Delta Router → 50/30/15/5 splits → on-chain treasury |
| **5** | Helix → $APN | Helix Chain → Emission Router → unified wallet → $APN (Pump.fun) liquidity path |
| **6** | Secrets (all services) | HashiCorp Vault HCP → Vault Agent / AppRole → runtime inject → Express, Odysseus, Akash, Kairo |

---

## Canonical diagram

```mermaid
---
title: YieldSwarm + Kairo Full Stack — Helix DNA v2.1
config:
  theme: dark
  flowchart:
    curve: basis
---

flowchart TB
  %% ───────────── USERS ─────────────
  subgraph Users["USERS"]
    direction LR
    KairoDriver["Kairo Drivers<br/>DePIN nodes · Mapbox"]
    Customer["Customers / Traders<br/>Payments · Arena"]
    Operator["Operators / Admins<br/>Odysseus · Vault"]
  end

  %% ───────────── EDGE ─────────────
  subgraph Edge["EDGE / PRESENTATION"]
    direction TB
    UD["Unstoppable Domains<br/>yieldswarm.crypto · kairo.x"]
    CF["Cloudflare Worker<br/>gateway.yieldswarm.crypto"]
    Vercel["Vercel Next.js<br/>Payments · marketing"]
    Vite["Vite dApp<br/>Arena · Portal"]
    Static["Static dashboards<br/>$5M Vault · DePIN HQ"]
    UD --> CF
    UD --> Vercel
    Vercel --> Vite
    Vercel --> Static
  end

  %% ───────────── INTEGRATION ─────────────
  subgraph Integration["INTEGRATION LAYER"]
    Express["Express Backend :8080<br/>backend/src · /api/*"]
    KairoAPI["Kairo API :8091<br/>identity + signed telemetry"]
    RpcMesh["Alchemy RPC Mesh<br/>164 networks · /api/rpc/alchemy"]
    Express --> RpcMesh
  end

  %% ───────────── INTELLIGENCE ─────────────
  subgraph Intelligence["INTELLIGENCE LAYER"]
    direction TB
    Odysseus["Odysseus<br/>LiteLLM router + ChromaDB"]
    Agents["10,080 Mutated Agents<br/>120 cron shards"]
    Deities["169 Deity Council<br/>Kimiclaw consensus"]
    Router["RTX 3090 Model Router<br/>vLLM / Ollama aware"]
    Sovereign["Iteration-100 Sovereign Core<br/>self-healing loops"]
    Helix["Helix Chain<br/>YSLR · activate-helix.sh"]
    Mutation["Mutation Engine<br/>NFT + ZK proofs"]
    Odysseus --> Agents --> Mutation --> Deities
    Router --> Odysseus
    Sovereign --> Helix
  end

  %% ───────────── DATA / DEPIN ─────────────
  subgraph DataDePIN["DATA / DEPIN"]
    SignedTel["Signed driving telemetry"]
    Mandelbrot["Mandelbrot scheduler<br/>Tree of Life fractal backoff"]
    SignedTel --> Mandelbrot --> Sovereign
  end

  %% ───────────── COMPUTE ─────────────
  subgraph Compute["COMPUTE"]
    direction LR
    Akash["Akash RTX 3090/5090<br/>bittensor-miner · monolith"]
    Azure["Azure"]
    GCP["GCP"]
    RunPod["RunPod"]
    Vultr["Vultr"]
    Akash -.->|fallback| Azure
    Akash -.-> GCP
    Akash -.-> RunPod
    Akash -.-> Vultr
  end

  %% ───────────── ON-CHAIN ─────────────
  subgraph OnChain["ON-CHAIN"]
    APN["$APN · Pump.fun"]
    GreatDelta["Great Delta Emission Router<br/>50% / 30% / 15% / 5%"]
    Wallet["Unified multi-chain wallet<br/>EVM · Solana · TON"]
    GreatDelta --> Wallet --> APN
  end

  %% ───────────── SECRETS ─────────────
  subgraph Secrets["SECRETS — RUNTIME INJECTION ONLY"]
  Vault["HashiCorp Vault HCP<br/>yieldswarm/* KV"]
  Agent["Vault Agent / AppRole<br/>tmpfs /run/secrets"]
  Vault --> Agent
  end

  %% ───────────── TRI-LAYER ─────────────
  subgraph TriLayer["TRI-LAYER HELICAL ARCHITECTURE"]
    direction LR
    Greek["Greek D¹<br/>access · TEE · vaults"]
    Eastern["Eastern E¹<br/>feedback · recursive routing"]
    PDs["Paradigm Shift PDs¹<br/>ZK · mutation · trading"]
    Greek --> Eastern --> PDs
  end

  %% ───────────── USER FLOWS (6 arrows) ─────────────
  KairoDriver -->|"① signed telemetry"| SignedTel
  Customer -->|"② payments · arena"| Vercel
  Vercel --> CF --> Express
  CF --> Akash
  Agents -->|"③ agent turns"| Odysseus
  Sovereign -->|"④ treasury splits"| GreatDelta
  Helix -->|"⑤ emission"| GreatDelta
  Agent -->|"⑥ inject"| Express
  Agent --> Odysseus
  Agent --> Akash
  Agent --> KairoAPI

  Express --> Router
  Express --> Odysseus
  KairoAPI --> SignedTel
  Akash --> Router
  Akash --> KairoAPI
  TriLayer -.-> Intelligence
  TriLayer -.-> Integration

  classDef user fill:#1a1a2e,stroke:#00d4ff,color:#fff
  classDef edge fill:#16213e,stroke:#48dbfb,color:#fff
  classDef integrate fill:#0f3460,stroke:#00ff9f,color:#fff
  classDef intel fill:#1e3799,stroke:#f9ca24,color:#fff
  classDef compute fill:#0f3460,stroke:#feca57,color:#fff
  classDef chain fill:#1a1a2e,stroke:#ff6b6b,color:#fff
  classDef secret fill:#2d132c,stroke:#b83b5e,color:#fff
  classDef tri fill:#16213e,stroke:#9b59b6,color:#fff

  class KairoDriver,Customer,Operator user
  class UD,CF,Vercel,Vite,Static edge
  class Express,KairoAPI,RpcMesh integrate
  class Odysseus,Agents,Deities,Router,Sovereign,Helix,Mutation intel
  class Akash,Azure,GCP,RunPod,Vultr compute
  class APN,GreatDelta,Wallet chain
  class Vault,Agent secret
  class Greek,Eastern,PDs tri
```

---

## Investor view (simplified)

```mermaid
flowchart LR
  Users["Drivers · Traders · Operators"] --> Edge["17-domain edge<br/>Vercel + Cloudflare"]
  Edge --> Platform["Helix platform<br/>AI agents · DePIN · payments"]
  Platform --> Compute["Decentralized GPU<br/>Akash + cloud fallback"]
  Platform --> Chain["On-chain economics<br/>$APN · treasury splits"]
  Compute --> Revenue["Revenue<br/>fees · mining · marketplace"]
  Chain --> Revenue

  Vault["Vault-secured secrets"] -.-> Platform
  Vault -.-> Compute

  style Users fill:#1a1a2e,stroke:#00d4ff,color:#fff
  style Platform fill:#16213e,stroke:#00ff9f,color:#fff
  style Revenue fill:#0f3460,stroke:#feca57,color:#fff
```

---

## Deployment topology

Focused view for Akash + Azure + Vault operators (see [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md)).

```mermaid
flowchart TB
  subgraph operators["Operator hosts"]
    Termux["Termux / server<br/>live Akash deploy"]
    Azure["Azure Cloud Shell<br/>preflight only"]
    HCP["Vault HCP<br/>seed-secrets.sh"]
  end

  subgraph deploy["Deploy scripts"]
    Preflight["akash-preflight.sh"]
    Bittensor["deploy-bittensor.sh"]
    Monolith["deploy-to-akash.sh<br/>swarm-monolith"]
    Elevators["launch_swarm_elevators.sh<br/>14 book roots"]
    Gateway["wrangler gateway worker"]
  end

  subgraph akash["Akash mainnet"]
    SDL1["akash-bittensor-miner.sdl.yml<br/>RTX 3090"]
    SDL2["deploy-swarm-monolith.yaml<br/>3× RTX 3090"]
    Lease[".run/akash-lease.env"]
  end

  subgraph edge_live["Production edge"]
    GW["api.yieldswarm.crypto"]
    VER["yieldswarm.crypto"]
  end

  HCP -->|AppRole wrap| Bittensor
  Termux --> Preflight --> Bittensor --> SDL1 --> Lease
  Termux --> Monolith --> SDL2
  Termux --> Elevators
  Lease --> Gateway --> GW
  Azure --> Preflight
  VER --> GW

  classDef op fill:#1a1a2e,stroke:#00d4ff,color:#fff
  classDef ak fill:#0f3460,stroke:#feca57,color:#fff
  class Termux,Azure,HCP op
  class SDL1,SDL2,Lease ak
```

### Deployment status callouts

| Component | Script / SDL | Vault role | Gate |
|-----------|--------------|------------|------|
| Bittensor miner | `scripts/deploy-bittensor.sh` | `bittensor-runtime` | Funded `akash1…` wallet |
| Integration backend | `scripts/deploy-backend-akash.sh` | `integration-backend` | GHCR image pushed |
| Odysseus brain | `scripts/deploy-odysseus-vault-akash.sh` | `odysseus-runtime` | Vault wrap at deploy |
| Swarm monolith | `scripts/deploy-to-akash.sh` | `akash-runtime` | Phase 4 hardening |
| 14 elevators | `launch_swarm_elevators.sh` | `runtime/swarm` | `SWARM_API_KEY_PRIMARY` |
| CF gateway | `workers/gateway-yieldswarm-crypto.js` | Worker secrets | `AKASH_ORIGIN` from lease |

---

## Code & config map

| Layer | Primary paths |
|-------|----------------|
| Express `:8080` | `backend/src/` · `backend/src/routes/` |
| Kairo `:8091` | `kairo/backend/` · `agents/bittensor_miner.py` |
| Odysseus | `docker/Dockerfile.odysseus-brain` · `scripts/start-odysseus-brain.sh` |
| Model router | `api/yieldswarm_model_routing.py` · `services/akash_worker_sync.py` |
| Sovereign loops | `deploy/scripts/start-sovereign-loops.sh` |
| Helix Chain | `backend/src/adapters/helix.js` · `scripts/activate-helix.sh` |
| Mutation | `services/nft_mutation_engine.py` · `contracts/MutationController.sol` |
| Great Delta | `telemetry/great-delta/` · `SPLIT_*_BPS` env |
| Akash SDLs | `deploy/akash-bittensor-miner.sdl.yml` · `deploy/deploy-swarm-monolith.yaml` |
| Vault inject | `akash/templates/runtime.env.ctmpl` · `vault/scripts/seed-secrets.sh` |
| Tri-Layer env | `GREEK_LAYER__*` · `EASTERN_LAYER__*` · `ZK__*` in `.env.example` |
| 14 pillars | `config/helix/pillars.yaml` |
| Domains | `DOMAINS.md` · `config/domains/registry.json` |
| RPC mesh | `config/alchemy/christophers-first-app.json` · `backend/src/routes/rpc.js` |

---

## Swarm network overlay (14 book roots)

```mermaid
flowchart LR
  subgraph elevators["14 book-root elevators"]
    R1["root_01_genesis"] --> R14["root_14_mainnet"]
  end
  Mesh["NeuralMeshElevators<br/>services/neural_mesh/elevators.py"]
  Elisazos["yieldswarm.network<br/>Elisazos sync"]
  R1 --> Mesh
  R14 --> Mesh
  Mesh --> Elisazos
  Elisazos --> Express
```

See [`SWARM_ELEVATORS_LAUNCH.md`](SWARM_ELEVATORS_LAUNCH.md).

---

## What is production-ready vs. pending

```mermaid
quadrantChart
  title Layer readiness (higher = more ready)
  x-axis Code complete --> Live mainnet
  y-axis Low traffic --> High traffic
  quadrant-1 Scale next
  quadrant-2 Production
  quadrant-3 Build
  quadrant-4 Harden
  Edge: [0.75, 0.7]
  Integration: [0.7, 0.55]
  Vault: [0.8, 0.65]
  Helix: [0.85, 0.5]
  Intelligence: [0.65, 0.35]
  Compute: [0.55, 0.25]
  On-Chain: [0.6, 0.2]
  DePIN: [0.5, 0.3]
```

**Yellow path to green:** fund Akash wallet → `deploy-bittensor.sh` → set `AKASH_ORIGIN` on CF gateway → seed Vault HCP → `./launch_swarm_elevators.sh` → `npx vercel --prod`.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| v2.1 | 2026-06 | Canonical full-stack doc; deployment + investor views; status table |
| v2.0 | 2026-06 | `SINGLE_PANE_OF_GLASS.md` Tri-Solenoid + RPC mesh |
| v1.0 | 2026-05 | `docs/ARCHITECTURE.md` initial Helix mesh |
