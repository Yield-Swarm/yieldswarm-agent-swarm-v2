# Vault Layer — YieldSwarm AgentSwarm OS

This directory contains everything required to provision and operate the
HashiCorp Vault instance that backs the YieldSwarm stack. Nothing in this
directory should ever contain a real secret — only the *shape* of the
secrets, the policies that gate them, and the bootstrap automation.

```
vault/
├── bootstrap/      # Idempotent setup scripts (engines, audit, AppRoles)
├── policies/       # Least-privilege ACL policies
├── seed/           # Interactive seeder (never writes to ps/cmdline)
└── README.md       # You are here.  Full runbook: ../../SECRETS.md
```

## KV namespace layout

All YieldSwarm secrets live under a single KV v2 mount (`secret/`) inside
the `yieldswarm/` prefix:

| Path                                        | Owner role          | Used by                  |
|---------------------------------------------|---------------------|--------------------------|
| `secret/yieldswarm/cloud/azure`             | `terraform-deployer`| Terraform AzureRM        |
| `secret/yieldswarm/cloud/runpod`            | `terraform-deployer`| Terraform RunPod         |
| `secret/yieldswarm/cloud/vultr`             | `terraform-deployer`| Terraform Vultr          |
| `secret/yieldswarm/cloud/digitalocean`      | `terraform-deployer`| Terraform DigitalOcean   |
| `secret/yieldswarm/rpc/{solana,helius,...}` | `terraform-deployer`+ `akash-workload` | Infra + agents |
| `secret/yieldswarm/akash/deployer`          | `terraform-deployer`| Akash CLI / SDL deploys  |
| `secret/yieldswarm/runtime/agentswarm`      | `akash-workload`    | AgentSwarm containers    |
| `secret/yieldswarm/runtime/llm`             | `akash-workload`    | AgentSwarm containers    |

The policies in `policies/` enforce that the `akash-workload` token *cannot*
read any `cloud/*` path even if it learns the path, and vice-versa.

## Roles

| Role                  | Auth method | Token TTL | Max TTL | Purpose                                 |
|-----------------------|-------------|-----------|---------|-----------------------------------------|
| `secrets-admin`       | (operator)  | n/a       | n/a     | Break-glass seeding & policy management |
| `terraform-deployer`  | `approle`   | 30m       | 2h      | `terraform plan/apply` runs in CI       |
| `akash-workload`      | `approle`   | 30m       | 2h      | Long-running Akash containers           |
| `ci-pipeline`         | `approle`   | 30m       | 2h      | CI runner: mint wrapped secret_ids      |

All AppRoles are configured with:

- `secret_id_ttl = 24h` — secret_ids rotate at least daily.
- `token_no_default_policy = true` — no implicit grants.
- `secret_id_bound_cidrs` and `token_bound_cidrs` — set via env vars
  (`TERRAFORM_CIDR`, `AKASH_CIDR`) when running `03-approles.sh`.
- Response-wrapped secret_id delivery (60s wrap TTL, single-use).

## Quick start

```bash
export VAULT_ADDR=https://vault.example.internal:8200
export VAULT_TOKEN=...   # admin or root for first bootstrap only

cd infrastructure/vault/bootstrap
./00-bootstrap.sh                    # engines + policies + AppRoles

cd ../seed
./seed-secrets.sh                    # interactive prompts (no echo)
```

The full operator runbook — including key rotation, break-glass procedure,
audit log shipping, and Akash workload wiring — lives in
[`/SECRETS.md`](../../SECRETS.md).
