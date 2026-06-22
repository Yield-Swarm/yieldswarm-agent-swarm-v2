# Phase 2 Solenoid Architecture — EVM Contracts

Solidity layer interlocking with Phase 1 Rust/Anchor runtime (`services/nexus/`, `onchain/programs/helix/`, `onchain/programs/arena/`).

## Flow

```
[Agent Intent / State Change]
             │
             ▼
┌─────────────────────────┐
│   Nexus (EVM + Rust)    │  Governance authorization & routing
└─────────────────────────┘
             │
             ▼
┌─────────────────────────┐
│   Helix (EVM + Anchor)  │  Yield matrix execution & mining roots
└─────────────────────────┘
             │
             ▼
┌─────────────────────────┐
│   Shadow (EVM + Arena)  │  ZK blinded intent obfuscation
└─────────────────────────┘
```

## Contracts

| Layer | EVM Contract | Interface | Rust/Anchor counterpart |
|-------|--------------|-----------|-------------------------|
| 1 | `contracts/solenoid/Nexus.sol` | `contracts/interfaces/INexus.sol` | `services/nexus/`, Nexus Chain API |
| 2 | `contracts/solenoid/Helix.sol` | `contracts/interfaces/IHelix.sol` | `onchain/programs/helix/` |
| 3 | `contracts/solenoid/Shadow.sol` | `contracts/interfaces/IShadow.sol` | `onchain/programs/arena/` |

## Build (Foundry)

```bash
forge build
forge test --match-contract SolenoidArchitectureTest -vv
```

## Deploy sequence

1. Deploy `Nexus` with 14-Council governance address
2. Deploy `Helix(nexus, assetVault)` and `Shadow()`
3. Council calls `nexus.setCallerStatus(helixAddress, true)`
4. Council registers swarm executor agents via `registerNode`

## Integration notes

- **Nexus EVM** authorizes pipeline callers (`authorizedCallers`) — Helix must be whitelisted.
- **Helix EVM** packs vault + amount + payload before `routeCommand`; executor agents must expose matching `execute(bytes)` selector.
- **Shadow EVM** commit-reveal uses `keccak256(abi.encodePacked(salt, payload, msg.sender))` — aligns with ZK-Swarm batch headers on Shadow Chain.

See also: `docs/TRI_SOLENOID_ARCHITECTURE.md`, `docs/SOLENOID_PHASE2_EVM.md`
