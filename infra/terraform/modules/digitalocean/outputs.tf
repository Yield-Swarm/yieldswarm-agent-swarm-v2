output "droplet_ids" {
  value = digitalocean_droplet.shard[*].id
}

output "droplet_ipv4" {
  value = digitalocean_droplet.shard[*].ipv4_address
}

output "vpc_id" {
  value = digitalocean_vpc.net.id
}

output "spaces_bucket" {
  value = digitalocean_spaces_bucket.state.name
}
