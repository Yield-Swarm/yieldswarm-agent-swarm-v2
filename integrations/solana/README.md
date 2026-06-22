# integrations/solana

TypeScript hooks for **Helix Solana cross-chain treasury** + **521-agent swarm ops**.

> **Important:** On-chain programs already exist in `programs/cross_chain` and `programs/swarm_ops`
> with production program IDs in `Anchor.toml`. Do **not** replace them with generic god-prompt
> placeholders (`CrossChainTreasury111...`).

## Program IDs

| Program | ID |
|---------|-----|
| cross_chain | `9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt` |
| swarm_ops | `6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz` |
| coordinator | `DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p` |

## Hooks

| Hook | Purpose |
|------|---------|
| `useCrossChainYield` | Treasury + bridge events (re-export from `sdk/helix`) |
| `useSwarmAgent` | Register agents via `/api/nexus/agents/register` |
| `useYieldVault` | Sovereign + Helix + cross-chain treasury fusion |

## Full SDK

`sdk/helix/src/client.ts` — `HelixClient.triggerRemoteHarvest()`, `buildReceiveYieldTx()`, IDL included.

## Build programs

```bash
cd ~/yieldswarm-agent-swarm-v2   # NOT /home/chris
anchor build
anchor deploy --provider.cluster devnet
```
