# Vault + Environment Injection — Full Integration Plan

> **Order:** Complete after D (priority list), A (layered `.env`), and C (deployment templates).  
> **Companion:** `docs/VAULT_AKASH_DEPLOY.md`, `docs/VAULT_AKASH_RUNTIME.md`, `vault/scripts/seed-secrets.sh`

HashiCorp Vault is the **secret source of truth** for production. Local `.env` files are a **bootstrap convenience** only — migrate to Vault before mainnet.

---

## 1. Secret structure by pillar

Secrets are organized to mirror the **14-pillar solenoid chain** and the four coordinate axes.

| Pillar | Vault KV path | Contents |
|--------|---------------|----------|
| 01 greek_vaults | `yieldswarm/runtime/core` | `agentswarm_master_key`, `database_encryption_key`, `session_secret` |
| 02 infra_oracles | `yieldswarm/integrations/*` | Tenderly, Sentry, Cloudflare, Pinata |
| 03 zk_mayhem_core | `yieldswarm/runtime/zk` | `verifier_address`, `mutation_controller`, circuit artifact hashes |
| 04 akash_gpu_workers | `yieldswarm/runtime/akash` | `owner_address`, wallet metadata |
| 05 arena_leaderboard | `yieldswarm/runtime/backend` | emission router, treasury addresses |
| 06 cross_chain_exec | `yieldswarm/rpc/ethereum`, `rpc/solana` | RPC URLs + API keys |
| 07 depin_orchestration | `yieldswarm/providers/*` | RunPod, Vast, Vultr, DO, Azure, AWS |
| 08 emission_routing | `yieldswarm/runtime/backend` | router URLs, split BPS |
| 09 agentswarm_os | `yieldswarm/runtime/odysseus` | Odysseus API, router key |
| 10 security_tee_mpc | `yieldswarm/runtime/wallets` | TEE signing, wallet encryption |
| 11 telemetry_observability | `yieldswarm/integrations/sentry` | DSN, sample rates |
| 12 governance | `yieldswarm/runtime/core` | Kimiclaw consensus key |
| 13 treasury_yield | `yieldswarm/runtime/payments` | Stripe, Square, Wise |
| 14 valhalla_portal | `yieldswarm/runtime/kairo` | Mapbox, Tesla fleet, TON |

### ZK entropy (pillar 03)

```bash
vault kv put yieldswarm/runtime/zk \
  verifier_address="$ZK__VERIFIER_ADDRESS" \
  mutation_controller="$MUTATION_CONTROLLER_ADDRESS" \
  nft_address="$YIELDSWARM_NFT_ADDRESS" \
  circuit_wasm_path="$ZK__CIRCUIT_WASM_PATH" \
  zkey_path="$ZK__ZKEY_PATH"
```

### LLM layer (18 APIs → single path)

```bash
vault kv put yieldswarm/runtime/llm \
  openai_api_key="$OPENAI_API_KEY" \
  anthropic_api_key="$ANTHROPIC_API_KEY" \
  grok_api_key="$GROK_API_KEY" \
  openrouter_api_key="$OPENROUTER_API_KEY" \
  fireworks_api_key="$FIREWORKS_API_KEY"
# ... remaining keys seeded by vault/scripts/seed-secrets.sh
```

---

## 2. Vault Agent injection into containers

Every Akash SDL uses the same injection pattern:

```yaml
env:
  - VAULT_ADDR=${VAULT_ADDR}
  - VAULT_ROLE_ID=${VAULT_ROLE_ID}
  - VAULT_SECRET_ID=${VAULT_SECRET_ID}
  - VAULT_KV_MOUNT=yieldswarm
  - VAULT_SECRET_PATHS=runtime/backend,runtime/akash,rpc/solana,runtime/odysseus,runtime/llm
  - AGENT_ENV_FILE=/run/secrets/agent.env
params:
  storage:
    secrets:
      mount: /run/secrets
```

**Boot sequence:**

1. Container starts with AppRole credentials (`VAULT_ROLE_ID` + wrapped `VAULT_SECRET_ID`).
2. Vault Agent renders `akash/templates/runtime.env.ctmpl` → `/run/secrets/agent.env`.
3. Entrypoint `source /run/secrets/agent.env` before starting Node/Python.

AppRoles (see `vault/policies/`):

| Role | Policy | Workload |
|------|--------|----------|
| `integration-backend` | `integration-backend.hcl` | Arena API backend |
| `bittensor-runtime` | `bittensor-runtime.hcl` | GPU miner |
| `odysseus-runtime` | `odysseus-runtime.hcl` | Odysseus + LiteLLM |
| `akash-runtime` | `akash-runtime.hcl` | Full swarm monolith |
| `kairo-runtime` | `kairo-runtime.hcl` | Kairo driver stack |

Issue credentials:

```bash
./scripts/akash-vault-prepare.sh integration-backend
./scripts/deploy-backend-akash.sh
```

---

## 3. Migration path: `.env` → Vault

| Stage | Where secrets live | When |
|-------|-------------------|------|
| **Local dev** | `.env` from `deploy/env/layered.env.example` | Day 0 |
| **CI / staging** | Vault `ci` token + short-lived leases | Before testnet |
| **Akash leases** | Vault Agent → `/run/secrets/agent.env` | Production |
| **Vercel (Portal)** | Vercel env UI synced from Vault manually | Payments only |

### Step-by-step migration

```bash
# 1. Copy layered template
cp deploy/env/layered.env.example .env
# Fill values locally (never commit)

# 2. Bootstrap Vault
export VAULT_ADDR=... VAULT_TOKEN=...
./vault/scripts/bootstrap.sh   # or vault/setup/bootstrap.sh

# 3. Seed all paths from .env
set -a; source .env; set +a
./vault/scripts/seed-secrets.sh

# 4. Verify paths
vault kv get yieldswarm/runtime/llm
vault kv get yieldswarm/runtime/zk

# 5. Strip secrets from .env — keep only non-secret config
#    GREEK_LAYER__*, TARGET_ENV, API_BASE, image tags

# 6. Deploy with AppRole injection
USE_VAULT_AKASH=true ./scripts/deploy-backend-akash.sh
```

### Verify injection on a running lease

```bash
./scripts/verify-vault-injection.sh
```

---

## 4. Security best practices

### Greek layer (D¹) enforcement

| Control | Env var | Vault path |
|---------|---------|------------|
| Access control | `GREEK_LAYER__ACCESS_CONTROL_ENABLED` | `runtime/core` |
| Context window cap | `GREEK_LAYER__MAX_CONTEXT_WINDOW` | non-secret — SDL env |
| Input sanitization | `GREEK_LAYER__STRICT_SANITIZATION` | non-secret — SDL env |
| Network lockdown | `NETWORK_LOCKDOWN_MODE` | `runtime/core` |

### 18 LLM keys + 18 cloud credentials

- **Never** commit to git, SDL files, or Docker images.
- Seed via `vault/scripts/seed-secrets.sh` only (reads from env, not CLI args).
- Rotate on a 90-day cadence; update Vault first, then redeploy leases.
- Use **separate AppRoles** per workload — backend cannot read bittensor wallet keys.

### Akash deploy host

| Variable | Sensitivity | Injection method |
|----------|-------------|------------------|
| `VAULT_ROLE_ID` | Low (public identifier) | `--env` at `akash deploy` |
| `VAULT_SECRET_ID` | **High** | Response-wrap token only (`VAULT_WRAPPED_SECRET_ID`) |
| `VAULT_TOKEN` | **High** | Deploy host only — never in SDL |

### Audit

- `HardenedAuditEngine` chains execution blocks off-chain (`src/infrastructure/entropy-core.js`).
- `TelemetryValidationBridge` anchors pillar pulses before mutation (`oracle-bridge.js`).
- Enable Sentry + Prometheus before mainnet (`deploy/monitoring/`).

---

## 5. Layered env ↔ Vault mapping

| `.env` prefix | Vault path | Notes |
|---------------|------------|-------|
| `GREEK_LAYER__*` | non-secret | Passed in SDL `env:` block |
| `EASTERN_LAYER__*` | non-secret | Routing flags |
| `ZK__*` | `runtime/zk` | Verifier + artifact paths |
| `LLM__*` / `*_API_KEY` | `runtime/llm` | 18 provider keys |
| `AKASH_*`, `RUNPOD_*`, etc. | `providers/*` | Cloud credentials |
| `TON_*`, `KAIRO_*`, `TESLA_*` | `runtime/kairo`, `rpc/ton` | TON + fleet |
| `NEON_*`, `PINATA_*` | `runtime/storage` | Database + IPFS |
| `SENTRY_*`, `DATADOG_*` | `integrations/sentry` | Observability |

Full variable catalog: `docs/ENV_VARS.md`.

---

## 6. Quick commands

```bash
# Seed from current shell env
./vault/scripts/seed-secrets.sh

# Render plug-and-play templates
./deploy/templates/lib/render-template.sh all

# Phase-ordered deploy harness
./deploy/deploy-full-stack.sh --phase 1
./deploy/deploy-full-stack.sh --phase all

# 14-pillar + Vault verification
./scripts/deploy-and-test-pillars.sh production
./scripts/verify-vault-injection.sh
```

---

## 7. Checklist before mainnet

- [ ] Vault HA or HCP with `$500 credit budget tracked
- [ ] All 18 LLM keys in `yieldswarm/runtime/llm` — none in `.env`
- [ ] ZK verifier deployed; address in `yieldswarm/runtime/zk`
- [ ] AppRoles issued per workload; wrap tokens expire < 10 min
- [ ] `GREEK_LAYER__ACCESS_CONTROL_ENABLED=true` on all SDLs
- [ ] Sentry DSN live; Prometheus scraping `/api/health`
- [ ] `./scripts/master-smoke-test.sh` green
- [ ] `./deploy/deploy-full-stack.sh --phase 4` complete
