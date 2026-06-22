# Hugging Face agent skills — fleet injection

Global + Claude hybrid setup for **Cursor**, **Claude Code**, and **YieldSwarm fleet nodes** (Termux, RunPod, Azure VMSS). The modern `hf` CLI auto-detects `AI_AGENT` / `CURSOR_AGENT` and pivots terminal output to machine-optimized format with pre-filled next-step commands.

## Quick install (any node)

```bash
export HF_TOKEN=hf_...   # from Vault path integrations/huggingface — never commit
./scripts/fleet/install-hf-agent-skills.sh
```

Or via Makefile:

```bash
export HF_TOKEN=hf_...
make install-hf-skills
```

## What the installer does

1. `pip install -U "huggingface_hub[cli]"` — modern `hf` entrypoint (legacy `huggingface-cli` deprecated)
2. Writes profile env (`AI_AGENT=1`, `CURSOR_AGENT=1`, `HF_TOKEN`, `HF_HUB_ENABLE_HF_TRANSFER=1`)
3. `hf skills add --global` — registers skills under `~/.agents/skills` (Cursor / Codex)
4. `hf skills add --claude --global` — Claude Code terminal integration

## Fleet wiring

| Entry point | When HF skills run |
|-------------|-------------------|
| `swarm_provision.sh` | Every fleet node provision |
| `scripts/mining/start-termux.sh` | Termux mining bootstrap |
| `scripts/fleet/sync-fleet.sh` | After rsync if `HF_TOKEN` set locally |
| `scripts/azure/vmss-worker-bootstrap.sh` | Azure VMSS customData on boot |

## Vault

Seed token (never commit):

```bash
export HF_TOKEN=hf_...
./vault/scripts/seed-secrets.sh
# → yieldswarm/integrations/huggingface (token)
```

## Agent usage

Prefer the `hf` binary over raw HTTP:

```bash
hf models ls --format agent
hf download REPO_ID
hf auth whoami
```

Append `--format agent` when piping output into mining telemetry or swarm parsers.

## Azure VMSS

Set `$HfToken` in `deploy-vmss.secrets.ps1` (from `scripts/azure/deploy-vmss.config.example.ps1`). The PowerShell deploy script injects `HF_TOKEN` into VMSS customData; bootstrap runs `install-hf-agent-skills.sh` after repo clone.

See [`docs/AZURE_VMSS_DEPLOYMENT.md`](AZURE_VMSS_DEPLOYMENT.md).

## Master God Prompt

The swarm directive lives in [`docs/MASTER_GOD_PROMPT.md`](MASTER_GOD_PROMPT.md) under **Hugging Face ecosystem agentic access**.
