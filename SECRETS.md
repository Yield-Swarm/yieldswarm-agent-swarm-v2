# YieldSwarm Secrets Management — HashiCorp Vault

> **Single source of truth:** every provider credential, RPC key, and runtime
> secret used by YieldSwarm lives in HashiCorp Vault. Nothing sensitive is
> ever committed, baked into a container image, or stored in Terraform state.
> The only thing that leaves Vault on its own is a **single-use, short-lived
> response-wrapped token** used to bootstrap workloads.

This document is the operator runbook. Follow it top to bottom on a fresh
Vault cluster.

---

## 1. Architecture at a glance

```
                          ┌──────────────────────────┐
                          │      HashiCorp Vault     │
                          │  KV v2: kv/yieldswarm/   │
                          │  Transit: yieldswarm-*   │
                          │  AppRoles, audit, policies│
                          └────────────┬─────────────┘
                                       │
            ┌──────────────────────────┼──────────────────────────┐
            │                          │                          │
   ┌────────▼────────┐       ┌─────────▼─────────┐       ┌────────▼─────────┐
   │  Terraform run  │       │  Akash container  │       │   Operators      │
   │  AppRole login  │       │  AppRole login    │       │  userpass + MFA  │
   │  → Azure/RunPod │       │  → exports env    │       │  → seed-secrets  │
   │    Vultr/DO/RPC │       │    then exec app  │       │    rotation      │
   └─────────────────┘       └───────────────────┘       └──────────────────┘
```

| Layer            | Where it runs          | Auth method     | Policy             |
| ---------------- | ---------------------- | --------------- | ------------------ |
| Terraform        | CI / operator laptop   | AppRole (1h)    | `terraform-reader` |
| Akash container  | Akash provider         | AppRole (24h periodic, wrapped secret_id) | `akash-runtime` |
| CI rotation jobs | GitHub Actions OIDC    | JWT auth        | `ci-writer`        |
| Humans           | CLI / UI               | userpass + MFA  | `secrets-admin`    |

---

## 2. Repository layout

```
infrastructure/
├── vault/
│   ├── policies/
│   │   ├── terraform-reader.hcl
│   │   ├── akash-runtime.hcl
│   │   ├── secrets-admin.hcl
│   │   └── ci-writer.hcl
│   ├── setup.sh           # idempotent cluster bootstrap
│   └── seed-secrets.sh    # writes provider creds into KV v2
├── terraform/
│   ├── versions.tf  variables.tf  vault.tf  providers.tf
│   ├── azure.tf  runpod.tf  vultr.tf  digitalocean.tf  rpc.tf
│   ├── outputs.tf  terraform.tfvars.example
│   └── templates/cloud-init-agent.sh.tftpl
└── akash/
    ├── Dockerfile             # builds ghcr.io/yieldswarm/openclaw-akash
    ├── entrypoint.sh          # AppRole login → export env → exec workload
    ├── healthcheck.sh
    ├── deploy.yaml            # SDL template (envsubst variables only)
    └── render-deploy.sh       # renders SDL with fresh wrapped secret_id
```

---

## 3. Prerequisites

On the operator workstation (or jump host):

```bash
# Required CLIs
vault     --version   # >= 1.15
terraform --version   # >= 1.6
akash     version     # >= 0.36
jq --version
envsubst --version

# Required env
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<root or admin token used only for bootstrap>"
```

Vault server must already exist (Raft cluster, integrated storage, TLS).
This guide assumes you have a functional `vault status` against the cluster.

---

## 4. One-time Vault bootstrap

```bash
cd infrastructure/vault
./setup.sh
```

The script is idempotent and will:

1. Enable audit devices (`file` at `/var/log/vault/audit.log`, plus `syslog`)
2. Mount **KV v2** at `kv/` and **transit** at `transit/`
3. Create the transit key `yieldswarm-wallets` (AES-256-GCM, 30-day auto-rotate, non-exportable)
4. Enable AppRole auth at `auth/approle/`
5. Write the four policies in `policies/`
6. Create the AppRoles:
   - `yieldswarm-terraform` — `terraform-reader` policy, 1h max TTL, single-use secret_id (10m TTL)
   - `yieldswarm-akash` — `akash-runtime` policy, 24h **periodic** token, single-use secret_id (1h TTL)
7. Print a fresh `role_id` and a **response-wrapped** `secret_id` for both AppRoles

> **Keep the wrapped tokens off disk.** They are single-unwrap and TTL-bound.
> If you don’t use them in 5 minutes, re-issue:
> `VAULT_WRAP_TTL=300 vault write -f -wrap-ttl=300 auth/approle/role/<role>/secret-id`

---

## 5. Seed provider credentials into Vault

Export every credential you intend to push, then run the seeder.
The seeder fails fast if a *required* var is missing; optional vars are blank.

```bash
# --- Azure (required if azure cloud is enabled) -----------------------------
export AZURE_SUBSCRIPTION_ID="..."
export AZURE_TENANT_ID="..."
export AZURE_CLIENT_ID="..."
export AZURE_CLIENT_SECRET="..."
export AZURE_RESOURCE_GROUP="yieldswarm-prod-rg"
export AZURE_LOCATION="eastus"

# --- RunPod -----------------------------------------------------------------
export RUNPOD_API_KEY="..."

# --- Vultr ------------------------------------------------------------------
export VULTR_API_KEY="..."
export VULTR_SSH_KEY_ID="..."

# --- DigitalOcean -----------------------------------------------------------
export DIGITALOCEAN_TOKEN="..."
export DO_SPACES_ACCESS_KEY="..."
export DO_SPACES_SECRET_KEY="..."
export DO_SSH_KEY_FINGERPRINT="aa:bb:cc:..."

# --- RPC / chain endpoints --------------------------------------------------
export SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
export HELIUS_API_KEY="..."
export JUPITER_API_KEY="..."
export BIRDEYE_API_KEY="..."
export RAYDIUM_API_KEY="..."
export TON_API_KEY="..."
export TAO_SUBNET_KEY="..."
export HELIX_CHAIN_BRIDGE_KEY="..."
export ZEC_SHIELDED_KEY="..."
export ERC4337_BUNDLER_KEY="..."

# --- Akash wallet (optional but required to run akash tx) -------------------
export AKASH_KEY_NAME="yieldswarm"
export AKASH_KEYRING_BACKEND="os"
export AKASH_NODE="https://rpc.akashnet.net:443"
export AKASH_CHAIN_ID="akashnet-2"
export AKASH_WALLET_MNEMONIC="word1 word2 ... word24"

# --- AgentSwarm runtime (optional, exported into Akash containers) ----------
export AGENTSWARM_MASTER_KEY="..."
export KIMICLAW_CONSENSUS_KEY="..."
export GROK_API_KEY="..."
export OPENAI_API_KEY="..."
export GEMINI_API_KEY="..."
export ANTHROPIC_API_KEY="..."
export WALLET_ENCRYPTION_KEY="..."
export TEE_SIGNING_KEY="..."
export DATABASE_ENCRYPTION_KEY="..."

# Seed
./infrastructure/vault/seed-secrets.sh
```

After this runs the following KV v2 paths exist:

```
kv/yieldswarm/infra/azure
kv/yieldswarm/infra/runpod
kv/yieldswarm/infra/vultr
kv/yieldswarm/infra/digitalocean
kv/yieldswarm/rpc
kv/yieldswarm/runtime/akash         (optional)
kv/yieldswarm/runtime/openclaw      (optional)
```

Verify (operator token, not Terraform AppRole):

```bash
vault kv list   kv/yieldswarm
vault kv get    kv/yieldswarm/infra/azure
vault kv get    kv/yieldswarm/rpc
```

Then **`unset`** every secret env var you just exported.

---

## 6. Provision cloud infrastructure with Terraform

Terraform never sees a raw cloud credential. At plan/apply time it logs in to
Vault with the `yieldswarm-terraform` AppRole and reads everything it needs.

### 6.1 One-shot credential exchange

```bash
cd infrastructure/terraform

# role_id is non-sensitive and stable; commit-safe in CI as a secret var.
export TF_VAR_vault_address="https://vault.example.com:8200"
export TF_VAR_vault_role_id="$(vault read -field=role_id \
    auth/approle/role/yieldswarm-terraform/role-id)"

# secret_id is single-use, TTL 10m. Get a fresh one immediately before apply.
export TF_VAR_vault_secret_id="$(vault write -f -field=secret_id \
    auth/approle/role/yieldswarm-terraform/secret-id)"
```

### 6.2 Plan + apply

```bash
terraform init
terraform plan  -out=tfplan
terraform apply tfplan
```

Outputs:

```
azure_resource_group        = "yieldswarm-prod-rg"
azure_key_vault_uri         = "https://yswarm-prod-kv.vault.azure.net/"
digitalocean_droplet_ips    = ["143.x.x.x"]
digitalocean_spaces_endpoint= "nyc3.digitaloceanspaces.com"
runpod_template_id          = "tpl_..."
vultr_instance_ips          = ["45.x.x.x"]
rpc_endpoint_count          = 10
rpc_bundle                  = <sensitive>
```

`rpc_bundle` is never printed; pipe it where you need it:

```bash
terraform output -json rpc_bundle | jq .
```

### 6.3 What the providers consume

| Provider     | Vault path                          | Credentials used                                            |
| ------------ | ----------------------------------- | ----------------------------------------------------------- |
| `azurerm`    | `kv/yieldswarm/infra/azure`         | `subscription_id`, `tenant_id`, `client_id`, `client_secret`|
| `vultr`      | `kv/yieldswarm/infra/vultr`         | `api_key`, `default_region`, `default_plan`, `ssh_key_id`   |
| `digitalocean`| `kv/yieldswarm/infra/digitalocean` | `token`, `spaces_access_key`, `spaces_secret_key`           |
| `restapi`*   | `kv/yieldswarm/infra/runpod`        | `api_key` (sent as `Authorization: Bearer`)                 |
| (consumed)   | `kv/yieldswarm/rpc`                 | All RPC keys; mirrored into Azure Key Vault + DO Spaces     |

*RunPod has no official Terraform provider — we drive its GraphQL endpoint
via the community `Mastercard/restapi` provider with the bearer token from
Vault.*

---

## 7. Build the Akash container

```bash
docker build \
  --tag ghcr.io/yieldswarm/openclaw-akash:$(git rev-parse --short HEAD) \
  --tag ghcr.io/yieldswarm/openclaw-akash:latest \
  --file infrastructure/akash/Dockerfile \
  .

docker push ghcr.io/yieldswarm/openclaw-akash:$(git rev-parse --short HEAD)
docker push ghcr.io/yieldswarm/openclaw-akash:latest
```

The image:

- runs as a non-root user (`yieldswarm`, uid 10001)
- ships only `vault`, `jq`, `tini`, the entrypoint, and the app source
- contains **zero secrets**; everything is fetched at container start

---

## 8. Deploy to Akash with runtime-injected secrets

```bash
# Operator token that can issue secret-ids for yieldswarm-akash.
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="<operator token with secrets-admin policy>"

# Renders /tmp/akash-deploy-XXXXXX.yaml with a fresh wrapped secret_id.
RENDERED="$(infrastructure/akash/render-deploy.sh)"

akash --keyring-backend "$AKASH_KEYRING_BACKEND" \
      --node "$AKASH_NODE" \
      --chain-id "$AKASH_CHAIN_ID" \
      tx deployment create "$RENDERED" \
      --from "$AKASH_KEY_NAME" \
      --gas auto --gas-adjustment 1.4 --gas-prices 0.025uakt -y

# As soon as `akash tx deployment create` returns, the wrapped token has been
# consumed inside the container. Even if `RENDERED` leaked from /tmp, the
# secret_id is dead.
shred -u "$RENDERED"
```

Inside the container, `/usr/local/bin/entrypoint.sh`:

1. Unwraps `VAULT_WRAPPING_TOKEN` → real `secret_id`
2. AppRole-logs-in with `VAULT_ROLE_ID` + `secret_id` → client token
3. Reads three KV v2 paths and exports each key as an env var:
   - `kv/yieldswarm/runtime/openclaw` → e.g. `OPENAI_API_KEY`, `GROK_API_KEY`
   - `kv/yieldswarm/rpc` → prefixed `RPC_*`, e.g. `RPC_SOLANA_RPC_URL`
   - `kv/yieldswarm/runtime/akash` → prefixed `AKASH_*`
4. Forks a token-renewer (renews every TTL/2; periodic token never expires)
5. `trap`s SIGTERM/SIGINT → revokes its own token before exit
6. `exec`s the workload (`APP_CMD` or `CMD` args)

---

## 9. Day-2 operations

### Rotate a single secret

```bash
vault kv patch kv/yieldswarm/infra/runpod api_key="rpa_new..."
```

KV v2 keeps every version; Terraform picks up the change on next `apply`.
Container workloads pick it up on their next restart (or via a sidecar
templating loop — see §10).

### Rotate the wallet transit key

```bash
vault write -f transit/keys/yieldswarm-wallets/rotate
```

Old ciphertext stays decryptable (older `min_decryption_version`); new
encrypts use the latest version automatically.

### Re-issue a wrapped secret_id (e.g. expired)

```bash
VAULT_WRAP_TTL=300 vault write -f -wrap-ttl=300 \
  auth/approle/role/yieldswarm-akash/secret-id
```

### Revoke a leaked AppRole secret_id

```bash
vault write auth/approle/role/yieldswarm-akash/secret-id-accessor/destroy \
  secret_id_accessor=<accessor>
```

### Tail the audit log

```bash
tail -F /var/log/vault/audit.log | jq 'select(.request.path | startswith("kv/data/yieldswarm"))'
```

---

## 10. Optional: Vault Agent sidecar for hot-reload

For long-running services that should pick up rotated secrets *without* a
container restart, run `vault agent` as a sidecar with a `template` block
rendering to a tmpfs file, plus `command` to signal the workload (e.g.
`SIGHUP`). The cloud-init in `templates/cloud-init-agent.sh.tftpl` already
installs the agent on Vultr/DO nodes; adapt the same `agent.hcl` into an
Akash sidecar service if you need it.

---

## 11. Security guarantees

- **No secret in git.** `.gitignore` blocks `*.tfvars`, `*.tfstate*`,
  rendered SDLs, and any `secret-id*` file.
- **No secret in image.** Dockerfile has no `ARG`/`ENV` carrying credentials.
- **No secret in Terraform state.** All `vault_kv_secret_v2` lookups produce
  values that are marked sensitive; `rpc_bundle` output is `sensitive = true`;
  state should be stored on encrypted backend (`backend "azurerm"` example in
  `versions.tf`).
- **No long-lived tokens.** Terraform AppRole tokens cap at 1h, secret_ids at
  10m single-use. Akash tokens are 24h periodic, secret_ids 1h single-use and
  delivered response-wrapped.
- **Defense in depth.** Each policy explicitly denies `sys/*` and unrelated
  KV paths; `ci-writer` cannot read `runtime/*`; `akash-runtime` cannot list
  AppRoles.
- **Auditable.** Every read/write hits the file + syslog audit devices.

---

## 12. Quick troubleshooting

| Symptom                                       | Likely cause                                | Fix |
| --------------------------------------------- | ------------------------------------------- | --- |
| `permission denied` from terraform on apply   | secret_id consumed / expired                | Re-issue: `vault write -f auth/approle/role/yieldswarm-terraform/secret-id` |
| Container loops with "failed to unwrap"       | Wrapping token already consumed / TTL hit   | Re-render SDL via `render-deploy.sh`, redeploy |
| `azurerm` errors with `AuthorizationFailed`   | `client_secret` rotated in IdP but not Vault| `vault kv patch kv/yieldswarm/infra/azure client_secret=...` |
| `restapi.runpod` 401                          | RunPod key rotated                          | `vault kv patch kv/yieldswarm/infra/runpod api_key=...` |
| Terraform `rpc_bundle` empty                  | Seeder skipped optional keys                | Re-run `seed-secrets.sh` with missing exports |

---

## 13. Reference

- Policies: `infrastructure/vault/policies/`
- Bootstrap: `infrastructure/vault/setup.sh`
- Seeder: `infrastructure/vault/seed-secrets.sh`
- Terraform root module: `infrastructure/terraform/`
- Akash image + SDL: `infrastructure/akash/`
