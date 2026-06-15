# =========================================================================
# Optional OIDC backend for human admin auth. Gated by var.enable_oidc so
# the module is usable in dev environments without an IdP.
# =========================================================================

resource "vault_jwt_auth_backend" "oidc" {
  count              = var.enable_oidc ? 1 : 0
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = var.oidc.discovery_url
  oidc_client_id     = var.oidc.client_id
  oidc_client_secret = var.oidc.client_secret
  default_role       = "admin"
  tune {
    default_lease_ttl  = "1h"
    max_lease_ttl      = "8h"
    listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "admin" {
  count                 = var.enable_oidc ? 1 : 0
  backend               = vault_jwt_auth_backend.oidc[0].path
  role_name             = "admin"
  role_type             = "oidc"
  user_claim            = "sub"
  bound_audiences       = [var.oidc.client_id]
  allowed_redirect_uris = var.oidc.allowed_redirect
  token_policies        = [vault_policy.managed["admin"].name]
  token_ttl             = 3600
  token_max_ttl         = 28800
  groups_claim          = "groups"
  bound_claims = {
    groups = var.oidc.admin_group
  }
}
