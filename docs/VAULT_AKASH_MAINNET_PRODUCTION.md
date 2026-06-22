# Akash Mainnet Production — Vault Agent + Cherry Servers

Finalized operator pipeline for **YieldSwarm Akash mainnet** with HashiCorp Vault runtime injection. Cherry Servers credentials live in Vault only — never in SDL, git, or Akash containers.

## Security model

| Layer | Cherry API key | Akash workload secrets |
|-------|----------------|------------------------|
| Vault path | `yieldswarm/cloud/cherry` (canonical) or `providers/cherry` | `runtime/*`, `rpc/*`, `integrations/*` |
| Akash container | **Denied** (`providers/*`, `cloud/*`) | Injected via Vault Agent → `/run/secrets/agent.env` |
| Operator host | Read via `multicloud-operator` AppRole | Mints wrapped SecretID only |

**Rotate immediately** if a Cherry API key appeared in chat, tickets, or logs. Seed only via shell:

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...                    # admin — one-time
export CHERRY_SERVERS_API_KEY=...         # from Cherry portal — never commit
export CHERRY_TEAM_ID=...                 # optional
./vault/scripts/seed-secrets.sh
unset CHERRY_SERVERS_API_KEY
```

## One-command production deploy

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...                    # operator token for wrap mint

./scripts/akash-mainnet-production.sh
```

Pipeline steps:

1. Vault connectivity check
2. Cherry API probe (`GET /v1/teams`) — skip with `SKIP_CHERRY_PREFLIGHT=1`
3. `akash-preflight.sh` — wallet balance, SDL tmpfs, Vault env keys
4. `akash-deploy-with-vault.sh` — mint wrapped SecretID → `deployment create`
5. Container `entrypoint.sh` → unwrap → **Vault Agent** → render `agent.env` → workload
6. Auto-heal daemon (default `AUTO_HEAL=1`)

Canonical SDL: `deploy/deploy-swarm-monolith.yaml`

## Vault Agent auto-injection (Akash container)

```
Operator (VAULT_TOKEN)
    │ vault write -wrap-ttl=600s auth/approle/role/akash-runtime/secret-id
    ▼
provider-services tx deployment create --env VAULT_WRAPPED_SECRET_ID=...
    ▼
akash/entrypoint.sh
    1. unwrap SecretID → /run/secrets/secret-id (one-shot)
    2. vault agent -config=/etc/vault-agent/vault-agent.hcl
    3. template → /run/secrets/agent.env
    4. source agent.env → exec yieldswarm agent
```

Templates:

- `akash/templates/runtime.env.ctmpl` — legacy monolith image
- `vault/templates/akash-runtime.ctmpl` — solenoid / sovereign_core layout

## Cherry preflight only

```bash
./scripts/cherry-vault-preflight.sh
# or
python3 -c "from services.infra.cherry_client import check_cherry_api; print(check_cherry_api())"
```

## Environment variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `CHERRY_SERVERS_API_KEY` | Vault seed shell only | Cherry Bearer token |
| `CHERRY_TEAM_ID` | Vault `cloud/cherry` | Default team for Nexus multicloud |
| `VAULT_ADDR` | SDL + operator | Vault cluster |
| `VAULT_TOKEN` | Operator shell | Mint wrapped SecretIDs |
| `VAULT_WRAPPED_SECRET_ID` | Deployment create | One-shot bootstrap |
| `AGENT_SHARD_ID` | Deployment create | Shard `0..119` |
| `SKIP_CHERRY_PREFLIGHT` | Operator | `1` to skip Cherry probe |
| `CHERRY_REQUIRED` | Operator | `1` to fail deploy if Cherry fails |

## Related

- [`docs/VAULT_AKASH_RUNTIME.md`](VAULT_AKASH_RUNTIME.md) — injection architecture
- [`docs/VAULT_SECRET_STRUCTURE.md`](VAULT_SECRET_STRUCTURE.md) — KV layout
- [`vault/scripts/seed-secrets.sh`](../vault/scripts/seed-secrets.sh) — seed Cherry + Akash paths
- [`deploy/scripts/akash-production-deploy.sh`](../deploy/scripts/akash-production-deploy.sh) — thin wrapper
