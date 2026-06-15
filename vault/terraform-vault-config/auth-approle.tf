# =========================================================================
# AppRole auth backend and one role per workload.
# SecretIDs are NOT created by Terraform - they are minted on demand by
# ci-bootstrap, response-wrapped, and one-shot.
# =========================================================================

resource "vault_auth_backend" "approle" {
  type        = "approle"
  description = "AppRole auth for non-human identities (CI, Akash, agents, terraform)."
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend            = vault_auth_backend.approle.path
  role_name          = "terraform"
  token_policies     = [vault_policy.managed["terraform"].name]
  token_ttl          = 1800 # 30m
  token_max_ttl      = 7200 # 2h
  secret_id_ttl      = 600  # 10m
  secret_id_num_uses = 1
  bind_secret_id     = true
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend               = vault_auth_backend.approle.path
  role_name             = "akash-runtime"
  token_policies        = [vault_policy.managed["akash-runtime"].name]
  token_ttl             = 3600  # 1h
  token_max_ttl         = 86400 # 24h
  secret_id_ttl         = 1800  # 30m
  secret_id_num_uses    = 1
  bind_secret_id        = true
  secret_id_bound_cidrs = var.akash_egress_cidrs
  token_bound_cidrs     = var.akash_egress_cidrs
}

resource "vault_approle_auth_backend_role" "agent_runtime" {
  backend            = vault_auth_backend.approle.path
  role_name          = "agent-runtime"
  token_policies     = [vault_policy.managed["agent-runtime"].name]
  token_ttl          = 14400  # 4h
  token_max_ttl      = 259200 # 72h
  secret_id_ttl      = 3600   # 1h
  secret_id_num_uses = 1
  bind_secret_id     = true
  token_bound_cidrs  = var.agent_runtime_cidrs
}

resource "vault_approle_auth_backend_role" "ci_bootstrap" {
  backend               = vault_auth_backend.approle.path
  role_name             = "ci-bootstrap"
  token_policies        = [vault_policy.managed["ci-bootstrap"].name]
  token_ttl             = 900  # 15m
  token_max_ttl         = 1800 # 30m
  secret_id_ttl         = 300  # 5m
  secret_id_num_uses    = 1
  bind_secret_id        = true
  secret_id_bound_cidrs = var.ci_egress_cidrs
  token_bound_cidrs     = var.ci_egress_cidrs
}
