# Production Vault Setup Guide

This repository is now Vault-first:

- Vault manages cloud, RPC, and runtime application secrets.
- Terraform bootstraps Vault mounts, policies, and AppRoles.
- Akash never receives static API keys in the SDL or the image.
- The Akash container fetches runtime secrets from Vault after the lease starts.

## 0. Prerequisites

Use Vault 1.19+ and Terraform 1.8+.

```bash
mkdir -p .secrets
chmod 700 .secrets

export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="<bootstrap-or-platform-admin-token>"
export TF_IN_AUTOMATION=1
```

If you use Vault Enterprise namespaces or a private CA bundle:

```bash
export VAULT_NAMESPACE="<namespace>"
export VAULT_CACERT="$PWD/.secrets/vault-ca.pem"
```

> Production note: store Terraform state in an encrypted remote backend before using this outside a single operator workstation.

## 1. Bootstrap Vault mounts, policies, and AppRoles

Create a local tfvars file from the example and edit only the non-secret connection settings:

```bash
cp infra/vault/terraform.tfvars.example infra/vault/terraform.tfvars
```

Initialize and apply the Vault bootstrap:

```bash
terraform -chdir=infra/vault init
terraform -chdir=infra/vault plan -out "$PWD/.secrets/vault-bootstrap.tfplan"
terraform -chdir=infra/vault apply "$PWD/.secrets/vault-bootstrap.tfplan"
```

This creates:

- `cloud/` KV v2 mount
- `rpc/` KV v2 mount
- `apps/` KV v2 mount
- `transit/` mount
- `yieldswarm-terraform-readonly` policy
- `yieldswarm-akash-runtime` policy
- `yieldswarm-terraform` AppRole
- `yieldswarm-akash` AppRole

## 2. Write cloud provider and RPC secrets into Vault

### Azure

```bash
vault kv put cloud/azure \
  subscription_id="<azure-subscription-id>" \
  tenant_id="<azure-tenant-id>" \
  client_id="<azure-client-id>" \
  client_secret="<azure-client-secret>"
```

### RunPod

```bash
vault kv put cloud/runpod \
  api_key="<runpod-api-key>"
```

### Vultr

```bash
vault kv put cloud/vultr \
  api_key="<vultr-api-key>"
```

### DigitalOcean

```bash
vault kv put cloud/digitalocean \
  token="<digitalocean-token>"
```

### RPC / chain access

```bash
vault kv put rpc/mainnet \
  SOLANA_RPC_URL="https://rpc.example.com" \
  HELIUS_API_KEY="<helius-api-key>" \
  BIRDEYE_API_KEY="<birdeye-api-key>" \
  JUPITER_API_KEY="<jupiter-api-key>" \
  RAYDIUM_API_KEY="<raydium-api-key>" \
  TON_API_KEY="<ton-api-key>" \
  TAO_SUBNET_KEY="<tao-subnet-key>" \
  HELIX_CHAIN_BRIDGE_KEY="<helix-bridge-key>" \
  ZEC_SHIELDED_KEY="<zec-shielded-key>" \
  ERC4337_BUNDLER_KEY="<erc4337-bundler-key>" \
  FAILOVER_RPC_LIST='["https://rpc-1.example.com","https://rpc-2.example.com"]'
```

## 3. Write runtime application secrets into Vault

Shared runtime secrets:

```bash
vault kv put apps/yieldswarm/base \
  AGENTSWARM_MASTER_KEY="<agentswarm-master-key>" \
  KIMICLAW_CONSENSUS_KEY="<kimiclaw-consensus-key>" \
  OPENAI_API_KEY="<openai-api-key>" \
  ANTHROPIC_API_KEY="<anthropic-api-key>" \
  GEMINI_API_KEY="<gemini-api-key>" \
  GROK_API_KEY="<grok-api-key>" \
  WALLET_ENCRYPTION_KEY="<wallet-encryption-key>" \
  TEE_SIGNING_KEY="<tee-signing-key>" \
  DATABASE_ENCRYPTION_KEY="<database-encryption-key>"
```

Akash runtime secrets:

```bash
vault kv put apps/yieldswarm/akash \
  AKASH_API_KEY="<akash-console-api-key>" \
  DEPIN_HELIUM_HOTSPOT_KEYS='["hotspot-1","hotspot-2"]' \
  GPU_CLUSTER_KEYS='["runpod-cluster-a","rtx4090-cluster-b"]' \
  GRASS_NODE_KEYS='["grass-node-1"]' \
  SMARTTHINGS_BRIDGE_TOKEN="<smartthings-token>" \
  COLORADO_POWER_PERMIT_ID="<permit-id>" \
  UTILITY_API_KEY="<utility-api-key>" \
  NOTION_API_KEY="<notion-api-key>" \
  LINEAR_API_KEY="<linear-api-key>" \
  VERCEL_API_TOKEN="<vercel-api-token>" \
  GITHUB_TOKEN="<github-token>" \
  S_AND_P_API_KEY="<s-and-p-api-key>" \
  FSD_DATA_FEED_KEY="<fsd-data-feed-key>" \
  TESLA_INTEGRATION_TOKEN="<tesla-token>" \
  TELEGRAM_BOT_TOKEN="<telegram-bot-token>" \
  X_API_KEYS='["x-key-1","x-key-2"]' \
  META_ADS_TOKEN="<meta-ads-token>" \
  FILECOIN_STORAGE_KEY="<filecoin-storage-key>" \
  MONITORING_PROMETHEUS_URL="https://prometheus.example.com" \
  ERROR_WEBHOOK="https://hooks.example.com/ops" \
  ADMIN_ACCOUNT_SEGMENT="<admin-account-segment>" \
  QUARANTINED_LLM_ARENA_KEY="<arena-key>" \
  ZKML_VERIFIER_KEY="<zkml-verifier-key>" \
  DEXSCREENER_API="<dexscreener-api-key>" \
  SOLSCAN_API_KEY="<solscan-api-key>" \
  EMAIL_SMTP_CONFIG='{"host":"smtp.gmail.com","port":587}' \
  NG64_BITTENSOR_NODE_STAKING_KEY="<ng64-staking-key>" \
  BITTENSOR_TRAINING_CONFIG='{"model":"your-model","epochs":10}' \
  UD_API_KEY="<unstoppable-domains-api-key>" \
  WISE_BUSINESS_EMAIL="<wise-business-email>"
```

## 4. Make Terraform verify that Vault contains the required secret contract

Enable the validation flag only after the secrets above exist:

```bash
terraform -chdir=infra/vault plan \
  -var="enable_secret_contract_validation=true"
```

If you want the flag to stay enabled in your local tfvars file:

```bash
python - <<'PY'
from pathlib import Path

path = Path("infra/vault/terraform.tfvars")
text = path.read_text(encoding="utf-8")
text = text.replace("enable_secret_contract_validation = false", "enable_secret_contract_validation = true")
path.write_text(text, encoding="utf-8")
PY
```

## 5. Build and publish the Akash image

Set your target registry and build the image:

```bash
export IMAGE_TAG="$(git rev-parse --short HEAD)"
export AKASH_IMAGE="ghcr.io/<org>/yieldswarm-agent-swarm-v2:${IMAGE_TAG}"

docker build -f docker/Dockerfile.akash -t "${AKASH_IMAGE}" .
docker push "${AKASH_IMAGE}"
```

## 6. Render and validate the Akash SDL

Set the non-secret deployment inputs:

```bash
export APP_ENV="production"
export LOG_LEVEL="INFO"
export NETWORK_LOCKDOWN_MODE="true"
export VAULT_KV_MOUNT="apps"
export VAULT_SECRET_PATHS="yieldswarm/base,yieldswarm/akash"
export VAULT_SECRET_WAIT_SECONDS="300"
export VAULT_SECRET_WAIT_INTERVAL="5"
export AKASH_CPU_UNITS="1.0"
export AKASH_MEMORY_SIZE="2Gi"
export AKASH_SECRET_STORAGE_SIZE="1Gi"
export AKASH_PRICE_AMOUNT="10000"
```

Render the SDL into the ignored `.secrets/` directory:

```bash
envsubst < deploy/akash/deployment.sdl.tpl.yml > .secrets/deployment.sdl.yml
provider-services deployment validate .secrets/deployment.sdl.yml
```

## 7. Create the Akash deployment

Configure the Akash CLI:

```bash
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_CHAIN_ID="akashnet-2"
export AKASH_GAS="auto"
export AKASH_GAS_PRICES="0.025uakt"
export AKASH_GAS_ADJUSTMENT="1.5"
export AKASH_KEY_NAME="<akash-wallet-key-name>"
export AKASH_KEYRING_BACKEND="os"
```

Create the deployment:

```bash
provider-services tx deployment create .secrets/deployment.sdl.yml \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  -y \
  --output json | tee .secrets/deployment-create.json
```

Extract the deployment owner and DSEQ:

```bash
export AKASH_OWNER="$(provider-services keys show "$AKASH_KEY_NAME" -a)"

export AKASH_DSEQ="$(
  python -c 'import json,sys; payload=json.load(open(sys.argv[1], encoding="utf-8")); \
events=payload["logs"][0]["events"]; \
print(next(attribute["value"] for event in events if event["type"] == "akash.v1.EventDeploymentCreated" for attribute in event["attributes"] if attribute["key"] == "dseq"))' \
  .secrets/deployment-create.json
)"
```

Wait for bids and choose a provider:

```bash
sleep 20

provider-services query market bid list \
  --owner "$AKASH_OWNER" \
  --dseq "$AKASH_DSEQ" \
  --node "$AKASH_NODE" \
  --output json | tee .secrets/bids.json

export AKASH_PROVIDER="$(
  python -c 'import json,sys; payload=json.load(open(sys.argv[1], encoding="utf-8")); bids=payload.get("bids", []); \
print(bids[0]["bid"]["provider"] if bids else (_ for _ in ()).throw(SystemExit("no bids returned for deployment")))' \
  .secrets/bids.json
)"
```

Create the lease and send the manifest:

```bash
provider-services tx market lease create \
  --dseq "$AKASH_DSEQ" \
  --provider "$AKASH_PROVIDER" \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  -y

provider-services send-manifest .secrets/deployment.sdl.yml \
  --dseq "$AKASH_DSEQ" \
  --provider "$AKASH_PROVIDER" \
  --from "$AKASH_KEY_NAME" \
  --node "$AKASH_NODE"
```

## 8. Inject the Vault bootstrap file after the lease starts

Read the AppRole identifiers without putting them in Terraform state:

```bash
export AKASH_VAULT_ROLE_ID="$(
  vault read -field=role_id auth/approle/role/yieldswarm-akash/role-id
)"

export AKASH_VAULT_SECRET_ID="$(
  vault write -f -field=secret_id auth/approle/role/yieldswarm-akash/secret-id
)"
```

Create the bootstrap env file locally:

```bash
cat > .secrets/akash-bootstrap.env <<EOF
VAULT_ADDR=${VAULT_ADDR}
VAULT_NAMESPACE=${VAULT_NAMESPACE:-}
VAULT_ROLE_ID=${AKASH_VAULT_ROLE_ID}
VAULT_SECRET_ID=${AKASH_VAULT_SECRET_ID}
VAULT_KV_MOUNT=apps
VAULT_SECRET_PATHS=yieldswarm/base,yieldswarm/akash
VAULT_SECRET_WAIT_SECONDS=300
VAULT_SECRET_WAIT_INTERVAL=5
EOF

chmod 600 .secrets/akash-bootstrap.env
```

Preferred injection method (`just-akash` writes the file to `/run/secrets/.env` without putting it in the SDL):

```bash
just inject "$AKASH_DSEQ" .secrets/akash-bootstrap.env
```

If you use the Python CLI wrapper instead:

```bash
uv run just-akash inject --dseq "$AKASH_DSEQ" --env-file .secrets/akash-bootstrap.env
```

## 9. Rotation commands

Rotate the Akash AppRole secret ID before every redeploy or operator handoff:

```bash
export AKASH_VAULT_SECRET_ID="$(
  vault write -f -field=secret_id auth/approle/role/yieldswarm-akash/secret-id
)"

cat > .secrets/akash-bootstrap.env <<EOF
VAULT_ADDR=${VAULT_ADDR}
VAULT_NAMESPACE=${VAULT_NAMESPACE:-}
VAULT_ROLE_ID=${AKASH_VAULT_ROLE_ID}
VAULT_SECRET_ID=${AKASH_VAULT_SECRET_ID}
VAULT_KV_MOUNT=apps
VAULT_SECRET_PATHS=yieldswarm/base,yieldswarm/akash
VAULT_SECRET_WAIT_SECONDS=300
VAULT_SECRET_WAIT_INTERVAL=5
EOF

chmod 600 .secrets/akash-bootstrap.env
just inject "$AKASH_DSEQ" .secrets/akash-bootstrap.env
```

Rotate any Vault secret in place by writing a new version:

```bash
vault kv put cloud/runpod api_key="<new-runpod-api-key>"
vault kv put apps/yieldswarm/akash AKASH_API_KEY="<new-akash-console-api-key>"
```

Verify the contract again after rotation:

```bash
terraform -chdir=infra/vault plan \
  -var="enable_secret_contract_validation=true"
```
