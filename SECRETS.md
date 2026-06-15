# YieldSwarm Secrets - HashiCorp Vault Integration

End-to-end runbook for bringing up Vault and wiring it into Terraform and the
Akash workload. **Every command in this document is idempotent and safe to
re-run.** No secret value is ever stored in this repository.

> **Threat model.** A reader of this repo, a CI log, a container layer, or
> the Akash deployment manifest must be unable to recover any production
> secret. Operators with a hardware-backed identity (OIDC / YubiKey) and
> auditors are the only humans who ever see plaintext.

---

## Table of contents

1. [Architecture in one picture](#1-architecture-in-one-picture)
2. [Prerequisites](#2-prerequisites)
3. [Bootstrap Vault](#3-bootstrap-vault)
4. [Seed secrets](#4-seed-secrets)
5. [Wire up Terraform](#5-wire-up-terraform)
6. [Wire up the Akash workload](#6-wire-up-the-akash-workload)
7. [Day-2: rotation, revocation, audit](#7-day-2-rotation-revocation-audit)
8. [Disaster recovery](#8-disaster-recovery)
9. [Verification checklist](#9-verification-checklist)

---

## 1. Architecture in one picture

```
                       +--------------------------------+
   operators ─OIDC──▶ |          Vault cluster          | ─audit log──▶  SIEM
                       |  (Raft HA, transit auto-unseal) |
                       +----+-------------+--------------+
                            │             │
                  approle   │             │  approle (wrapped secret_id, single use)
              (CI runners)  │             │
                            ▼             ▼
                  +---------------+   +-------------------------+
                  | Terraform CLI |   |  Akash container init   |
                  |  vault.tf     |   |  (vault-agent sidecar)  |
                  +-------+-------+   +-----------+-------------+
                          │                       │
              cloud APIs  ▼                       ▼  tmpfs env file
            (Azure / RunPod / Vultr / DO)        application process
```

* **Operators** authenticate to Vault via OIDC; humans never see long-lived
  tokens.
* **Terraform** authenticates with an AppRole bound to the `terraform-cicd`
  policy. The `role_id` lives in CI; the `secret_id` is response-wrapped per
  pipeline run.
* **Akash workloads** authenticate with an AppRole bound to the
  `akash-runtime` policy. The `role_id` is baked into the image (non-secret);
  the `secret_id` is response-wrapped, single-use, with a 5-minute TTL and is
  injected at `tx deployment create` time.

---

## 2. Prerequisites

| Binary             | Min version | Where you need it          |
|--------------------|-------------|----------------------------|
| `vault`            | 1.17.x      | operator workstation, CI   |
| `terraform`        | 1.7.x       | CI runner                  |
| `jq`               | 1.6         | bootstrap scripts          |
| `docker buildx`    | 0.13        | image build host           |
| `provider-services`| 0.6.x       | Akash deploy host          |

```bash
# macOS
brew install vault terraform jq akash-network/tap/provider-services

# Debian/Ubuntu
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y vault terraform jq
```

Export the cluster address everywhere:

```bash
export VAULT_ADDR="https://vault.yieldswarm.internal:8200"
```

---

## 3. Bootstrap Vault

> Run all four scripts on the **active** Raft leader. They are idempotent.

```bash
cd infra/vault/scripts

# 3.1  init + unseal (uses transit auto-unseal in prod; Shamir for lab)
sudo VAULT_INIT_MODE=auto VAULT_INIT_OUT=/run/secrets/vault-init.json \
     ./10-init-unseal.sh

# 3.2  authenticate as root one time to enable engines + policies
export VAULT_TOKEN="$(sudo jq -r .root_token /run/secrets/vault-init.json)"

# 3.3  KV v2, transit, approle, jwt, oidc, file audit
./20-enable-engines.sh

# 3.4  push every policies/*.hcl into Vault
./30-apply-policies.sh

# 3.5  create AppRoles + emit response-wrapped secret_ids for each consumer
sudo APPROLE_OUT_DIR=/run/secrets/approle WRAP_TTL=300s ./40-enable-auth.sh
```

After step 3.5 you have:

```
/run/secrets/approle/terraform-cicd.role_id
/run/secrets/approle/terraform-cicd.secret_id.wrapped
/run/secrets/approle/akash-runtime.role_id
/run/secrets/approle/akash-runtime.secret_id.wrapped
/run/secrets/approle/agent-readonly.role_id
/run/secrets/approle/agent-readonly.secret_id.wrapped
```

**Immediately:**

1. Ship the `*.role_id` files to their consumers (CI secret store, container
   build pipeline, internal agent fleet). The role_id is non-secret.
2. Ship the `*.secret_id.wrapped` tokens out of band. They expire in
   `WRAP_TTL` (default 5 min) and are single-use.
3. Revoke the root token:
   ```bash
   vault token revoke -self
   unset VAULT_TOKEN
   sudo shred -u /run/secrets/vault-init.json   # only after recovery shares are in a HSM
   ```

From this point forward, humans authenticate via OIDC:

```bash
vault login -method=oidc role=operator
```

---

## 4. Seed secrets

Produce a **single JSON bundle** in an air-gapped environment (TEE, ephemeral
VM, or offline laptop). Schema is documented in
`infra/vault/scripts/50-seed-secrets.sh`. Example skeleton:

```json
{
  "azure": {
    "client_id":       "00000000-0000-0000-0000-000000000000",
    "client_secret":   "REDACTED",
    "tenant_id":       "00000000-0000-0000-0000-000000000000",
    "subscription_id": "00000000-0000-0000-0000-000000000000",
    "location":        "westus2",
    "resource_group":  "yieldswarm-prod"
  },
  "runpod":       { "api_key": "rp_...",     "pod_template_id": "tmpl_..." },
  "vultr":        { "api_key": "VULTR...",   "region": "ewr", "plan": "vc2-2c-4gb" },
  "digitalocean": { "token": "dop_v1_...",   "spaces_access_key": "...", "spaces_secret_key": "...", "region": "nyc3", "droplet_size": "s-2vcpu-4gb" },
  "rpc": {
    "solana": { "url": "https://...", "helius_api_key": "...", "jupiter_api_key": "...", "birdeye_api_key": "...", "raydium_api_key": "..." },
    "eth":    { "mainnet_url": "https://...", "sepolia_url": "https://...", "bundler_url": "https://..." },
    "ton":    { "url": "https://...",  "api_key": "..." },
    "tao":    { "url": "https://...",  "subnet_key": "..." }
  },
  "akash":        { "wallet_mnemonic": "REDACTED 24 words", "keyring_passphrase": "REDACTED", "provider_uri": "https://provider.akash.network:8443", "chain_id": "akashnet-2" },
  "app": {
    "agentswarm": {
      "agentswarm_master_key":  "REDACTED",
      "kimiclaw_consensus_key": "REDACTED",
      "grok_api_key":           "REDACTED",
      "openai_api_key":         "REDACTED",
      "anthropic_api_key":      "REDACTED",
      "gemini_api_key":         "REDACTED"
    }
  }
}
```

Load it (the bundle is read once, then **shred it**):

```bash
vault login -method=oidc role=operator
export SECRETS_BUNDLE=/run/secrets/yieldswarm-bundle.json
sudo install -m 0400 ./bundle.json $SECRETS_BUNDLE
infra/vault/scripts/50-seed-secrets.sh
sudo shred -u $SECRETS_BUNDLE
```

Sanity-check (this only prints metadata, never values):

```bash
vault kv metadata get kv/yieldswarm/prod/azure
vault kv list           kv/metadata/yieldswarm/prod/rpc
```

---

## 5. Wire up Terraform

Terraform **never** sees a cloud-provider credential except through Vault.
The only long-lived secret in CI is the AppRole role_id; the secret_id is
response-wrapped per pipeline run.

### 5.1 CI environment variables

| Variable                              | Source                                                            |
|---------------------------------------|-------------------------------------------------------------------|
| `VAULT_ADDR`                          | static config                                                     |
| `TF_VAR_environment`                  | `prod` / `staging` / `dev`                                        |
| `TF_VAR_vault_address`                | same as `VAULT_ADDR`                                              |
| `TF_VAR_vault_role_id`                | CI secret store, value from `terraform-cicd.role_id`              |
| `TF_VAR_vault_secret_id_wrapped`      | freshly minted at pipeline start (see snippet below)              |

GitHub Actions example (the wrap call runs from a bastion that holds an
operator token; CI never sees a long-lived token):

```yaml
- name: Mint wrapped secret_id
  id: vault
  run: |
    wrapped=$(ssh bastion -- \
      vault write -wrap-ttl=600s -f -format=json \
        auth/approle/role/terraform-cicd/secret-id \
      | jq -r .wrap_info.token)
    echo "::add-mask::$wrapped"
    echo "wrapped=$wrapped" >>"$GITHUB_OUTPUT"

- name: Terraform plan
  env:
    VAULT_ADDR:                    ${{ secrets.VAULT_ADDR }}
    TF_VAR_environment:            prod
    TF_VAR_vault_address:          ${{ secrets.VAULT_ADDR }}
    TF_VAR_vault_role_id:          ${{ secrets.VAULT_TF_ROLE_ID }}
    TF_VAR_vault_secret_id_wrapped: ${{ steps.vault.outputs.wrapped }}
  run: |
    cd infra/terraform
    terraform init -backend-config=backend-prod.hcl
    terraform plan -input=false -out=tfplan
```

### 5.2 Local plan

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # edit env + addresses only

# Mint a wrapped secret_id (5 min TTL)
export TF_VAR_vault_role_id="$(cat /run/secrets/approle/terraform-cicd.role_id)"
export TF_VAR_vault_secret_id_wrapped="$(
  vault write -wrap-ttl=300s -f -format=json \
    auth/approle/role/terraform-cicd/secret-id \
  | jq -r .wrap_info.token
)"

terraform init -backend=false
terraform plan
```

If you see `Error: error unwrapping`, the wrapped token expired - mint a new
one. If you see `permission denied on kv/data/yieldswarm/prod/...`, the
`terraform-cicd` policy is missing a `read` capability on that path.

### 5.3 What Terraform reads from Vault

| Cloud / area     | Vault path                                          | Used to configure              |
|------------------|-----------------------------------------------------|---------------------------------|
| Azure            | `kv/data/yieldswarm/<env>/azure`                    | `azurerm` provider              |
| RunPod           | `kv/data/yieldswarm/<env>/runpod`                   | `runpod` provider               |
| Vultr            | `kv/data/yieldswarm/<env>/vultr`                    | `vultr` provider                |
| DigitalOcean     | `kv/data/yieldswarm/<env>/digitalocean`             | `digitalocean` provider         |
| RPC (Sol/Eth/...) | `kv/data/yieldswarm/<env>/rpc/{solana,eth,ton,tao}` | RPC module + downstream Vault write |

The RPC module re-publishes a curated, namespaced view at
`kv/data/yieldswarm/<env>/runtime/rpc-resolved` for downstream workloads.

---

## 6. Wire up the Akash workload

### 6.1 Build the image (role_id baked in, no secrets baked in)

```bash
ROLE_ID="$(cat /run/secrets/approle/akash-runtime.role_id)"

docker buildx build \
  --build-arg VAULT_APPROLE_ROLE_ID="${ROLE_ID}" \
  -f infra/akash/docker/Dockerfile \
  -t ghcr.io/yieldswarm/agentswarm:1.0.0 \
  --push .
```

The Dockerfile fetches a pinned + sha256-verified `vault` binary, copies the
Vault Agent config and template, drops to a non-root user, and exposes only
the `entrypoint.sh` orchestration surface.

### 6.2 Deploy

```bash
# Mint a fresh, single-use, 5-minute response-wrapped secret_id
WRAPPED="$(vault write -wrap-ttl=300s -f -format=json \
  auth/approle/role/akash-runtime/secret-id \
  | jq -r .wrap_info.token)"

AKASH_VAULT_SECRET_ID_WRAPPED="${WRAPPED}" \
  provider-services tx deployment create infra/akash/deploy.yaml \
    --from "${AKASH_KEY_NAME}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --node     "${AKASH_NODE}"

unset WRAPPED AKASH_VAULT_SECRET_ID_WRAPPED
```

### 6.3 What happens inside the container

1. `entrypoint.sh` validates env, writes the wrapped token to a tmpfs file
   (mode 0400), then starts `vault agent`.
2. Vault Agent unwraps the token, logs in via AppRole, renders
   `/run/vault-agent/app.env` from `app.env.ctmpl`, and keeps it fresh.
3. `entrypoint.sh` sources the env file with `set -a`, drops to uid `app`,
   and execs the application.
4. On shutdown the env file and the secret_id file are shredded.

There is **no path** by which the wrapped token, the role_id, or any rendered
secret can leak into the container image layers, the SDL, the Akash
manifest, or container logs.

---

## 7. Day-2: rotation, revocation, audit

### Rotate an AppRole secret_id

```bash
infra/vault/scripts/60-rotate-approle.sh terraform-cicd
infra/vault/scripts/60-rotate-approle.sh akash-runtime
```

Existing tokens minted under the old secret_id keep working until their TTL
elapses. To force revocation now:

```bash
vault list  auth/token/accessors                 # find offending accessors
vault token revoke -accessor <accessor>
```

### Rotate a cloud-provider credential

1. Rotate at the cloud provider's console / API.
2. `vault kv patch kv/yieldswarm/prod/<provider> <key>=<new-value>` (KV v2
   keeps the previous version for rollback).
3. Re-run the Terraform pipeline. The new credential is picked up
   automatically because Terraform reads from Vault on every plan.
4. For the Akash workload, no redeploy is necessary - Vault Agent re-renders
   the env file on the next refresh, and a `SIGHUP` is sent to the app (see
   the `command =` hook in `vault-agent.hcl`).

### Rotate a transit key

```bash
vault write -f transit/keys/wallet-encryption/rotate
# Optional: re-wrap previously encrypted ciphertexts so old key versions can
# be retired:
vault write transit/keys/wallet-encryption/config min_decryption_version=N
```

### Audit

The file audit device writes hashed access records to
`/var/log/vault/audit.log`. Ship that to your SIEM. Spot-check:

```bash
sudo tail -n 100 /var/log/vault/audit.log | jq 'select(.type == "request")
  | { time, path: .request.path, op: .request.operation, accessor: .auth.accessor }'
```

---

## 8. Disaster recovery

* **Lost quorum (Raft)** - restore from `vault operator raft snapshot save`
  taken in the previous 24h. Snapshots are taken nightly to the encrypted
  Azure storage account provisioned by `modules/azure`.
* **Lost auto-unseal KMS key** - rebuild Vault from the recovery key shares
  generated by `10-init-unseal.sh`. Recovery shares are held in HSMs by
  three break-glass operators (`m of n = 3 of 5`).
* **Compromised AppRole secret_id** - revoke all child tokens
  (`vault token revoke -accessor`) and run `60-rotate-approle.sh <role>`.

---

## 9. Verification checklist

Run this before declaring the integration done:

```bash
# Vault healthy
vault status                                          # initialized=true, sealed=false

# Policies present
for p in admin operator terraform-cicd akash-runtime agent-readonly; do
  vault policy read "$p" >/dev/null && echo "ok: $p"
done

# Secrets present
for k in azure runpod vultr digitalocean akash; do
  vault kv metadata get "kv/yieldswarm/prod/$k" >/dev/null && echo "ok: $k"
done
for k in solana eth ton tao; do
  vault kv metadata get "kv/yieldswarm/prod/rpc/$k" >/dev/null && echo "ok: rpc/$k"
done

# Transit keys present
for k in wallet-encryption db-encryption tee-signing tf-outputs; do
  vault read "transit/keys/$k" >/dev/null && echo "ok: transit/$k"
done

# AppRoles bound to correct policies
for r in terraform-cicd akash-runtime agent-readonly; do
  vault read -format=json "auth/approle/role/$r" \
    | jq -e --arg r "$r" '.data.token_policies | index($r) != null' >/dev/null \
    && echo "ok: approle/$r bound to policy $r"
done

# No secret material is staged in the repo
! grep -RInE 'api[_-]?key|secret|token|password|mnemonic' \
    --include='*.tf' --include='*.hcl' --include='*.yaml' --include='Dockerfile*' \
    --exclude-dir=.git \
    -- infra/ \
  | grep -vE '(variable|description|sensitive|=\s*null|=\s*"")' \
  && echo "ok: no embedded secrets"
```

If every line prints `ok:`, the integration is production-grade and you can
hand over to on-call.
