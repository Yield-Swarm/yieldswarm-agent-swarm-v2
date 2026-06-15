output "instance_ids" {
  value = vultr_instance.shard[*].id
}

output "ipv4" {
  value = vultr_instance.shard[*].main_ip
}

output "vpc_id" {
  value = vultr_vpc.net.id
}
