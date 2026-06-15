# Multi-Cloud Worker Fallback (Akash saturation failover)

Terraform modules and Packer templates that spin up **equivalent AgentSwarm
worker capacity** across **Azure (VMSS)**, **GCP (Managed Instance Group)**,
**RunPod (GPU pods)** and **Vultr (instances)** whenever Akash is saturated.

```
infra/
├── terraform/
│   ├── backend.tf            # HCP Terraform "Helixchainprod" workspace
│   ├── versions.tf           # provider version pins
│   ├── providers.tf          # provider configuration (creds via env/vars)
│   ├── variables.tf          # all root inputs
│   ├── main.tf               # capacity math + module wiring
│   ├── outputs.tf            # capacity plan + per-provider results
│   ├── terraform.tfvars.example
│   ├── templates/
│   │   └── worker-bootstrap.sh.tftpl   # cloud-init/startup-script
│   └── modules/
│       ├── azure-vmss/       # Linux VM Scale Set
│       ├── gcp-mig/          # zonal Managed Instance Group
│       ├── runpod/           # one runpod_pod per worker
│       └── vultr/            # one vultr_instance per worker
└── packer/
    ├── variables.pkr.hcl
    ├── azure-worker.pkr.hcl  # -> Azure managed image
    ├── gcp-worker.pkr.hcl    # -> GCE image
    ├── vultr-worker.pkr.hcl  # -> Vultr snapshot
    ├── scripts/install-worker.sh
    ├── docker/               # the worker container image (RunPod + VMs)
    └── worker.pkrvars.hcl.example
```

## How capacity equivalence works

A "worker unit" is one container running `agents_per_worker` agent shards
(default 84, matching `AGENTS_PER_SHARD`). The root module computes the deficit:

```
deficit = max(0, desired_total_workers - akash_current_workers)
```

and distributes it across the **enabled** providers proportionally to
`fallback_weights`, rounding each share **up** so the provisioned total always
**meets or exceeds** the deficit. `max_workers_per_provider` caps spend per
provider.

Example (`desired_total_workers = 120`, `akash_current_workers = 40`,
weights `azure:3 gcp:3 runpod:2 vultr:2`):

| Provider | Workers |
|----------|---------|
| azure    | 24 (VMSS instances) |
| gcp      | 24 (MIG target size) |
| runpod   | 16 (pods) |
| vultr    | 16 (instances) |
| **total**| **80** = deficit |

If Akash recovers (`akash_current_workers >= desired_total_workers`) the deficit
is `0`, every module is disabled via `count`, and `terraform apply` tears the
fallback fleet back down.

Drive it from the Akash optimizer agent, e.g.:

```bash
terraform apply \
  -var "akash_current_workers=$(akash-current-lease-count)" \
  -var "desired_total_workers=120"
```

## Quick start (Helixchainprod workspace)

```bash
cd infra/terraform

# HCP Terraform backend -> workspace "Helixchainprod"
export TF_CLOUD_ORGANIZATION="<your-hcp-org>"
export TF_TOKEN_app_terraform_io="<hcp-terraform-token>"

# Provider credentials (or set them as sensitive workspace variables)
export ARM_SUBSCRIPTION_ID=... ARM_TENANT_ID=... ARM_CLIENT_ID=... ARM_CLIENT_SECRET=...
export GOOGLE_CREDENTIALS="$(cat sa.json)"
export VULTR_API_KEY=...
export RUNPOD_API_KEY=...

cp terraform.tfvars.example terraform.tfvars   # edit capacity + sizing
terraform init
terraform plan
terraform apply
```

### Local state (no HCP)

```bash
cd infra/terraform
terraform init -backend=false   # validate / plan only
# ...or comment out the cloud{} block in backend.tf for local state files
```

## Building worker images (optional but recommended)

VM modules boot the Ubuntu 22.04 marketplace image by default and install Docker
on first boot. For faster, immutable boots, bake images with Packer and pass the
results back into Terraform:

```bash
cd infra/packer
packer init .
cp worker.pkrvars.hcl.example worker.pkrvars.hcl   # edit
packer build -var-file=worker.pkrvars.hcl -only="azure-worker.*" .
packer build -var-file=worker.pkrvars.hcl -only="gcp-worker.*"   .
packer build -var-file=worker.pkrvars.hcl -only="vultr-worker.*" .
```

Then set the Terraform variables:

| Packer output        | Terraform variable        |
|----------------------|---------------------------|
| Azure managed image  | `azure_source_image_id`   |
| GCE image            | `gcp_source_image`        |
| Vultr snapshot       | `vultr_snapshot_id`       |

RunPod is container-native, so it runs `worker_container_image` directly — build
and push that image from `packer/docker/`:

```bash
docker build -t ghcr.io/yieldswarm/agentswarm-worker:latest infra/packer/docker
docker push ghcr.io/yieldswarm/agentswarm-worker:latest
```

## GPU workers

| Provider | How to enable GPUs |
|----------|--------------------|
| Azure    | `azure_vm_size = "Standard_NC4as_T4_v3"` (or other N-series) |
| GCP      | `gcp_gpu_type = "nvidia-tesla-t4"`, `gcp_gpu_count = 1` |
| RunPod   | `runpod_gpu_type_ids`, `runpod_gpu_count` (GPU by default) |
| Vultr    | `vultr_plan = "vcg-a16-..."` (a GPU plan) |

When building images for GPU hosts set `enable_gpu = true` so the NVIDIA driver
and container toolkit are baked in; the bootstrap script then runs the worker
with `--gpus all`.

## Security notes

- No credentials are committed. They come from environment variables or
  sensitive HCP workspace variables.
- `terraform.tfvars`, `*.pkrvars.hcl` and `*.pem` are gitignored.
- If `ssh_public_key` is empty, a break-glass RSA key is generated and exposed
  via the sensitive `breakglass_private_key_pem` output — capture it into a
  secret manager and rotate.

## Validation

```bash
cd infra/terraform && terraform fmt -recursive && terraform validate
cd infra/packer    && packer fmt . && packer validate -var-file=worker.pkrvars.hcl .
```
