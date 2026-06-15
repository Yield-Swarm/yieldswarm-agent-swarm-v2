# YieldSwarm Secrets Management — HashiCorp Vault

This is the single source of truth for how YieldSwarm handles secrets. Every
credential — cloud providers (Azure, RunPod, Vultr, DigitalOcean), RPC
endpoints, and application runtime keys — lives in **HashiCorp Vault**. Nothing
sensitive is committed to git, baked into images, or written to `.tf`/`.tfvars`
files.

```
┌──────────────┐   AppRole    ┌─────────────────────┐
│  Terraform   │ ───────────▶ │                     │  reads cloud/* + rpc/*
│  (CI)        │              │   HashiCorp Vault   │
└──────────────┘              │   KV v2  @ kv/      │
                              │   Transit @ transit/│
┌──────────────┐   AppRole    │   AppRole auth      │  reads app/* + rpc/*
│ Akash agents │ ───────────▶ │                     │
│ (entrypoint) │              └─────────────────────┘
└──────────────┘
```

## Repository layout

| Path | Purpose |
|------|---------|
| `infra/vault/config/vault.hcl` | Production Vault server config (Raft HA, TLS, auto-unseal) |
| `infra/vault/policies/*.hcl` | Least-privilege ACL policies |
| `infra/vault/bootstrap/bootstrap.sh` | Enables engines, policies, AppRole (idempotent) |
| `infra/vault/bootstrap/seed-secrets.sh` | Writes secret values from env into KV |
| `infra/terraform/` | Terraform that pulls all provider creds from Vault |
| `infra/akash/` | Vault-aware Dockerfile, entrypoint, and Akash SDL |

## Secret layout (KV v2, mount `kv/`)

| Vault path | Keys |
|------------|------|
| `kv/yieldswarm/cloud/azure` | `subscription_id`, `tenant_id`, `client_id`, `client_secret` |
| `kv/yieldswarm/cloud/runpod` | `api_key` |
| `kv/yieldswarm/cloud/vultr` | `api_key` |
| `kv/yieldswarm/cloud/digitalocean` | `token`, `spaces_access_id`, `spaces_secret_key` |
| `kv/yieldswarm/rpc/solana` | `rpc_url`, `helius_api_key`, `birdeye_api_key`, `jupiter_api_key` |
| `kv/yieldswarm/app/core` | `agentswarm_master_key`, `kimiclaw_consensus_key`, `wallet_encryption_key`, `tee_signing_key`, `database_encryption_key` |
| `kv/yieldswarm/app/llm` | `openai_api_key`, `anthropic_api_key`, `gemini_api_key`, `grok_api_key` |

---

## 0. Prerequisites

```bash
vault version          # Vault CLI >= 1.15
terraform version      # Terraform >= 1.6
jq --version           # required by the Akash entrypoint
provider-services version   # Akash CLI (for deployment)
```

---

## 1. Stand up the Vault server (production)

Deploy `infra/vault/config/vault.hcl` to each node (rendering `NODE_NAME`,
`NODE_FQDN`, and the `retry_join` peers), provision TLS certs into
`/etc/vault.d/tls/`, then start Vault and initialize **once**:

```bash
# On the first node only:
export VAULT_ADDR="https://vault.internal:8200"
vault operator init -key-shares=5 -key-threshold=3
```

Store the unseal keys and the initial root token in your offline break-glass
vault (e.g. a hardware token / sealed envelope). If you configured the
`azurekeyvault` auto-unseal stanza, nodes unseal automatically; otherwise
unseal each node with 3 of the 5 keys:

```bash
vault operator unseal   # repeat with 3 distinct keys
```

---

## 2. Bootstrap engines, policies, and AppRole

```bash
export VAULT_ADDR="https://vault.internal:8200"
export VAULT_TOKEN="<initial-root-token>"

./infra/vault/bootstrap/bootstrap.sh
```

This idempotently enables the `kv` (v2) and `transit` engines, a file audit
device, writes the three ACL policies, and creates the two AppRoles
(`terraform-provisioner`, `akash-runtime`).

---

## 3. Seed secret values

Export only the secrets you have; empty groups are skipped. Run from a trusted,
ephemeral shell (TEE / air-gapped). **These commands set environment variables
locally — they are never committed.**

```bash
export VAULT_ADDR="https://vault.internal:8200"
export VAULT_TOKEN="<admin-or-root-token>"

# Cloud providers
export AZURE_SUBSCRIPTION_ID="..." AZURE_TENANT_ID="..." \
       AZURE_CLIENT_ID="..."       AZURE_CLIENT_SECRET="..."
export RUNPOD_API_KEY="..."
export VULTR_API_KEY="..."
export DIGITALOCEAN_TOKEN="..."

# RPC
export SOLANA_RPC_URL="https://api.mainnet-beta.solana.com" \
       HELIUS_API_KEY="..." BIRDEYE_API_KEY="..." JUPITER_API_KEY="..."

# App runtime
export AGENTSWARM_MASTER_KEY="..." KIMICLAW_CONSENSUS_KEY="..." \
       WALLET_ENCRYPTION_KEY="..." TEE_SIGNING_KEY="..." \
       DATABASE_ENCRYPTION_KEY="..." \
       OPENAI_API_KEY="..." ANTHROPIC_API_KEY="..." \
       GEMINI_API_KEY="..." GROK_API_KEY="..."

./infra/vault/bootstrap/seed-secrets.sh
```

Verify (paths only, never values, in shared terminals):

```bash
vault kv list -mount=kv yieldswarm/cloud
vault kv list -mount=kv yieldswarm/rpc
vault kv get  -mount=kv yieldswarm/cloud/azure   # only on a trusted screen
```

Rotate a single value any time without touching code:

```bash
vault kv patch -mount=kv yieldswarm/cloud/vultr api_key="<new-key>"
```

---

## 4. Terraform — provision infra with Vault-sourced credentials

Terraform authenticates to Vault with the `terraform-provisioner` AppRole and
reads `cloud/*` + `rpc/*`. No provider credentials are stored in any file.

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # edit non-secret values only

export VAULT_ADDR="https://vault.internal:8200"

# Mint short-lived AppRole creds for this run (CI does this per pipeline):
export TF_VAR_vault_approle_role_id="$(
  vault read -field=role_id auth/approle/role/terraform-provisioner/role-id)"
export TF_VAR_vault_approle_secret_id="$(
  vault write -field=secret_id -f auth/approle/role/terraform-provisioner/secret-id)"

terraform init \
  -backend-config="resource_group_name=yieldswarm-tfstate" \
  -backend-config="storage_account_name=yieldswarmtfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=infra/terraform.tfstate"

terraform plan
terraform apply
```

> **State is sensitive.** Reading Vault secrets into Terraform persists them in
> state, so the backend is an encrypted, access-controlled Azure Blob container
> (`backend.tf`). Never store state locally or in git.

Enable the example resources per environment with the toggles in
`terraform.tfvars` (`enable_azure_examples`, etc.). Add real resources to
`main.tf`; the provider wiring already pulls from Vault.

---

## 5. Akash — build the image and inject secrets at runtime

The container ships with **zero secrets**. At boot, `entrypoint.sh` logs into
Vault with the `akash-runtime` AppRole, loads `app/*` + `rpc/*`, exports them as
environment variables, revokes its token, then `exec`s the workload.

### 5a. Build & push

```bash
# Build from the repo root (Dockerfile expects the repo as context):
docker build -f infra/akash/Dockerfile -t ghcr.io/<org>/yieldswarm-agents:1.0.0 .
docker push ghcr.io/<org>/yieldswarm-agents:1.0.0
```

### 5b. Mint deploy-time credentials (rotated every deployment)

```bash
export VAULT_ADDR="https://vault.internal:8200"

ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)"

# Response-wrapped, single-use secret_id (120s TTL). The raw secret_id is
# never exposed — only this wrapping token travels in the manifest.
WRAP_TOKEN="$(vault write -wrap-ttl=120s -field=wrapping_token \
  -f auth/approle/role/akash-runtime/secret-id)"
```

### 5c. Render the SDL and deploy

```bash
sed -e "s|AKASH_IMAGE|ghcr.io/<org>/yieldswarm-agents:1.0.0|" \
    -e "s|VAULT_ADDR|${VAULT_ADDR}|" \
    -e "s|VAULT_ROLE_ID|${ROLE_ID}|" \
    -e "s|VAULT_SECRET_ID_WRAPPING_TOKEN|${WRAP_TOKEN}|" \
    infra/akash/deploy.yaml > /tmp/deploy.rendered.yaml

provider-services tx deployment create /tmp/deploy.rendered.yaml \
  --from <akash-key> --node <rpc> --chain-id <chain>

shred -u /tmp/deploy.rendered.yaml   # remove the rendered manifest immediately
```

Because the wrapped secret_id is single-use and expires in ~120s, a leaked
manifest is worthless after the deploy completes. Mint a fresh one for every
deployment.

### Local test (Docker, without Akash)

```bash
docker run --rm \
  -e VAULT_ADDR="https://vault.internal:8200" \
  -e VAULT_ROLE_ID="${ROLE_ID}" \
  -e VAULT_SECRET_ID_WRAPPING_TOKEN="${WRAP_TOKEN}" \
  ghcr.io/<org>/yieldswarm-agents:1.0.0
```

---

## 6. Operations

### Rotation
- **Secret values:** `vault kv patch -mount=kv <path> <key>=<new>` — consumers
  pick up the new version on next Terraform run / container restart.
- **AppRole secret_id:** short TTLs mean they expire automatically; just mint a
  new one. Force-revoke all with:
  ```bash
  vault write -f auth/approle/role/akash-runtime/secret-id-accessor/destroy \
    secret_id_accessor=<accessor>
  ```
- **Transit key:** `vault write -f transit/keys/yieldswarm-data/rotate`

### Auditing
File audit is enabled at `/var/log/vault/audit.log`. Secret values are HMAC'd in
audit logs, so the log records *who read what, when* without exposing values.

### Least privilege
| Principal | Policy | Can read |
|-----------|--------|----------|
| Terraform / CI | `terraform-provisioner` | `cloud/*`, `rpc/*` (read-only) |
| Akash agents | `akash-runtime` | `app/*`, `rpc/*` (read-only) |
| Operators | `secrets-admin` | full management of `yieldswarm/*` |

Terraform cannot read application keys; agents cannot read cloud provisioning
credentials. Revoke the initial root token after bootstrap and manage operator
access through an OIDC-backed identity group mapped to `secrets-admin`.

### Never do
- ❌ Commit `.env`, `terraform.tfvars`, `*.tfstate`, or `.vault-token`.
- ❌ Put secrets in the Akash SDL, Dockerfile, or any `.tf` file.
- ❌ Bake secrets into container images.
- ❌ Echo secret values in CI logs (mark CI variables as masked).
