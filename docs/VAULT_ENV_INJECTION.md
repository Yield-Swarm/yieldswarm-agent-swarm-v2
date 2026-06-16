# Vault + Environment Injection Setup

> **Part B** of the deploy handoff (after D → A → C)  
> Canonical KV layout: `docs/VAULT_SECRET_STRUCTURE.md`  
> Seed script: `vault/scripts/seed-secrets.sh`  
> Export helper: `scripts/vault-export-env.py`

## Goals

1. **Single source of truth** for 18 LLM keys + 18 cloud credentials  
2. **No secrets in git** — `.env` is local/dev only; production uses Vault Agent  
3. **Pillar-aligned paths** — D¹ Greek isolation, ZK¹ entropy keys separated from LLM routing  
4. **Smooth migration** from flat `.env` → layered `config/layered.env.example` → Vault

---

## Secret structure by pillar

| Pillar | Vault path prefix | Example keys |
|--------|-------------------|--------------|
| **D¹ Greek** | `yieldswarm/internal/security` | `AGENTSWARM_MASTER_KEY`, `TEE_SIGNING_KEY`, policy tokens |
| **E¹ Eastern** | `yieldswarm/runtime/feedback` | webhook URLs, scheduler tokens |
| **ZK¹** | `yieldswarm/runtime/zk` | verifier address, zkey hash, `MUTATION_CONTROLLER_ADDRESS` |
| **LLM (18 APIs)** | `yieldswarm/runtime/llm/*` | `openai`, `anthropic`, `fireworks`, `openrouter`, … |
| **Multi-cloud** | `yieldswarm/cloud/*` | `aws`, `azure`, `gcp`, `runpod`, `vast`, `akash` |
| **Database** | `yieldswarm/internal/database` | `DATABASE_URL`, `NEON_PROJECT_ID` |
| **TON + Kairo** | `yieldswarm/runtime/kairo`, `yieldswarm/external/toncenter` | driver keys, TON API |
| **Payments** | `yieldswarm/payments/*` | Square, Wise, Web3 hot wallets |

---

## Container injection patterns

### 1. Vault Agent sidecar (Akash / K8s)

```hcl
# deploy/templates/vault/agent.hcl.tpl (concept)
vault {
  address = "${VAULT_ADDR}"
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = { role = "yieldswarm-odysseus-runtime" }
  }
}

template {
  source      = "/vault/templates/app.env.tpl"
  destination = "/run/secrets/app.env"
  command     = "kill -HUP 1"
}
```

Akash SDL env reference:

```yaml
env:
  - VAULT_ADDR=${VAULT_ADDR}
  - VAULT_TOKEN_FILE=/run/secrets/vault-token
```

See `deploy/akash/odysseus-vault.sdl.yml` for production pattern.

### 2. Init container export (CI / Codespaces)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN="$(cat /run/secrets/vault-token)"
python3 scripts/vault-export-env.py --profile production > .env
bash deploy/deploy-full-stack.sh --phase 1
```

### 3. AppRole wrap for Akash deploy

```bash
vault write -f auth/approle/role/yieldswarm-deploy/token policies=yieldswarm-deploy
# Store wrap token in yieldswarm/akash/deployment
```

---

## Migration path: `.env` → Vault

| Step | Action | Verify |
|------|--------|--------|
| 1 | Copy `config/layered.env.example` → `.env` | `make preflight` |
| 2 | Run `vault/scripts/seed-secrets.sh` with real values | `vault kv get yieldswarm/internal/database` |
| 3 | Point apps at Vault Agent instead of `.env` | Container starts without `.env` mount |
| 4 | Remove secrets from Vercel/Render — inject via Vault export in CI | `deploy-production-full.sh` neon step |
| 5 | Rotate keys quarterly; update `DATABASE_URL` via Neon console | Audit log in Vault |

---

## Layered env → Vault mapping

| `.env.layered` prefix | Vault path |
|-----------------------|------------|
| `GREEK_LAYER__*` | policy config (non-secret); keys → `internal/security` |
| `ZK__*` | `runtime/zk` |
| `OPENAI_API_KEY`, etc. | `runtime/llm/<provider>` |
| `RUNPOD_API_KEY`, `AZURE_*` | `cloud/<provider>` |
| `DATABASE_URL` | `internal/database` |
| `TONCENTER_API_KEY` | `external/toncenter` |

---

## Security best practices

1. **Least privilege** — one Vault policy per service (backend, odysseus, akash-worker, mandelbrot-bot)  
2. **No LLM keys in frontend** — router key only on LiteLLM container  
3. **Dynamic DB creds** — prefer Neon + Vault database secrets engine for production  
4. **Audit** — enable Vault audit device → ship to Neon `helix_chain_snapshots` correlation  
5. **Greek layer flags** — set `GREEK_LAYER__STRICT_SANITIZATION=true` before mainnet  
6. **Bug bounty** — separate `BOUNTY_POOL_SOL` wallet in `yieldswarm/payments/web3`, not in app runtime policy

---

## Quick commands

```bash
# Seed all paths (interactive / from env file)
bash vault/scripts/seed-secrets.sh

# Export layered .env for local dev
python3 scripts/vault-export-env.py --profile odysseus > .env

# Verify Neon from Vault-exported DATABASE_URL
python3 -m services.neon_store --migrate
python3 -m services.neon_store --counts

# Production full pipeline (Vault first)
bash scripts/deploy-production-full.sh
```

---

## References

- `docs/VAULT_SECRET_STRUCTURE.md` — full path tree  
- `docs/VAULT_AKASH_DEPLOY.md` — Akash + AppRole  
- `config/layered.env.example` — layered template (A)  
- `deploy/deploy-full-stack.sh` — phase-ordered deploy (C)  
- `docs/DEPLOYMENT_PRIORITY_ORDER.md` — priority order (D)
