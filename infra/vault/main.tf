provider "vault" {
  address   = var.vault_addr
  namespace = var.vault_namespace
}

locals {
  kv_mount_path    = trim(var.kv_mount_path, "/")
  approle_auth_path = trim(var.approle_auth_path, "/")

  cloud_secret_paths = [
    "cloud/azure",
    "cloud/runpod",
    "cloud/vultr",
    "cloud/digitalocean",
  ]

  runtime_secret_paths = concat(local.cloud_secret_paths, ["rpc"])
}

resource "vault_mount" "yieldswarm" {
  path        = local.kv_mount_path
  type        = "kv-v2"
  description = "YieldSwarm production secrets for Terraform and runtime workloads"
}

resource "vault_auth_backend" "approle" {
  path        = local.approle_auth_path
  type        = "approle"
  description = "AppRole authentication for short-lived YieldSwarm runtime credentials"
}

resource "vault_policy" "terraform_read" {
  name = var.terraform_policy_name

  policy = <<-HCL
    path "${local.kv_mount_path}/data/cloud/azure" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/runpod" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/vultr" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/digitalocean" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/rpc" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/metadata/cloud" {
      capabilities = ["list"]
    }

    path "${local.kv_mount_path}/metadata/cloud/*" {
      capabilities = ["read", "list"]
    }

    path "${local.kv_mount_path}/metadata/rpc" {
      capabilities = ["read"]
    }
  HCL
}

resource "vault_policy" "akash_runtime" {
  name = var.akash_policy_name

  policy = <<-HCL
    path "${local.kv_mount_path}/data/cloud/azure" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/runpod" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/vultr" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/cloud/digitalocean" {
      capabilities = ["read"]
    }

    path "${local.kv_mount_path}/data/rpc" {
      capabilities = ["read"]
    }
  HCL
}

resource "vault_policy" "secret_operator" {
  name = var.secret_operator_policy_name

  policy = <<-HCL
    path "${local.kv_mount_path}/data/*" {
      capabilities = ["create", "update", "read", "delete", "patch"]
    }

    path "${local.kv_mount_path}/metadata" {
      capabilities = ["list"]
    }

    path "${local.kv_mount_path}/metadata/*" {
      capabilities = ["read", "list", "delete"]
    }

    path "${local.kv_mount_path}/delete/*" {
      capabilities = ["update"]
    }

    path "${local.kv_mount_path}/undelete/*" {
      capabilities = ["update"]
    }

    path "${local.kv_mount_path}/destroy/*" {
      capabilities = ["update"]
    }
  HCL
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.akash_role_name
  bind_secret_id = true

  token_policies = [
    vault_policy.akash_runtime.name,
  ]

  token_ttl     = var.akash_token_ttl_seconds
  token_max_ttl = var.akash_token_max_ttl_seconds
  token_type    = "service"

  secret_id_ttl      = var.akash_secret_id_ttl_seconds
  secret_id_num_uses = var.akash_secret_id_num_uses
}
