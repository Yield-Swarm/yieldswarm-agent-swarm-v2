# Secrets Management — YieldSwarm AgentSwarm OS

This guide is the operational runbook for the **HashiCorp Vault** integration
that backs every secret used by Terraform (Azure / RunPod / Vultr /
DigitalOcean / RPC) and by the Akash runtime workload.

**Hard rules:**
1. Plaintext secrets live in exactly one place: HashiCorp Vault.
2. Terraform reads secrets from Vault at plan time via AppRole.
3. The Akash workload pulls secrets at **runtime** via `vault-agent` — nothing
   is baked into the image, the SDL, or any Akash-side env.
4. AppRole `secret_id`s are issued **response-wrapped** and are one-shot.
5. Audit logging is on from minute zero.

Repository layout that implements those rules:

```
vault/
  policies/        # admin.hcl, terraform.hcl, ci.hcl, akash-runtime.hcl
  scripts/         # bootstrap.sh, seed-secrets.sh, issue-secret-id.sh
terraform/
  modules/         # vault-secrets, azure, runpod, vultr, digitalocean, rpc
  envs/prod/       # backend.hcl + terraform.tfvars.example
akash/
  Dockerfile       # multi-stage; bundles vault binary, runs as non-root
  entrypoint.sh    # unwraps secret_id, launches vault-agent, execs app
  vault-agent/     # config.hcl + templates/env.ctmpl
  deploy.yaml      # SDL — secrets injected via deploy-time --env, never inlined
```

---

## 0. Prerequisites

On the **operator workstation** (the person running bootstrap and Terraform):

```bash
# Vault CLI ≥ 1.17, Terraform ≥ 1.6, jq, akash provider-services
vault   --version
terraform version
jq      --version
provider-services version    # for deploying to Akash
```

On the **Vault server**:
* Vault Enterprise or OSS ≥ 1.17, initialised and unsealed.
* TLS enabled (do not run production over `http://`).
* A break-glass admin token available for the bootstrap step (this is the only
  time a long-lived token is used; revoke or reduce it immediately after).

Set once per shell session:

```bash
export VAULT_ADDR="https://vault.yieldswarm.internal:8200"
export VAULT_TOKEN="<break-glass admin token>"        # ONLY for bootstrap
vault token lookup >/dev/null                          # sanity check
```

---

## 1. Bootstrap Vault (one time)

This enables audit logging, the KV-v2 and transit secrets engines, the AppRole
auth method, and writes all four ACL policies. It is **idempotent** — safe to
re-run after policy edits.

```bash
./vault/scripts/bootstrap.sh
```

Expected output ends with the role IDs for the three AppRoles
(`terraform`, `ci`, `akash-runtime`). Role IDs are **not secret** on their own;
record them in your config management of choice (e.g. 1Password operator vault,
GitHub Actions Variables — NOT Secrets).

Verify:

```bash
vault secrets list        | grep -E '^(yieldswarm|transit)/'
vault auth list           | grep '^approle/'
vault policy list         | grep -E '^(admin|terraform|ci|akash-runtime)$'
vault audit list          | grep '^file/'
```

### 1a. Reduce the break-glass token

After bootstrap, revoke or shorten the admin token. Recommended:

```bash
# Option A — revoke the token you used.
vault token revoke -self

# Option B — keep it but constrain it to a short TTL behind a hardware key.
vault write auth/token/roles/break-glass \
    allowed_policies=admin orphan=true token_period=1h
```

---

## 2. Seed provider + runtime secrets

`seed-secrets.sh` reads from your shell environment and writes to KV-v2. It
**only** writes paths whose env vars are set, so partial runs are safe.

Stage the values into the current shell **without writing them to disk or
history**:

```bash
# Disable history for this shell so secrets don't end up in ~/.bash_history.
set +o history    # bash
# Or in zsh: setopt HIST_IGNORE_SPACE  and prefix every export with a space.

# --- Cloud providers (consumed by Terraform) ---
read -rs -p "AZURE_CLIENT_ID: "       AZURE_CLIENT_ID;       echo; export AZURE_CLIENT_ID
read -rs -p "AZURE_CLIENT_SECRET: "   AZURE_CLIENT_SECRET;   echo; export AZURE_CLIENT_SECRET
read -rs -p "AZURE_TENANT_ID: "       AZURE_TENANT_ID;       echo; export AZURE_TENANT_ID
read -rs -p "AZURE_SUBSCRIPTION_ID: " AZURE_SUBSCRIPTION_ID; echo; export AZURE_SUBSCRIPTION_ID
read -rs -p "RUNPOD_API_KEY: "        RUNPOD_API_KEY;        echo; export RUNPOD_API_KEY
read -rs -p "VULTR_API_KEY: "         VULTR_API_KEY;         echo; export VULTR_API_KEY
read -rs -p "DIGITALOCEAN_TOKEN: "    DIGITALOCEAN_TOKEN;    echo; export DIGITALOCEAN_TOKEN

# --- RPC endpoints ---
read -rs -p "SOLANA_RPC_URL: "        SOLANA_RPC_URL;        echo; export SOLANA_RPC_URL
read -rs -p "HELIUS_API_KEY: "        HELIUS_API_KEY;        echo; export HELIUS_API_KEY
read -rs -p "BIRDEYE_API_KEY: "       BIRDEYE_API_KEY;       echo; export BIRDEYE_API_KEY
read -rs -p "JUPITER_API_KEY: "       JUPITER_API_KEY;       echo; export JUPITER_API_KEY

# --- Runtime / LLM / wallets (consumed by the Akash workload) ---
read -rs -p "AGENTSWARM_MASTER_KEY: " AGENTSWARM_MASTER_KEY; echo; export AGENTSWARM_MASTER_KEY
read -rs -p "OPENAI_API_KEY: "        OPENAI_API_KEY;        echo; export OPENAI_API_KEY
read -rs -p "ANTHROPIC_API_KEY: "     ANTHROPIC_API_KEY;     echo; export ANTHROPIC_API_KEY
read -rs -p "WALLET_ENCRYPTION_KEY: " WALLET_ENCRYPTION_KEY; echo; export WALLET_ENCRYPTION_KEY
# …repeat for every secret you intend to store; the script silently skips
#   anything that isn't set.

./vault/scripts/seed-secrets.sh

# Wipe the variables from this shell.
unset AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID \
      RUNPOD_API_KEY VULTR_API_KEY DIGITALOCEAN_TOKEN \
      SOLANA_RPC_URL HELIUS_API_KEY BIRDEYE_API_KEY JUPITER_API_KEY \
      AGENTSWARM_MASTER_KEY OPENAI_API_KEY ANTHROPIC_API_KEY WALLET_ENCRYPTION_KEY
set -o history
```

Verify (the `--field` flag prevents accidental dumping of values to TTY):

```bash
vault kv get -field=client_id yieldswarm/providers/azure        >/dev/null && echo OK
vault kv get -field=api_key   yieldswarm/providers/runpod       >/dev/null && echo OK
vault kv get -field=api_key   yieldswarm/providers/vultr        >/dev/null && echo OK
vault kv get -field=token     yieldswarm/providers/digitalocean >/dev/null && echo OK
vault kv get -field=url       yieldswarm/rpc/solana             >/dev/null && echo OK
```

---

## 3. Issue AppRole Secret IDs

`role_id` is non-secret. `secret_id` is the credential — always issue it
**response-wrapped**.

### 3a. For the operator running Terraform locally

```bash
# 5-minute wrap TTL, single-use. Eval pulls VAULT_ROLE_ID + VAULT_SECRET_ID_WRAP_TOKEN
# into the current shell without ever touching disk.
eval "$(./vault/scripts/issue-secret-id.sh terraform 5m)"

# Unwrap now (consumes the wrap token).
export TF_VAR_vault_role_id="$VAULT_ROLE_ID"
export TF_VAR_vault_secret_id="$(vault unwrap -field=secret_id "$VAULT_SECRET_ID_WRAP_TOKEN")"
unset VAULT_SECRET_ID_WRAP_TOKEN
```

### 3b. For CI (GitHub Actions / GitLab CI)

A short-lived runner (≤ 1 h) needs its own wrap token per job. A small
helper service (or a manual operator step) calls
`issue-secret-id.sh ci 15m` and posts the resulting wrap token into the job's
**masked** secret store. The CI job then runs:

```yaml
# .github/workflows/terraform.yml (excerpt)
- name: Resolve Vault credentials
  env:
    VAULT_ADDR: ${{ vars.VAULT_ADDR }}
    VAULT_ROLE_ID: ${{ vars.VAULT_ROLE_ID_CI }}          # non-secret Variable
    VAULT_WRAP_TOKEN: ${{ secrets.VAULT_WRAP_TOKEN_CI }}  # one-shot Secret
  run: |
    set -euo pipefail
    SECRET_ID="$(vault unwrap -field=secret_id "$VAULT_WRAP_TOKEN")"
    echo "::add-mask::$SECRET_ID"
    echo "TF_VAR_vault_addr=$VAULT_ADDR"           >> "$GITHUB_ENV"
    echo "TF_VAR_vault_role_id=$VAULT_ROLE_ID"     >> "$GITHUB_ENV"
    echo "TF_VAR_vault_secret_id=$SECRET_ID"       >> "$GITHUB_ENV"
```

The wrap token is dead after one unwrap; rotate `VAULT_WRAP_TOKEN_CI`
on every workflow run via a scheduled job that calls `issue-secret-id.sh`.

### 3c. For the Akash deployment

```bash
eval "$(./vault/scripts/issue-secret-id.sh akash-runtime 10m)"
# VAULT_ROLE_ID + VAULT_SECRET_ID_WRAP_TOKEN are now in the shell.
# Pass them to provider-services as --env (see §5). The container unwraps
# the wrap token inside entrypoint.sh; the operator never unwraps it.
```

---

## 4. Run Terraform

State holds Vault-sourced values — pick an encrypted backend before the
first `init`. The repo ships an Azure Storage backend pre-wired in
`terraform/backend.tf` with environment-specific values in
`terraform/envs/<env>/backend.hcl`.

```bash
cd terraform
cp envs/prod/terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: vault_addr, vault_role_id, regions, RG name.
# Do NOT put vault_secret_id in this file.

terraform init -backend-config=envs/prod/backend.hcl

# vault_role_id + vault_secret_id come from §3a above.
terraform validate
terraform plan  -out=tfplan
terraform apply tfplan
```

What this does, end-to-end:

1. Vault provider logs in with `(role_id, secret_id)` → short-lived token.
2. `module.vault_secrets` reads four KV paths + one per RPC chain.
3. Outputs are piped (sensitive) into `module.azure`, `module.runpod`, etc.
4. Each provider module validates the credentials live (RunPod via GraphQL,
   Vultr via account read, DigitalOcean via region list).
5. Plan fails loudly if any required secret is missing or any provider
   rejects the credential.

To disable a provider in a given run (e.g. for an incident response with
narrow blast radius), pass `-var enable_runpod=false` (or any of
`enable_azure`, `enable_vultr`, `enable_digitalocean`).

---

## 5. Deploy to Akash

Build and publish the image:

```bash
docker build -t ghcr.io/yieldswarm/agent-runtime:2.0.0 akash/
docker push  ghcr.io/yieldswarm/agent-runtime:2.0.0

# Replace the :tag@sha256:... pin in akash/deploy.yaml with the published digest.
DIGEST="$(docker buildx imagetools inspect ghcr.io/yieldswarm/agent-runtime:2.0.0 \
            --format '{{json .Manifest.Digest}}' | tr -d '"')"
sed -i "s|REPLACE_WITH_PUBLISHED_DIGEST|${DIGEST#sha256:}|" akash/deploy.yaml
```

Issue a fresh wrap token and deploy:

```bash
eval "$(./vault/scripts/issue-secret-id.sh akash-runtime 10m)"

provider-services tx deployment create akash/deploy.yaml \
    --from "$AKASH_KEY_NAME" \
    --gas-prices 0.025uakt --gas auto --gas-adjustment 1.4 \
    --env "VAULT_ADDR=https://vault.yieldswarm.io:8200" \
    --env "VAULT_ROLE_ID=$VAULT_ROLE_ID" \
    --env "VAULT_SECRET_ID_WRAP_TOKEN=$VAULT_SECRET_ID_WRAP_TOKEN"

unset VAULT_ROLE_ID VAULT_SECRET_ID_WRAP_TOKEN
```

Inside the container, `entrypoint.sh`:
1. Validates the env vars.
2. Calls `vault unwrap` once on the wrap token (it's now dead).
3. Writes `role_id` + `secret_id` to mode-0400 tmpfs files.
4. Launches `vault agent` (auto-auth AppRole) as the non-root `yieldswarm` user.
5. Vault Agent renders `/run/secrets/env` from
   `vault-agent/templates/env.ctmpl`, then deletes the secret_id file
   (`remove_secret_id_file_after_reading = true`).
6. Entrypoint `source`s `/run/secrets/env` and execs the app. The app sees the
   secrets as environment variables and never talks to Vault directly.
7. Healthcheck `test -s /run/secrets/env || exit 1` ensures Akash restarts the
   pod if rendering ever fails.

To verify a live deployment without leaking values:

```bash
provider-services lease-status -d $DSEQ --provider $PROVIDER
# ...then hit /healthz on the exposed URI — it returns presence flags, never values.
curl -sS https://api.yieldswarm.io/healthz | jq
```

---

## 6. Rotation

| What                        | How                                                            | Frequency        |
|-----------------------------|----------------------------------------------------------------|------------------|
| AppRole `secret_id` (any)   | `vault write -f auth/approle/role/<r>/secret-id` (or script)   | Per deploy / 24h |
| KV provider secret          | `vault kv put yieldswarm/providers/<p> <k>=<v>`                | Per provider SLA |
| Transit `wallet` key        | `vault write -f transit/keys/wallet/rotate`                    | Quarterly        |
| Vault root/break-glass      | `vault operator rekey` (Shamir) + `vault token revoke -self`   | Quarterly        |
| Container image             | Rebuild + repush + bump pinned digest in `akash/deploy.yaml`   | Per CVE / monthly|

Rotating a KV value is a hot-swap for the Akash workload: vault-agent watches
KV versions and re-renders `/run/secrets/env`; the post-render command sends
`SIGHUP` to PID 1 so the app can reload (or, if it doesn't, the next pod
restart picks it up automatically).

---

## 7. Threat model & guarantees

| Threat                                          | Mitigation                                                    |
|-------------------------------------------------|---------------------------------------------------------------|
| Long-lived static credentials in CI             | AppRole + one-shot wrap tokens; CI token TTL ≤ 1 h.           |
| Secrets baked into Docker image                 | Multi-stage build; secrets only enter via vault-agent render. |
| Secrets in Akash SDL or chain history           | Only the wrap token is on the deployment env, single-use.     |
| Compromised wrap token in transit               | TTL ≤ 10 min, single-use; the unwrap call burns it.           |
| State file leakage                              | Backend pinned to encrypted storage; `terraform.tfvars` git-ignored. |
| Shell history exfiltration                      | `read -rs` + `set +o history` flow in §2.                     |
| Operator pivot via stolen Vault token           | All consumer policies are read-only over their narrow path.   |
| Vault outage at deploy time                     | Healthcheck fails the pod; Akash retries; no fallback to file.|
| Bit-rot of audit trail                          | `audit enable file` enforced by bootstrap; verify in §1.      |

---

## 8. Troubleshooting

```bash
# vault-agent failing to auth?
provider-services logs -d $DSEQ --provider $PROVIDER yieldswarm
# Look for "missing client token" -> wrap token already used / expired.
# Re-issue with: eval "$(./vault/scripts/issue-secret-id.sh akash-runtime 10m)"
# then redeploy.

# Terraform plan refusing with "Azure credentials are incomplete"?
vault kv get yieldswarm/providers/azure
# Re-seed the missing fields via §2.

# RunPod plan-time verification failing?
# - confirm the key with: curl -H "Authorization: Bearer <KEY>" -d '{"query":"{myself{id}}"}' https://api.runpod.io/graphql
# - rotate it: vault kv patch yieldswarm/providers/runpod api_key=<NEW>

# Health endpoint says a required secret is missing?
curl -sS https://api.yieldswarm.io/healthz | jq '.required'
# Find the missing key, check the matching template line in
# akash/vault-agent/templates/env.ctmpl, then `vault kv get` the corresponding
# yieldswarm/runtime/* path.
```

---

## 9. Future hardening — ephemeral values (TF ≥ 1.10, vault provider ≥ 5)

`terraform validate` emits a deprecation warning recommending the new
**ephemeral** `vault_kv_secret_v2` resource over the data source. Ephemeral
values never enter `terraform.tfstate`. Migration path when the team bumps
`required_version` to `>= 1.10`:

1. Replace each `data "vault_kv_secret_v2" "X"` in
   `terraform/modules/vault-secrets/main.tf` with `ephemeral "vault_kv_secret_v2" "X"`.
2. Mark every module output that surfaces an ephemeral value with
   `ephemeral = true`. Downstream consumers (provider configurations) already
   accept ephemeral inputs.
3. Where a resource attribute supports a `_wo` write-only variant
   (e.g. `vault_approle_auth_backend_login.secret_id_wo`), prefer it.

Until then, the existing data-source path is fully supported and the warning
is informational.

---

## 10. What lives where (cheat sheet)

| Secret                                    | Vault path                                 | Consumed by              |
|-------------------------------------------|--------------------------------------------|--------------------------|
| Azure SP                                  | `yieldswarm/providers/azure`               | terraform `module.azure` |
| RunPod API key                            | `yieldswarm/providers/runpod`              | terraform `module.runpod`|
| Vultr API key                             | `yieldswarm/providers/vultr`               | terraform `module.vultr` |
| DigitalOcean token + Spaces               | `yieldswarm/providers/digitalocean`        | terraform `module.digitalocean` |
| RPC endpoints + chain API keys            | `yieldswarm/rpc/{solana,ethereum,ton,…}`   | terraform `module.rpc` + Akash runtime |
| Master / consensus / DB encryption keys   | `yieldswarm/runtime/core`                  | Akash runtime            |
| LLM provider keys                         | `yieldswarm/runtime/llm`                   | Akash runtime            |
| Wallet / signing keys                     | `yieldswarm/runtime/wallets`               | Akash runtime            |
| GitHub / Vercel / Notion / Linear / TG / UD | `yieldswarm/integrations/<svc>`          | Akash runtime            |

No secret ever exists in:
* `.env.example` — only placeholder names live there for documentation.
* `akash/deploy.yaml` — only references to env vars, never values.
* `terraform/**/*.tf` — only `data.vault_kv_secret_v2.*` reads.
* Container image layers — verify with `dive ghcr.io/yieldswarm/agent-runtime:2.0.0`.
