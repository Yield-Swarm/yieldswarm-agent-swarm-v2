# MCP Setup — YieldSwarm Top 12 Plugins

Production-ready MCP configuration for Cursor agents working on YieldSwarm.

## Load configuration

**Option A — project (recommended, team-shared):**

```bash
cp .cursor/mcp-config-top12.json .cursor/mcp.json
```

**Option B — merge manually:** Copy individual `mcpServers` blocks from `mcp-config-top12.json` into `.cursor/mcp.json`.

**Option C — global:** Copy to `~/.cursor/mcp.json` for all projects.

Then: **Cursor Settings → Tools & MCP** → enable each server → authenticate if prompted.

## Required environment variables

Set in your shell profile or Cursor env (never commit values):

| Server | Env vars | YieldSwarm use |
|--------|----------|----------------|
| **stripe** | `STRIPE_SECRET_KEY` | Payments app, 1% fee routing, webhook debugging |
| **aws** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` | S3 artifacts, fallback infra |
| **azure** | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Container Apps fallback, Terraform |
| **databricks-sql** | `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, `DATABRICKS_HTTP_PATH` | Telemetry warehouse, agent performance SQL |
| **linear** | `LINEAR_API_KEY` | Sprint tracking, sovereign loop issues |
| **slack** | `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` | Deploy alerts, auto-heal notifications |
| **sentry** | `SENTRY_AUTH_TOKEN` | Production error triage (payments, backend) |
| **grafana-cloud** | `GRAFANA_URL`, `GRAFANA_API_KEY` | Sovereign loop + Akash fleet dashboards |
| **notion** | `NOTION_API_KEY` | Runbooks, funding docs, ops wiki |
| **render** | `RENDER_API_KEY` | Backend deploy/restart (`render.yaml`) |
| **browserbase** | `BROWSERBASE_API_KEY`, `BROWSERBASE_PROJECT_ID` | E2E Arena / payments smoke tests |
| **huggingface** | `HF_TOKEN` | Model eval, Ollama routing benchmarks |

Seed from Vault where possible:

```bash
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/runtime/llm
```

## Per-plugin notes

### Stripe
Query charges, customers, and webhook events while debugging `src/app/payments` and Stripe deposit flows.

### AWS / Azure
Inspect cloud resources during `terraform/` and `deploy/terraform` fallback applies. Credentials should match Vault paths `providers/azure` (not committed).

### Databricks SQL
Run analytics on agent shard cron output and Kairo telemetry once warehouse is wired.

### Linear
Create/update issues for merge coordination (`TODAY_TASKS.md` streams).

### Slack
Post deploy status from `scripts/deploy-all.sh` or sovereign loop faults.

### Sentry
Correlate backend `:8080` and Vercel function errors with release tags.

### Grafana Cloud
Query Prometheus metrics from `deploy/monitoring/` stack.

### Notion
Sync `PRODUCTION_SPINUP.md` and funding materials for investor updates.

### Render
Manage `yieldswarm-api` service defined in `render.yaml`.

### Browserbase
Headless browser validation of Arena dashboard and payment checkout.

### Hugging Face
Compare inference models for Odysseus router and Bittensor miner Ollama configs.

## Security

- Pin versions in `args` (e.g. `@stripe/mcp@0.1.0`) before production use
- Use `${env:VAR}` interpolation only — no literals in git
- Restrict API keys to least-privilege scopes
- Review MCP tool calls in Cursor before approving destructive operations

## Troubleshooting

1. Run the `command` + `args` manually in a terminal
2. Check **View → Output → MCP** in Cursor
3. Verify `node` / `npx` on PATH
4. Re-auth OAuth servers (Sentry) if tokens expire
