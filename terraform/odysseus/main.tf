locals {
  runtime_metadata_path = replace(var.runtime_secret_path, "/data/", "/metadata/")
  deploy_metadata_path  = replace(var.deploy_secret_path, "/data/", "/metadata/")
}

resource "vault_policy" "odysseus_runtime" {
  name = var.runtime_policy_name

  policy = <<-EOT
    path "${var.runtime_secret_path}" {
      capabilities = ["read"]
    }

    path "${local.runtime_metadata_path}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_policy" "odysseus_deploy" {
  name = var.deploy_policy_name

  policy = <<-EOT
    path "${var.deploy_secret_path}" {
      capabilities = ["read"]
    }

    path "${local.deploy_metadata_path}" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_jwt_auth_backend_role" "github_actions" {
  count = var.configure_github_actions_role ? 1 : 0

  backend        = var.github_jwt_auth_backend
  role_name      = var.github_jwt_role
  role_type      = "jwt"
  token_policies = [
    vault_policy.odysseus_deploy.name,
    vault_policy.odysseus_runtime.name,
  ]
  token_ttl      = 900

  bound_audiences = [var.github_jwt_audience]
  bound_claims_type = "glob"
  bound_claims = {
    repository = var.github_repository
    ref        = "refs/*"
  }
  user_claim = "actor"
}

resource "vault_jwt_auth_backend_role" "runtime" {
  count = var.configure_runtime_jwt_role ? 1 : 0

  backend        = var.runtime_jwt_auth_backend
  role_name      = var.runtime_jwt_role
  role_type      = "jwt"
  token_policies = [vault_policy.odysseus_runtime.name]
  token_ttl      = 1800

  bound_audiences = [var.runtime_jwt_audience]
  bound_subject   = var.runtime_bound_subject
  user_claim      = "sub"
}
