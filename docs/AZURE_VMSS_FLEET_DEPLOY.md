# Azure VMSS Fleet Deploy — SSH + Scale + GPU Clusters

End-to-end deployment for YieldSwarm mainnet on Azure `YieldSwarm` resource group.

## Prerequisites

```bash
az login
az account set --subscription "<subscription-id>"

cp deploy/azure-mainnet.env.example deploy/azure-mainnet.env
# Edit: AZURE_SUBSCRIPTION_ID, capacities, GPU size

# Place existing key OR let deploy generate one:
# cp ~/vmss_key.pem ./vmss_key.pem && chmod 400 vmss_key.pem
```

## One-command deploy (scale VMSS + wire LB + SSH bootstrap)

```bash
./scripts/azure/deploy-vmss-fleet.sh --env deploy/azure-mainnet.env
```

### Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print planned actions without Azure/SSH |
| `--gpu-only` | Skip CPU VMSS scale; only GPU cluster |
| `--terraform-gpu` | Provision GPU workers via `infra/terraform` |
| `--skip-bootstrap` | Skip SSH remote install |
| `--skip-wire` | Skip LB/NSG wiring |
| `--skip-domains` | Skip Front Door domain binding |
| `--autoscale` | Configure predictive + metric autoscale after deploy |

## Autoscale (predictive + reactive)

```bash
# Standalone autoscale configuration
./scripts/azure/configure-vmss-autoscale.sh --env deploy/azure-mainnet.env

# Or combined with fleet deploy
./scripts/azure/deploy-vmss-fleet.sh --env deploy/azure-mainnet.env --autoscale
```

See `docs/AZURE_VMSS_AUTOSCALE.md` for thresholds, OldestVM scale-in, GPU custom metrics.

## SSH into every instance

```bash
# Interactive shell on each instance (ports 50000, 50001, …)
./scripts/azure/ssh-vmss-fleet.sh --env deploy/azure-mainnet.env

# Run command across fleet
./scripts/azure/ssh-vmss-fleet.sh --cmd "systemctl status yieldswarm-backend"

# Bootstrap all nodes
./scripts/azure/ssh-vmss-fleet.sh --bootstrap
```

Manual SSH:

```bash
ssh -i vmss_key.pem -p 50000 azureuser@4.249.252.26   # instance 0
ssh -i vmss_key.pem -p 50001 azureuser@4.249.252.26   # instance 1
```

## GPU cluster

Default GPU SKU: `Standard_NC4as_T4_v3` (NVIDIA T4).

```bash
# Scale existing GPU VMSS (if already in YieldSwarm RG)
./scripts/azure/deploy-vmss-fleet.sh --gpu-only

# Full Terraform GPU fleet (creates new VMSS in RG)
./scripts/azure/deploy-vmss-fleet.sh --terraform-gpu
```

Terraform direct:

```bash
cd infra/terraform
export ARM_SUBSCRIPTION_ID=...
terraform init
terraform apply \
  -var 'enabled_fallbacks=["azure"]' \
  -var 'desired_total_workers=4' \
  -var 'azure_vm_size=Standard_NC4as_T4_v3' \
  -var 'azure_resource_group_name=YieldSwarm'
```

## Deploy sequence (what the orchestrator runs)

1. `az vmss scale` — CPU `vmss_3cf043e`
2. GPU VMSS scale or Terraform provision
3. `scripts/wire_infrastructure.sh` — NSG + LB probes
4. `scripts/azure/provision-custom-domains.sh` — Front Door TLS
5. `scripts/azure/ssh-vmss-fleet.sh --bootstrap` — install YieldSwarm on each node

## Verify

```bash
curl -s "http://4.249.252.26:8080/api/health"
./scripts/azure/ssh-vmss-fleet.sh --cmd "curl -s localhost:8080/api/health"
```

## Related

- `docs/AZURE_MAINNET_VMSS_TOPOLOGY.md` — network Mermaid map
- `scripts/wire_infrastructure.sh` — LB/NSG only
- `infra/README.md` — multi-cloud Terraform fallback
