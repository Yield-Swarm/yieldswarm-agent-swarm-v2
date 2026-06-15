# HashiCorp Vault Secrets Setup

This repository keeps production secrets in HashiCorp Vault. Terraform reads cloud and RPC credentials from Vault, and Akash workloads receive secrets at runtime through Vault Agent. Do not commit `.env`, `.tfvars`, Terraform state, Vault tokens, AppRole SecretIDs, mnemonics, private keys, or provider API tokens.

## 0. Prerequisites

- A production Vault cluster reachable over TLS.
- `vault`, `terraform`, `docker`, `envsubst`, and `akash` CLIs installed locally.
- A Vault admin token or an operator identity allowed to manage mounts, policies, and AppRoles.
- Docker registry credentials for the image used by Akash.

Set the Vault address and authenticate:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_NAMESPACE=""
vault login
vault status
```

For HCP Vault or Vault Enterprise namespaces, set the real namespace:

```bash
export VAULT_NAMESPACE="admin"
```

## 1. Bootstrap Vault engines, policies, and AppRoles

Before team or CI use, configure encrypted remote Terraform state. For Azure-backed state, copy `infra/terraform/examples/backend.azurerm.tf.example` into the stack directory as `backend.tf` and edit the storage account details.

Run Terraform against the bootstrap stack:

```bash
terraform -chdir=infra/terraform/vault-bootstrap init
terraform -chdir=infra/terraform/vault-bootstrap plan \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_namespace=${VAULT_NAMESPACE}"
terraform -chdir=infra/terraform/vault-bootstrap apply \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_namespace=${VAULT_NAMESPACE}"
```

This creates:

- `secret/` KV v2 engine for YieldSwarm secrets.
- `transit/` engine with non-exportable encryption keys.
- `yieldswarm-terraform-ci`, `yieldswarm-akash-runtime`, `yieldswarm-chainlink-vault-manager`, and `yieldswarm-openclaw-scaler` policies.
- AppRole identities for Terraform automation and runtime workloads.

If `secret/` or `transit/` already exist and are managed outside this repository, import them before applying:

```bash
terraform -chdir=infra/terraform/vault-bootstrap import vault_mount.kv secret
terraform -chdir=infra/terraform/vault-bootstrap import vault_mount.transit transit
```

## 2. Seed required secrets into Vault

Use a shell that does not write secrets to history. These commands prompt for values and then write them to KV v2. The environment variables exist only in your current shell session.

```bash
set +o history

read_secret() {
  local name="$1"
  local prompt="$2"
  read -rsp "${prompt}: " "${name}"
  printf '\n'
  export "${name}"
}
```

### Core swarm and LLM secrets

```bash
read_secret AGENTSWARM_MASTER_KEY "AgentSwarm master key"
read_secret KIMICLAW_CONSENSUS_KEY "Kimiclaw consensus key"
vault kv put secret/yieldswarm/core \
  AGENTSWARM_MASTER_KEY="${AGENTSWARM_MASTER_KEY}" \
  KIMICLAW_CONSENSUS_KEY="${KIMICLAW_CONSENSUS_KEY}"

read_secret GROK_API_KEY "Grok API key"
read_secret OPENAI_API_KEY "OpenAI API key"
read_secret GEMINI_API_KEY "Gemini API key"
read_secret ANTHROPIC_API_KEY "Anthropic API key"
vault kv put secret/yieldswarm/llm \
  GROK_API_KEY="${GROK_API_KEY}" \
  OPENAI_API_KEY="${OPENAI_API_KEY}" \
  GEMINI_API_KEY="${GEMINI_API_KEY}" \
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
```

### Azure, RunPod, Vultr, DigitalOcean, and RPC secrets

```bash
read_secret AZURE_SUBSCRIPTION_ID "Azure subscription ID"
read_secret AZURE_TENANT_ID "Azure tenant ID"
read_secret AZURE_CLIENT_ID "Azure client ID"
read_secret AZURE_CLIENT_SECRET "Azure client secret"
vault kv put secret/yieldswarm/cloud/azure \
  subscription_id="${AZURE_SUBSCRIPTION_ID}" \
  tenant_id="${AZURE_TENANT_ID}" \
  client_id="${AZURE_CLIENT_ID}" \
  client_secret="${AZURE_CLIENT_SECRET}"

read_secret RUNPOD_API_KEY "RunPod API key"
read_secret RUNPOD_ENDPOINT_ID "RunPod endpoint ID"
vault kv put secret/yieldswarm/cloud/runpod \
  api_key="${RUNPOD_API_KEY}" \
  endpoint_id="${RUNPOD_ENDPOINT_ID}"

read_secret VULTR_API_KEY "Vultr API key"
read_secret VULTR_REGION "Vultr default region"
vault kv put secret/yieldswarm/cloud/vultr \
  api_key="${VULTR_API_KEY}" \
  region="${VULTR_REGION}"

read_secret DIGITALOCEAN_TOKEN "DigitalOcean API token"
read_secret DIGITALOCEAN_REGION "DigitalOcean default region"
vault kv put secret/yieldswarm/cloud/digitalocean \
  token="${DIGITALOCEAN_TOKEN}" \
  region="${DIGITALOCEAN_REGION}"

read_secret PRIMARY_RPC_URL "Primary RPC URL"
read_secret SOLANA_RPC_URL "Solana RPC URL"
read_secret ETHEREUM_RPC_URL "Ethereum RPC URL"
read_secret POLYGON_RPC_URL "Polygon RPC URL"
read_secret HELIUS_API_KEY "Helius API key"
vault kv put secret/yieldswarm/rpc \
  primary_rpc_url="${PRIMARY_RPC_URL}" \
  solana_rpc_url="${SOLANA_RPC_URL}" \
  ethereum_rpc_url="${ETHEREUM_RPC_URL}" \
  polygon_rpc_url="${POLYGON_RPC_URL}" \
  helius_api_key="${HELIUS_API_KEY}"
```

### Akash and signing secrets

```bash
read_secret AKASH_KEY_NAME "Akash key name"
read_secret AKASH_WALLET_ADDRESS "Akash wallet address"
read_secret AKASH_MNEMONIC "Akash mnemonic"
read_secret AKASH_NET "Akash net"
read_secret AKASH_CHAIN_ID "Akash chain ID"
read_secret AKASH_NODE "Akash RPC node"
vault kv put secret/yieldswarm/depin/akash \
  key_name="${AKASH_KEY_NAME}" \
  wallet_address="${AKASH_WALLET_ADDRESS}" \
  mnemonic="${AKASH_MNEMONIC}" \
  net="${AKASH_NET}" \
  chain_id="${AKASH_CHAIN_ID}" \
  node="${AKASH_NODE}"

read_secret WALLET_ENCRYPTION_KEY "Wallet encryption key"
read_secret TEE_SIGNING_KEY "TEE signing key"
read_secret CHAINLINK_VAULT_ADDRESS "Chainlink vault address"
vault kv put secret/yieldswarm/blockchain/signing \
  wallet_encryption_key="${WALLET_ENCRYPTION_KEY}" \
  tee_signing_key="${TEE_SIGNING_KEY}" \
  chainlink_vault_address="${CHAINLINK_VAULT_ADDRESS}"
```

Clear shell variables after seeding:

```bash
unset AGENTSWARM_MASTER_KEY KIMICLAW_CONSENSUS_KEY
unset GROK_API_KEY OPENAI_API_KEY GEMINI_API_KEY ANTHROPIC_API_KEY
unset AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET
unset RUNPOD_API_KEY RUNPOD_ENDPOINT_ID VULTR_API_KEY VULTR_REGION
unset DIGITALOCEAN_TOKEN DIGITALOCEAN_REGION
unset PRIMARY_RPC_URL SOLANA_RPC_URL ETHEREUM_RPC_URL POLYGON_RPC_URL HELIUS_API_KEY
unset AKASH_KEY_NAME AKASH_WALLET_ADDRESS AKASH_MNEMONIC AKASH_NET AKASH_CHAIN_ID AKASH_NODE
unset WALLET_ENCRYPTION_KEY TEE_SIGNING_KEY CHAINLINK_VAULT_ADDRESS
set -o history
```

## 3. Make Terraform pull secrets from Vault

Use the runtime secret stack as a module or copy its `data "vault_kv_secret_v2"` pattern into your cloud stacks. Validate that Terraform can read the seeded values:

```bash
terraform -chdir=infra/terraform/runtime-secrets init
terraform -chdir=infra/terraform/runtime-secrets plan \
  -var="vault_addr=${VAULT_ADDR}" \
  -var="vault_namespace=${VAULT_NAMESPACE}"
```

Inspect the available sensitive output without printing values:

```bash
terraform -chdir=infra/terraform/runtime-secrets output secret_paths
```

Provider blocks should consume Vault-derived locals. Use `infra/terraform/runtime-secrets/providers.tf.example` as the pattern for Azure, DigitalOcean, Vultr, RunPod, and RPC-backed modules.

## 4. Build and publish the Akash agent image

Build from the repository root. Use your registry and tag:

```bash
export AKASH_AGENT_IMAGE="registry.example.com/yieldswarm/akash-agent:$(git rev-parse --short HEAD)"
docker build -f docker/Dockerfile.akash-agent -t "${AKASH_AGENT_IMAGE}" .
docker push "${AKASH_AGENT_IMAGE}"
```

The image contains the Vault CLI, Vault Agent config, entrypoint, and agent code. It does not contain any secret values.

## 5. Deploy to Akash with runtime secret injection

Read the non-secret AppRole role ID and issue a one-use wrapped SecretID:

```bash
export VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/yieldswarm-akash-runtime/role-id)"
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=10m -field=wrapping_token -f auth/approle/role/yieldswarm-akash-runtime/secret-id)"
export AKASH_KEY_NAME="$(vault kv get -field=key_name secret/yieldswarm/depin/akash)"
export AKASH_NODE="$(vault kv get -field=node secret/yieldswarm/depin/akash)"
export AKASH_CHAIN_ID="$(vault kv get -field=chain_id secret/yieldswarm/depin/akash)"
```

Render the SDL locally without committing the rendered file:

```bash
export LOG_LEVEL="INFO"
envsubst < akash/deploy.yaml > /tmp/yieldswarm-akash.yaml
```

Create the Akash deployment:

```bash
akash tx deployment create /tmp/yieldswarm-akash.yaml \
  --from "${AKASH_KEY_NAME}" \
  --node "${AKASH_NODE}" \
  --chain-id "${AKASH_CHAIN_ID}" \
  --fees 5000uakt \
  -y
```

After the deployment is accepted, remove the rendered SDL and wrapped token from your shell:

```bash
rm -f /tmp/yieldswarm-akash.yaml
unset VAULT_WRAPPED_SECRET_ID VAULT_ROLE_ID AKASH_KEY_NAME AKASH_NODE AKASH_CHAIN_ID
```

The container startup sequence is:

1. `docker/vault-entrypoint.sh` writes the non-secret role ID to `/vault/auth/role_id`.
2. The entrypoint unwraps `VAULT_WRAPPED_SECRET_ID` into a one-use SecretID and writes it to `/vault/auth/secret_id`.
3. Vault Agent authenticates with AppRole, renders `/vault/secrets/yieldswarm.json`, and renews its token.
4. The entrypoint loads the JSON into the process environment and `exec`s the workload.

## 6. Rotation and incident response

Rotate any secret that was previously stored outside Vault or exposed in repository history:

```bash
vault kv put secret/yieldswarm/cloud/runpod api_key="NEW_VALUE" endpoint_id="CURRENT_ENDPOINT"
```

For AppRole rotation, issue a fresh wrapped SecretID per deployment:

```bash
export VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=10m -field=wrapping_token -f auth/approle/role/yieldswarm-akash-runtime/secret-id)"
```

Do not reuse wrapped tokens. Do not store wrapped tokens in GitHub Actions logs, Akash SDL files, chat systems, tickets, or password managers after deployment.
