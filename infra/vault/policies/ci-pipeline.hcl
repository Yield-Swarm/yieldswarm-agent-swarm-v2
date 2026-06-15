# =============================================================================
# Policy: ci-pipeline
# -----------------------------------------------------------------------------
# For GitHub Actions / Vercel build hooks. Strictly limited to *build-time*
# secrets (npm tokens, container registry creds, deployment webhooks). Has NO
# access to runtime or infra credentials.
# =============================================================================

path "yieldswarm/data/build/*" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/build/*" {
  capabilities = ["read", "list"]
}

# Sign image manifests so prod can verify provenance.
path "transit/sign/ci-image-signing" {
  capabilities = ["update"]
}

path "transit/verify/ci-image-signing" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
