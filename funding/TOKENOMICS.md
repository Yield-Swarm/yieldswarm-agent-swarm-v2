# Tokenomics & Agent Marketplace

## Great Delta emission split (on-chain policy)

Canonical **50 / 30 / 15 / 5** allocation:

| Bucket | BPS | Purpose |
|--------|-----|---------|
| Core Treasury | 5000 | Protocol reserves, $5M vault target |
| Growth Treasury | 3000 | Fleet expansion, new subnets |
| Insurance Treasury | 1500 | Slashing / outage buffer |
| Ops Treasury | 500 | Running costs, monitoring |

Implemented in `GreatDeltaEmissionRouter.sol` and mirrored in `backend/src/lib/great-delta-split.js`.

## Agent marketplace — holographic “coffee variables”

Inspired by composable drink orders (size, milk, shots, syrup), each agent listing exposes **holographic variables** buyers tune at purchase time:

| Variable | Example values | Pricing effect |
|----------|----------------|----------------|
| `compute_tier` | RTX 3090 · A100 · H100 | Base lease multiplier |
| `latency_sla` | 99% · 99.9% · 99.99% | Premium for sovereign heal |
| `model_family` | Ollama · Grok · Claude-route | Inference cost pass-through |
| `shard_density` | 1 · 12 · 84 agents | Cron fan-out |
| `treasury_apy_floor` | 20% · 30% · 40% | Sovereign mandate tier |
| `emission_route` | core · growth · insurance · ops | Great Delta bucket preference |

Each variable is a **dimension in a holographic price surface** — the marketplace UI renders a live preview (like customizing a drink) before the buyer commits $APN or fiat.

### Example bundle

```
Agent: "Runic Helix Miner v3"
  compute_tier=RTX3090
  latency_sla=99.9%
  model_family=ollama:llama3.1:8b
  shard_density=12
  treasury_apy_floor=30%
  emission_route=growth
→ quoted @ 842 $APN / epoch
```

## Supply (placeholder — legal review required)

| Instrument | Notes |
|------------|-------|
| $APN | Emission router token; epoch emissions per Great Delta |
| Agent licenses | NFT keys for marketplace premium tiers |
| SAFE | Fiat raise instrument (DUNA) |

*All figures subject to counsel review before public distribution.*
