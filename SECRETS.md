# YieldSwarm AgentSwarm OS — Secrets Management with HashiCorp Vault

Production-grade secret management for YieldSwarm. **All cloud provider credentials and RPC keys live in Vault** — never in git, Docker images, or Akash SDL files.

## Architecture

```
┌─────────────┐     AppRole      ┌──────────────────┐
│  Terraform  │ ───────────────► │  HashiCorp Vault │
│  CI/CD      │   (terraform)    │  KV v2: yieldswarm│
└─────────────┘                  └────────┬─────────┘
                                          │
┌─────────────┐     AppRole               │ read
│   Akash     │ ───────────────►          │
│  Container  │   (akash-runtime)         ▼
└─────────────┘                  ┌──────────────────┐
                                 │  Secret Paths:    │
                                 │  azure, runpod,   │
                                 │  vultr, digital-  │
                                 │  ocean, rpc, akash│
                                 └──────────────────┘
```

| Component | Auth Method | Policy | Secret Paths |
|-----------|-------------|--------|--------------|
| Terraform CI/CD | AppRole `terraform` | `yieldswarm-terraform` | azure, runpod, vultr, digitalocean, rpc, akash |
| Akash runtime | AppRole `akash-runtime` | `yieldswarm-akash-runtime` | akash, rpc, runpod |
| Operators (bootstrap) | Root/OIDC token | `yieldswarm-admin` | all |
| CI validation | AppRole `ci-readonly` | `yieldswarm-ci-readonly` | all (read) |

---

## 1. Install Vault CLI

```bash
# macOS
brew tap hashicorp/tap && brew install hashicorp/tap/vault

# Linux (Debian/Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault jq
```

---

## 2. Start Vault (Production)

Use the config at `infra/vault/config/vault.hcl`. Mount TLS certificates and configure KMS auto-unseal before going live.

```bash
# On your Vault server (example with Docker — replace with your HA cluster)
docker run -d \
  --name vault \
  --cap-add=IPC_LOCK \
  -p 8200:8200 \
  -v "$(pwd)/infra/vault/config:/vault/config:ro" \
  -v vault-data:/vault/data \
  -v /path/to/tls:/vault/tls:ro \
  hashicorp/vault:1.17 server -config=/vault/config/vault.hcl
```

### Initialize and unseal (first run only)

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_CACERT=/path/to/ca.pem

vault operator init -key-shares=5 -key-threshold=3 -format=json | tee vault-init.json
# Store unseal keys and root token in your break-glass KMS — NEVER commit vault-init.json

vault operator unseal   # repeat until sealed=false (3 of 5 keys)
export VAULT_TOKEN=<root-token-from-init>
```

> **Production:** Replace manual unseal with AWS KMS, GCP CKMS, or Azure Key Vault auto-unseal. See [Vault seal documentation](https://developer.hashicorp.com/vault/docs/configuration/seal).

---

## 3. Bootstrap Policies, AppRoles, and Secret Paths

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<admin-token>

chmod +x infra/vault/scripts/*.sh
./infra/vault/scripts/bootstrap.sh
```

This script:
- Mounts KV v2 at `yieldswarm/`
- Writes policies from `infra/vault/policies/`
- Enables AppRole auth and creates `terraform`, `akash-runtime`, `ci-readonly` roles
- Seeds placeholder secrets at all required paths

---

## 4. Write Real Secret Values

Replace every `REPLACE_ME` placeholder. **Never paste real values into git.**

### Azure

```bash
vault kv put yieldswarm/azure \
  subscription_id="YOUR_SUBSCRIPTION_ID" \
  tenant_id="YOUR_TENANT_ID" \
  client_id="YOUR_CLIENT_ID" \
  client_secret="YOUR_CLIENT_SECRET" \
  resource_group="yieldswarm-prod" \
  location="eastus2"
```

Or from the JSON template:

```bash
vault kv put yieldswarm/azure @infra/vault/secrets/azure.json
```

### RunPod

```bash
vault kv put yieldswarm/runpod \
  api_key="YOUR_RUNPOD_API_KEY" \
  default_gpu_type="NVIDIA RTX 4090" \
  default_region="US"
```

### Vultr

```bash
vault kv put yieldswarm/vultr \
  api_key="YOUR_VULTR_API_KEY" \
  default_region="ewr"
```

### DigitalOcean

```bash
vault kv put yieldswarm/digitalocean \
  api_token="YOUR_DO_API_TOKEN" \
  default_region="nyc3" \
  spaces_access_key="YOUR_SPACES_KEY" \
  spaces_secret_key="YOUR_SPACES_SECRET"
```

### RPC (Solana + failover)

```bash
vault kv put yieldswarm/rpc \
  solana_rpc_url="https://mainnet.helius-rpc.com/?api-key=YOUR_KEY" \
  helius_api_key="YOUR_HELIUS_KEY" \
  failover_rpc_list='["https://rpc1.example.com","https://rpc2.example.com"]' \
  birdeye_api_key="YOUR_BIRDEYE_KEY" \
  jupiter_api_key="YOUR_JUPITER_KEY" \
  raydium_api_key="YOUR_RAYDIUM_KEY"
```

### Akash runtime

```bash
vault kv put yieldswarm/akash \
  wallet_mnemonic="YOUR_AKASH_WALLET_MNEMONIC" \
  certificate_path="/secrets/akash/cert.pem" \
  key_path="/secrets/akash/key.pem" \
  rpc_endpoint="https://rpc.akash.network:443" \
  chain_id="akashnet-2" \
  gas_prices="0.025uakt" \
  agentswarm_master_key="YOUR_MASTER_KEY" \
  gpu_cluster_keys='["runpod_key_1","runpod_key_2"]'
```

### Validate

```bash
./infra/vault/scripts/validate-secrets.sh
```

---

## 5. Generate AppRole Credentials

### Terraform CI/CD

```bash
export TF_VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform/role-id)
export TF_VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/terraform/secret-id)

echo "Store these in your CI secret store (GitHub Actions, Azure DevOps, etc.):"
echo "  VAULT_APPROLE_ROLE_ID=${TF_VAULT_ROLE_ID}"
echo "  VAULT_APPROLE_SECRET_ID=${TF_VAULT_SECRET_ID}"
```

### Akash runtime

```bash
export AKASH_VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
export AKASH_VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)
```

> `role_id` is not highly sensitive. `secret_id` is — treat it like a password and rotate regularly.

### Rotate secret-id

```bash
./infra/vault/scripts/rotate-approle-secret.sh terraform
./infra/vault/scripts/rotate-approle-secret.sh akash-runtime
```

---

## 6. Terraform — Pull Secrets from Vault

Terraform reads all provider credentials from Vault at plan/apply time via the `terraform` AppRole.

```bash
cd terraform

export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export TF_VAR_vault_address="${VAULT_ADDR}"
export TF_VAR_vault_approle_role_id="${TF_VAULT_ROLE_ID}"
export TF_VAR_vault_approle_secret_id="${TF_VAULT_SECRET_ID}"

terraform init
terraform plan
terraform apply
```

### What Terraform reads from Vault

| Vault Path | Provider | Keys Used |
|------------|----------|-----------|
| `yieldswarm/azure` | `azurerm` | subscription_id, tenant_id, client_id, client_secret |
| `yieldswarm/runpod` | `runpod` | api_key |
| `yieldswarm/vultr` | `vultr` | api_key |
| `yieldswarm/digitalocean` | `digitalocean` | api_token |
| `yieldswarm/rpc` | outputs / env wiring | solana_rpc_url, helius_api_key, failover_rpc_list |
| `yieldswarm/akash` | outputs | chain_id, rpc_endpoint |

By default, resource creation is disabled (`*_create_* = false`). Enable provisioning in `terraform.tfvars` only when ready:

```hcl
azure_create_resource_group = true
do_create_droplet           = true
vultr_create_instance       = true
runpod_create_pod           = true
```

### CI example (GitHub Actions)

```yaml
env:
  VAULT_ADDR: https://vault.yieldswarm.internal:8200
  TF_VAR_vault_approle_role_id: ${{ secrets.VAULT_APPROLE_ROLE_ID }}
  TF_VAR_vault_approle_secret_id: ${{ secrets.VAULT_APPROLE_SECRET_ID }}

steps:
  - uses: hashicorp/setup-terraform@v3
  - run: terraform init && terraform plan
    working-directory: terraform
```

---

## 7. Akash — Runtime Secret Injection

Secrets are **never** baked into the Docker image. The entrypoint authenticates to Vault at container start and injects environment variables.

### Build and push image

```bash
docker build -f deploy/akash/Dockerfile -t ghcr.io/yield-swarm/agentswarm-akash:latest .
docker push ghcr.io/yield-swarm/agentswarm-akash:latest
```

### Deploy to Akash

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_ROLE_ID="${AKASH_VAULT_ROLE_ID}"
export VAULT_SECRET_ID="${AKASH_VAULT_SECRET_ID}"

chmod +x deploy/akash/deploy.sh
./deploy/akash/deploy.sh
```

The SDL (`deploy/akash/deploy.yaml`) references `${VAULT_ADDR}`, `${VAULT_ROLE_ID}`, and `${VAULT_SECRET_ID}` as deploy-time variables — substituted by `deploy.sh` via `envsubst` and never committed.

### How injection works

1. Container starts → `entrypoint.sh` runs
2. AppRole login to Vault
3. Fetches `yieldswarm/akash`, `yieldswarm/rpc`, `yieldswarm/runpod`
4. Writes `/run/secrets/app.env` (mode 600), sources it
5. Rejects any `REPLACE_ME` placeholders
6. Execs `python agents/akash-optimizer.py`

### Vault Agent sidecar (alternative)

For long-running leases, use `deploy/akash/vault-agent.hcl` + `deploy/akash/templates/app.env.tpl` to auto-renew secrets every 5 minutes.

---

## 8. Local Development

For local agent development without Vault, use a dev Vault instance:

```bash
# Dev-only — in-memory Vault (never use in production)
docker run -d --name vault-dev -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=dev-root-token \
  hashicorp/vault:1.17 server -dev

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=dev-root-token
export VAULT_SKIP_VERIFY=true

./infra/vault/scripts/bootstrap.sh
# Write real dev secrets, then:
export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
export VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)

docker build -f deploy/akash/Dockerfile -t agentswarm-akash:dev .
docker run --rm \
  -e VAULT_ADDR=http://host.docker.internal:8200 \
  -e VAULT_ROLE_ID \
  -e VAULT_SECRET_ID \
  -e VAULT_SKIP_VERIFY=true \
  agentswarm-akash:dev
```

---

## 9. Secret Path Reference

```
yieldswarm/
├── azure          # Azure service principal
├── runpod         # RunPod API key
├── vultr          # Vultr API key
├── digitalocean   # DO API token + Spaces keys
├── rpc            # Solana RPC URLs and API keys
└── akash          # Akash wallet, certs, agent keys
```

---

## 10. Security Checklist

- [ ] Vault HA cluster with TLS and KMS auto-unseal
- [ ] Root token revoked after bootstrap; operators use OIDC
- [ ] All `REPLACE_ME` values replaced in Vault
- [ ] AppRole `secret_id` stored only in CI/CD and deploy-time env
- [ ] `secret_id` rotation scheduled (weekly recommended)
- [ ] Audit logging enabled (`vault audit enable file ...`)
- [ ] No secrets in git, Docker layers, or Akash SDL committed files
- [ ] `validate-secrets.sh` passes in CI before deploy
- [ ] Break-glass unseal keys stored in separate KMS/HSM

---

## 11. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Vault AppRole login failed` | Check `VAULT_ROLE_ID` / `VAULT_SECRET_ID`; rotate if expired |
| `REPLACE_ME placeholders` | Run `vault kv put` for each path with real values |
| `permission denied` on secret path | Verify AppRole policy matches the path |
| Terraform can't reach Vault | Check `VAULT_ADDR`, TLS cert, and network ACLs |
| Akash container exits immediately | Check `docker logs`; ensure Vault is reachable from provider network |

```bash
# Test AppRole login manually
vault write auth/approle/login \
  role_id="${VAULT_ROLE_ID}" \
  secret_id="${VAULT_SECRET_ID}"

# Read a secret with the returned token
vault kv get yieldswarm/azure
```
