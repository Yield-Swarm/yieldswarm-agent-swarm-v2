# YieldSwarm Vault Layer

This directory contains everything needed to stand up a production-grade
HashiCorp Vault deployment for the YieldSwarm AgentSwarm OS v2 platform.

```
vault/
├── policies/                   # HCL policies, one per consumer identity
│   ├── admin.hcl
│   ├── ci-bootstrap.hcl
│   ├── terraform.hcl
│   ├── akash-runtime.hcl
│   └── agent-runtime.hcl
├── setup/                      # Imperative bootstrap (run once on a fresh Vault)
│   ├── bootstrap.sh            # End-to-end orchestrator
│   ├── 01-init.sh              # vault operator init + key splitting
│   ├── 02-enable-engines.sh    # KVv2 mounts, transit, database, pki, audit
│   ├── 03-write-policies.sh    # Pushes everything in policies/ to Vault
│   ├── 04-enable-auth.sh       # AppRole + (optional) OIDC + Kubernetes/JWT
│   ├── 05-seed-secrets.sh      # Imports values from a local .env into KVv2
│   └── lib.sh                  # Shared helpers (vault status, KV helpers)
├── terraform-vault-config/     # Declarative Vault server configuration
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── mounts.tf               # KVv2 mounts, transit, audit
│   ├── policies.tf             # Loads policies/*.hcl
│   ├── auth-approle.tf         # Bootstrap AppRoles for terraform/akash/agents
│   ├── auth-oidc.tf            # Optional human auth (GitHub/Google)
│   └── outputs.tf
└── README.md (this file)
```

## Threat model

* **Never** commit a real secret to git. This repo only ships *examples*.
* All consumers (Terraform, Akash workloads, GitHub Actions, local devs)
  authenticate to Vault and pull secrets at runtime. There are no
  long-lived plaintext API keys in CI, containers, or VMs.
* Bootstrap secrets (RoleID + wrapped SecretID) are the only sensitive
  values handled outside Vault, and SecretIDs are response-wrapped so
  they can be exchanged exactly once before expiry.
* Every Vault path is covered by an explicit deny-by-default policy.
  Read the policy file before granting it to a new consumer.

See [`/SECRETS.md`](../SECRETS.md) at the repo root for the full
operator runbook with the exact commands to bring this up.
