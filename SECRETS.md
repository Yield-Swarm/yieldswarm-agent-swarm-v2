# YieldSwarm Secrets Management

Production-grade secret handling with [HashiCorp Vault](https://developer.hashicorp.com/vault). All cloud provider credentials (Azure, RunPod, Vultr, DigitalOcean) and RPC endpoints are stored in Vault KV v2 and injected at runtime. **Nothing sensitive is hardcoded in Terraform, Docker images, or Akash SDL files.**

## Architecture

```
┌─────────────────┐     AppRole      ┌──────────────────┐
│ Terraform CI/CD │ ───────────────► │  Vault (KV v2)   │
└─────────────────┘                  │  yieldswarm/*    │
                                       └────────┬─────────┘
┌─────────────────┐     AppRole                │
│ Akash container │ ───────────────────────────┘
│ (entrypoint)    │     exports env vars at start
└─────────────────┘
```

| Path | Contents | Readers |
|------|----------|---------|
| `yieldswarm/azure` | tenant_id, subscription_id, client_id, client_secret, resource_group, location | Terraform, Akash |
| `yieldswarm/runpod` | api_key | Terraform, Akash |
| `yieldswarm/vultr` | api_key | Terraform, Akash |
| `yieldswarm/digitalocean` | token, spaces_access_key, spaces_secret_key | Terraform, Akash |
| `yieldswarm/rpc` | solana_rpc_url, helius_api_key, failover_rpc_list | Terraform, Akash |
| `yieldswarm/agents` | grok_api_key, openai_api_key, agentswarm_master_key | Akash only |

## Prerequisites

- HashiCorp Vault 1.17+ (or use local dev compose)
- `vault` CLI, `jq`, `docker`, `terraform` >= 1.6
- TLS certificates for production Vault (`vault/tls/vault.crt`, `vault/tls/vault.key`)
- For Akash: `provider-services` CLI and funded wallet

---

## 1. Local development Vault

Start a dev Vault instance:

```bash
cd /workspace
docker compose -f vault/docker-compose.yml up -d
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
vault status
```

Bootstrap policies, AppRoles, and secret paths:

```bash
chmod +x vault/scripts/*.sh akash/scripts/*.sh akash/docker-entrypoint.sh
./vault/scripts/bootstrap.sh
```

Save the emitted `VAULT_ROLE_ID` / `VAULT_SECRET_ID` pairs for Terraform and Akash.

---

## 2. Production Vault cluster

### 2.1 Initialize and unseal

On the first Vault node:

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
vault operator init -key-shares=5 -key-threshold=3 -format=json > vault-init.json
# Store vault-init.json in a physical safe; never commit it.

vault operator unseal   # repeat with 3 of 5 keys
vault login <initial-root-token>
```

### 2.2 Start Vault with production config

```bash
docker run -d \
  --name vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -v /opt/vault/data:/vault/data \
  -v /opt/vault/tls:/vault/tls:ro \
  -v /workspace/vault/config/vault.hcl:/vault/config/vault.hcl:ro \
  hashicorp/vault:1.17 server -config=/vault/config/vault.hcl
```

For HA Raft, deploy three nodes using `vault/config/vault.hcl` and join followers:

```bash
vault operator raft join https://vault-1.yieldswarm.internal:8200
```

### 2.3 Enable audit logging

```bash
vault audit enable file file_path=/vault/audit/audit.log
```

### 2.4 Bootstrap YieldSwarm

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<bootstrap-token>
./vault/scripts/bootstrap.sh
```

### 2.5 Write real secret values

Replace every `REPLACE_ME_BEFORE_PRODUCTION` placeholder:

```bash
vault kv put yieldswarm/azure \
  tenant_id="<azure-tenant-id>" \
  subscription_id="<azure-subscription-id>" \
  client_id="<app-registration-client-id>" \
  client_secret="<app-registration-secret>" \
  resource_group="yieldswarm-prod" \
  location="eastus"

vault kv put yieldswarm/runpod \
  api_key="<runpod-api-key>"

vault kv put yieldswarm/vultr \
  api_key="<vultr-api-key>"

vault kv put yieldswarm/digitalocean \
  token="<do-personal-access-token>" \
  spaces_access_key="<spaces-key>" \
  spaces_secret_key="<spaces-secret>"

vault kv put yieldswarm/rpc \
  solana_rpc_url="https://mainnet.helius-rpc.com/?api-key=<key>" \
  helius_api_key="<helius-api-key>" \
  failover_rpc_list='["https://api.mainnet-beta.solana.com","https://solana-mainnet.g.alchemy.com/v2/<key>"]'

vault kv put yieldswarm/agents \
  grok_api_key="<grok-key>" \
  openai_api_key="<openai-key>" \
  agentswarm_master_key="<master-key>"
```

Verify (values are redacted in `-format=json` output when using `-field`):

```bash
vault kv get yieldswarm/azure
vault kv get yieldswarm/rpc
```

### 2.6 Revoke bootstrap root token

```bash
vault token revoke <bootstrap-root-token>
```

---

## 3. Terraform (pull secrets from Vault)

Terraform authenticates via the `yieldswarm-terraform` AppRole and reads all provider credentials from Vault. No secrets in `.tfvars` or code.

### 3.1 Configure CI/CD environment

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export TF_VAR_vault_role_id="<terraform-approle-role-id>"
export TF_VAR_vault_secret_id="<terraform-approle-secret-id>"
```

### 3.2 Plan and apply

```bash
cd terraform
terraform init
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

Terraform loads secrets via `modules/secrets` data sources and configures:

- `azurerm` — Azure subscription credentials
- `runpod` — RunPod API key
- `vultr` — Vultr API key
- `digitalocean` — DO token

RPC endpoints are available as sensitive module outputs for downstream modules.

### 3.3 GitHub Actions example

```yaml
env:
  VAULT_ADDR: https://vault.yieldswarm.internal:8200
  TF_VAR_vault_role_id: ${{ secrets.VAULT_TF_ROLE_ID }}
  TF_VAR_vault_secret_id: ${{ secrets.VAULT_TF_SECRET_ID }}
```

---

## 4. Akash runtime injection

The Akash container **never** embeds API keys. At startup, `akash/docker-entrypoint.sh`:

1. Authenticates to Vault via AppRole (`VAULT_ROLE_ID`, `VAULT_SECRET_ID`)
2. Reads KV paths: azure, runpod, vultr, digitalocean, rpc, agents
3. Exports uppercase env vars (e.g. `SOLANA_RPC_URL`, `RUNPOD_API_KEY`)
4. Unsets `VAULT_TOKEN` and `VAULT_SECRET_ID`
5. Execs the agent process

### 4.1 Build and push image

```bash
docker build -f akash/Dockerfile -t ghcr.io/yieldswarm/agentswarm-akash:latest .
docker push ghcr.io/yieldswarm/agentswarm-akash:latest
```

### 4.2 Deploy to Akash

```bash
export VAULT_ROLE_ID="<akash-runtime-approle-role-id>"
export VAULT_SECRET_ID="<akash-runtime-approle-secret-id>"
./akash/scripts/deploy.sh

provider-services run akash tx deployment create /tmp/deploy.yaml --from <wallet> --node https://rpc.akash.network:443 --chain-id akashnet-2
```

Only AppRole bootstrap credentials are passed at deploy time — not provider API keys.

### 4.3 Local smoke test

```bash
docker compose -f vault/docker-compose.yml up -d
./vault/scripts/bootstrap.sh   # capture akash AppRole creds

export VAULT_ADDR=http://host.docker.internal:8200
export VAULT_ROLE_ID=<akash-role-id>
export VAULT_SECRET_ID=<akash-secret-id>

docker build -f akash/Dockerfile -t agentswarm-akash:dev .
docker run --rm \
  -e VAULT_ADDR \
  -e VAULT_ROLE_ID \
  -e VAULT_SECRET_ID \
  -e VAULT_SKIP_VERIFY=true \
  agentswarm-akash:dev
```

Expected output: `Akash Optimizer Agent active - connecting to leases and optimizing for profit`

---

## 5. AppRole rotation

Rotate `secret_id` without changing `role_id`:

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<admin-token>

./vault/scripts/rotate-secret-id.sh terraform
./vault/scripts/rotate-secret-id.sh akash-runtime
```

Update CI/CD and Akash SDL env with the new `secret_id`. Old secret IDs can be revoked:

```bash
vault write auth/approle/role/yieldswarm-terraform/secret-id/destroy secret_id=<old-id>
```

---

## 6. Policies reference

| Policy | Purpose |
|--------|---------|
| `yieldswarm-admin` | Bootstrap, secret writes, AppRole management |
| `yieldswarm-terraform-read` | Read-only: azure, runpod, vultr, digitalocean, rpc |
| `yieldswarm-akash-runtime` | Read-only: azure, runpod, vultr, digitalocean, rpc, agents |

Files: `vault/policies/*.hcl`

---

## 7. Security checklist

- [ ] Vault runs with TLS and Raft HA (3+ nodes)
- [ ] Auto-unseal via Transit or cloud KMS configured
- [ ] Audit log enabled and shipped to SIEM
- [ ] Bootstrap root token revoked
- [ ] All placeholders replaced in Vault
- [ ] AppRole `secret_id` stored only in CI/CD / deploy-time env
- [ ] `VAULT_TOKEN` never passed to application containers
- [ ] `.env` files gitignored; use `.env.example` as documentation only
- [ ] Rotate provider keys quarterly via `vault kv put`

---

## 8. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied` on kv get | Check AppRole policy matches path (`yieldswarm/data/...`) |
| Terraform provider auth fails | Verify `TF_VAR_vault_role_id` and `secret_id`; check token TTL |
| Akash container exits immediately | Confirm `VAULT_ADDR` reachable from provider; check AppRole creds |
| `REPLACE_ME_BEFORE_PRODUCTION` in env | Run `vault kv put` with real values (section 2.5) |
| TLS errors | Set `VAULT_SKIP_VERIFY=true` only in dev; fix certs in prod |

---

## File map

```
vault/
  config/vault.hcl          # Production server config (Raft + TLS)
  policies/                 # ACL policies
  scripts/bootstrap.sh      # One-time setup
  scripts/rotate-secret-id.sh
  docker-compose.yml        # Local dev Vault

terraform/
  providers.tf              # Vault auth + cloud providers from secrets
  modules/secrets/          # vault_kv_secret_v2 data sources

akash/
  Dockerfile
  docker-entrypoint.sh      # Runtime Vault injection
  deploy.yaml               # Akash SDL (no API keys)
  scripts/deploy.sh

SECRETS.md                  # This guide
```
