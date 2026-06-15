# YieldSwarm on Akash

This directory contains the runtime artefacts for shipping a YieldSwarm
agent shard to the Akash Network. Every secret a shard needs is fetched
from HashiCorp Vault at container start - **nothing sensitive is baked
into the image or the SDL**.

## Files

| File                             | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| `Dockerfile`                     | Hardened image (non-root, pinned Vault, tini, tmpfs secrets) |
| `entrypoint.sh`                  | Unwraps SecretID → starts Vault Agent → execs the workload  |
| `vault-agent.hcl`                | AppRole auto-auth + KVv2 template rendering                  |
| `templates/agent.env.ctmpl`      | Consul-Template that renders `/run/secrets/agent.env`        |
| `deploy.yaml`                    | Akash SDL (no secrets, only `VAULT_*` bootstrap env vars)    |

## Secret flow

```
operator / CI
    │  vault write -wrap-ttl=600s -force auth/approle/role/akash-runtime/secret-id
    ▼  → WRAPPED_SECRET_ID (one-shot, ~10 min)
provider-services tx deployment create deploy.yaml \
    --env VAULT_ROLE_ID=<role_id> \
    --env VAULT_WRAPPED_SECRET_ID=<WRAPPED_SECRET_ID> \
    --env AGENT_SHARD_ID=<0..119>
    │
    ▼
Akash provider starts container
    │
    ▼
entrypoint.sh
  1. validate env
  2. vault unwrap WRAPPED_SECRET_ID  → /run/secrets/secret-id (tmpfs, 0400)
  3. exec vault agent (AppRole login + KV template)
  4. wait for /run/secrets/agent.env
  5. source it, exec workload
    │
    ▼
yieldswarm.agent process
```

## What lives where

- `/run/secrets/role-id`              – the AppRole role_id (non-sensitive)
- `/run/secrets/secret-id`            – removed by Vault Agent after first use
- `/run/secrets/vault-token`          – tmpfs, mode 0400, in-memory only
- `/run/secrets/agent.env`            – tmpfs, mode 0400, sourced by entrypoint
- `/run/secrets/vault-agent.pid`      – PID file
- `127.0.0.1:8100`                    – Vault Agent API proxy for the workload

## Updating secrets

Rotate a secret in Vault (`vault kv put yieldswarm/rpc/helius api_key=...`).
Vault Agent re-renders `agent.env` within `static_secret_render_interval`
(5 minutes) and sends SIGHUP to the workload, which reloads its env.

## Local development

```bash
# 1. Run a dev Vault.
docker run --rm -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.18.2

# 2. Seed it.
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/02-enable-engines.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/03-write-policies.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
  ./vault/setup/04-enable-auth.sh
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root SOURCE_ENV=./.env \
  ./vault/setup/05-seed-secrets.sh

# 3. Build the image.
docker build -t yieldswarm-agent:dev -f akash/Dockerfile .

# 4. Get a wrapped SecretID.
ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
WRAP=$(vault write -wrap-ttl=600s -force -format=json \
        auth/approle/role/akash-runtime/secret-id \
        | jq -r '.wrap_info.token')

# 5. Run.
docker run --rm -it \
  -e VAULT_ADDR=http://host.docker.internal:8200 \
  -e VAULT_ROLE_ID="${ROLE_ID}" \
  -e VAULT_WRAPPED_SECRET_ID="${WRAP}" \
  -e AGENT_SHARD_ID=0 \
  --tmpfs /run/secrets:size=8m,mode=0700 \
  yieldswarm-agent:dev
```
