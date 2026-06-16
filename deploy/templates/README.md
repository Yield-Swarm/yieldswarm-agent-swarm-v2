# Plug-and-Play Deployment Templates

Env-driven templates for multi-cloud deploy. **No hardcoded secrets.**

## Render

```bash
cp deploy/env/layered.env.example .env   # fill secrets
./deploy/templates/lib/render-template.sh all
# Output: deploy/rendered/
```

## Targets

| Target | Template | Output |
|--------|----------|--------|
| `akash` | `cloud/akash/backend.sdl.tmpl.yml` | `rendered/cloud/akash/backend.sdl.yml` |
| `azure` | `cloud/azure/container-instance.env.tmpl` | `rendered/cloud/azure/container-instance.env` |
| `aws` | `cloud/aws/ecs-task.env.tmpl` | `rendered/cloud/aws/ecs-task.env` |
| `vast` | `cloud/vast/on-demand.env.tmpl` | `rendered/cloud/vast/on-demand.env` |
| `llm-router` | `llm-router/docker-compose.tmpl.yml` | `rendered/llm-router/docker-compose.yml` |
| `zk-entropy` | `zk-entropy/deploy.env.tmpl` | `rendered/zk-entropy/deploy.env` |
| `ton-kairo` | `ton-kairo/stack.env.tmpl` | `rendered/ton-kairo/stack.env` |

## Full stack harness

```bash
DRY_RUN=1 ./deploy/deploy-full-stack.sh --phase all
./deploy/deploy-full-stack.sh --phase 2
```

See `docs/DEPLOYMENT_PRIORITY.md` for phase order.
