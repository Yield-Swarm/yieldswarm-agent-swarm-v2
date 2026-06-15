output "account_name" {
  description = "Vultr account name — proves the API key is valid."
  value       = data.vultr_account.this.name
}

output "account_email" {
  value     = data.vultr_account.this.email
  sensitive = true
}
