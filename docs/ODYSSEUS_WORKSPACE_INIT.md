# Odysseus Workspace Initialization

Azure [todo-nodejs-mongo](https://github.com/Azure-Samples/todo-nodejs-mongo) pattern applied to the Odysseus runtime: decoupled JSON config, environment variable mapping, and multi-host deployment (local / Docker / Azure App Service).

## Layout

```text
odysseus-workspace/
├── config/
│   ├── default.json                      # baseline (AI Foundry endpoint + resource ID)
│   ├── custom-environment-variables.json # env → config key mapping
│   ├── development.json
│   └── production.json
├── src/
│   ├── config/loader.ts                  # agnostic config loader
│   ├── azure/ai-foundry.ts               # AZURE_AI_FOUNDRY_KEY validation
│   ├── geod/scheduler-hook.ts            # GEOD cron post-init hook
│   ├── bootstrap.ts                      # initialization sequence
│   └── index.ts                          # entrypoint
├── azure.yaml                            # azd deploy manifest
├── Dockerfile
└── package.json
```

## Bootstrap sequence

1. `loadOdysseusConfig()` — merge default + `NODE_ENV` + env mapping
2. `AzureAiFoundryClient.validate()` — probe Foundry with `AZURE_AI_FOUNDRY_KEY`
3. `attachGeodScheduler()` — run GEOD tick + register cron (`GEOD_CRON_EXPRESSION`)

## Environment variables

| Variable | Purpose |
|----------|---------|
| `AZURE_AI_FOUNDRY_ENDPOINT` | Project API base URL |
| `AZURE_AI_FOUNDRY_RESOURCE_ID` | Azure resource ID |
| `AZURE_AI_FOUNDRY_KEY` | API key (required in production) |
| `GEOD_CRON_ENABLED` | `1` / `0` |
| `GEOD_CRON_EXPRESSION` | Default `*/15 * * * *` |
| `GEOD_ENTROPY_SHARD_COUNT` | Default `120` |

## Local run

```bash
cd odysseus-workspace
npm install
export AZURE_AI_FOUNDRY_KEY=your_key
export ODYSSEUS_SKIP_FOUNDRY_VALIDATE=1   # optional offline
npm run dev
```

## Docker (full Odysseus stack)

```bash
docker compose -f docker-compose.yml -f docker-compose.odysseus.yml up -d odysseus-workspace
```

## Azure App Service (Bicep)

```bash
az deployment group create \
  --resource-group rg-cbreezy666-2775 \
  --template-file infra/odysseus/main.bicep \
  --parameters azureAiFoundryKey="$AZURE_AI_FOUNDRY_KEY"
```

## GEOD Python tick

```bash
python3 services/geod/scheduler.py --tick
python3 agents/geod_scheduler_agent.py
```

State: `.run/geod/last-tick.json`

## Related

- `docs/odysseus-yieldswarm.md`
- `docs/AZURE_VM_DASHBOARD.md`
- `services/cloud_scheduler/scheduler.py`
