# Vault Runtime Secret Injection on Akash

End-to-end flow for injecting HashiCorp Vault secrets into Akash containers
using **response-wrapped AppRole SecretIDs**, **short-lived tokens**, and
**Vault Agent** (or hvac) at container start.

## Architecture

```
CI / operator (VAULT_TOKEN)
        │
        ▼
vault write -wrap-ttl=600s auth/approle/role/akash-runtime/secret-id
        │
        ▼
provider-services tx deployment create sdl.yaml \
  --env VAULT_ROLE_ID=... \
  --env VAULT_WRAPPED_SECRET_ID=... \
  --env AGENT_SHARD_ID=0
        │
        ▼
Akash container entrypoint
  1. unwrap SecretID (one-shot)
  2. vault agent → /run/secrets/agent.env
  3. source env → exec workload
```

Nothing except bootstrap coordinates (`VAULT_ADDR`, `VAULT_ROLE_ID`,
`VAULT_WRAPPED_SECRET_ID`, `AGENT_SHARD_ID`) is stored in the SDL or on-chain.
All application secrets are read from KV at runtime.

## AppRoles & policies

| AppRole | Policy | Workload |
|---------|--------|----------|
| `akash-runtime` | `akash-runtime.hcl` | YieldSwarm agent shards |
| `bittensor-runtime` | `bittensor-runtime.hcl` | Bittensor miner on Akash |
| `ci-bootstrap` | `ci-bootstrap.hcl` | CI — mints wrapped SecretIDs only |

Token TTLs (Terraform `auth-approle.tf`):

- **SecretID**: 30m, single use
- **Token**: 1h TTL, 24h max (renewable by Vault Agent)
- **Wrap token**: 600s default at deploy time

## KV paths (mount: `yieldswarm`)

Canonical runtime paths consumed by `akash/templates/runtime.env.ctmpl`:

| Path | Contents |
|------|----------|
| `runtime/core` | Master keys, DB encryption |
| `runtime/llm` | OpenAI, Anthropic, Grok, Gemini, … |
| `runtime/wallets` | Wallet/TEE signing keys |
| `runtime/bittensor` | BT wallet, netuid, Ollama model |
| `runtime/akash` | Deploy operator wallet config |
| `agents/shards/{id}` | Per-shard API/signing keys |
| `rpc/*` | Chain RPC + API keys |
| `integrations/*` | GitHub, Vercel, Telegram, … |

Legacy paths (`akash/runtime`, `llm/*`) remain readable for backward compatibility.

**Denied to Akash**: `cloud/*`, `providers/*`, `sys/*`

## Deploy

### Preflight (run first)

```bash
./scripts/akash-preflight.sh
# Checks: CLI, wallet >= 0.5 AKT, SDL placeholders, VAULT_TOKEN / wrap readiness
```

### Automated (recommended)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<ci-or-admin-token>
export AGENT_SHARD_ID=0

# Full lifecycle + state files + verify
./scripts/akash-deploy-with-vault.sh deploy/deploy-swarm-monolith.yaml

# Or explicit pipeline
./scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml
```

`akash-deploy-with-vault.sh` delegates to `deploy-to-akash.sh` (no longer stops at manifest-only).

### Manual wrap + deploy

```bash
eval "$(./vault/scripts/issue-secret-id.sh akash-runtime 10m)"
export AGENT_SHARD_ID=0

provider-services tx deployment create akash/deploy.yaml \
  --from yieldswarm \
  --env "VAULT_ADDR=${VAULT_ADDR}" \
  --env "VAULT_ROLE_ID=${VAULT_ROLE_ID}" \
  --env "VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}" \
  --env "AGENT_SHARD_ID=${AGENT_SHARD_ID}"
```

## SDL requirements

Vault-ready SDLs declare **key-only** env entries (values from `--env` at create):

```yaml
env:
  - VAULT_ADDR=https://vault.yieldswarm.io:8200
  - VAULT_ROLE_ID
  - VAULT_WRAPPED_SECRET_ID
  - AGENT_SHARD_ID
params:
  storage:
    secrets:
      mount: /run/secrets    # tmpfs — secrets never touch disk
```

Reference manifests:

- `deploy/deploy-swarm-monolith.yaml` — agent shard
- `deploy/akash-bittensor-miner.sdl.yml` — Bittensor miner
- `akash/deploy.yaml` — minimal agent SDL

## Container images

| Image | Secret mechanism |
|-------|------------------|
| `ghcr.io/yield-swarm/yieldswarm-agent` | Vault Agent sidecar (`akash/entrypoint.sh`) |
| `ghcr.io/yield-swarm/bittensor-miner` | hvac unwrap + `vault-export-env.py` |

## Environment variables

| Variable | Set by | Purpose |
|----------|--------|---------|
| `VAULT_INJECT_RUNTIME_SECRETS` | deploy script | `auto` (default), `yes`, `no` |
| `VAULT_AKASH_ROLE` | deploy script | `akash-runtime` or `bittensor-runtime` |
| `VAULT_WRAP_TTL` | deploy script | Wrap TTL (default `600s`) |
| `VAULT_WRAPPED_SECRET_ID` | deployment create | One-shot wrap token |
| `VAULT_SECRET_ID_WRAP_TOKEN` | issue-secret-id.sh | Alias accepted by entrypoints |
| `AGENT_ENV_FILE` | SDL | Render target (default `/run/secrets/agent.env`) |

## Bootstrap & seed

```bash
# Policies + AppRoles
cd vault/terraform-vault-config && terraform apply

# Or imperative setup
./vault/setup/bootstrap.sh

# Seed KV from operator env
export VAULT_TOKEN=...
./vault/scripts/seed-secrets.sh
```

## Security notes

1. Never commit `VAULT_WRAPPED_SECRET_ID` or plaintext `VAULT_SECRET_ID` to git.
2. Wrap tokens are single-use; re-deploy mints a fresh wrap.
3. SDLs use **key-only** env entries for secrets (`VAULT_WRAPPED_SECRET_ID` without inline values).
4. Both monolith and bittensor SDLs mount `/run/secrets` as **ram tmpfs** (8Mi).
5. `lib/secrets.py` and `akash/entrypoint.sh` both accept `VAULT_WRAPPED_SECRET_ID` or `VAULT_SECRET_ID_WRAP_TOKEN`, unwrap once, then clear wrap env vars.
6. Pin `APPROLE_AKASH_CIDRS` to Akash provider egress in production.
7. Cloud provider credentials (`providers/*`) are Terraform-only.

### SDL checklist (no plaintext secrets)

| SDL | Vault env keys | tmpfs `/run/secrets` |
|-----|----------------|----------------------|
| `deploy/deploy-swarm-monolith.yaml` | `VAULT_ROLE_ID`, `VAULT_WRAPPED_SECRET_ID` | yes |
| `deploy/akash-bittensor-miner.sdl.yml` | same + `VAULT_KV_MOUNT` paths | yes |
| `akash/deploy.yaml` | same | yes |

Run `./scripts/akash-preflight.sh` to validate SDL + Vault bootstrap before mainnet deploy.

See also: `SECRETS.md`, `akash/README.md`, `docs/AKASH_DEPLOY.md`
