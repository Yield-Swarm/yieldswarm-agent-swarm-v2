# Cherry Servers — Multi-Cloud VM/GPU Spec Research Packet

> **[RESEARCH MODE]** Principal Cloud Architect export for **Justas | CherryServers**  
> Purpose: justify free cloud credits with CPU, RAM, storage, GPU inventory, and 30-day usage.

**One-command export (wired for Cursor / Vault):**

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<short-lived-operator-token>

# Local host only (run on each VM: Azure, GCP, RunPod, Haji):
python3 scripts/telemetry/sys_profile.py

# Cloud API inventory (from a machine with az/gcloud/RUNPOD_API_KEY):
./scripts/cherry-servers/export-cloud-specs.sh --load-vault

# Full packet (local host + cloud APIs):
./scripts/cherry-servers/collect-all.sh --load-vault
```

Outputs:

- `.run/cherry-servers-cloud-specs.json` — machine-readable cloud inventory
- `.run/cherry-servers-cloud-specs.md` — presentation summary
- `.run/cherry-servers-local-host.json` / `.md` — local host telemetry
- `.run/cherry-servers-full-packet.json` / `.md` — merged packet for Cherry Servers

### Git checkout blocked by `package.json` (Termux / PR #55)

If `gh pr checkout 55` fails because of local `package.json` edits:

```bash
git stash
gh pr checkout 55
# optional restore: git stash pop
```

Or discard local edits: `git checkout -- package.json && gh pr checkout 55`

Use branch `cursor/cherry-servers-cloud-specs-4f85` (latest) or `cursor/cherry-servers-cloud-specs-597f`.

---

## 0. Authentication & environment (run once)

### Vault → cloud credentials (YieldSwarm layout)

```bash
export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
export VAULT_TOKEN="<operator-token>"

# Azure service principal
eval "$(vault kv get -format=json yieldswarm/cloud/azure | jq -r '
  .data.data | to_entries[] | "export AZURE_\(.key | ascii_upcase)=\(.value | @sh)"
')"

az login --service-principal \
  -u "$AZURE_CLIENT_ID" \
  -p "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# RunPod
export RUNPOD_API_KEY="$(vault kv get -field=api_key yieldswarm/cloud/runpod)"

# GCP (if seeded)
vault kv get -format=json yieldswarm/cloud/gcp \
  | jq -r '.data.data.credentials_json' > /tmp/gcp-sa.json
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp-sa.json
export GCP_PROJECT_ID="$(jq -r .project_id /tmp/gcp-sa.json)"
gcloud auth activate-service-account --key-file=/tmp/gcp-sa.json
gcloud config set project "$GCP_PROJECT_ID"
```

### Manual auth (no Vault)

```bash
az login
export AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-yieldswarm-rg}"

gcloud auth login
gcloud auth application-default login
export GCP_PROJECT_ID="$(gcloud config get-value project)"

export RUNPOD_API_KEY="<from RunPod console → Settings → API Keys>"
export RUNPOD_ENDPOINT="https://api.runpod.io/graphql"
```

---

## 1. Azure CLI — VM specs + 30-day metrics

### Inventory (all VMs + container groups)

```bash
export WINDOW_START="$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)"
export WINDOW_END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

az vm list --resource-group "$AZURE_RESOURCE_GROUP" -o table
az container list --resource-group "$AZURE_RESOURCE_GROUP" -o table
```

### Per-VM: CPU type, core count, RAM, disks

```bash
VM_NAME="<your-vm>"
RG="${AZURE_RESOURCE_GROUP}"

az vm show -g "$RG" -n "$VM_NAME" -o json \
  | jq '{name, location, vm_size: .hardwareProfile.vmSize, os: .storageProfile.osDisk, data_disks: .storageProfile.dataDisks}'

SIZE="$(az vm show -g "$RG" -n "$VM_NAME" --query hardwareProfile.vmSize -o tsv)"
LOC="$(az vm show -g "$RG" -n "$VM_NAME" --query location -o tsv)"

az vm list-sizes --location "$LOC" --query "[?name=='$SIZE']" -o table
```

### GPU SKUs (NC/ND/NV series)

```bash
az vm list-sizes --location "${AZURE_LOCATION:-eastus}" \
  --query "[?contains(name, 'NC') || contains(name, 'ND') || contains(name, 'NV')].{SKU:name, vCPUs:numberOfCores, RAM_GB:memoryInMb}" \
  -o table
```

### 30-day CPU + memory averages (Azure Monitor)

```bash
VM_ID="$(az vm show -g "$RG" -n "$VM_NAME" --query id -o tsv)"

az monitor metrics list --resource "$VM_ID" \
  --metric "Percentage CPU" \
  --start-time "$WINDOW_START" --end-time "$WINDOW_END" \
  --interval PT1H --aggregation Average Maximum -o table

az monitor metrics list --resource "$VM_ID" \
  --metric "Available Memory Bytes" \
  --start-time "$WINDOW_START" --end-time "$WINDOW_END" \
  --interval PT1H --aggregation Average -o table
```

### Azure Container Instances (YieldSwarm core backend)

```bash
az container show \
  --resource-group "${AZURE_RESOURCE_GROUP:-yieldswarm-rg}" \
  --name "${AZURE_CONTAINER_GROUP:-yieldswarm-core}" \
  --query "{cpu:containers[0].resources.requests.cpu, memoryGb:containers[0].resources.requests.memoryInGb, image:containers[0].image, state:instanceView.state}" \
  -o json
```

---

## 2. Google Cloud CLI — VM specs + 30-day metrics

### Instance inventory

```bash
gcloud compute instances list --project="$GCP_PROJECT_ID" \
  --format="table(name,zone,machineType.basename(),status,networkInterfaces[0].networkIP)"
```

### CPU, RAM, disks, GPUs (per instance)

```bash
INSTANCE="<name>"
ZONE="${GCP_ZONE:-us-central1-a}"

gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --project="$GCP_PROJECT_ID" --format=json \
  | jq '{
      name: .name,
      machine_type: (.machineType | split("/") | last),
      cpu_platform: .cpuPlatform,
      disks: [.disks[] | {device: .deviceName, boot: .boot, sizeGb: .diskSizeGb}],
      gpus: [.guestAccelerators[]? | {type: .acceleratorType, count: .acceleratorCount}]
    }'

MT="$(gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --format='value(machineType)' | awk -F/ '{print $NF}')"
gcloud compute machine-types describe "$MT" --zone="$ZONE" \
  --format="table(name,guestCpus,memoryMb)"
```

### Available GPU types in zone

```bash
gcloud compute accelerator-types list --zones="$ZONE" \
  --format="table(name,description,maximumCardsPerInstance)"
```

### 30-day CPU utilization (Cloud Monitoring)

```bash
INSTANCE_ID="$(gcloud compute instances describe "$INSTANCE" --zone="$ZONE" --format='value(id)')"

gcloud monitoring time-series list \
  --project="$GCP_PROJECT_ID" \
  --filter="metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.labels.instance_id=\"${INSTANCE_ID}\"" \
  --start-time="-30d" --end-time=now \
  --format=json \
  | jq '[.[].points[]?.value.doubleValue] | {samples: length, avg: (add/length), max: max}'
```

### 30-day memory utilization

```bash
gcloud monitoring time-series list \
  --project="$GCP_PROJECT_ID" \
  --filter="metric.type=\"agent.googleapis.com/memory/percent_used\" AND resource.labels.instance_id=\"${INSTANCE_ID}\"" \
  --start-time="-30d" --end-time=now \
  --format=json
```

> **Note:** Memory agent metrics require Ops Agent on the VM. CPU utilization is always available.

---

## 3. RunPod API — GPU pods + live utilization

### GraphQL: fleet inventory + GPU catalog

```bash
curl -sS "$RUNPOD_ENDPOINT" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { gpuTypes { id displayName memoryInGb secureCloud communityCloud } myself { pods { id name desiredStatus costPerHr machine { gpuDisplayName gpuCount } runtime { uptimeInSeconds gpus { gpuUtilPercent memoryUtilPercent } } } } }"}' \
  | jq .
```

### Per-pod GPU utilization (live)

```bash
POD_ID="<pod-id>"

curl -sS "$RUNPOD_ENDPOINT" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"query { pod(input: {podId: \\\"$POD_ID\\\"}) { id name machine { gpuDisplayName } runtime { gpus { gpuUtilPercent memoryUtilPercent } } } }\"}" \
  | jq .
```

### 30-day RunPod usage

RunPod's public GraphQL API exposes **live** GPU/memory utilization on running pods. For **30-day billing and average utilization**, export from:

**RunPod Console → Billing → Usage** (CSV)

Attach that CSV to the Cherry Servers credits packet alongside the JSON export from this repo.

---

## 4. Presentation template (Justas | CherryServers)

Copy into your credits application:

| Provider | Resource | vCPU | RAM | Storage | GPU | 30d Avg CPU | 30d Avg GPU | Monthly est. |
|----------|----------|------|-----|---------|-----|-------------|-------------|--------------|
| Azure | `yieldswarm-core` ACI | 4 | 16 GB | 50 GB ephemeral | — | _from metrics_ | — | _$/mo_ |
| Azure | VM `…` | _cores_ | _GB_ | _OS+data disks_ | NC-series? | _%_ | — | _$/mo_ |
| GCP | `e2-standard-4` | 4 | 16 GB | _disks_ | T4 x1? | _ratio_ | _%_ | _$/mo_ |
| RunPod | RTX 4090 pod | — | — | 50 GB container | RTX 4090 x1 | — | _live %_ | _$/hr_ |

**Workload justification (YieldSwarm):**

- Multi-agent inference (Odysseus + LiteLLM router) on GPU burst (RunPod)
- Integration backend + telemetry fusion (Azure ACI)
- Fallback worker MIG (GCP) when Akash capacity saturated
- Target fleet: 120 workers @ 84 agents each (`infra/terraform/terraform.tfvars.example`)

---

## 5. Cursor deep-research prompt (canonical)

Paste into Cursor Composer when refreshing this packet:

```text
[RESEARCH MODE] As a Principal Cloud Architect, perform deep research and generate the necessary shell commands for Azure CLI, Google Cloud CLI (gcloud), and RunPod API to extract comprehensive VM specifications. The output must include CPU type and count, total RAM, storage configuration, available GPU model and utilization, and average usage statistics for the last 30 days. Format the final output clearly for presentation to "Justas | CherryServers" to justify free cloud credits, ensuring all environmental variables and authentication contexts are correctly assumed and incorporated for seamless execution in a wired environment like Cursor.
```

Then run:

```bash
./scripts/cherry-servers/export-cloud-specs.sh --load-vault
```

---

## 6. Related repo paths

| Path | Purpose |
|------|---------|
| `scripts/cherry-servers/export-cloud-specs.sh` | Automated multi-cloud export |
| `scripts/multicloud-preflight.sh` | GO/NO-GO credential check |
| `vault/setup/05-seed-secrets.sh` | Seed `yieldswarm/cloud/{azure,runpod,gcp}` |
| `infra/terraform/terraform.tfvars.example` | Fallback worker sizing defaults |
| `docs/MULTI_CLOUD_30DAY_PLAN.md` | Credit harvest orchestration |

---

## 7. Termux note

If running from Android Termux, use **proot Ubuntu** first — cloud CLIs need glibc Linux:

```bash
proot-distro login ubuntu
# then run export-cloud-specs.sh inside Ubuntu
```

See [`docs/TERMUX_PROOT_BUILD.md`](TERMUX_PROOT_BUILD.md).
