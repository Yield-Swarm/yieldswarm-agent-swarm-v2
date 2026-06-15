output "vault_mount_paths" {
  description = "Mounted secrets engines created for YieldSwarm."
  value = {
    cloud   = vault_mount.cloud.path
    rpc     = vault_mount.rpc.path
    apps    = vault_mount.apps.path
    transit = vault_mount.transit.path
  }
}

output "vault_policy_names" {
  description = "Policies used by Terraform and Akash runtime identities."
  value = {
    terraform = vault_policy.terraform_readonly.name
    akash     = vault_policy.akash_runtime.name
  }
}

output "approle_names" {
  description = "AppRole names. Generate role IDs and secret IDs outside Terraform to avoid writing them into state."
  value = {
    terraform = vault_approle_auth_backend_role.terraform.role_name
    akash     = vault_approle_auth_backend_role.akash.role_name
  }
}

output "secret_contracts" {
  description = "Expected Vault paths and required fields for cloud and runtime secrets."
  value = {
    cloud_azure = {
      path   = "${vault_mount.cloud.path}/data/azure"
      fields = local.secret_contracts.azure.required_fields
    }
    cloud_runpod = {
      path   = "${vault_mount.cloud.path}/data/runpod"
      fields = local.secret_contracts.runpod.required_fields
    }
    cloud_vultr = {
      path   = "${vault_mount.cloud.path}/data/vultr"
      fields = local.secret_contracts.vultr.required_fields
    }
    cloud_digitalocean = {
      path   = "${vault_mount.cloud.path}/data/digitalocean"
      fields = local.secret_contracts.digitalocean.required_fields
    }
    rpc_mainnet = {
      path   = "${vault_mount.rpc.path}/data/mainnet"
      fields = local.secret_contracts.rpc.required_fields
    }
    apps_yieldswarm_runtime = {
      path   = "${vault_mount.apps.path}/data/yieldswarm/akash"
      fields = ["AKASH_API_KEY", "GPU_CLUSTER_KEYS", "DEPIN_HELIUM_HOTSPOT_KEYS", "GRASS_NODE_KEYS"]
    }
  }
}
