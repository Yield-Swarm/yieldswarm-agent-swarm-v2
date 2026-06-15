# =============================================================================
# Policy: terraform-deploy
# -----------------------------------------------------------------------------
# Granted to the Terraform CI runner via AppRole. Read-only on infra secrets
# (Azure / RunPod / Vultr / DigitalOcean / RPC) so a compromised CI cannot
# rewrite production credentials, plus the ability to write Terraform state
# back into Vault's KV mount under `tfstate/`.
# =============================================================================

# --- Read-only: infrastructure provider credentials ---
path "yieldswarm/data/infra/azure" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/infra/azure" {
  capabilities = ["read", "list"]
}

path "yieldswarm/data/infra/runpod" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/infra/runpod" {
  capabilities = ["read", "list"]
}

path "yieldswarm/data/infra/vultr" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/infra/vultr" {
  capabilities = ["read", "list"]
}

path "yieldswarm/data/infra/digitalocean" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/infra/digitalocean" {
  capabilities = ["read", "list"]
}

# --- Read-only: every RPC endpoint we wire into Terraform ---
path "yieldswarm/data/rpc/*" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/rpc/*" {
  capabilities = ["read", "list"]
}

# --- Terraform remote state (optional, encrypted-at-rest via Vault) ---
path "yieldswarm/data/tfstate/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "yieldswarm/metadata/tfstate/*" {
  capabilities = ["read", "list", "delete"]
}

# --- Transit: sign Terraform plan artifacts so prod apply can verify them ---
path "transit/sign/terraform-ci" {
  capabilities = ["update"]
}

path "transit/verify/terraform-ci" {
  capabilities = ["update"]
}

# --- Token hygiene ---
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# NOTE on writes: this policy intentionally does NOT grant create/update/patch
# on yieldswarm/data/infra/*. Rotation of provider credentials is performed by
# the dedicated `secrets-rotator` policy, never by the Terraform CI principal.
# Vault policies are pure allow-lists, so omission == deny.

