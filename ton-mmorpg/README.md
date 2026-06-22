# TON MMORPG — Server-Authoritative On-Chain Game

Legitimate TON MMORPG track: **PoE engine**, **PlayerSBT**, **InGameJetton (IGJ)**, server-authoritative settlement, TonConnect dashboard, Telegram TMA (planned).

## Architecture

```
Client / TMA  →  Authoritative Server  →  TON Mainnet
(TonConnect)     (PoE + sync loop)        (PlayerSBT + IGJ)
```

**Core security rule:** `Δt` is derived from **on-chain `last_update`** on PlayerSBT — never trust client `deltaTime`.

## Packages

| Path | Role |
|------|------|
| `server/` | Sync API, PoE engine, timestamp reader, rate limiter |
| `contracts/tact/` | PlayerSBT + InGameJetton Tact skeletons |
| `client/` | Dashboard UX (session tag, proof panel, sync row) |
| `docs/ARCHITECTURE.md` | Full architecture spec summary |

## Quick start

```bash
cd ton-mmorpg/server
cp .env.example .env   # TONCENTER_API_KEY, contract addresses — never commit secrets
npm ci
npm run dev

# Contracts (requires blueprint + tact compiler)
cd ../contracts
npx blueprint build
```

## Sync endpoint

```bash
curl -X POST http://localhost:3100/api/sync \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <session>" \
  -d '{"wallet":"EQ...","activityScore":42}'
```

## Boundaries

- No secrets in git or chat — use Vercel env / Vault / Doppler.
- Out of scope: cloud-mining evasion, airdrop farming, ToS-violating automation.

See `docs/ARCHITECTURE.md` for the 7-step sync loop and threat model.
