output "primary_healthy" {
  description = "Whether the primary (Akash) worker passed its health probe."
  value       = local.primary_healthy
}

output "active_fallback" {
  description = "Which fallback cloud (if any) is currently provisioned."
  value       = local.active_fallback
}

output "worker_image" {
  description = "Worker image deployed to the active backend."
  value       = local.worker_image
}

output "fallback_url_file" {
  description = "File the fallback deploy scripts write the live worker URL to."
  value       = "${path.module}/fallback-url.txt"
}
