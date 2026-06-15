# Helixchain Multi-Cloud Packer Templates

This folder contains image pipelines for each fallback target:

- `azure-vmss.pkr.hcl` -> Azure managed image for VMSS
- `gcp-mig.pkr.hcl` -> GCP image for MIG template
- `runpod-container.pkr.hcl` -> OCI image for RunPod pods
- `vultr-snapshot.pkr.hcl` -> Vultr snapshot image

All templates install baseline dependencies and create `/opt/helixchain`.

## Usage

```bash
cd infra/packer
packer init .
```

### Azure

```bash
packer build azure-vmss.pkr.hcl
```

### GCP

```bash
packer build -var 'project_id=<PROJECT_ID>' gcp-mig.pkr.hcl
```

### RunPod

```bash
packer build -var 'repository=<REGISTRY>/<IMAGE>' -var 'tag=prod' runpod-container.pkr.hcl
# push after build:
# docker push <REGISTRY>/<IMAGE>:prod
```

### Vultr

```bash
export VULTR_API_KEY=<KEY>
packer build vultr-snapshot.pkr.hcl
```

Use generated image IDs in `infra/terraform/terraform.tfvars`.
