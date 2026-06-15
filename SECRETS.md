# Secrets Management with HashiCorp Vault

This repository never stores secrets in source. Every credential lives in
**HashiCorp Vault** and is delivered to consumers at the last possible moment:

- **Terraform** reads cloud (Azure, RunPod, Vultr, DigitalOcean) and RPC
  credentials from Vault at plan/apply time via a least-privilege AppRole.
- **The Akash runtime** fetches its application + RPC secrets from Vault at
  container start and injects them as environment variables, then drops its
  Vault token. Nothing is baked into the image or the on-chain manifest.

```
                         ┌─────────────────────────┐
                         │        Vault (KV v2)     │
                         │  secret/yieldswarm/...    │
                         │   ├─ cloud/azure          │
                         │   ├─ cloud/runpod         │
                         │   ├─ cloud/vultr          │
                         │   ├─ cloud/digitalocean   │
                         │   ├─ rpc                  │
                         │   └─ app                  │
                         └────────────┬─────────────┘
            AppRole: yieldswarm-terraform│  AppRole: yieldswarm-akash
              (policy: terraform-read)   │   (policy: akash-runtime-read)
                 reads cloud/* + rpc     │     reads app + rpc
                         ┌───────────────┴───────────────┐
                         ▼                                ▼
                  ┌─────────────┐                 ┌──────────────────┐
                  │  Terraform  │                 │  Akash container │
                  │ providers   │                 │  entrypoint.sh   │
                  │ azurerm/    │                 │  → env vars →    │
                  │ runpod/...  │                 │  app process     │
                  └─────────────┘                 └──────────────────┘
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `infra/vault/policies/*.hcl` | Least-privilege Vault policies |
| `infra/vault/bootstrap.sh` | Enables KV v2 + AppRole, writes policies & roles |
| `infra/vault/seed-secrets.sh` | Writes secrets from env into Vault (no values in repo) |
| `infra/vault/secrets.env.example` | Template for the values you seed |
| `infra/terraform/` | Terraform that sources all provider creds from Vault |
| `deploy/akash/entrypoint.sh` | Runtime secret injection for the container |
| `deploy/akash/Dockerfile` | Image with the Vault CLI + entrypoint |
| `deploy/akash/deploy.sdl.yaml` | Akash SDL (no secrets — wrapping token only) |

## Secret paths and keys

All paths live under the KV v2 mount (default `secret/`).

| Path | Keys | Consumed by |
| --- | --- | --- |
| `yieldswarm/cloud/azure` | `arm_client_id`, `arm_client_secret`, `arm_tenant_id`, `arm_subscription_id` | Terraform (azurerm) |
| `yieldswarm/cloud/runpod` | `api_key` | Terraform (runpod) |
| `yieldswarm/cloud/vultr` | `api_key` | Terraform (vultr) |
| `yieldswarm/cloud/digitalocean` | `token` | Terraform (digitalocean) |
| `yieldswarm/rpc` | `SOLANA_RPC_URL`, `HELIUS_API_KEY`, `BIRDEYE_API_KEY`, `JUPITER_API_KEY`, `RAYDIUM_API_KEY`, `TON_API_KEY`, `TAO_SUBNET_KEY`, `FAILOVER_RPC_LIST` | Terraform + Akash |
| `yieldswarm/app` | `AGENTSWARM_MASTER_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GROK_API_KEY`, `GEMINI_API_KEY`, `WALLET_ENCRYPTION_KEY`, `TEE_SIGNING_KEY`, `DATABASE_ENCRYPTION_KEY`, … | Akash runtime |

## Prerequisites

- A reachable Vault server (`VAULT_ADDR`) — Vault **1.12+**.
- The `vault` CLI and `jq` on the operator machine.
- A privileged `VAULT_TOKEN` for the one-time bootstrap (e.g. the root token or
  an admin token that can mount engines and write policies).

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<privileged-token>"   # bootstrap only
vault status
```

> **Local trial:** run a throwaway dev server with
> `vault server -dev -dev-root-token-id=root` and use
> `VAULT_ADDR=http://127.0.0.1:8200`, `VAULT_TOKEN=root`. This entire guide was
> validated end-to-end against a dev server.

---

## Step 1 — Bootstrap Vault (engines, policies, AppRoles)

```bash
cd infra/vault
./bootstrap.sh
```

This is idempotent and:

1. Enables the **KV v2** engine at `secret/`.
2. Enables the **AppRole** auth method at `approle/`.
3. Writes the `terraform-read`, `akash-runtime-read`, and `secrets-admin`
   policies.
4. Creates the `yieldswarm-terraform` and `yieldswarm-akash` AppRoles.
5. Prints the two **RoleIDs** (non-sensitive — store them in CI / the SDL).

Override defaults with env vars if needed, e.g. a custom mount:

```bash
KV_MOUNT=kv APPROLE_PATH=approle ./bootstrap.sh
```

Capture the RoleIDs from the output:

```bash
export TF_ROLE_ID="<yieldswarm-terraform RoleID>"
export AKASH_ROLE_ID="<yieldswarm-akash RoleID>"
```

---

## Step 2 — Seed the secrets

Populate values in your environment, then write them to Vault. Values are passed
to Vault over **stdin as JSON**, so they never appear in your shell history or
the process list.

```bash
cd infra/vault
cp secrets.env.example secrets.env     # secrets.env is .gitignored
"$EDITOR" secrets.env                   # fill in real values

set -a; source ./secrets.env; set +a
./seed-secrets.sh
```

Only variables that are set get written; the rest are skipped. Verify:

```bash
vault kv list -mount=secret yieldswarm
vault kv list -mount=secret yieldswarm/cloud
vault kv get  -mount=secret yieldswarm/cloud/azure
```

To rotate a single value later, just re-run `seed-secrets.sh` (KV v2 keeps the
version history) or write one key directly:

```bash
vault kv patch -mount=secret yieldswarm/cloud/runpod api_key="<new-key>"
```

---

## Step 3 — Run Terraform (pulls all creds from Vault)

Issue a SecretID for the Terraform AppRole and run Terraform. The SecretID is
provided through the environment so it never lands in a file.

```bash
cd infra/terraform

export VAULT_ADDR="https://vault.example.com:8200"
export TF_VAR_vault_address="$VAULT_ADDR"
export TF_VAR_vault_role_id="$TF_ROLE_ID"
export TF_VAR_vault_secret_id="$(vault write -f -field=secret_id \
    auth/approle/role/yieldswarm-terraform/secret-id)"

terraform init
terraform plan
```

Expected plan output confirms every provider credential was sourced from Vault:

```text
credentials_sourced_from_vault = {
  azure        = true
  digitalocean = true
  rpc          = true
  runpod       = true
  vultr        = true
}
```

`providers.tf` configures `azurerm`, `runpod`, `vultr`, and `digitalocean`
exclusively from the `vault_kv_secret_v2` data sources in `vault.tf`. Add your
resources to `main.tf`; they consume the already-configured providers and the
RPC values via `local.rpc["SOLANA_RPC_URL"]`, etc.

> **Local/dev alternative:** skip AppRole and let the provider use `VAULT_TOKEN`
> directly by leaving `vault_role_id` empty:
> ```bash
> export VAULT_TOKEN=root TF_VAR_vault_address="$VAULT_ADDR"
> terraform plan
> ```

> **State safety:** Terraform state can contain the resolved secret values.
> Use a remote backend with encryption at rest (e.g. azurerm/S3 backend) and
> restrict access. `*.tfstate` and `*.tfvars` are git-ignored.

---

## Step 4 — Build & push the Akash image

The image bundles the Vault CLI + `jq` + the runtime entrypoint. It contains
**no secrets**.

```bash
# From the repository root (build context = repo root).
docker build -f deploy/akash/Dockerfile -t ghcr.io/YOUR_ORG/yieldswarm:1.0.0 .
docker push ghcr.io/YOUR_ORG/yieldswarm:1.0.0
```

Pin to an immutable digest for production and use it in the SDL:

```bash
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/YOUR_ORG/yieldswarm:1.0.0
```

---

## Step 5 — Deploy to Akash with runtime secret injection

The Akash manifest (including its `env`) is visible to the provider running the
workload. Therefore we **never** put a raw SecretID or token in the SDL. Instead
we deliver a **response-wrapped, single-use, short-TTL SecretID**: even if the
provider observes it, it cannot be replayed after the container unwraps it once.

1. Mint a wrapping token immediately before deploying (120s TTL):

   ```bash
   export VAULT_ROLE_ID="$AKASH_ROLE_ID"
   export VAULT_SECRET_ID_WRAPPING_TOKEN="$(vault write -wrap-ttl=120s -f \
       -field=wrapping_token auth/approle/role/yieldswarm-akash/secret-id)"
   ```

2. Render the SDL so the wrapping token is injected (never committed):

   ```bash
   envsubst < deploy/akash/deploy.sdl.yaml > /tmp/deploy.rendered.yaml
   ```

   Also set `VAULT_ADDR` and `VAULT_ROLE_ID` in the SDL (the RoleID is
   non-sensitive). The image defaults the remaining `VAULT_*` paths.

3. Deploy with the Akash CLI (standard flow):

   ```bash
   akash tx deployment create /tmp/deploy.rendered.yaml --from <key> ...
   # ... accept a bid, create a lease ...
   akash provider send-manifest /tmp/deploy.rendered.yaml --from <key> ...
   ```

At container start, `entrypoint.sh`:

1. Unwraps the SecretID and logs in to the `yieldswarm-akash` AppRole.
2. Reads `yieldswarm/app` and `yieldswarm/rpc` from Vault.
3. Exports each key as an environment variable for the app.
4. Revokes its Vault token and scrubs it from the child environment.

You can reproduce this locally:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
WRAP="$(vault write -wrap-ttl=120s -f -field=wrapping_token \
    auth/approle/role/yieldswarm-akash/secret-id)"
env -i PATH="$PATH" \
  VAULT_ADDR="$VAULT_ADDR" \
  VAULT_ROLE_ID="$AKASH_ROLE_ID" \
  VAULT_SECRET_ID_WRAPPING_TOKEN="$WRAP" \
  deploy/akash/entrypoint.sh sh -c 'echo "OPENAI=[$OPENAI_API_KEY]"'
```

### Runtime configuration (env vars)

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `VAULT_ADDR` | yes | — | Vault endpoint |
| `VAULT_ROLE_ID` | yes¹ | — | Non-sensitive AppRole RoleID |
| `VAULT_SECRET_ID_WRAPPING_TOKEN` | yes¹ | — | **Recommended.** Wrapped, single-use SecretID |
| `VAULT_SECRET_ID` | — | — | Raw SecretID (less safe alternative) |
| `VAULT_TOKEN` | — | — | Pre-issued token (local/dev only) |
| `VAULT_APPROLE_PATH` | — | `approle` | AppRole mount |
| `VAULT_KV_MOUNT` | — | `secret` | KV v2 mount |
| `VAULT_APP_PATH` | — | `yieldswarm/app` | App secret path |
| `VAULT_RPC_PATH` | — | `yieldswarm/rpc` | RPC secret path |
| `VAULT_NAMESPACE` | — | — | Vault Enterprise / HCP namespace |
| `VAULT_CACERT` | — | — | CA bundle for TLS verification |
| `VAULT_REVOKE_TOKEN_AFTER_LOAD` | — | `true` | Revoke token after injection |

¹ Provide either AppRole auth (`VAULT_ROLE_ID` + a SecretID source) **or**
`VAULT_TOKEN`.

---

## Rotation & operations

- **Rotate a secret value:** re-run `seed-secrets.sh` or `vault kv patch …`,
  then redeploy/re-plan. KV v2 retains version history for rollback.
- **Rotate the Terraform SecretID:** simply mint a new one (step 3). SecretIDs
  are short-lived by policy.
- **Akash SecretIDs are single-use** (`secret_id_num_uses=1`) with a 24h TTL by
  default — a fresh wrapping token is minted per deploy.
- **Revoke a role's access:** `vault write auth/approle/role/<role>/secret-id-accessor/destroy …`
  or delete/disable the AppRole.
- **Audit:** enable a Vault audit device (`vault audit enable file …`) to log
  every secret access.

## Security guarantees

- No secret values, tokens, or endpoints are committed to this repository.
- Least-privilege policies: Terraform cannot read app secrets; the Akash
  runtime cannot read raw cloud IaC credentials. (Both verified.)
- Akash SecretIDs are response-wrapped, single-use, and short-lived, so the
  on-chain manifest cannot leak reusable credentials.
- The runtime revokes its Vault token and removes it from the app environment
  after injecting secrets.
- Secrets are written to Vault via stdin JSON, never via command-line args.
- TLS verification is on by default; `VAULT_SKIP_VERIFY` exists only for local
  testing and must never be used in production.
