# YieldSwarm — Secrets Management Runbook

This document is the **single source of truth** for how secrets flow
through the YieldSwarm AgentSwarm OS. If a procedure isn't documented
here, it isn't approved.

```
┌─────────────────┐    AppRole (wrap_ttl=60s)    ┌──────────────────────┐
│ Operator/CI     │ ───────────────────────────▶ │ HashiCorp Vault      │
│ (admin token)   │  ◀─── role_id + wrap token ─ │  KV v2 + Transit     │
└─────────────────┘                              └──────────┬───────────┘
        │                                                   │ (read-only)
        │ provider-services tx deployment create            │
        ▼                                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Akash provider → container (entrypoint.sh)                             │
│   1. unwrap secret_id   2. AppRole login   3. kv get   4. exec child   │
│   5. background token renewer   6. SIGTERM ⇒ revoke + clean shutdown   │
└────────────────────────────────────────────────────────────────────────┘

        Terraform CI pipeline (parallel path)
┌─────────────────┐    AppRole (wrap_ttl=60s)    ┌──────────────────────┐
│ CI runner       │ ───────────────────────────▶ │ Vault                │
│ (ci-pipeline)   │                              └──────────┬───────────┘
└─────────────────┘                                         │
        │ tf-with-vault.sh plan / apply                     │ data sources
        ▼                                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Terraform → Azure / RunPod / Vultr / DigitalOcean / RPC providers      │
└────────────────────────────────────────────────────────────────────────┘
```

## 0. Hard rules

1. **No secret value ever lands in git, in `.env`, in a Docker layer, in
   the Akash SDL after rendering, in CI logs, in `terraform plan`
   output, or in `/proc/<pid>/cmdline`.**
2. Long-lived credentials live **only** inside Vault. Everything else
   (AppRole tokens, secret_ids, Vault tokens) is short-lived and
   auto-rotating.
3. Bootstrap tokens (Vault root, the operator's initial admin token) are
   sealed in a hardware token / 1Password vault and used only for
   policy/engine changes.
4. Every secret read is audited by the Vault file audit device
   (`/var/log/vault/audit.log`).
5. The `terraform-deployer` AppRole cannot read workload runtime
   secrets. The `akash-workload` AppRole cannot read cloud provider
   credentials. This separation is enforced by ACL, not by convention.

## 1. Provision Vault (one-time)

These steps run against a freshly initialised Vault cluster (HA or
single-node, KMS-unsealed). All scripts are idempotent.

### 1.1 Install the CLI

```bash
# Linux x86_64; pin the version that matches your server.
curl -fsSL https://releases.hashicorp.com/vault/1.18.2/vault_1.18.2_linux_amd64.zip \
    -o /tmp/vault.zip
sudo unzip -o /tmp/vault.zip -d /usr/local/bin
vault -version
```

### 1.2 Point at the cluster

```bash
export VAULT_ADDR=https://vault.internal:8200
export VAULT_NAMESPACE=                  # leave empty for Vault OSS
export VAULT_TOKEN=<one-shot admin token from your KMS recovery flow>
```

> Never check `VAULT_TOKEN` into shell history. Use a password manager
> CLI plugin (`op run --env-file=...`, `bw run`, etc.) to inject it.

### 1.3 Run the bootstrap pipeline

```bash
cd infrastructure/vault/bootstrap
./00-bootstrap.sh
```

This applies, in order:

| Script              | What it does                                                       |
|---------------------|--------------------------------------------------------------------|
| `01-engines.sh`     | Enables `kv-v2` at `secret/`, `transit/`, file audit, AppRole auth |
| `02-policies.sh`    | Writes `secrets-admin`, `terraform-deployer`, `akash-workload`, `ci-pipeline` |
| `03-approles.sh`    | Creates the AppRoles with hardened TTLs and (optional) CIDR binds  |

After the first run, immediately tighten the CIDR allow-lists:

```bash
TERRAFORM_CIDR=10.42.0.0/24 AKASH_CIDR=185.234.0.0/16 \
    ./03-approles.sh
```

### 1.4 Verify

```bash
vault secrets list
vault auth list
vault policy list
vault audit list
```

Expected output includes `secret/ (kv, v2)`, `transit/`, `approle/`,
and a `file/` audit device.

## 2. Seed the secret material

The seeder **never** accepts secrets on the command line. Two flows:

### 2.1 Interactive (preferred for first run)

```bash
cd infrastructure/vault/seed
./seed-secrets.sh
```

You'll be prompted for each key. Input is not echoed. Blank values write
empty strings (useful for environments where a provider is unused).

### 2.2 From a sealed envelope file (CI / disaster recovery)

```bash
# secrets.env is a sealed file from your password manager. Decrypt to
# memory using a one-shot pipe; the file never touches disk in plaintext.
op read "op://prod/yieldswarm-vault-seed/notesPlain" > /dev/shm/secrets.env
./seed-secrets.sh --from-env-file /dev/shm/secrets.env
shred -u /dev/shm/secrets.env
```

The schema (and the only paths the seeder will write to) is hard-coded
inside the script and matches the policy files. To add a new bundle,
edit `SCHEMA` in `seed-secrets.sh` **and** the relevant `.hcl` policy.

### 2.3 What secrets go where

| Vault path                                  | Keys (examples)                                                              |
|---------------------------------------------|------------------------------------------------------------------------------|
| `secret/yieldswarm/cloud/azure`             | `client_id`, `client_secret`, `tenant_id`, `subscription_id`                 |
| `secret/yieldswarm/cloud/runpod`            | `api_key`, `org_id`, `default_pod_template`                                  |
| `secret/yieldswarm/cloud/vultr`             | `api_key`, `default_region`                                                  |
| `secret/yieldswarm/cloud/digitalocean`      | `api_token`, `spaces_access_id`, `spaces_secret_key`, `default_region`       |
| `secret/yieldswarm/rpc/solana`              | `primary_url`, `failover_url`, `ws_url`                                      |
| `secret/yieldswarm/rpc/helius`              | `api_key`, `url`                                                             |
| `secret/yieldswarm/rpc/birdeye`             | `api_key`                                                                    |
| `secret/yieldswarm/rpc/jupiter`             | `api_key`                                                                    |
| `secret/yieldswarm/rpc/ethereum`            | `primary_url`, `failover_url`                                                |
| `secret/yieldswarm/akash/deployer`          | `key_name`, `keyring_backend`, `chain_id`, `node_url`, `wallet_mnemonic`     |
| `secret/yieldswarm/runtime/agentswarm`      | `master_key`, `kimiclaw_key`, `wallet_encryption_key`, `tee_signing_key`, ... |
| `secret/yieldswarm/runtime/llm`             | `openai_api_key`, `anthropic_api_key`, `gemini_api_key`, `grok_api_key`      |

## 3. Issue working credentials

### 3.1 For a CI runner (`ci-pipeline` policy)

```bash
# On the Vault control plane:
vault token create \
    -policy=ci-pipeline \
    -ttl=24h -renewable=true \
    -display-name="ci-runner-$(date -u +%Y%m%d)"
```

Inject the resulting token into the CI runner as a masked variable
named `VAULT_TOKEN`. Rotate it every 24h via a cron that re-issues from
a privileged orchestrator.

### 3.2 For local Terraform (operator)

```bash
# From the same shell you bootstrapped from:
export VAULT_TOKEN=<your ci-pipeline token>
cd infrastructure/terraform
./tf-with-vault.sh init
./tf-with-vault.sh plan -out=tfplan
./tf-with-vault.sh apply tfplan
```

`tf-with-vault.sh`:

1. Reads `terraform-deployer/role-id` (non-secret).
2. Mints a fresh `secret_id` (or unwraps `WRAPPED_SECRET_ID` if supplied).
3. Exports `TF_VAR_vault_auth_role_id` / `TF_VAR_vault_auth_secret_id`.
4. **Unsets `VAULT_TOKEN`** before exec-ing Terraform, so Terraform can
   only see the data its `terraform-deployer` policy allows.

### 3.3 For Akash workload (operator → provider)

```bash
export VAULT_ADDR=https://vault.internal:8200
export VAULT_TOKEN=<ci-pipeline token>
export YIELDSWARM_IMAGE=registry.digitalocean.com/yieldswarm-prod/agentswarm:$(git rev-parse --short HEAD)
export AKASH_KEY_NAME=deployer

./infrastructure/akash/deploy.sh
```

`deploy.sh` mints a 60-second response-wrapped `secret_id` and bakes it
into the rendered SDL. The container must boot, unwrap the token, and
exchange it for a workload token within those 60s. The rendered SDL is
shredded immediately after submission.

## 4. Day-2 operations

### 4.1 Rotate a leaf secret (e.g. `helius.api_key`)

```bash
export VAULT_TOKEN=<secrets-admin token>
KEY=$(printf 'new-helius-key-here')      # source from your generator
vault kv patch -mount=secret yieldswarm/rpc/helius api_key="$KEY"
unset KEY
```

Active workloads pick up the new value at next container restart. To
force an immediate rotation:

```bash
provider-services tx deployment close --dseq $DSEQ ...
./infrastructure/akash/deploy.sh
```

### 4.2 Rotate an AppRole secret_id (compromise suspected)

```bash
vault write -f auth/approle/role/akash-workload/secret-id
# All currently-issued secret_ids remain valid until their TTL elapses;
# to revoke all outstanding secret_ids immediately:
for accessor in $(vault list -format=json auth/approle/role/akash-workload/secret-id \
        | jq -r '.[]'); do
    vault write auth/approle/role/akash-workload/secret-id-accessor/destroy \
        secret_id_accessor="$accessor"
done
```

### 4.3 Rotate a Vault policy

Policies are version-controlled under `infrastructure/vault/policies/`.

```bash
cd infrastructure/vault/bootstrap
./02-policies.sh           # re-applies all four policies from disk
```

Existing tokens keep their original policy snapshot until renewed.

### 4.4 Add a new secret bundle

1. Add the path + keys to `SCHEMA` in `seed-secrets.sh`.
2. Grant the appropriate role read access in
   `policies/{terraform-deployer,akash-workload}.hcl`.
3. If consumed by Terraform: add a `data "vault_kv_secret_v2"` block in
   `infrastructure/terraform/vault.tf`.
4. If consumed by Akash workload: add the path to the `BUNDLES` array
   in `infrastructure/akash/docker/entrypoint.sh`.
5. Re-run `./02-policies.sh` and `./seed-secrets.sh`.

### 4.5 Break-glass: rotate the AppRole role_id

This is only needed if the `role_id` itself has been logged in
plaintext somewhere it shouldn't have been.

```bash
NEW=$(uuidgen)
vault write auth/approle/role/akash-workload/role-id role_id="$NEW"
# Re-deploy any consumers; they will need the new role_id baked in.
```

### 4.6 Audit log forwarding

The bootstrap enables a `file` audit device at `/var/log/vault/audit.log`
with HMAC accessor masking. In production you should also enable a
secondary `syslog` or `socket` device pointed at your SIEM:

```bash
vault audit enable -path=siem socket address=logs.internal:6514 socket_type=tcp
```

Never disable the `file/` device — Vault refuses to serve requests if
all enabled audit devices fail to write.

## 5. CI integration cheat-sheet

### 5.1 GitHub Actions

```yaml
jobs:
  terraform:
    runs-on: self-hosted-vault-network
    env:
      VAULT_ADDR: https://vault.internal:8200
      VAULT_TOKEN: ${{ secrets.VAULT_CI_TOKEN }}      # ci-pipeline policy
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with: { terraform_version: 1.9.5 }
      - run: |
          curl -fsSL https://releases.hashicorp.com/vault/1.18.2/vault_1.18.2_linux_amd64.zip -o vault.zip
          sudo unzip -o vault.zip -d /usr/local/bin
      - run: ./infrastructure/terraform/tf-with-vault.sh init
      - run: ./infrastructure/terraform/tf-with-vault.sh plan -out=tfplan
      - if: github.ref == 'refs/heads/main'
        run: ./infrastructure/terraform/tf-with-vault.sh apply -auto-approve tfplan
```

`VAULT_CI_TOKEN` is rotated daily by a workflow that re-runs
`vault token create -policy=ci-pipeline -ttl=24h` from a privileged
orchestrator and updates the GitHub secret via the REST API.

### 5.2 Required secret store entries

The only secrets your CI provider holds are:

| Name                  | Value                                            |
|-----------------------|--------------------------------------------------|
| `VAULT_CI_TOKEN`      | Token with the `ci-pipeline` policy (24h TTL)    |
| `AKASH_KEY_MNEMONIC`  | Akash deployer wallet mnemonic (only on deploy job) |
| `IMAGE_REGISTRY_PAT`  | Push token for the container registry            |

Everything else is fetched from Vault at run time.

## 6. Disaster recovery

| Scenario                              | Mitigation                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Vault unreachable from CI             | Terraform `plan`/`apply` aborts at `auth_login`. No partial provisioning occurs because every provider sources credentials from `local.*` which require successful KV reads.                                                                                                                                                                                                                                                                            |
| Vault unreachable from Akash container| `entrypoint.sh` waits `VAULT_BOOTSTRAP_TIMEOUT` seconds (default 30, override in SDL) then exits non-zero. Akash provider restarts the container; back-off avoids tight loops.                                                                                                                                                                                                                                                                          |
| `VAULT_TOKEN` leak (any role)         | `vault token revoke <accessor>` from the secrets-admin token. All downstream secrets are unreadable; provisioning halts within one minute. Rotate the underlying KV values whose access timestamp falls inside the exposure window.                                                                                                                                                                                                                     |
| Audit log tampering                   | Vault refuses to serve if any enabled audit device fails to write. Forward to an append-only SIEM (`socket` device) so a local-file delete does not silence the trail.                                                                                                                                                                                                                                                                                  |
| Loss of root token                    | Re-key Vault via the operator's KMS recovery shares. Re-run `00-bootstrap.sh`; it is idempotent and will not damage existing data.                                                                                                                                                                                                                                                                                                                      |

## 7. Quick verification checklist

Run this after every change to the secrets layer:

```bash
# 1. Policies match what's on disk.
diff <(vault policy read terraform-deployer)  infrastructure/vault/policies/terraform-deployer.hcl
diff <(vault policy read akash-workload)      infrastructure/vault/policies/akash-workload.hcl

# 2. AppRoles still enforce short TTLs.
vault read -format=json auth/approle/role/terraform-deployer \
    | jq '{token_ttl, token_max_ttl, secret_id_ttl, secret_id_bound_cidrs}'

# 3. Terraform can auth and read.
./infrastructure/terraform/tf-with-vault.sh plan -refresh-only

# 4. Akash entrypoint smoke-test (locally).
docker run --rm -it \
    -e VAULT_ADDR=https://vault.internal:8200 \
    -e VAULT_ROLE_ID="$(vault read -field=role_id auth/approle/role/akash-workload/role-id)" \
    -e VAULT_WRAPPED_SECRET_ID="$(vault write -wrap-ttl=60s -force \
        -field=wrapping_token auth/approle/role/akash-workload/secret-id)" \
    yieldswarm/agentswarm:latest /bin/true
```

If any of those four steps fails, **do not promote the change**.

---

Maintainer: Platform / Security team.  
For an architecture overview see `infrastructure/vault/README.md` and
`infrastructure/akash/README.md`.
