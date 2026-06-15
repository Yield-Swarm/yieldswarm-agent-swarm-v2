# YieldSwarm AgentSwarm OS — Secrets Management

Production-grade HashiCorp Vault integration for YieldSwarm. All cloud provider credentials (Azure, RunPod, Vultr, DigitalOcean) and RPC secrets are stored in Vault and injected at runtime. **Nothing is hardcoded.**

## Architecture

```
┌─────────────────┐     AppRole      ┌──────────────────┐
│  Terraform CI   │ ───────────────► │  HashiCorp Vault │
│  (plan/apply)   │ ◄── KV v2 read   │  yieldswarm/     │
└─────────────────┘                  └────────┬─────────┘
                                              │ AppRole
┌─────────────────┐     Vault Agent           │
│  Akash Container│ ◄─────────────────────────┘
│  (runtime)      │   renders /opt/yieldswarm/secrets.env
└─────────────────┘
```

### Secret Paths (KV v2 mount: `yieldswarm/`)

| Path | Contents | Consumers |
|------|----------|-----------|
| `yieldswarm/azure` | subscription_id, client_id, client_secret, tenant_id | Terraform |
| `yieldswarm/runpod` | api_key, endpoint | Terraform, Akash agents |
| `yieldswarm/vultr` | api_key | Terraform |
| `yieldswarm/digitalocean` | token, spaces keys | Terraform |
| `yieldswarm/rpc` | solana_rpc_url, helius_api_key, failover_rpc_list | Terraform, Akash agents |
| `yieldswarm/agents/runtime` | master keys, LLM API keys, encryption keys | Akash containers |
| `yieldswarm/agents/shard/NNN` | per-shard overrides (000–119) | Shard crons |

---

## Prerequisites

- HashiCorp Vault 1.15+ (HA recommended)
- `vault` CLI, `jq`, `curl`
- TLS certificates for Vault (`/etc/vault/tls/`)
- AWS KMS key for auto-unseal (production) or manual unseal keys (staging)
- Docker (for Akash image build)
- Terraform 1.6+
- Akash CLI (`akash`) for deployment

---

## Step 1: Install and Start Vault (Production)

```bash
# Install Vault (Ubuntu/Debian)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault

# Create data and TLS directories
sudo mkdir -p /opt/vault/data /etc/vault/tls
sudo cp vault/config/vault.hcl /etc/vault/vault.hcl

# Place TLS certs (from your CA or cert-manager)
sudo cp vault.crt /etc/vault/tls/vault.crt
sudo cp vault.key /etc/vault/tls/vault.key

# Start Vault
sudo vault server -config=/etc/vault/vault.hcl
```

### Initialize and Unseal

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200

# One-time init — SAVE output to a secure offline location
vault operator init -key-shares=5 -key-threshold=3 -format=json | tee vault-init.json

# Unseal (3 of 5 key holders required)
vault operator unseal  # repeat with 3 different unseal keys

# Authenticate with initial root token (revoke after bootstrap)
export VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)
```

> **Production:** Configure `seal "awskms"` in `vault/config/vault.hcl` for auto-unseal. Revoke the root token immediately after bootstrap.

---

## Step 2: Bootstrap Policies, Engines, and AppRoles

```bash
cd vault/scripts
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<admin-token>

./bootstrap.sh
```

This runs, in order:

1. `enable-secrets-engines.sh` — enables KV v2 at `yieldswarm/`
2. `create-policies.sh` — applies admin, terraform, akash, and agent policies
3. `create-approles.sh` — creates `yieldswarm-terraform`, `yieldswarm-akash`, `yieldswarm-agent`
4. `seed-secrets.sh` — creates secret paths with `REPLACE_ME` placeholders

### Create Shard Policies (120 cron shards)

```bash
./create-shard-policies.sh 0 119
```

---

## Step 3: Store Production Secrets

Replace every `REPLACE_ME` value. **Never echo secrets to logs.**

```bash
# Azure service principal
vault kv put yieldswarm/azure \
  subscription_id="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  client_id="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  client_secret="YOUR_CLIENT_SECRET" \
  tenant_id="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  resource_group="yieldswarm-prod" \
  location="eastus"

# RunPod
vault kv put yieldswarm/runpod \
  api_key="YOUR_RUNPOD_API_KEY" \
  endpoint="https://api.runpod.io/graphql"

# Vultr
vault kv put yieldswarm/vultr \
  api_key="YOUR_VULTR_API_KEY"

# DigitalOcean
vault kv put yieldswarm/digitalocean \
  token="YOUR_DO_TOKEN" \
  spaces_access_key="YOUR_SPACES_KEY" \
  spaces_secret_key="YOUR_SPACES_SECRET" \
  spaces_region="nyc3"

# RPC endpoints and API keys
vault kv put yieldswarm/rpc \
  solana_rpc_url="https://mainnet.helius-rpc.com/?api-key=YOUR_KEY" \
  helius_api_key="YOUR_HELIUS_KEY" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]' \
  birdeye_api_key="YOUR_BIRDEYE_KEY" \
  jupiter_api_key="YOUR_JUPITER_KEY"

# Agent runtime secrets (Akash containers)
vault kv put yieldswarm/agents/runtime \
  agentswarm_master_key="YOUR_MASTER_KEY" \
  kimiclaw_consensus_key="YOUR_KIMICLAW_KEY" \
  grok_api_key="YOUR_GROK_KEY" \
  openai_api_key="YOUR_OPENAI_KEY" \
  gemini_api_key="YOUR_GEMINI_KEY" \
  anthropic_api_key="YOUR_ANTHROPIC_KEY" \
  wallet_encryption_key="YOUR_WALLET_KEY" \
  tee_signing_key="YOUR_TEE_KEY" \
  database_encryption_key="YOUR_DB_KEY" \
  gpu_cluster_keys='["YOUR_RUNPOD_KEY"]' \
  agent_shard_id="0" \
  agent_count_total="10080" \
  agents_per_shard="84"
```

### Verify (no values shown)

```bash
vault kv get -format=json yieldswarm/azure | jq '.data.data | keys'
vault kv get -format=json yieldswarm/rpc | jq '.data.data | keys'
```

---

## Step 4: Configure AppRole Credentials for CI/CD

```bash
# Terraform AppRole — store role_id in CI variables
vault read auth/approle/role/yieldswarm-terraform/role-id

# Generate secret_id (short-lived; rotate regularly)
vault write -f auth/approle/role/yieldswarm-terraform/secret-id

# Akash AppRole — role_id goes in SDL env; secret_id at deploy time only
vault read auth/approle/role/yieldswarm-akash/role-id
vault write -f -wrap-ttl=300s auth/approle/role/yieldswarm-akash/secret-id
```

Store in your CI/CD secret store:

| Variable | Source |
|----------|--------|
| `VAULT_ADDR` | `https://vault.yieldswarm.internal:8200` |
| `TF_VAR_vault_addr` | Same as above |
| `TF_VAR_vault_role_id` | `yieldswarm-terraform` role_id |
| `TF_VAR_vault_secret_id` | Generated secret_id (rotate each apply) |
| `VAULT_ROLE_ID` | `yieldswarm-akash` role_id |
| `VAULT_SECRET_ID` | Generated at deploy time only |

---

## Step 5: Terraform (Pull Secrets from Vault)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set vault_role_id; inject secret_id via env

export TF_VAR_vault_secret_id="YOUR_TERRAFORM_SECRET_ID"
terraform init
terraform plan
terraform apply
```

Terraform reads all provider credentials from Vault at plan/apply time:

- **Azure** → `data.vault_kv_secret_v2.azure` → `azurerm` provider
- **RunPod** → `data.vault_kv_secret_v2.runpod` → HTTP GraphQL validation
- **Vultr** → `data.vault_kv_secret_v2.vultr` → `vultr` provider
- **DigitalOcean** → `data.vault_kv_secret_v2.digitalocean` → `digitalocean` provider
- **RPC** → `data.vault_kv_secret_v2.rpc` → health checks + Azure Key Vault sync

No secrets are committed to git or stored in `.tfvars` beyond the AppRole credentials.

---

## Step 6: Build and Deploy Akash Container

### Build Docker Image

```bash
docker build -t yieldswarm/agentswarm:latest -f akash/Dockerfile .
docker push yieldswarm/agentswarm:latest
```

### Deploy to Akash

```bash
export AKASH_KEY_NAME=your-wallet
export AKASH_NET=mainnet
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/yieldswarm-akash/role-id)
export VAULT_SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/yieldswarm-akash/secret-id)

cd akash
./deploy.sh
```

### Runtime Secret Flow

1. Akash injects `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID` as environment variables
2. `entrypoint.sh` writes AppRole credentials to `/run/vault/` (secret_id deleted after read)
3. Vault Agent authenticates and renders templates to `/opt/yieldswarm/secrets.env`
4. Entrypoint sources secrets and validates required keys
5. Agent runner starts with all credentials in environment

### Local Development (Vault skipped)

```bash
# Create a local secrets file — never commit
cat > /tmp/secrets.env <<'EOF'
AGENTSWARM_MASTER_KEY=dev-only-key
SOLANA_RPC_URL=https://api.devnet.solana.com
EOF

docker run --rm \
  -e VAULT_SKIP=true \
  -e YIELDSWARM_SECRETS_FILE=/tmp/secrets.env \
  -v /tmp/secrets.env:/tmp/secrets.env:ro \
  yieldswarm/agentswarm:latest
```

---

## Step 7: Secret Rotation

### Rotate a Cloud Provider Key

```bash
# Update secret (CAS required — pass current version)
vault kv put yieldswarm/runpod api_key="NEW_KEY" endpoint="https://api.runpod.io/graphql"

# Restart affected workloads (Akash lease update or container restart)
```

### Rotate AppRole secret_id

```bash
# Revoke old secret_id
vault write auth/approle/role/yieldswarm-akash/secret-id-accessor/destroy \
  secret_id_accessor="ACCESSOR_FROM_LOOKUP"

# Issue new secret_id
vault write -f auth/approle/role/yieldswarm-akash/secret-id
```

### Rotate Encryption Keys

```bash
vault kv put yieldswarm/agents/runtime \
  agentswarm_master_key="NEW_KEY"
```

---

## Security Checklist

- [ ] Root token revoked after bootstrap
- [ ] Auto-unseal configured (AWS KMS or HSM)
- [ ] TLS enabled on Vault listener
- [ ] AppRole secret_ids have TTL and rotation policy
- [ ] `cas_required=true` on KV mount (prevents accidental overwrites)
- [ ] Audit logging enabled: `vault audit enable file file_path=/var/log/vault/audit.log`
- [ ] No secrets in git, SDL, Docker image, or Terraform state outputs
- [ ] CI/CD uses short-lived secret_ids per pipeline run
- [ ] Shard policies isolate cron secrets (000–119)

### Enable Audit Log

```bash
vault audit enable file file_path=/var/log/vault/audit.log
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied` on kv get | Check AppRole policy matches secret path |
| Vault Agent timeout | Verify `VAULT_ADDR` reachable from Akash provider network |
| `Timed out waiting for secrets` | Check templates: `vault agent -config=akash/vault-agent.hcl -test` |
| Terraform auth failure | Regenerate secret_id; verify role_id |
| `cas_required` error on put | Use `vault kv patch` or pass `-cas=N` with current version |

### Test Vault Agent Locally

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
echo "$VAULT_ROLE_ID" > /tmp/role-id
echo "$VAULT_SECRET_ID" > /tmp/secret-id

vault agent -config=akash/vault-agent.hcl -test
```

---

## File Reference

| Path | Purpose |
|------|---------|
| `vault/config/vault.hcl` | Production Vault server config |
| `vault/policies/*.hcl` | Least-privilege policies |
| `vault/scripts/bootstrap.sh` | One-command bootstrap |
| `terraform/vault-data.tf` | Vault data sources for all providers |
| `akash/Dockerfile` | Container with Vault Agent |
| `akash/entrypoint.sh` | Runtime secret injection |
| `akash/deploy.yaml` | Akash SDL (no secrets) |
| `lib/secrets.py` | Python secret loader |
