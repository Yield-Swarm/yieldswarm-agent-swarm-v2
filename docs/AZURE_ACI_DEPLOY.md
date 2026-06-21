# Azure Container Instances — YieldSwarm Core

Deploy the integration backend (`swarm-orchestrator`) to **Azure Container Instances** using `deploy/azure-deploy.yml`.

This complements `terraform/azure.tf` (Container Apps for agent shards). Use ACI for a single public-facing core API (:8080) with Command Center, Arena, and Single Pane endpoints.

## Quick deploy

```bash
az login
export AZURE_SUBSCRIPTION_ID=...
export AZURE_RESOURCE_GROUP=yieldswarm-rg
export VAULT_ROLE_ID=...
export VAULT_WRAPPED_SECRET_ID=...   # from scripts/akash-vault-prepare.sh
export AKASH_OWNER_ADDRESS=akash1...
export AGENTSWARM_MASTER_KEY=...     # mining auth
export GHCR_USER=... GHCR_TOKEN=...  # if image is private

./scripts/deploy-azure-core.sh
```

Or via unified deploy:

```bash
./scripts/deploy-production.sh azure-aci
```

Dry run:

```bash
./scripts/deploy-azure-core.sh --dry-run
```

## Template

| Resource | Value |
|----------|-------|
| Type | `Microsoft.ContainerInstance/containerGroups` |
| Name | `yieldswarm-core` |
| Region | `eastus` (override with `AZURE_LOCATION`) |
| CPU / RAM | 4 vCPU / 16 GB |
| Image | `ghcr.io/yieldswarm/yieldswarm-backend:latest` |
| DNS | `yieldswarm-core.<region>.azurecontainer.io` |

## Secrets

Never commit real values. Copy `deploy/azure-deploy.parameters.example.json` to `.run/azure-deploy.parameters.json` locally, or let the deploy script build parameters from env.

| Parameter | Env var |
|-----------|---------|
| `vaultAddr` | `VAULT_ADDR` |
| `vaultRoleId` | `VAULT_ROLE_ID` |
| `vaultWrappedSecretId` | `VAULT_WRAPPED_SECRET_ID` |
| `akashOwnerAddress` | `AKASH_OWNER_ADDRESS` |
| `agentSwarmMasterKey` | `AGENTSWARM_MASTER_KEY` |
| `databaseUrl` | `DATABASE_URL` (Neon) |
| `ghcrUser` / `ghcrToken` | `GHCR_USER` / `GHCR_TOKEN` |

On boot, `scripts/backend-entrypoint.sh` unwraps Vault AppRole and loads runtime secrets before starting `node src/server.js`.

## Post-deploy URLs

```
http://<fqdn>:8080/api/health
http://<fqdn>:8080/command-center
http://<fqdn>:8080/api/single-pane/overview
http://<fqdn>:8080/api/mining/status
```

## Teardown

```bash
az container delete --resource-group yieldswarm-rg --name yieldswarm-core --yes
```

## Related

- `terraform/azure.tf` — Container Apps agent shards
- `deploy/templates/cloud/azure/container-instance.env.tmpl` — env bundle
- `docs/VAULT_AKASH_RUNTIME.md` — AppRole wrapping
