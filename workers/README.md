# Cloudflare Workers

## `gateway-yieldswarm-crypto.js`

Phase 2 stable proxy for Akash API endpoints behind `api.yieldswarm.crypto` and `gateway.yieldswarm.crypto`.

See `DOMAINS.md` §4 and `config/domains/registry.json`.

```bash
source .run/akash-lease.env
export AKASH_ORIGIN="${AKASH_WORKER_URLS%%,*}"

wrangler deploy workers/gateway-yieldswarm-crypto.js
wrangler secret put AKASH_ORIGIN
```
