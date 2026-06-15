output "droplet_ips" {
  description = "Public IP addresses of DigitalOcean Droplets."
  value       = digitalocean_droplet.agent[*].ipv4_address
}

output "spaces_bucket_name" {
  description = "DigitalOcean Spaces bucket name."
  value       = digitalocean_spaces_bucket.agentswarm.name
}

output "spaces_bucket_endpoint" {
  description = "DigitalOcean Spaces bucket endpoint URL."
  value       = digitalocean_spaces_bucket.agentswarm.bucket_domain_name
}

output "database_host" {
  description = "PostgreSQL cluster host."
  value       = digitalocean_database_cluster.agentswarm.host
}

output "database_port" {
  description = "PostgreSQL cluster port."
  value       = digitalocean_database_cluster.agentswarm.port
}

output "database_name" {
  description = "PostgreSQL database name."
  value       = digitalocean_database_db.agents.name
}
