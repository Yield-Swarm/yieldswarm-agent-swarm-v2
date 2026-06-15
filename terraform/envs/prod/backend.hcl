# terraform/envs/prod/backend.hcl
# Used with: terraform init -backend-config=envs/prod/backend.hcl
#
# State holds sensitive Vault-sourced values, so the backing storage MUST
# have encryption at rest + access controls. See SECRETS.md §"State backend".

resource_group_name  = "yieldswarm-tfstate-rg"
storage_account_name = "yieldswarmtfstate"
container_name       = "prod"
key                  = "yieldswarm.prod.tfstate"
