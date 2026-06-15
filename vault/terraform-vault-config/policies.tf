# =========================================================================
# Push every HCL file under ../policies into Vault as a managed policy.
# The policy bodies live in source control so this stays GitOps-friendly.
# =========================================================================

locals {
  policy_files = fileset("${path.module}/../policies", "*.hcl")
  policies = {
    for f in local.policy_files :
    trimsuffix(f, ".hcl") => file("${path.module}/../policies/${f}")
  }
}

resource "vault_policy" "managed" {
  for_each = local.policies
  name     = each.key
  policy   = each.value
}
