output "available_region_slugs" {
  description = "DO regions currently accepting new Droplets — proves the token works."
  value       = [for r in data.digitalocean_regions.available.regions : r.slug]
}

output "default_region" {
  value = var.default_region
}
