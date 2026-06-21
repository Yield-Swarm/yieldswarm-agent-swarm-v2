# Plug-and-Play Deployment Templates

Env-driven templates for multi-cloud, LLM routing, ZK entropy, and TON/Kairo layers. **No hardcoded secrets.**

## Structure

```text
deploy/templates/
├── cloud/
│   ├── akash/ollama-worker.sdl.yml.tpl
│   ├── akash/backend.sdl.tmpl.yml
│   ├── azure/tfc-workspace.env.tpl
│   ├── azure/container-instance.env.tmpl
│   └── ../../azure-deploy.yml          # ACI ARM template (core API)
│   ├── aws/ecs-task.env.tmpl
│   └── vast/on-demand.env.tmpl
├── llm-router/
├── zk-entropy/
└── ton-kairo/
```

## Render

```bash
cp deploy/env/layered.env.example .env   # or config/layered.env.example
# fill secrets or: python3 scripts/vault-export-env.py > .env

./deploy/templates/lib/render-template.sh all
# output: deploy/rendered/
```

## Deploy full stack

```bash
DRY_RUN=1 ./deploy/deploy-full-stack.sh --phase all
./deploy/deploy-full-stack.sh --phase 2
docker compose -f deploy/docker-compose.stack.yml up -d
```

See `docs/DEPLOYMENT_PRIORITY_ORDER.md` and `docs/DEPLOYMENT_PRIORITY.md` for phase order.
