provider "vault" {
  namespace = var.vault_namespace
}

resource "vault_mount" "kvv2" {
  path        = var.kv_mount_path
  type        = "kv"
  description = "Static provider and workload secrets for ${var.environment}"

  options = {
    version = "2"
  }
}

resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "Transit encryption for ${var.environment}"
}

resource "vault_transit_secret_backend_key" "openclaw_runtime" {
  backend            = vault_mount.transit.path
  name               = "openclaw-runtime"
  type               = "aes256-gcm96"
  deletion_allowed   = false
  exportable         = false
  auto_rotate_period = 2592000
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = var.approle_path
  description = "AppRole auth for ${var.environment} machine identities"
}

locals {
  terraform_policy = <<-EOT
    path "${var.kv_mount_path}/data/providers/azure" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/data/providers/runpod" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/data/providers/vultr" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/data/providers/digitalocean" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/data/network/rpc" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/metadata/providers/*" {
      capabilities = ["list"]
    }

    path "${var.kv_mount_path}/metadata/network/*" {
      capabilities = ["list"]
    }
  EOT

  openclaw_policy = <<-EOT
    path "${var.kv_mount_path}/data/${var.openclaw_secret_path}" {
      capabilities = ["read"]
    }

    path "${var.kv_mount_path}/metadata/apps/openclaw/*" {
      capabilities = ["list"]
    }

    path "${var.transit_mount_path}/encrypt/openclaw-runtime" {
      capabilities = ["update"]
    }

    path "${var.transit_mount_path}/decrypt/openclaw-runtime" {
      capabilities = ["update"]
    }

    path "${var.transit_mount_path}/rewrap/openclaw-runtime" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_policy" "terraform" {
  name   = var.terraform_role_name
  policy = local.terraform_policy
}

resource "vault_policy" "openclaw" {
  name   = var.openclaw_role_name
  policy = local.openclaw_policy
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.terraform_role_name
  token_policies          = [vault_policy.terraform.name]
  token_ttl               = var.terraform_token_ttl_seconds
  token_max_ttl           = var.terraform_token_max_ttl_seconds
  token_no_default_policy = true
  secret_id_num_uses      = 1
  secret_id_ttl           = var.terraform_secret_id_ttl_seconds
  bind_secret_id          = true
}

resource "vault_approle_auth_backend_role" "openclaw" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.openclaw_role_name
  token_policies          = [vault_policy.openclaw.name]
  token_ttl               = var.openclaw_token_ttl_seconds
  token_max_ttl           = var.openclaw_token_max_ttl_seconds
  token_no_default_policy = true
  secret_id_num_uses      = 1
  secret_id_ttl           = var.openclaw_secret_id_ttl_seconds
  bind_secret_id          = true
  secret_id_bound_cidrs   = var.openclaw_secret_id_bound_cidrs
  token_bound_cidrs       = var.openclaw_token_bound_cidrs
}

data "vault_approle_auth_backend_role_id" "terraform" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.terraform.role_name
}

data "vault_approle_auth_backend_role_id" "openclaw" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.openclaw.role_name
}
