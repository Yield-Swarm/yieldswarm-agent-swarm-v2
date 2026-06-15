# Akash Deployment

## What this does

Runs the YieldSwarm AgentSwarm OS on Akash with **zero secrets baked into the
image and zero secrets in the SDL**. Secrets are pulled from Vault at runtime
by a Vault Agent sidecar inside the same container.

## Build the image

```bash
# role_id is the *non-secret half* of the AppRole credential.  It identifies
# the workload but cannot authenticate without a matching secret_id.
ROLE_ID="$(cat /run/secrets/approle/akash-runtime.role_id)"

docker buildx build \
  --build-arg VAULT_APPROLE_ROLE_ID="${ROLE_ID}" \
  -f infra/akash/docker/Dockerfile \
  -t ghcr.io/yieldswarm/agentswarm:1.0.0 \
  --push .
```

## Deploy

```bash
# Mint a fresh, single-use, 5-minute response-wrapped secret_id.
WRAPPED="$(vault write -wrap-ttl=300s -f -format=json \
  auth/approle/role/akash-runtime/secret-id \
  | jq -r .wrap_info.token)"

# Hand it to the deployment - the wrapped token expires in 5 minutes and
# can only be unwrapped once, by the Vault Agent inside the container.
AKASH_VAULT_SECRET_ID_WRAPPED="${WRAPPED}" \
  provider-services tx deployment create infra/akash/deploy.yaml \
    --from "${AKASH_KEY_NAME}" \
    --chain-id "${AKASH_CHAIN_ID}" \
    --node     "${AKASH_NODE}"

unset WRAPPED AKASH_VAULT_SECRET_ID_WRAPPED
```

## Verify

```bash
# Tail logs - look for "vault-agent rendered env file (N keys)" then
# "secrets loaded; exec'ing application as uid=app".
provider-services lease-logs --dseq "${DSEQ}" --service agentswarm --follow
```

If you see `FATAL: timed out waiting for vault-agent to render` the secret_id
already expired (>5 min between mint and deploy) or the AppRole policy does
not grant access to one of the templated KV paths.  Re-issue a wrapped
secret_id and redeploy.
