# Payment Rails — Square + Wise + Unified Web3 Wallet

## Fee Structure

| Actor | Rate | Description |
|-------|------|-------------|
| Customer | 1% flat fee | Added to trip fare via Square/Wise |
| Driver | 2x base pay | `DRIVER_PAY_MULTIPLIER=2.0` |
| Instant cashout | 1.5% fee | Optional immediate payout |

## Earnings Breakdown

Each driver payout includes:
- **App revenue** — 2x base trip pay
- **DePIN rewards** — Kairo telemetry contribution
- **Crypto rewards** — $APN / on-chain incentives

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/payments/customer/charge` | Process 1% fee customer payment |
| POST | `/api/v1/payments/driver/earnings` | Record 2x driver earnings |
| GET | `/api/v1/payments/driver/:id/wallet` | Unified Web3 wallet view |
| GET | `/api/v1/payments/driver/:id/earnings` | Earnings history |
| POST | `/api/v1/payments/webhooks/square` | Square webhook (HMAC verified) |
| POST | `/api/v1/payments/webhooks/wise` | Wise webhook (HMAC verified) |

## Webhook Setup

**Square:** Developer Dashboard → Webhooks → `https://api.yieldswarm.crypto/api/v1/payments/webhooks/square`

**Wise:** Business API → Webhooks → `https://api.yieldswarm.crypto/api/v1/payments/webhooks/wise`

## Example: Complete Trip Flow

```bash
# 1. Customer pays $10 fare + 1% fee
curl -X POST http://localhost:3000/api/v1/payments/customer/charge \
  -H "Content-Type: application/json" \
  -d '{"tripId":"trip-001","customerId":"cust-001","baseAmountCents":1000}'

# 2. Driver earns 2x on $5 base + DePIN rewards
curl -X POST http://localhost:3000/api/v1/payments/driver/earnings \
  -H "Content-Type: application/json" \
  -d '{"driverId":"<driver-id>","tripId":"trip-001","basePayCents":500,"depinRewardsCents":25,"instantCashout":true}'

# 3. View unified wallet
curl http://localhost:3000/api/v1/payments/driver/<driver-id>/wallet
```
