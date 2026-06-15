# YieldSwarm — Single Pane of Glass

Canonical architecture visual: **Helix Chain + 35-Layer Neural Mesh + 17 Domains**.

See also: `docs/ARCHITECTURE.md` (investor view + repo anchors) · `docs/HELIX_SINGLE_PANE.md` (layer detail).

---

```mermaid
---
title: YieldSwarm Helix Chain + 35-Layer Neural Mesh (Single Pane of Glass)
config:
  theme: dark
---

flowchart TB
    subgraph Ingress ["USER / INGRESS LAYER (17 Domains)"]
        Vercel["Vercel (Next.js)<br/>Payments + Frontend dApp"]
        Render["Render<br/>Integration Backend API"]
        Akash["Akash (RTX 3090)<br/>GPU Workers + Bittensor Miners"]
        MultiCloud["Azure / GCP / RunPod<br/>Multi-cloud fallback"]
        Domains["Unstoppable Domains<br/>17 custom domains"]
    end

    Ingress --> Edge["17-DOMAIN EDGE ROUTING + API LAYER<br/>(9 Frontend Zones + 8 Backend Fluid Compute)"]

    Edge --> Helix["HELIX CHAIN / 35-LAYER NEURAL MESH CORE"]

    subgraph HelixCore ["35-Layer Neural Mesh"]
        direction TB
        L1_3["Layers 1–3: Foundational Ingress + TEE + JPL HORIZONS"]
        L4_6["Layers 4–6: Precessional Oracle + Agent Performance + Pre-load Models"]
        L7_9["Layers 7–9: Multi-Cloud DePIN + Akash Lease Manager + Vault Injection"]
        L10["Layer 10: MASTER SOLENOID ANCHOR (Core Orchestration)"]
        L11_13["Layers 11–13: Renaissance Polymath Refiners<br/>(Tesla + da Vinci + Michelangelo)"]
        L14_16["Layers 14–16: Sub-Space Telemetry + Sovereign Self-Healing Loops"]
        L17_19["Layers 17–19: Cross-Epoch Bridges + Great Delta Emission Router (50/30/15/5)"]
        L20_21["Layers 20–21: Quantum-Resistant Vectors + Treasury Rebalancer"]
        L22["Layer 22: DIMENSIONAL SINGULARITY ANCHOR"]
        L23_28["Layers 23–28: Agent Mutation Engine + 10,080 Agents + 169 Deities"]
        L29_31["Layers 29–31: Odysseus Central Memory (ChromaDB) + RTX 3090 Model Router"]
        L32_34["Layers 32–34: Kairo Driver Pipeline (Crypto Identity + Signed Telemetry)"]
        L35["Layer 35: OMNI APEX — Sovereign Core + $5M Vault Telemetry + Agent Marketplace"]
        L1_3 --> L4_6 --> L7_9 --> L10 --> L11_13 --> L14_16 --> L17_19 --> L20_21 --> L22 --> L23_28 --> L29_31 --> L32_34 --> L35
    end

    Helix --> L1_3
    L35 --> Intelligence["INTELLIGENCE + EXECUTION LAYER<br/>Odysseus • Model Router • Sovereign Runtime • Great Delta • Kairo Pipeline"]

    Intelligence --> Secrets["SECRETS + INFRA LAYER<br/>HashiCorp Vault (Runtime Injection) • Multi-Cloud • Akash RTX 3090 • GHCR"]

    Secrets --> Revenue["REVENUE + PAYMENTS LAYER<br/>Payments (Square + Wise + Web3) • 1% Fee + 2× Driver Pay • Agent Marketplace • Holographic Coffee Variables • $5M Vault Dashboard"]

    style Ingress fill:#1a1a2e,stroke:#00d4ff
    style HelixCore fill:#16213e,stroke:#00ff9f
    style Intelligence fill:#0f3460,stroke:#ff6b6b
    style Secrets fill:#1a1a2e,stroke:#feca57
    style Revenue fill:#16213e,stroke:#48dbfb
```

---

## Legend

| Term | Meaning |
|------|---------|
| **Helix Chain** | Ascending computational solenoid — data accelerates through layers |
| **35-Layer Neural Mesh** | Full sovereign stack from ingress to Omni Apex |
| **17 Domains** | 9 frontend zones + 8 backend fluid compute |
| **Layer 10** | Master Solenoid Anchor — core orchestration |
| **Layer 22** | Dimensional Singularity Anchor |
| **Layer 35** | Omni Apex — sovereign core + marketplace |

## Data flow

**Signed Kairo Telemetry → Mandelbrot / Tree of Life → Sovereign Loops → Treasury (50/30/15/5)**

## Live surfaces

| Pane | URL / command |
|------|----------------|
| Helix | `GET /api/helix/status` · `./scripts/activate-helix.sh` |
| Arena | `/arena?workers=<lease-uri>` |
| Council | `/council/status.html` |
| Sovereign | `GET /api/sovereign/state` |
