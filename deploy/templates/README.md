# Plug-and-Play Deployment Templates

Env-driven templates for multi-cloud, LLM routing, ZK entropy, and TON/Kairo layers.

## Structure

```text
deploy/templates/
├── cloud/
│   ├── akash/ollama-worker.sdl.yml.tpl
│   └── azure/tfc-workspace.env.tpl
├── llm-router/litellm.config.yaml.tpl
├── zk-entropy/scheduler.env.tpl
└── ton-kairo/stack.env.tpl
```

## Render

```bash
cp config/layered.env.example .env
# fill secrets or: python3 scripts/vault-export-env.py > .env

bash deploy/deploy-full-stack.sh --render-only
# output: deploy/rendered/
```

## Deploy full stack

```bash
bash deploy/deploy-full-stack.sh              # phases 1–4
bash deploy/deploy-full-stack.sh --phase 1    # foundation only
bash deploy/deploy-full-stack.sh --dry-run
```

## Docker Compose (local)

```bash
docker compose -f deploy/docker-compose.stack.yml up -d
```

See `docs/DEPLOYMENT_PRIORITY_ORDER.md` for phase order and gates.
