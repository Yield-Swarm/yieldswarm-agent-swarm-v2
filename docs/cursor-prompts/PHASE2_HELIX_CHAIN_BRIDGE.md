# Phase 2 — Helix Chain Bridge (Paste-Ready Cursor Prompt)

Copy everything inside the **Prompt block** below into an active **Cursor multi-file session** after Phase 1 (`.env.template` + `scripts/inject_secrets.sh`) is complete.

---

## Prompt block (copy from here)

```markdown
Context Reference: Root `.env.template` + `docs/PHASE1_SECURE_ENV.md` + Phase 1 Security Architecture

You are the Helix Chain Engineering Swarm. Your task is to build a highly secure Cross-Chain Settlement Bridge targeting the Helix Chain, Solana Mainnet, and Ethereum environments, utilizing Confidential Computing (TEE) signing paradigms.

## Repository anchors (do not remove)

- Helix activation adapter: `backend/src/adapters/helix.js`
- Cross-chain MVP docs: `docs/CROSS_CHAIN_MVP.md`
- Jupiter service stub: `services/cross_chain/jupiter.py`
- Entropy / solenoid validation: `src/infrastructure/entropy-core.js`, `src/infrastructure/oracle-bridge.js`
- Existing env guardrails: `NETWORK_LOCKDOWN_MODE`, `SLIPPAGE_TOLERANCE=0.005`, `IMPERMANENT_LOSS_THRESHOLD` in `.env.template`

## Deliverables

Implement the core execution module under `src/bridge/engine.ts` using the following technical requirements:

### 1. SECURE SIGNING CONTEXT

- Do **not** pull raw secret string parameters from `process.env` for signing keys.
- Add dependencies: `@azure/identity`, `@azure/keyvault-secrets` (root `package.json`).
- Integrate `DefaultAzureCredential` + `SecretClient` to resolve `KV_SECRET_REF:<name>` placeholders from `.env.template` against `AZURE_KEYVAULT_NAME`.
- Utilize the stored `kimiclaw-consensus-key` (env: `KIMICLAW_CONSENSUS_KEY`) to authenticate outgoing cryptographic settlement signatures.
- Add `src/bridge/secrets.ts` — `resolveSecret(ref: string): Promise<string>` with in-memory cache and **no logging of values**.

### 2. CROSS-CHAIN INTEGRATION

- Establish network connections via multi-endpoint RPC fallbacks combining:
  - `HELIX_CHAIN_ENDPOINT` (primary)
  - `QUICKNODE_SOLANA_RPC_URL` / `QUICKNODE_API_KEY`
  - `HELIUS_API_KEY` + `SOLANA_RPC_URL`
  - `ETHEREUM_RPC_URL` + Infura/Ankr fallbacks from KV
- Add structural code paths for routing token swaps via the Jupiter API (`JUPITER_API_KEY`, quote-api.jup.ag v6) for optimized slippage tolerances.
- Reuse patterns from `services/cross_chain/jupiter.py` where applicable; do not duplicate Python in TS — mirror interfaces only.
- Set an internal guardrail enforcing **max slippage 0.5%** (`SLIPPAGE_TOLERANCE`) and **impermanent loss** thresholds (`IMPERMANENT_LOSS_THRESHOLD`) before submitting swaps.

### 3. MAYHEM_MODE / NETWORK_LOCKDOWN_MODE LOGIC

- If `NETWORK_LOCKDOWN_MODE` evaluates to `true`, freeze all **outgoing manual** cross-chain transactions instantly.
- Exception: Allow autonomous automated shard agents executing programmatic arbitrage to continue within TEE-isolated memory if internal cryptographic validation passes (`TelemetryValidationBridge` / `HardenedAuditEngine` hooks from entropy-core).
- Export `assertSettlementAllowed(ctx: SettlementContext): void` that encodes this policy.

### 4. MONITORING

- Attach structured logging using Sentry DSN hooks (`SENTRY_DSN` via KV) to record transactional failures or threshold exceptions.
- **Never** log raw wallet payloads, private keys, or full transaction signatures — redact to prefix/suffix hashes only.
- Add `src/bridge/telemetry.ts` with `captureBridgeFailure(error, meta)` safe wrapper.

### 5. TESTS & WIRING

- Add `src/bridge/engine.test.ts` (vitest): mock Key Vault client, lockdown mode blocks manual tx, slippage guard rejects >0.5%.
- Wire a thin HTTP surface in `backend/src/routes/helix.js` → `POST /api/helix/settlement/quote` (dry-run default when `CROSS_CHAIN_DRY_RUN=1`).
- Run: `npm run test:unit` and `cd backend && npm test` — all green.

## Constraints

- Multi-file safety: **do not refactor away** existing project validation code (`entropy-core`, `oracle-bridge`, `helix.js` activation flow).
- TypeScript strict mode; ESM compatible with repo vitest config.
- No plaintext secrets in code, tests, or fixtures.

Output the clean, production-grade TypeScript implementation now.
```

---

## After paste — verification checklist

- [ ] `src/bridge/engine.ts`, `secrets.ts`, `telemetry.ts` exist
- [ ] `@azure/identity` + `@azure/keyvault-secrets` in root `package.json`
- [ ] `npm run test:unit` passes
- [ ] `NETWORK_LOCKDOWN_MODE=true` blocks manual settlement in tests
- [ ] Sentry events contain no raw keys or full addresses
- [ ] `docs/PHASE1_SECURE_ENV.md` KV names match `resolveSecret` lookups

## Optional follow-up vectors

1. **Terraform / Bicep** — deploy YieldSwarmProd VM + `ysmdbazcosmos` VNet lockdown
2. **Solana Pump.fun** — `$APN` token issuance script (`PUMP_FUN_COIN_ID` in KV)
