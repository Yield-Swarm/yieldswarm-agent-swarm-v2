# PoE Mainnet Claim API — Server-Authoritative Emissions

Anti-Sybil and anti–time-manipulation layer for Proof-of-Engagement token claims.

## Architecture

| Layer | Module | Role |
|-------|--------|------|
| Schema | `src/types/game.ts` | `PlayerProfile`, `ClaimRequest` Zod types |
| Engine | `src/lib/game/engine.ts` | Bounded `calculatePoEEmission()` |
| Rate limit | `src/lib/server/rateLimiter.ts` | Per-wallet token bucket (Redis / in-memory) |
| On-chain state | `src/lib/ton/playerState.ts` | `lastSaveTimestamp` from indexer or RPC |
| Signer | `src/lib/server/signer.ts` | HMAC claim authorization |
| Route | `src/app/api/claim/route.ts` | `POST /api/claim` |

**Client never supplies `deltaTime`.** The server derives it from indexed or on-chain `lastSaveTimestamp`.

## Environment

```bash
# Required for production rate limiting
REDIS_URL=https://....upstash.io
REDIS_TOKEN=...

# Claim signatures (required in production)
CLAIM_SIGNING_SECRET=...

# TON state sources (at least one)
TON_PLAYER_SBT_CONTRACT=EQ...
TON_RPC_ENDPOINT=https://toncenter.com/api/v2/jsonRPC
TONCENTER_API_KEY=...
TON_INDEXER_URL=https://tonapi.io
```

Without Redis, the rate limiter falls back to in-memory buckets (dev/Termux only — not safe for multi-instance production).

## Local verification

```bash
npm install
npm run dev

curl -X POST http://localhost:3000/api/claim \
  -H "Content-Type: application/json" \
  -d '{
    "walletAddress": "EQD4g3Y-N26G_vK3hXq9rB0123456789abcdefghijklmnop",
    "nonce": 100021,
    "action": {
      "baseFactor": 50,
      "metrics": [2, 10],
      "weights": [0.5, 1.0],
      "actionType": "combat"
    }
  }'
```

Expected: `200` with `contractMessage.serverSignature`. Rapid repeats return `429` after bucket exhaustion.

## Rate limit tuning

| Variable | Default | Meaning |
|----------|---------|---------|
| `POE_RATE_LIMIT_BURST` | 10 | Max burst actions per wallet |
| `POE_RATE_LIMIT_REFILL` | 0.2 | Tokens/sec (1 token / 5s) |

## Tests

```bash
npm run test:claim
```
