# SECRETS — HashiCorp Vault Operator Runbook

> **TL;DR** — Every credential YieldSwarm v2 consumes (Azure, RunPod, Vultr,
> DigitalOcean, RPC providers, LLM keys, agent shard keys, Akash runtime
> bundle) lives in HashiCorp Vault. Terraform reads them at `plan/apply`
> time, Akash workloads pull them at container start via an in-container
> Vault Agent. **Nothing sensitive is ever committed to git, baked into
> a container image, or exported into a long-lived shell.**

---

## Table of contents

1. [Architecture](#1-architecture)
2. [Prerequisites](#2-prerequisites)
3. [One-time bootstrap](#3-one-time-bootstrap)
4. [Day-2 operations](#4-day-2-operations)
   1. [Adding a new secret](#41-adding-a-new-secret)
   2. [Rotating a secret](#42-rotating-a-secret)
   3. [Granting a new consumer access](#43-granting-a-new-consumer-access)
   4. [Issuing a wrapped SecretID](#44-issuing-a-wrapped-secretid)
5. [Running Terraform with Vault](#5-running-terraform-with-vault)
6. [Deploying to Akash with Vault](#6-deploying-to-akash-with-vault)
7. [CI/CD wiring (GitHub Actions)](#7-cicd-wiring-github-actions)
8. [Incident response](#8-incident-response)
9. [Path reference](#9-path-reference)

---

## 1. Architecture

```
                                ┌─────────────────────┐
                                │  HashiCorp Vault    │
                                │  vault.yieldswarm.io│
                                │  (Raft HA, 5 nodes) │
                                └──────────┬──────────┘
                                           │
            ┌──────────────────────────────┼──────────────────────────────┐
            │                              │                              │
   ┌────────▼─────────┐         ┌──────────▼─────────┐        ┌───────────▼──────────┐
   │ Terraform        │         │ Akash workloads     │        │ Agent shards         │
   │ (Azure/RunPod/   │         │ (vault-agent in     │        │ (Vercel/Azure/Vultr/ │
   │  Vultr/DO/RPC)   │         │  container)         │        │  DO with vault-agent)│
   │                  │         │                     │        │                      │
   │ AppRole:         │         │ AppRole:            │        │ AppRole:             │
   │ `terraform`      │         │ `akash-runtime`     │        │ `agent-runtime`      │
   │ Policy:          │         │ Policy:             │        │ Policy:              │
   │ `terraform.hcl`  │         │ `akash-runtime.hcl` │        │ `agent-runtime.hcl`  │
   └──────────────────┘         └─────────────────────┘        └──────────────────────┘
```

| Identity         | Auth method        | Policy                | Token TTL | SecretID TTL |
| ---------------- | ------------------ | --------------------- | --------- | ------------ |
| Human admins     | OIDC (MFA)         | `admin.hcl`           | 1h        | n/a          |
| CI runner        | AppRole `ci-bootstrap` | `ci-bootstrap.hcl` | 15m       | 5m           |
| Terraform        | AppRole `terraform`    | `terraform.hcl`    | 30m       | 10m          |
| Akash container  | AppRole `akash-runtime`| `akash-runtime.hcl`| 1h        | 30m          |
| On-prem agents   | AppRole `agent-runtime`| `agent-runtime.hcl`| 4h        | 1h           |

KVv2 mount is `yieldswarm/`. Full path layout in [§9](#9-path-reference).

---

## 2. Prerequisites

HCP tenant layout (org, project, IAM): [`docs/HCP_ORGANIZATION.md`](docs/HCP_ORGANIZATION.md).

On the operator workstation (laptop or TEE):

| Tool         | Min version | Notes                                                |
| ------------ | ----------- | ---------------------------------------------------- |
| `vault` CLI  | 1.18.0      | `brew install vault` / apt `vault`                   |
| `terraform`  | 1.6.0       | `brew install terraform`                             |
| `jq`         | 1.6         | required by all setup scripts                        |
| `curl`       | any         | health checks                                        |
| `provider-services` (Akash) | 0.6+ | Only on the host that submits Akash deployments |
| `gh` CLI     | optional    | only if you wire CI rotations through GitHub        |

A Vault server reachable at `${VAULT_ADDR}`. For a fresh cluster:

```bash
# Single-node dev (testing only, IN-MEMORY, NO persistence):
docker run --rm -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.18.2

# Production: deploy the official Helm chart or Vault Enterprise with
# Integrated Storage (Raft) and auto-unseal via Azure Key Vault / AWS KMS.
# https://developer.hashicorp.com/vault/tutorials/raft
```

Set the address everywhere you'll be running commands from:

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
```

---

## 3. One-time bootstrap

Run from the repo root, on a **trusted workstation** (not CI):

```bash
# 1. (skip on dev) Initialise + unseal the cluster. Splits the master key
#    into 5 Shamir shares with threshold 3. The root token + shares are
#    written to ./.vault-init/init.json (mode 600).
VAULT_ADDR=https://vault.yieldswarm.io:8200 \
OUTPUT_DIR=./.vault-init \
KEY_SHARES=5 KEY_THRESHOLD=3 \
  ./vault/setup/01-init.sh

# 2. Source the root token written by init.sh.
export VAULT_TOKEN=$(jq -r '.root_token' ./.vault-init/init.json)

# 3. Enable engines (KVv2 @ yieldswarm/, transit, PKI, file audit).
./vault/setup/02-enable-engines.sh

# 4. Push all policies in vault/policies/*.hcl.
./vault/setup/03-write-policies.sh

# 5. Enable AppRole + create the 4 roles (terraform / akash-runtime /
#    agent-runtime / ci-bootstrap). Optionally enable OIDC.
APPROLE_AKASH_CIDRS="0.0.0.0/0" \
ENABLE_OIDC=false \
  ./vault/setup/04-enable-auth.sh

# 6. (optional) Seed Vault from a local .env file.
SOURCE_ENV=./.env ./vault/setup/05-seed-secrets.sh

# 7. Distribute the 5 unseal shares to their holders (TEE / Yubikey /
#    paper), then DESTROY the local copy.
shred -u ./.vault-init/init.json

# 8. Revoke the root token used for bootstrap.
vault token revoke "${VAULT_TOKEN}"
unset VAULT_TOKEN
```

Or run all of steps 1-6 in one go:

```bash
VAULT_ADDR=https://vault.yieldswarm.io:8200 \
OUTPUT_DIR=./.vault-init \
SOURCE_ENV=./.env \
APPROLE_AKASH_CIDRS="0.0.0.0/0" \
  ./vault/setup/bootstrap.sh
```

### 3.1 Move Vault config under GitOps

After the imperative bootstrap, switch to declarative management so future
policy / mount / AppRole changes flow through pull requests:

```bash
# Auth as admin via OIDC (or the root token if OIDC isn't ready yet).
vault login -method=oidc

cd vault/terraform-vault-config
terraform init  -backend-config=backend.hcl   # configure your S3+DynamoDB
terraform plan  -out=plan.tfplan
terraform apply plan.tfplan
```

The Terraform stack in `vault/terraform-vault-config/` is the source of
truth for: KVv2 mount, transit mount + keys, audit device, all 5
policies, all 4 AppRoles, and optional OIDC.

---

## 4. Day-2 operations

### 4.1 Adding a new secret

```bash
vault kv put yieldswarm/rpc/quicknode api_key='qn_xxx...'
vault kv get yieldswarm/rpc/quicknode
```

If the new path needs to be readable by an existing role, edit the
matching `vault/policies/<role>.hcl`, open a PR, and re-apply
`vault/terraform-vault-config`. No restart needed for consumers - Vault
Agent picks up the new path on the next render cycle.

### 4.2 Rotating a secret

```bash
# 1. Put the new value as a new version.
vault kv put yieldswarm/cloud/runpod api_key='runpod_new_key'

# 2. (Optional) Confirm the bump.
vault kv metadata get yieldswarm/cloud/runpod

# 3. Force in-flight consumers to roll. Vault Agent re-reads every
#    static_secret_render_interval (5 minutes) by default. To roll
#    immediately on Akash, restart the deployment:
provider-services tx deployment close --owner $WALLET --dseq $DSEQ
provider-services tx deployment create deploy.yaml --from $WALLET ...
```

If the secret is suspected compromised, also revoke any leases that
might reference it:

```bash
vault list sys/leases/lookup/auth/approle/login
vault lease revoke -prefix auth/approle/login
```

### 4.3 Granting a new consumer access

1. Add a new HCL file under `vault/policies/<consumer>.hcl` with the
   minimum set of `path "yieldswarm/data/..." { capabilities = ["read"] }`
   rules required.
2. Add a corresponding `vault_approle_auth_backend_role` block under
   `vault/terraform-vault-config/auth-approle.tf`.
3. `terraform apply` the Vault config stack.
4. Hand the consumer the role_id and issue a wrapped SecretID
   ([§4.4](#44-issuing-a-wrapped-secretid)).

### 4.4 Issuing a wrapped SecretID

A wrapped SecretID is the **only** sensitive material we hand to a
consumer out-of-band. It is one-shot, short-TTL, and the unwrap
operation is auditable.

```bash
# Get the role_id (non-sensitive, can be stored in plaintext / TF outputs).
ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)

# Mint a wrapped SecretID, TTL 10 minutes (Akash deploy needs enough
# time to schedule + pull the image).
WRAP_TOKEN=$(vault write -wrap-ttl=600s -force -format=json \
  auth/approle/role/akash-runtime/secret-id \
  | jq -r '.wrap_info.token')

echo "Hand these to the operator/CI for ONE deployment:"
echo "  VAULT_ROLE_ID=${ROLE_ID}"
echo "  VAULT_WRAPPED_SECRET_ID=${WRAP_TOKEN}"
```

If you need to mint these from CI itself, use the `ci-bootstrap` AppRole
which has exactly that and only that capability:

```bash
# Inside GitHub Actions, after AppRole login as ci-bootstrap:
vault write -wrap-ttl=600s -force -format=json \
  auth/approle/role/akash-runtime/secret-id \
  | jq -r '.wrap_info.token'
```

---

## 5. Running Terraform with Vault

```bash
# Operator: log in via OIDC (browser-based, MFA enforced)
vault login -method=oidc

# Mint a wrapped SecretID for the terraform role
WRAP=$(vault write -wrap-ttl=300s -force -format=json \
  auth/approle/role/terraform/secret-id \
  | jq -r '.wrap_info.token')

# Hand off to whatever shell will run terraform
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_ROLE_ID=$(vault read -field=role_id \
  auth/approle/role/terraform/role-id)
export VAULT_WRAPPED_SECRET_ID="${WRAP}"

# This sources the wrap → unwrap → approle/login flow and exports a
# 30-minute VAULT_TOKEN.
cd terraform
source ./scripts/vault-login.sh

terraform init -backend-config=backend.hcl
terraform plan  -out=plan.tfplan
terraform apply plan.tfplan
```

What Terraform reads from Vault:

| Path                              | Used by                          |
| --------------------------------- | -------------------------------- |
| `yieldswarm/cloud/azure`          | `azurerm` provider               |
| `yieldswarm/cloud/runpod`         | RunPod GraphQL via `http` data   |
| `yieldswarm/cloud/vultr`          | `vultr` provider                 |
| `yieldswarm/cloud/digitalocean`   | `digitalocean` provider          |
| `yieldswarm/rpc/{helius,birdeye,jupiter,solana,raydium,ton}` | `rpc_bundle` output |

These are the only credentials Terraform ever sees. The `terraform.hcl`
policy hard-denies all other paths.

---

## 6. Deploying to Akash with Vault

```bash
# 1. Mint a wrapped SecretID with the akash-runtime role. TTL must be
#    long enough to cover the deployment schedule + first container boot.
ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
WRAP=$(vault write -wrap-ttl=600s -force -format=json \
  auth/approle/role/akash-runtime/secret-id \
  | jq -r '.wrap_info.token')

# 2. Pick the shard you're deploying.
SHARD_ID=0

# 3. Submit the deployment. The 3 --env flags are the ONLY sensitive
#    values the SDL needs - everything else is fetched from Vault by the
#    in-container Vault Agent.
cd akash
provider-services tx deployment create deploy.yaml \
  --from $YOUR_AKASH_WALLET \
  --keyring-backend os \
  --env VAULT_ROLE_ID="${ROLE_ID}" \
  --env VAULT_WRAPPED_SECRET_ID="${WRAP}" \
  --env AGENT_SHARD_ID="${SHARD_ID}"

# 4. Accept the cheapest bid, create the lease, send the manifest.
#    (Standard Akash flow, omitted here.)
```

What happens inside the container (see `akash/entrypoint.sh`):

1. Validate `VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_WRAPPED_SECRET_ID`,
   `AGENT_SHARD_ID`.
2. `vault unwrap` the wrapped SecretID → `/run/secrets/secret-id` (tmpfs).
3. Start `vault agent`, which performs AppRole login and renders
   `/run/secrets/agent.env` from `templates/agent.env.ctmpl`.
4. Wait up to 120s for the first render, source the env, exec the
   workload.
5. On SIGTERM, both Vault Agent and the workload are stopped cleanly.

Everything is on tmpfs (`/run/secrets`) and tied to the container's
lifetime. The wrapped SecretID becomes useless after step 2.

---

## 7. CI/CD wiring (GitHub Actions)

```yaml
# .github/workflows/akash-deploy.yml (snippet)
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write       # for JWT auth, if you use it instead of approle
      contents: read
    steps:
      - uses: actions/checkout@v4

      # CI logs in to Vault using the ci-bootstrap AppRole. The secrets
      # below are GitHub Actions repository secrets and contain ONLY:
      #   - VAULT_ADDR
      #   - VAULT_CI_ROLE_ID
      #   - VAULT_CI_SECRET_ID  (rotated weekly by the ops cron)
      - name: Vault login (ci-bootstrap)
        id: vault
        run: |
          set -euo pipefail
          export VAULT_ADDR='${{ secrets.VAULT_ADDR }}'
          TOKEN=$(vault write -format=json auth/approle/login \
            role_id='${{ secrets.VAULT_CI_ROLE_ID }}' \
            secret_id='${{ secrets.VAULT_CI_SECRET_ID }}' \
            | jq -r '.auth.client_token')
          echo "::add-mask::${TOKEN}"
          echo "VAULT_TOKEN=${TOKEN}" >> "$GITHUB_ENV"

      - name: Mint wrapped SecretID for Akash
        id: akash-cred
        run: |
          set -euo pipefail
          ROLE_ID=$(vault read -field=role_id \
            auth/approle/role/akash-runtime/role-id)
          WRAP=$(vault write -wrap-ttl=600s -force -format=json \
            auth/approle/role/akash-runtime/secret-id \
            | jq -r '.wrap_info.token')
          echo "::add-mask::${WRAP}"
          echo "ROLE_ID=${ROLE_ID}" >> "$GITHUB_OUTPUT"
          echo "WRAP=${WRAP}"       >> "$GITHUB_OUTPUT"

      - name: provider-services deploy
        run: |
          provider-services tx deployment create akash/deploy.yaml \
            --from ci-wallet \
            --env VAULT_ROLE_ID='${{ steps.akash-cred.outputs.ROLE_ID }}' \
            --env VAULT_WRAPPED_SECRET_ID='${{ steps.akash-cred.outputs.WRAP }}' \
            --env AGENT_SHARD_ID='${{ matrix.shard }}'
```

The only repo-scoped GitHub secrets you ever store are:

| Secret name             | Sensitivity | Rotation cadence |
| ----------------------- | ----------- | ---------------- |
| `VAULT_ADDR`            | none        | rarely           |
| `VAULT_CI_ROLE_ID`      | low         | yearly           |
| `VAULT_CI_SECRET_ID`    | medium      | weekly (cron)    |

All other credentials flow through Vault.

---

## 8. Incident response

### A SecretID may have leaked

```bash
# Revoke that SecretID specifically
vault write -force auth/approle/role/<role>/secret-id-accessor/destroy \
  secret_id_accessor=<accessor>

# Or nuke all SecretIDs for the role and re-mint
vault write -force auth/approle/role/<role>/secret-id-num-uses num_uses=1
```

### A token may have leaked

```bash
vault token revoke <token>
vault token revoke -accessor <accessor>
# or nuclear: revoke every lease created under approle in the last hour
vault list sys/leases/lookup/auth/approle/login
```

### Suspected Vault root compromise

1. Seal the cluster immediately: `vault operator seal`.
2. Rotate the root token: `vault operator generate-root` from a fresh
   majority of unseal shares, then `vault token revoke` the old one.
3. Rotate every KV secret (run `vault kv put` for each path with new
   values - applications re-render automatically).
4. Rotate every AppRole RoleID: `vault write -force auth/approle/role/<r>/role-id`.

### Audit log

The file audit device writes to `${AUDIT_FILE_PATH:-/var/log/vault/audit.log}`.
Pipe it into your SIEM (Loki, Splunk, Sumo, etc.). Every secret read,
policy change, and login is captured with the caller's accessor and
remote address.

---

## 9. Path reference

KVv2 mount: **`yieldswarm/`** (data path: `yieldswarm/data/<key>`).

```
yieldswarm/
├── cloud/
│   ├── azure              { client_id, client_secret, tenant_id, subscription_id }
│   ├── runpod             { api_key }
│   ├── vultr              { api_key, ssh_public_key }
│   └── digitalocean       { token, ssh_public_key }
├── rpc/
│   ├── helius             { api_key }
│   ├── birdeye            { api_key }
│   ├── jupiter            { api_key }
│   ├── solana             { http_url, ws_url }
│   ├── raydium            { api_key }
│   └── ton                { api_key }
├── llm/
│   ├── openai             { api_key }
│   ├── anthropic          { api_key }
│   ├── grok               { api_key }
│   └── gemini             { api_key }
├── akash/
│   └── runtime            { master_key, kimiclaw_key, wallet_encryption_key, tee_signing_key, database_encryption_key }
├── agents/
│   └── shards/
│       ├── 0              { api_key, signing_key, ... }
│       ├── 1              { ... }
│       └── ... (up to 119)
└── integrations/
    ├── notion             { api_key }
    ├── linear             { api_key }
    ├── github             { token }
    ├── vercel             { token }
    └── telegram           { bot_token }
```

Policy → path matrix:

| Path glob                       | admin | terraform | akash-runtime | agent-runtime | ci-bootstrap |
| ------------------------------- | :---: | :-------: | :-----------: | :-----------: | :----------: |
| `yieldswarm/data/cloud/*`       | RW    | R         | DENY          | DENY          | —            |
| `yieldswarm/data/rpc/+`         | RW    | R         | R             | R             | —            |
| `yieldswarm/data/llm/+`         | RW    | —         | R             | R             | —            |
| `yieldswarm/data/akash/runtime` | RW    | —         | R             | —             | —            |
| `yieldswarm/data/agents/shards/+` | RW  | —         | R             | R             | —            |
| `yieldswarm/data/integrations/+`| RW    | —         | —             | R             | —            |
| `transit/encrypt/agent-runtime` | RW    | —         | U             | U             | —            |
| `transit/encrypt/terraform-state`| RW   | U         | —             | —             | —            |
| `auth/approle/role/*/secret-id` | RW    | —         | —             | —             | U (wrap-only)|
| `sys/*`                         | RW    | DENY      | DENY          | DENY          | —            |

R = read, U = update, RW = full, DENY = explicit deny, — = no policy
mention (deny by default).

---

## Appendix A — files in this repo

```
SECRETS.md                                ← this file
vault/
  README.md
  policies/
    admin.hcl
    ci-bootstrap.hcl
    terraform.hcl
    akash-runtime.hcl
    agent-runtime.hcl
  setup/
    bootstrap.sh
    01-init.sh
    02-enable-engines.sh
    03-write-policies.sh
    04-enable-auth.sh
    05-seed-secrets.sh
    lib.sh
  terraform-vault-config/
    versions.tf
    providers.tf
    variables.tf
    mounts.tf
    policies.tf
    auth-approle.tf
    auth-oidc.tf
    outputs.tf
terraform/                                ← infrastructure stack
  README.md
  versions.tf
  variables.tf
  providers.tf
  vault.tf                                ← all `data "vault_kv_secret_v2"`
  azure.tf
  runpod.tf
  vultr.tf
  digitalocean.tf
  rpc.tf
  outputs.tf
  cloud-init/
    vault-bootstrap.tftpl
  scripts/
    vault-login.sh
akash/
  README.md
  Dockerfile
  entrypoint.sh
  vault-agent.hcl
  templates/
    agent.env.ctmpl
  deploy.yaml
```
