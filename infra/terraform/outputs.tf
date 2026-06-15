## outputs.tf
## Every output is marked sensitive.  Plain `terraform output` will redact;
## use `terraform output -json | jq` only inside ephemeral, trusted shells.

output "azure" {
  value     = var.enable_azure ? module.azure[0] : null
  sensitive = true
}

output "runpod" {
  value     = var.enable_runpod ? module.runpod[0] : null
  sensitive = true
}

output "vultr" {
  value     = var.enable_vultr ? module.vultr[0] : null
  sensitive = true
}

output "digitalocean" {
  value     = var.enable_digitalocean ? module.digitalocean[0] : null
  sensitive = true
}

output "rpc" {
  value     = module.rpc
  sensitive = true
}
