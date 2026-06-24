# YSLR World Chain — Poseidon Delta Trident v3.05911111100

Single deploy map for domains, pentagramal agents, mining, Coinbase, and Termux.

## One-command mainnet

```bash
cp deploy/env/trident-mainnet.env.example deploy/env/trident-mainnet.env
# Fill UD_API_KEY, wallets, CDP keys, Azure SSH
npm run trident:deploy
```

## Domain map (Unstoppable Domains)

| Layer | Domain | Role |
|-------|--------|------|
| AI/DeFi | defiswarmagents.com (+ defisearmagents.com alias) | Kairos dApp |
| AI/DeFi | defiswarmagents.link | IPFS gateway |
| AI/DeFi | defiswarmagents.info | Analytics API |
| Consensus | helixpow.pw | Vehicle WSS ingest |
| Consensus | helixpow.blockchain | PoW registry |
| Consensus | helixpos.xyz / helixpow.xyz | Staking/mining UI |
| Consensus | starthelixchain.xyz | RPC multiplexer |
| Consensus | genushelix.blockchain | DID root |
| Treasury | yieldswarmofficial.pw / .blockchain | Yield UI + vault |
| Treasury | yieldswarmtreasury.pw / .blockchain | DAO + treasury |
| Codex | yslrcodex.com / .infi / yslecodex.link | Docs + IPFS CDN |

Wire: `npm run trident:wire-domains` (requires `UD_API_KEY`).

## Pentagramal agents (5000ms tick)

| Worker | Domain | Script |
|--------|--------|--------|
| Sentinel | helixpow.pw | `services/depin/vehicle-edge.mjs` |
| Nexus | lolminer :4067 | `scripts/mining/tandem-pow-launch.sh` |
| Liquidity | yieldswarmofficial.pw | `src/core/SovereignLoopManager.ts` |
| Treasury | yieldswarmtreasury.pw | Kairos freeze on tunnel silence |
| Codex | yslrcodex.com | SovereignLoopManager codex worker |

Start ring: `npm run trident:loops`

## Contracts (Base / YSLR World Chain)

- `contracts/KairosYieldEngine.sol` — multi-collateral yield + oracle
- `contracts/PoseidonDeltaTridentStakingVault.sol` — 13-asset PoS vault

## APIs

| Endpoint | Purpose |
|----------|---------|
| `GET /api/trident/marketplace-bridge` | Arena + mining + infra status |
| `GET/POST /api/trident/coinbase-swarm` | Coinbase portfolio / trades |
| `POST /api/iot/telemetry` | Vehicle DePIN ingest (helixpow.pw) |

## Platform launch

| Environment | Command |
|-------------|---------|
| **Termux** (no SWC) | `npm run termux:dev` or `npm run termux:backend` |
| **Termux proot** | `proot-distro login ubuntu` → `npm run dev` |
| **HP Windows #1** | `.\scripts\windows\launch-hp-dashboard.ps1 -Role frontend` |
| **HP Windows #2** | `.\scripts\windows\launch-hp-dashboard.ps1 -Role backend` |
| **Azure SSH** | `npm run azure:wire-ssh` |
| **Azure VMSS** | `npm run azure:vmss-mining` |

## Mining tandem (XMR/KAS/ZEPH/LTC/DOGE)

```bash
# Edit wallets in deploy/env/trident-mainnet.env
MINING_DRY_RUN=0 MINING_PAYOUT_ASSET=LTC npm run mining:tandem
```

## Realistic expectations

Mining ROI at $0.115/kWh is typically 12–24 months for efficient hardware, not 90-day 5× returns. Use Cherry/RunPod/Azure free credits for **compute burst**, not guaranteed yield projections.
