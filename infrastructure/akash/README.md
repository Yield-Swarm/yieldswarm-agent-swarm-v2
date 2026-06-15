# Akash Layer — YieldSwarm AgentSwarm OS

Container image + Akash SDL for the AgentSwarm workload. **No secret value
ever lives in this directory or in the image.** All runtime credentials
are fetched from Vault by the container entrypoint using an AppRole
secret_id delivered through a single-use, response-wrapped token.

```
akash/
├── deploy.yaml          # SDL template (envsubst placeholders only)
├── deploy.sh            # Mints a wrapped secret_id and submits the deploy
├── docker/
│   ├── Dockerfile       # Multi-stage build; pulls pinned Vault CLI
│   ├── entrypoint.sh    # Vault-aware secret injector (PID 1 via tini)
│   └── healthcheck.sh   # Process + token liveness probe
└── README.md
```

## Threat model

| Asset                     | Where it lives                  | Mitigation                                          |
|---------------------------|---------------------------------|-----------------------------------------------------|
| API keys, RPC keys, etc.  | Vault KV v2 only                | Never on disk, image layer, env file, or argv       |
| AppRole `secret_id`       | Wrapping token in SDL env var   | TTL ≤ 60s; single-use; revoked after unwrap         |
| Workload Vault token      | Container process env table     | TTL 30m, renewed every 10m; revoked on SIGTERM     |
| Vault audit log           | Vault server side               | File audit device enabled by `01-engines.sh`        |
| Image registry credentials| Akash provider config           | Outside scope of this repo (use DOCR / GHCR PATs)   |

The entrypoint enforces:

- Argv-clean: secrets reach the workload via env table only (no
  `/proc/<pid>/cmdline` leak).
- Tmpfs-clean: any on-disk staging file is `shred -u`-deleted the moment
  the value is in memory.
- Stdout-clean: a sed-based redactor masks anything that looks like a
  Vault token in the container logs.

## Build & push

```bash
docker buildx build \
    --platform linux/amd64 \
    -t registry.digitalocean.com/yieldswarm-prod/agentswarm:$(git rev-parse --short HEAD) \
    -f infrastructure/akash/docker/Dockerfile \
    infrastructure/akash/docker
docker push registry.digitalocean.com/yieldswarm-prod/agentswarm:<tag>
```

The `Dockerfile` expects an `app/` directory next to it containing the
AgentSwarm Python payload. Adjust the `COPY app/ /app/` line if your
build context differs.

## Deploy

```bash
export VAULT_ADDR=https://vault.internal:8200
export VAULT_TOKEN=...                                # ci-pipeline policy
export YIELDSWARM_IMAGE=registry.../agentswarm:<tag>
export AKASH_KEY_NAME=deployer

./infrastructure/akash/deploy.sh
```

The script:
1. Fetches the `akash-workload` role_id (non-secret).
2. Mints a fresh response-wrapped `secret_id` (60s TTL).
3. Renders `deploy.yaml` via `envsubst` into a tmpfs file.
4. Submits the deployment with `provider-services tx deployment create`.
5. Shreds the rendered file on exit.

If the container fails to start within the 60s wrap TTL, the wrapping
token expires and the SDL must be re-rendered.  For long start-up
profiles you can override `WRAP_TTL=180s` — but never raise it above the
`secret_id_ttl` configured on the AppRole.

## Rotation

- The container automatically revokes its workload token on SIGTERM, so
  rolling a deployment naturally rotates the token.
- The `secret_id` rotates every time `deploy.sh` runs.  Re-run on a
  schedule (e.g. nightly) even when the image hasn't changed.
- The `role_id` is durable; rotate it via `vault write
  auth/approle/role/akash-workload/role-id role_id=<new>` only on a
  break-glass event.
