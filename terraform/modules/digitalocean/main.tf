# Provider configured at root (terraform/providers.tf) from var.credentials.
# Module deliberately stays provider-config-free so it can be `count`-gated.

# Validates the token early. Lists at most a handful of regions; if the call
# fails the plan aborts here instead of partway through resource creation.
data "digitalocean_regions" "available" {
  filter {
    key    = "available"
    values = ["true"]
  }
}
