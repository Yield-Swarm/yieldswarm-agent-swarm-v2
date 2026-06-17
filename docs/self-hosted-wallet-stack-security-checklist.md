# Self-Hosted Wallet Stack — Security & Ops Checklist

One-page hardening guide for the YieldSwarm custom wallet UX (Wagmi + viem + optional WC v2 relay). Use before production traffic.

## Content Security Policy (CSP)

- **default-src** `'self'`
- **script-src** `'self'` + explicit CDN hashes if using Tailwind/scripts from CDN; avoid `'unsafe-inline'` in production — use nonces
- **connect-src** restrict to your API origin + known RPC endpoints (Alchemy, Helius, etc.)
- **frame-ancestors** `'none'` on wallet modal routes
- Block `object-src`, `base-uri`, and inline event handlers

## Key custody

- Never log private keys, mnemonics, or raw signatures in server logs
- SIWE messages must include domain, chainId, nonce, and expiry
- Store only public addresses server-side; verify signatures before referral claims
- Paymaster / bundler keys live in Vault — rotate quarterly

## WalletConnect / relay (MVP → scale)

| Phase | Approach |
|-------|----------|
| MVP | Wagmi + RainbowKit + Reown Cloud project ID (injected + WC QR) |
| 1k+ DAU | Self-hosted relay on Cloudflare Workers with DDoS protection |
| Scale | Dedicated relay cluster + geographic anycast |

- Rate-limit relay handshake endpoints (60 req/min/IP minimum)
- Monitor relay error rate and p99 latency
- Do **not** self-host relay until ops runbook + on-call exists

## API hardening (referral funnel)

- Rate-limit `/api/referral/*` (implemented: 60/min/IP)
- Validate wallet address format per chain before state anchor writes
- State anchors are append-only; never mutate historical anchors
- UTM params logged for attribution only — no PII in anchor payloads

## Fraud & quality gates

- Optional KYC-lite or minimum activity before staking unlock
- Cooldown between link-click events (same linkId + wallet)
- Flag rapid multi-wallet claims from same IP

## Monitoring

- Alert on: 5xx rate > 1%, referral claim spike > 3σ, RPC 429 storms
- Dashboard: connected wallets/hr, claim conversion, 40% unlock rate
- Incident response: disable `/api/referral/claim` via feature flag in Vault

## Incident response

1. Revoke compromised WC project ID / relay keys
2. Rotate Vault secrets (`ORACLE_RELAYER_PRIVATE_KEY`, paymaster keys)
3. Publish post-mortem with state anchor chain export for audit
4. Re-enable traffic after CSP + rate-limit verification

## Deployment checklist

- [ ] CSP headers on `/new-to-crypto` and `/portal`
- [ ] `VITE_WALLETCONNECT_PROJECT_ID` set (MVP) or self-hosted relay URL (scale)
- [ ] RPC URLs use dedicated providers (not public mainnet defaults)
- [ ] Referral reward split env vars reviewed (`REFERRAL_REWARD_USER_BPS` / `TREASURY_BPS`)
- [ ] Affiliate disclaimers visible on landing page
- [ ] No guaranteed APY language in copy
