# Helix Chain Mode — Execution Plan

Parallel tracks for YieldSwarm / Kairo infrastructure activation.
**Date:** 2026-06-15

---

## Track status

| Track | Focus | Status | Key artifacts |
|-------|-------|--------|-----------------|
| **Domain** | Unstoppable Domains wiring | ✅ Documented | `DOMAINS.md` |
| **Infra** | Akash + multi-cloud | ✅ Scaffolded | `deploy/`, `akash/`, `infra/` |
| **Secrets** | HashiCorp Vault | ✅ Scaffolded | `vault/`, `SECRETS.md`, `terraform/` |
| **Merge** | Clean main + branch ladder | ✅ Documented | `BRANCHES.md` |
| **Kairo** | Cryptographic identity | 🔜 Pending | `/kairo` folder (next PR) |

---

## Priority decision (agent recommendation)

**Clean merge into `main` first**, then Akash deploy. Rationale:

1. Infra files must land on `main` before `terraform apply` or `akash-deploy.sh`
   reference stable paths.
2. Vault bootstrap (`./vault/scripts/bootstrap.sh`) needs committed policies.
3. Domain wiring (UD dashboard) can run in parallel — no repo dependency.

---

## Track 1 — Domains (start now)

See `DOMAINS.md` for exact records. Tonight's minimum:

1. `yieldswarm.crypto` → Website = `https://v2-0-bay.vercel.app`
2. Set `crypto.ETH.address`, `crypto.BTC.address`, `crypto.SOL.address`
3. Add `app` CNAME → Vercel; register `app.yieldswarm.crypto` in Vercel
4. (Optional) Delegate to Cloudflare nameservers

---

## Track 2 — Akash production deploy

### Prerequisites

```bash
# Install Akash CLI
curl -sSfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash

# Fund wallet
provider-services keys add yieldswarm  # or import existing
provider-services query bank balances $(provider-services keys show yieldswarm -a)
```

### Deploy monolith (3× RTX 3090)

```bash
export AKASH_KEY_NAME=yieldswarm
export AUTO_SELECT_BID=1
export AKASH_DEPOSIT=5000000uakt

./scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

### Or full orchestrated deploy

```bash
cp deploy/config.env.example deploy/config.env
cp .env.example .env
# Fill secrets via Vault (see SECRETS.md)

make preflight
make deploy    # build → akash → terraform → frontend → monitoring
```

### Lease manager (auto-failover)

```bash
cp akash/akash-lease-manager.env.example akash/.env
cd akash && ./run.sh
# Or install systemd: sudo cp akash/akash-lease-manager.service /etc/systemd/system/
```

---

## Track 3 — Multi-cloud Terraform (Helixchainprod)

```bash
cd infra/terraform

export TF_CLOUD_ORGANIZATION="<your-hcp-org>"
export TF_TOKEN_app_terraform_io="<hcp-terraform-token>"

# Secrets from Vault (not env files)
export TF_VAR_vault_address="https://vault.yieldswarm.internal:8200"
# Issue wrapped secret_id per SECRETS.md

cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Fallback triggers when `akash_current_workers < desired_total_workers`.
See `infra/README.md` for capacity math.

---

## Track 4 — Vault wiring

```bash
export VAULT_ADDR="https://vault.yieldswarm.internal:8200"
export VAULT_TOKEN="<break-glass admin token>"

./vault/scripts/bootstrap.sh
./vault/scripts/seed-secrets.sh    # interactive, reads from stdin
./vault/scripts/issue-secret-id.sh terraform   # response-wrapped
```

Akash runtime pulls secrets via `vault-agent` at container start
(`akash/entrypoint.sh` + `akash/vault-agent/`).

---

## Track 5 — Merge into main

1. Merge this PR (`cursor/helix-chain-activation-597f`) → `main`
2. Create track branches per `BRANCHES.md`
3. Close duplicate `cursor/*` PRs; merge canonical branches in dependency order
4. Tag `v1.0-helix-launch` after first Akash success

---

## Celebration (after first Akash + domains live)

```bash
git tag -a v1.0-helix-launch -m "Helix Chain activation"
git checkout -b milestone/helix-chain-activation
# CELEBRATION.md added on that branch
git push origin v1.0-helix-launch milestone/helix-chain-activation
```

---

## Exact commands cheat sheet

```bash
# === DOMAINS (manual, UD dashboard) ===
# See DOMAINS.md Section 2

# === VAULT ===
./vault/scripts/bootstrap.sh && ./vault/scripts/seed-secrets.sh

# === AKASH ===
export AKASH_KEY_NAME=yieldswarm AUTO_SELECT_BID=1
./scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml

# === TERRAFORM ===
cd infra/terraform && terraform init && terraform apply

# === FULL STACK ===
make deploy

# === VERIFY ===
make status
curl -sf https://api.yieldswarm.crypto/healthz
dig app.yieldswarm.crypto CNAME +short
```
