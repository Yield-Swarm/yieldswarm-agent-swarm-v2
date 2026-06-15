# Secrets Management — HashiCorp Vault Integration

This guide walks the AgentSwarm OS platform from a clean slate to a fully
production-grade HashiCorp Vault setup that is the single source of truth for
every credential used by Terraform, Akash workloads, and CI.

**Hard rules enforced by this integration:**

1. **No secret is ever committed to git.** `.env.example` is a *template only*
   and contains zero real values.
2. **No secret is ever baked into a container image.** Akash workloads receive
   their secrets at runtime via Vault Agent, which renders an env-file the
   workload then sources.
3. **No secret is ever passed to Terraform via a file on disk.** Provider
   credentials are fetched via `vault_kv_secret_v2` data sources using a
   short-lived AppRole token.
4. **Every non-human principal authenticates with AppRole.** Tokens have
   bounded TTLs (1 h for CI, 15 m for the rotator, 24 h for long-lived
   workloads with auto-renewal).
5. **Secret IDs are response-wrapped** when delivered to a target host. The
   wrapping token has a 5-minute TTL and is single-use.

---

## 0. Prerequisites

| Tool          | Minimum version | Purpose                                |
| ------------- | --------------- | -------------------------------------- |
| `vault`       | 1.15+           | CLI + agent binary                     |
| `terraform`   | 1.7+            | Infra-as-code runner                   |
| `jq`          | 1.6+            | Bootstrap scripts + entrypoint         |
| `yq`          | 4.x             | Akash SDL templating in `deploy.sh`    |
| `akash`       | 0.34+           | Akash Network CLI                      |
| `docker` (or `buildx`) | 24+    | Image build (no secrets in image)      |

---

## 1. Bring up the Vault cluster

You need a 3-node Raft Vault cluster reachable at
`https://vault.yieldswarm.internal:8200`. The canonical server config lives at
[`infra/vault/config/vault.hcl`](infra/vault/config/vault.hcl) and includes:

* Raft integrated storage (no Consul dependency).
* TLS-only listener with TLS 1.3 minimum.
* **Auto-unseal via Azure Key Vault** by default. Swap the `seal` stanza for
  `awskms` / `gcpckms` / `transit` for other clouds.
* JSON structured logs + Prometheus telemetry.

The recommended bring-up is:

```bash
# On EACH of the three Vault nodes (vault-0 / vault-1 / vault-2):
sudo install -d -o vault -g vault -m 0750 /vault/{config,data,logs,tls,plugins}
sudo cp infra/vault/config/vault.hcl /vault/config/vault.hcl
# Replace the per-node placeholders in vault.hcl:
sudo sed -i \
  -e "s/VAULT_NODE_ID/$(hostname -s)/" \
  -e "s/VAULT_NODE_FQDN/$(hostname -f)/" \
  /vault/config/vault.hcl
# TLS bundle (cert / key / ca) goes into /vault/tls/. Generate via your PKI.
sudo systemctl enable --now vault
```

On vault-0 only:

```bash
export VAULT_ADDR=https://vault-0.vault.internal:8200
vault operator init -recovery-shares=5 -recovery-threshold=3
# Capture root token + recovery keys to your offline HSM.
```

The other two nodes will join automatically via the `retry_join` blocks.

---

## 2. Bootstrap engines, policies, AppRoles, and seed paths

All bootstrap logic is idempotent. Run from any host that has the `vault` CLI
and network access to the cluster.

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<root token from step 1>

cd infra/vault/bootstrap
./bootstrap.sh
```

Under the hood `bootstrap.sh` calls:

| Step                          | Script                  | Effect                                                                                  |
| ----------------------------- | ----------------------- | --------------------------------------------------------------------------------------- |
| Enable engines + audit + keys | `00-enable-engines.sh`  | KV-v2 at `yieldswarm/`, `transit/`, `pki_int/`, AppRole + OIDC auth, file audit device. |
| Install policies              | `10-policies.sh`        | Uploads every `infra/vault/policies/*.hcl` file as a Vault policy.                      |
| Provision AppRoles            | `20-approles.sh`        | Creates `terraform-deploy`, `akash-runtime`, `ci-pipeline`, `secrets-rotator`.          |
| Seed placeholder KV paths     | `30-seed-secrets.sh`    | Writes `REPLACE_ME` placeholders so every Terraform data source resolves.               |

The final output is a table of `role_id` + **response-wrapped** `secret_id`
tokens. Each wrapping token has a 5-minute TTL and is single-use. Deliver them
to the target hosts via your secure channel of choice (Bitwarden Send, 1Password
Travel Mode, Vault Cubbyhole, etc.), then unwrap on the target:

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
SECRET_ID=$(VAULT_TOKEN=$WRAP_TOKEN vault unwrap -field=secret_id -)
```

---

## 3. Replace placeholder secrets with real values

Placeholders are stamped with the literal string `REPLACE_ME`. The Terraform
root module includes a precondition that fails the plan if any placeholder is
left in place.

Set real values one path at a time:

```bash
# --- Azure ---
vault kv patch yieldswarm/infra/azure \
  subscription_id="00000000-0000-0000-0000-000000000000" \
  tenant_id="$AZ_TENANT" \
  client_id="$AZ_CLIENT_ID" \
  client_secret="$AZ_CLIENT_SECRET" \
  resource_group="yieldswarm-prod" \
  location="eastus2"

# --- RunPod ---
vault kv patch yieldswarm/infra/runpod \
  api_key="$RUNPOD_KEY" \
  org_id="$RUNPOD_ORG"

# --- Vultr ---
vault kv patch yieldswarm/infra/vultr api_key="$VULTR_KEY"

# --- DigitalOcean ---
vault kv patch yieldswarm/infra/digitalocean \
  api_token="$DO_TOKEN" \
  spaces_access_key="$DO_SPACES_KEY" \
  spaces_secret_key="$DO_SPACES_SECRET"

# --- RPCs (one per chain) ---
vault kv patch yieldswarm/rpc/solana \
  primary="$SOLANA_RPC" helius="$HELIUS_RPC" api_key="$HELIUS_KEY"

vault kv patch yieldswarm/rpc/ton    primary="$TON_RPC"    api_key="$TON_KEY"
vault kv patch yieldswarm/rpc/tao    primary="$TAO_WS"     subnet_key="$TAO_KEY"
vault kv patch yieldswarm/rpc/helix  primary="$HELIX_RPC"  bridge_key="$HELIX_KEY"
vault kv patch yieldswarm/rpc/zec    primary="$ZEC_RPC"    shielded_key="$ZEC_KEY"
vault kv patch yieldswarm/rpc/erc4337 primary="$ERC4337_RPC" bundler_key="$ERC4337_KEY"

# --- Runtime app, wallet, depin, social secrets ---
vault kv patch yieldswarm/runtime/app \
  AGENTSWARM_MASTER_KEY="$(openssl rand -hex 32)" \
  KIMICLAW_CONSENSUS_KEY="$(openssl rand -hex 32)" \
  GROK_API_KEY="$GROK" \
  OPENAI_API_KEY="$OPENAI" \
  GEMINI_API_KEY="$GEMINI" \
  ANTHROPIC_API_KEY="$ANTHROPIC" \
  TEE_SIGNING_KEY="$(openssl rand -hex 32)" \
  DATABASE_ENCRYPTION_KEY="$(openssl rand -hex 32)"

vault kv patch yieldswarm/runtime/wallet \
  WALLET_ENCRYPTION_KEY="$(openssl rand -hex 32)" \
  PUMP_FUN_DEPLOY_KEY="$PUMP_KEY"

vault kv patch yieldswarm/runtime/depin \
  DEPIN_HELIUM_HOTSPOT_KEYS="$HELIUM_JSON" \
  GPU_CLUSTER_KEYS="$GPU_JSON" \
  GRASS_NODE_KEYS="$GRASS_JSON" \
  SMARTTHINGS_BRIDGE_TOKEN="$ST_TOKEN" \
  UTILITY_API_KEY="$UTIL_KEY"

vault kv patch yieldswarm/runtime/social \
  TELEGRAM_BOT_TOKEN="$TG_TOKEN" \
  X_API_KEYS="$X_JSON" \
  META_ADS_TOKEN="$META_TOKEN" \
  NOTION_API_KEY="$NOTION" \
  LINEAR_API_KEY="$LINEAR" \
  VERCEL_API_TOKEN="$VERCEL_TOKEN" \
  GITHUB_TOKEN="$GH_TOKEN" \
  UD_API_KEY="$UD_KEY"
```

Verify nothing is left as `REPLACE_ME`:

```bash
for p in infra/azure infra/runpod infra/vultr infra/digitalocean \
         rpc/solana rpc/ton rpc/tao rpc/helix rpc/zec rpc/erc4337 \
         runtime/app runtime/wallet runtime/depin runtime/social; do
  if vault kv get -format=json "yieldswarm/$p" \
     | jq -e '.data.data | to_entries | map(select(.value == "REPLACE_ME")) | length == 0' \
     > /dev/null; then
    echo "OK   $p"
  else
    echo "FAIL $p"
  fi
done
```

---

## 4. Run Terraform against Vault

Terraform fetches every provider credential from Vault. Only the Vault
connection info is supplied via tfvars / env vars.

```bash
cd infra/terraform

# 4a. Wrap a fresh secret_id for the terraform-deploy AppRole:
ROLE_ID=$(vault read -field=role_id auth/approle/role/terraform-deploy/role-id)
WRAP=$(VAULT_WRAP_TTL=300s vault write -f -field=wrapping_token \
        auth/approle/role/terraform-deploy/secret-id)

# 4b. On the CI runner (or your laptop), unwrap and export:
export TF_VAR_vault_address="https://vault.yieldswarm.internal:8200"
export TF_VAR_vault_approle_role_id="$ROLE_ID"
export TF_VAR_vault_approle_secret_id=$(VAULT_TOKEN="$WRAP" vault unwrap -field=secret_id -)

# 4c. Standard Terraform flow:
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

What this gets you:

* **No provider credential ever exists on disk** outside Vault.
* The CI runner only ever sees the `role_id` (low-sensitivity) and a
  one-shot wrapping token (5-minute TTL).
* The fail-fast `null_resource.fail_on_placeholders` block (in
  `infra/terraform/vault.tf`) refuses to plan if any provider credential in
  Vault is still set to `REPLACE_ME`.

---

## 5. Build and publish the Akash image

The Dockerfile lives at [`infra/akash/Dockerfile`](infra/akash/Dockerfile). It
**never** copies `.env*`, never has `ARG SECRET=...`, and runs as uid 10001.

```bash
cd infra/akash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/yield-swarm/agentswarm-os:0.1.0 \
  --push .
```

The image contains:

* `vault` binary (used as `vault agent`).
* `supervisord` running as the unprivileged user.
* `docker-entrypoint.sh` which:
  1. Validates `VAULT_ADDR`, `VAULT_ROLE_ID` are set.
  2. Materialises the AppRole secret_id from one of
     `VAULT_SECRET_ID_FILE`, `VAULT_SECRET_ID_WRAP_TOKEN`, or `VAULT_SECRET_ID`
     (in that order of preference).
  3. Hands off to supervisord, which launches Vault Agent and then the app.
* Vault Agent renders `/etc/agentswarm/secrets/runtime.env` and
  `/etc/agentswarm/secrets/rpc.json` from KV-v2.
* `wait-for-secrets.sh` blocks the app process until the env file exists AND
  contains a non-placeholder `AGENTSWARM_MASTER_KEY`.

---

## 6. Deploy to Akash with runtime-injected secrets

`infra/akash/scripts/deploy.sh` mints a fresh wrapping token, renders the SDL
**in memory**, and pipes it straight to the Akash CLI.

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=<token with permission to mint akash-runtime secret-ids>
export AKASH_KEY_NAME=mainnet
export AKASH_NODE=https://rpc.akashnet.net:443
export AKASH_CHAIN_ID=akashnet-2
export AGENT_SHARD_ID=0

bash infra/akash/scripts/deploy.sh
```

The rendered manifest contains:

* `VAULT_ADDR` (non-sensitive).
* `VAULT_ROLE_ID` (low-sensitivity).
* `VAULT_SECRET_ID_WRAP_TOKEN` (single-use, 5-minute TTL).
* `AGENT_SHARD_ID` (0..119).

It does **NOT** contain any API keys, wallet seeds, or RPC tokens. Those are
fetched by Vault Agent inside the container at startup.

Once the lease is bid on and accepted, you can confirm the bind worked:

```bash
akash provider lease-status \
  --dseq $DSEQ --provider $PROVIDER \
  --from $AKASH_KEY_NAME --keyring-backend os
```

Watch the container logs for a JSON line like:

```json
{"ts":"...","level":"INFO","msg":"Secrets rendered. Releasing app start.","component":"wait-for-secrets"}
```

---

## 7. Secret rotation

The `secrets-rotator` AppRole is consumed by one of the 120 cron jobs. The
flow is:

1. Cron acquires a 15-minute token via AppRole.
2. Mints a new credential at the provider (`az ad sp credential reset`,
   RunPod API key endpoint, Vultr API, DO PAT API).
3. `vault kv patch yieldswarm/infra/<provider> <new_keys>`.
4. Waits N minutes (long enough for Vault Agent template TTLs to roll over),
   then revokes the previous credential at the provider.

KV-v2 versioning means the previous version remains retrievable for
investigation; pin retention via:

```bash
vault kv metadata put -max-versions=10 -delete-version-after=720h \
  yieldswarm/infra/azure
```

---

## 8. Break-glass procedure

If Vault is unreachable AND you need to apply infra in a hurry:

1. Authenticate to Vault via OIDC and pull the relevant infra secret to a
   throwaway file:

   ```bash
   vault login -method=oidc role=admin
   vault kv get -format=json yieldswarm/infra/azure \
     | jq '.data.data' > /dev/shm/azure.json
   ```

2. Hand-edit `infra/terraform/providers.tf` to read from that file. This is a
   **manual** procedure — there is no built-in escape hatch by design.
3. After recovery, **rotate** every credential that touched the disk via the
   normal rotation flow (step 7) and shred `/dev/shm/azure.json`.

---

## 9. Audit + observability

* `audit.log` is JSON, mounted at `/vault/logs/audit.log`. Ship it to Loki /
  Azure Log Analytics / Datadog with a redaction filter for `response.data.*`.
* `/v1/sys/metrics?format=prometheus` is scraped from each Vault node.
* Every AppRole token has `display_name` set so `auth/token/lookup` reveals
  which workload created it.

---

## 10. File map

```
infra/
├── akash/
│   ├── Dockerfile                # Runtime image (no secrets baked in)
│   ├── deploy.yaml               # Akash SDL manifest (no secrets)
│   ├── scripts/
│   │   ├── deploy.sh             # Mint + wrap + render + akash tx deploy
│   │   ├── docker-entrypoint.sh  # Materialise secret_id, exec supervisord
│   │   └── wait-for-secrets.sh   # Block app start until env is rendered
│   ├── templates/
│   │   ├── rpc.json.ctmpl        # Vault Agent template for RPC endpoints
│   │   └── runtime.env.ctmpl     # Vault Agent template for runtime env
│   └── vault-agent/
│       ├── agent.hcl             # Vault Agent config (AppRole auto-auth)
│       └── supervisord.conf      # vault-agent + app process supervisor
├── terraform/
│   ├── backend.tf                # Remote state (Azure Blob by default)
│   ├── main.tf                   # Root composition
│   ├── modules/
│   │   ├── azure-core/
│   │   ├── digitalocean-droplets/
│   │   ├── rpc-endpoints/
│   │   ├── runpod-gpu/
│   │   └── vultr-edge/
│   ├── outputs.tf
│   ├── providers.tf              # Vault AppRole login + providers
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   ├── vault.tf                  # Every credential pulled from Vault
│   └── versions.tf
└── vault/
    ├── bootstrap/                # Idempotent bootstrap scripts
    │   ├── 00-enable-engines.sh
    │   ├── 10-policies.sh
    │   ├── 20-approles.sh
    │   ├── 30-seed-secrets.sh
    │   └── bootstrap.sh
    ├── config/
    │   └── vault.hcl             # Production Vault server config
    └── policies/
        ├── admin.hcl             # Break-glass humans only
        ├── akash-runtime.hcl     # Workload read-only on runtime secrets
        ├── ci-pipeline.hcl       # GitHub Actions / Vercel hooks
        ├── secrets-rotator.hcl   # Cron-driven credential rotation
        └── terraform-deploy.hcl  # CI runner: read infra, no writes
```
