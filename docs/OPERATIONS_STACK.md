# YieldSwarm Operations Stack

Operational view of the live production stack — agent orchestration, mainnet core, cloud GPU fleet, edge miners, and observability. Complements the 35-layer neural mesh in [`ARCHITECTURE.md`](ARCHITECTURE.md).

**Edit this file directly on GitHub** — Mermaid renders in the preview tab.

---

## Full stack (operator view)

```mermaid
---
title: YieldSwarm AgentSwarm OS v2 — Operations Stack
config:
  theme: dark
  flowchart:
    curve: basis
---

flowchart TB
    subgraph Agents ["AGENT SWARM LAYER"]
        direction LR
        Kimmy["Kimmy<br/>Consensus Council"]
        Cursor["Cursor<br/>Cloud Agents + MCP"]
        Odysseus["Odysseus<br/>Memory + LiteLLM"]
        Kira["Kira<br/>Strategy / SuperGrok"]
        Consensus["Kimiclaw<br/>Consensus + Governance"]
    end

    subgraph Core ["CORE + MAINNET"]
        direction LR
        GitHub["GitHub Mono-repo<br/>yieldswarm-agent-swarm-v2"]
        Zeeve["Zeeve Mainnet<br/>Node Ops · 3% profit share"]
        Helix["Helix Chain<br/>Genesis + Treasury"]
        Trident["Trident Protocol<br/>WS :8095 orchestrator"]
    end

    subgraph Compute ["COMPUTE POWER"]
        direction TB
        Cherry["Cherry Servers<br/>Credits + bare metal"]
        Azure["Azure<br/>VM + ACI dashboard"]
        subgraph GPUFleet ["GPU Fleet"]
            RunPod["RunPod<br/>H100 / H200"]
            Akash["Akash<br/>DePIN leases"]
            Vast["Vast.ai<br/>Spot GPU"]
            Salad["Salad Cloud<br/>Budget PoWUoI"]
        end
    end

    subgraph Mining ["MINING + PoWUoI"]
        direction LR
        PoWUoI["PoWUoI Pools<br/>PRL · KRX · ZANO · QTC · IRON · TON"]
        SRBMiner["SRBMiner<br/>Pearl / ETC / ERG switcher"]
        ASIC["On-prem ASICs<br/>S19×3 · L7 · Z15 fleet"]
    end

    subgraph Edge ["EDGE NODES"]
        direction TB
        iPhones["AT&T Vista Farm<br/>700 phones · VLAN 20"]
        Termux["Termux Edge<br/>TCL 10 NXT · new iPhones"]
        XMRig["XMRig 8-slot<br/>TPIT-TERMUX workers"]
        LG07["Antminer L7<br/>Scrypt lane"]
    end

    subgraph Ops ["OPS + INTEGRATIONS"]
        direction LR
        Prom["Prometheus<br/>+ Grafana"]
        Vault["HashiCorp Vault<br/>Secret injection"]
        APIs["API Mesh<br/>Alchemy · Salad · Akash · Tesla"]
        Dashboard["Trident Dashboard<br/>npm run dashboard"]
    end

  Agents --> Core
  Core --> Compute
  Core --> Mining
  Core --> Edge
  Compute --> Mining
  Edge --> Mining
  Mining --> Ops
  Compute --> Ops
  Core --> Ops
  Trident --> Dashboard
  XMRig --> Prom
  PoWUoI --> Prom

  classDef agent fill:#1a1a2e,stroke:#00d4ff,color:#fff
  classDef core fill:#0f3460,stroke:#00ff9f,color:#fff
  classDef compute fill:#16213e,stroke:#48dbfb,color:#fff
  classDef edge fill:#1a1a2e,stroke:#feca57,color:#fff
  classDef ops fill:#16213e,stroke:#ff6b6b,color:#fff

  class Agents,Kimmy,Cursor,Odysseus,Kira,Consensus agent
  class Core,GitHub,Zeeve,Helix,Trident core
  class Compute,Cherry,Azure,GPUFleet,RunPod,Akash,Vast,Salad compute
  class Edge,iPhones,Termux,XMRig,LG07,Mining,PoWUoI,SRBMiner,ASIC edge
  class Ops,Prom,Vault,APIs,Dashboard ops
```

---

## Detail: edge + telemetry path

```mermaid
flowchart LR
    subgraph Phone ["Termux (TCL / iPhone)"]
        T1["tmux mining session<br/>8 × XMRig"]
        T2["xmrig-status.sh<br/>ports 8081–8088"]
        T3[".data/termux-xmrig/latest.json"]
    end

    subgraph Trident ["yieldswarm-core"]
        WS["orchestrator.js<br/>:8095"]
        Bridge["telemetry-bridge.js"]
        Dash["dashboard-listener.js"]
    end

    subgraph Scrape ["Prometheus"]
        Exp["xmrig-prometheus-exporter.sh"]
        Graf["Grafana panel"]
    end

    T1 --> T2 --> T3
    T3 --> Bridge
    WS --> Bridge --> Dash
    T2 --> Exp --> Graf
```

---

## Repo anchors

| Layer | Component | Repo path |
|-------|-----------|-----------|
| Agent swarm | Trident orchestrator | `yieldswarm-core/src/orchestrator.js` |
| Agent swarm | Profitability switcher | `yieldswarm-core/src/swarm-switcher.js` |
| Mainnet | Helix genesis | `scripts/activate-helix.sh`, `backend/src/adapters/helix.js` |
| Zeeve | Profit share (3%) | `services/business/profit_share.py` |
| Cherry | Credits packet export | `scripts/cherry-servers/export-cloud-specs.sh` |
| Azure | VM dashboard runbook | `docs/AZURE_VM_DASHBOARD.md` |
| GPU fleet | Akash SDL + deploy | `deploy/akash/`, `make deploy-akash-europlots` |
| GPU fleet | Salad $100 deploy | `scripts/salad/deploy-pouw-budget.sh` |
| PoWUoI | Pool registry + launcher | `config/mining/pouw-coins.json`, `mining/pouw_launcher.py` |
| Pearl | SRBMiner deploy | `scripts/mining/deploy-pearl-srbminer.sh` |
| Edge | Termux XMRig 8-slot | `scripts/termux/xmrig-start-8.sh` |
| Edge | Termux fleet daemon | `scripts/termux/mining-daemon.sh` |
| Ops | Prometheus stack | `deploy/monitoring/`, `make monitoring-up` |
| Ops | Vault injection | `docs/VAULT_AKASH_RUNTIME.md` |

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 35-layer neural mesh + investor view |
| [`YieldSwarm_Full_Stack_Deployment_Overview.md`](YieldSwarm_Full_Stack_Deployment_Overview.md) | Zeeve outreach + 14-pillar summary |
| [`MINING_INFRASTRUCTURE.md`](MINING_INFRASTRUCTURE.md) | Mining roots + pool wiring |
| [`CHERRY_SERVERS_CLOUD_SPECS_RESEARCH.md`](CHERRY_SERVERS_CLOUD_SPECS_RESEARCH.md) | Cherry credits packet |
| [`outreach/email-zeeve-ravi.md`](outreach/email-zeeve-ravi.md) | Zeeve mainnet call prep |
