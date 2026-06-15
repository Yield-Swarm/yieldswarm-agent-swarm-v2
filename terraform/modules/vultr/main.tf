# Provider configured at root (terraform/providers.tf) from var.credentials.
# Module deliberately stays provider-config-free so it can be `count`-gated.

# Lightweight existence-check resource: reading account info forces the provider
# to authenticate, so a bad/rotated key fails at plan time instead of deep in
# the dependency graph.
data "vultr_account" "this" {}
