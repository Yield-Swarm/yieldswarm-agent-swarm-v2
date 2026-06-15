# Secrets Management — APN / YieldSwarm

HashiCorp Vault is the single source of truth for every secret the
platform uses. This guide walks an operator from a freshly initialised
Vault cluster all the way to a running Akash deployment whose container
fetches credentials at startup. **No secret value is ever stored in
git, in a Terraform variable file, or in an image layer.**

```
                 +-----------------------------+
   operator -->  |  HashiCorp Vault (Raft)     |
                 |  kv/apn/*    transit/apn-*  |
                 +--------------+--------------+
                                |
            +-------------------+--------------------+
            |                                        |
            v                                        v
   AppRole: apn-terraform                AppRole: apn-akash-runtime
   policy:  apn-terraform-read           policy:  apn-akash-runtime
            |                                        |
            v                                        v
   Terraform (Azure / RunPod /            Akash deployment:
   Vultr / DigitalOcean / RPC)            Vault Agent --> dotenv
                                          --> swarm process
```

Layout on disk:

```
infra/
  vault/
    config/vault.hcl
    policies/{apn-admin,apn-terraform-read,apn-akash-runtime}.hcl
    bootstrap/{00-enable-engines,10-write-policies,
               20-create-approles,30-seed-secrets}.sh
  terraform/
    versions.tf providers.tf main.tf variables.tf outputs.tf
    modules/{azure,runpod,vultr,digitalocean,rpc}/
  akash/
    deploy.yaml Dockerfile entrypoint.sh vault-agent.hcl
    templates/apn.env.tmpl
```

---

## 0. Prerequisites

| Tool                | Version |
|---------------------|---------|
| `vault` CLI         | 1.17+   |
| `terraform`         | 1.6+    |
| `jq`                | 1.6+    |
| `docker` / `buildx` | 24+     |
| `provider-services` | latest  |

Export the cluster endpoint once:

```bash
export VAULT_ADDR=https://vault.apn.internal:8200
```

---

## 1. Bring up the Vault cluster

Render `infra/vault/config/vault.hcl` for each node (set `node_id` and
the auto-unseal block for your cloud), then start the service:

```bash
sudo install -d -m 0750 -o vault -g vault /var/lib/vault/raft /var/log/vault
sudo install -m 0640 -o vault -g vault \
  infra/vault/config/vault.hcl /etc/vault.d/vault.hcl
sudo systemctl enable --now vault
```

Initialise the cluster (only on the first node):

```bash
vault operator init -recovery-shares=5 -recovery-threshold=3 -format=json \
  > vault-init.json
chmod 600 vault-init.json
```

Store `vault-init.json` in your offline break-glass safe; the recovery
keys are never needed during normal operation (KMS auto-unseals).

Log in with the initial root token:

```bash
export VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)
vault status
```

---

## 2. Run the bootstrap scripts

The scripts are idempotent and read-only against any path that is not
prefixed `apn-` or `kv/apn/`.

```bash
# (1) Enable kv v2, transit, AppRole, and the file audit device.
infra/vault/bootstrap/00-enable-engines.sh

# (2) Upload the three apn-* policies from infra/vault/policies/.
infra/vault/bootstrap/10-write-policies.sh

# (3) Create the apn-terraform and apn-akash-runtime AppRoles +
#     the apn-wallet-encryption / apn-db-encryption / apn-tee-signing
#     transit keys. CIDR-bind the AppRoles to your CI / Akash egress
#     ranges:
APN_TERRAFORM_CIDRS="10.10.0.0/24" \
APN_AKASH_CIDRS="0.0.0.0/0" \
  infra/vault/bootstrap/20-create-approles.sh
```

Revoke the root token as soon as a human-rotatable admin token exists:

```bash
vault token create -policy=apn-admin -ttl=1h -format=json \
  | jq -r '.auth.client_token' > /tmp/apn-admin.token
export VAULT_TOKEN=$(cat /tmp/apn-admin.token)
vault token revoke "$(jq -r '.root_token' vault-init.json)"
shred -u /tmp/apn-admin.token
```

---

## 3. Seed Vault with the real secret values

Load the plaintext values into the operator's shell from an air-gapped
source (TEE, encrypted USB, secret-distribution tool). The script reads
each value from the matching environment variable name in `.env.example`
and never logs the value.

```bash
# Example: pull from an age-encrypted file stored on a yubikey.
age -d -i /run/yubikey/apn.age secrets/apn.env.age > /run/apn.env
set -a; . /run/apn.env; set +a
shred -u /run/apn.env

infra/vault/bootstrap/30-seed-secrets.sh
```

Verify a subset (do **not** print full values into shared terminals):

```bash
vault kv get -field=api_key kv/apn/llm/openai | head -c 6 ; echo '…'
vault kv list kv/apn
vault kv list kv/apn/rpc
```

---

## 4. Issue AppRole credentials

### 4a. Terraform (CI)

```bash
TF_ROLE_ID=$(vault read -format=json auth/approle/role/apn-terraform/role-id \
              | jq -r .data.role_id)
TF_SECRET_ID=$(vault write -f -format=json \
              auth/approle/role/apn-terraform/secret-id \
              | jq -r .data.secret_id)

# Inject into the CI runner as files (preferred) or env vars.
printf '%s' "$TF_ROLE_ID"   | gh secret set APN_TF_VAULT_ROLE_ID
printf '%s' "$TF_SECRET_ID" | gh secret set APN_TF_VAULT_SECRET_ID
```

In CI, before `terraform init`:

```bash
install -d -m 0700 /run/apn
printf '%s' "$APN_TF_VAULT_ROLE_ID"   > /run/apn/terraform.role-id
printf '%s' "$APN_TF_VAULT_SECRET_ID" > /run/apn/terraform.secret-id
chmod 0400 /run/apn/terraform.*
export TF_VAR_vault_address="$VAULT_ADDR"
```

### 4b. Akash runtime

Always wrap the secret-id so only the operator who configures the
deployment ever sees the raw value:

```bash
AK_ROLE_ID=$(vault read -format=json auth/approle/role/apn-akash-runtime/role-id \
             | jq -r .data.role_id)
WRAPPED=$(vault write -f -wrap-ttl=5m -format=json \
          auth/approle/role/apn-akash-runtime/secret-id \
          | jq -r .wrap_info.token)
echo "Hand the wrapping token to the operator (single use, expires 5m):"
echo "$WRAPPED"

# Operator side:
AK_SECRET_ID=$(VAULT_TOKEN=$WRAPPED vault unwrap -format=json \
              | jq -r .data.secret_id)
```

---

## 5. Run Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # contains no secrets
terraform init \
  -backend-config="resource_group_name=apn-tfstate" \
  -backend-config="storage_account_name=apntfstate" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=apn/prod.tfstate"
terraform plan  -out tfplan
terraform apply tfplan
```

Terraform exchanges the AppRole pair for a 20-minute token, pulls every
provider credential from `kv/apn/{azure,runpod,vultr,digitalocean,rpc/*}`,
applies the change, and self-revokes the token at exit. No `*.tfvars`
file ever contains a secret.

---

## 6. Build & publish the Akash image

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/yieldswarm/apn-agentswarm:1.0.0 \
  -f infra/akash/Dockerfile \
  --push .
```

The image contains:

* Vault Agent (pulled from the official HashiCorp image)
* The APN agents package
* `apn-entrypoint` that starts Vault Agent first, blocks until the
  KV templates render, sources the resulting dotenv, drops to the
  unprivileged `apn` user, and execs the swarm process.

Nothing in the image embeds an API key. Scanning with `trivy image
ghcr.io/yieldswarm/apn-agentswarm:1.0.0 --scanners secret` should
report zero findings.

---

## 7. Deploy on Akash

Create a per-deployment env file (kept off the image and out of git):

```bash
cat > /run/apn/akash.env <<EOF
VAULT_ADDR=$VAULT_ADDR
VAULT_KV_MOUNT=kv
VAULT_SECRET_PREFIX=apn
VAULT_ROLE_ID=$AK_ROLE_ID
VAULT_SECRET_ID=$AK_SECRET_ID
AGENT_SHARD_ID=0
EOF
chmod 0400 /run/apn/akash.env
```

Render `infra/akash/deploy.yaml` against this env (the SDL declares the
variables; the provider receives them via `--env-file` at submit):

```bash
provider-services tx deployment create infra/akash/deploy.yaml \
  --from apn-deployer --gas auto --gas-adjustment 1.5 -y \
  --env-file /run/apn/akash.env
shred -u /run/apn/akash.env
```

When the container starts:

1. `apn-entrypoint` stages `VAULT_ROLE_ID` / `VAULT_SECRET_ID` on a
   `0700` tmpfs (`/run/apn/vault/`).
2. Vault Agent logs in via AppRole, then deletes the secret-id from
   disk (`remove_secret_id_file_after_reading = true`).
3. Vault Agent renders `/run/apn/secrets/apn.env` from
   `kv/apn/{core,llm,rpc,integrations,depin}` using
   `infra/akash/templates/apn.env.tmpl`.
4. The entrypoint sources that dotenv, drops privileges with `gosu`,
   and execs the swarm process. The env file is `0400 apn:apn` on a
   tmpfs; it never touches durable storage.
5. Vault Agent re-renders the dotenv every 5 minutes; on SIGTERM the
   entrypoint forwards the signal so Vault Agent revokes its token
   before shutdown.

---

## 8. Rotation runbook

| Asset                       | Rotation cadence | Command                                                                 |
|-----------------------------|------------------|--------------------------------------------------------------------------|
| `apn-terraform` secret-id   | 24h (auto-expire) | re-run step 4a in CI                                                    |
| `apn-akash-runtime` secret-id | 30 days         | re-run step 4b, redeploy Akash workload                                  |
| Transit keys (`apn-*`)      | 90 days          | `vault write -f transit/keys/apn-wallet-encryption/rotate`               |
| Any provider API key        | on compromise    | rotate at provider, then `vault kv patch kv/apn/<path> field=<new>`     |
| Vault audit log             | daily            | `logrotate` on `/var/log/vault/audit.log`                                |

KV v2 keeps the last 10 versions of every path; rollback is
`vault kv rollback -version=<n> kv/apn/<path>`.

---

## 9. Verification checklist

Run these before declaring a deployment production-ready:

```bash
# (a) No literal secrets in the repo.
rg -n --hidden -g '!*.example' \
  -e 'eyJ|sk-[A-Za-z0-9]{20,}|hvs\.[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}'

# (b) Vault Agent renders all expected variables.
docker run --rm \
  -e VAULT_ADDR=$VAULT_ADDR \
  -e VAULT_ROLE_ID=$AK_ROLE_ID \
  -e VAULT_SECRET_ID=$AK_SECRET_ID \
  ghcr.io/yieldswarm/apn-agentswarm:1.0.0 \
  bash -c 'sleep 5 && grep -c = /run/apn/secrets/apn.env'

# (c) Terraform plan succeeds with read-only Vault policy.
( cd infra/terraform && terraform plan -refresh-only )

# (d) Audit log shows only expected callers.
sudo tail -n 50 /var/log/vault/audit.log | jq '.auth.display_name'
```

If any of (a)–(d) fails, the deployment is **not** production-grade —
do not promote.
