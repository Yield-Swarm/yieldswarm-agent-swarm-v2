# HashiCorp Vault Secret Structure

Canonical KV layout for YieldSwarm across payments, Akash, multi-cloud, Tesla, and internal services.

**Mount:** `yieldswarm` (KV v2). Docs may write `secret/yieldswarm/...` or `kv/yieldswarm/...` — both mean the same logical path under mount `yieldswarm`.

```bash
# CLI (correct)
vault kv put yieldswarm/payments/square access_token=... location_id=...

# Policy ACL (KV v2 data path)
path "yieldswarm/data/payments/square" { capabilities = ["read"] }
```

---

## Recommended path tree

```text
yieldswarm/
├── payments/
│   ├── square          # Square Web Payments + webhooks
│   ├── wise            # Wise payouts / inbound
│   └── web3            # Hot wallet keys for on/off ramps
├── akash/
│   ├── wallet          # Mnemonic, key name, owner address
│   └── deployment      # AppRole wrap tokens, chain/node metadata
├── cloud/              # Multi-cloud operator + Terraform (alias: providers/)
│   ├── aws
│   ├── azure
│   ├── gcp
│   ├── runpod
│   ├── vast
│   └── alibaba
├── integrations/
│   └── tesla           # Fleet API client_id/secret + key ref
├── external/
│   ├── mapbox          # Kairo maps (alias: integrations/mapbox)
│   └── toncenter       # TON API (alias: rpc/ton)
└── internal/
    ├── database        # Neon/Postgres connection
    └── redis           # Celery / async queue broker
```

Legacy paths (`runtime/payments`, `runtime/akash`, `providers/azure`) remain seeded for backward compatibility. New workloads should prefer the tree above.

---

## Example secrets

### Square — `yieldswarm/payments/square`

```json
{
  "access_token": "EAAA...",
  "location_id": "L...",
  "webhook_signature_key": "..."
}
```

Env vars: `SQUARE_ACCESS_TOKEN`, `SQUARE_LOCATION_ID`, `SQUARE_WEBHOOK_SIGNATURE_KEY`

### Wise — `yieldswarm/payments/wise`

```json
{
  "api_token": "...",
  "profile_id": "...",
  "webhook_public_key": "..."
}
```

### Web3 — `yieldswarm/payments/web3`

```json
{
  "hot_wallet_evm_private_key": "...",
  "hot_wallet_solana_secret_key": "...",
  "treasury_evm_address": "...",
  "treasury_solana_address": "..."
}
```

### Akash wallet — `yieldswarm/akash/wallet`

```json
{
  "key_name": "yieldswarm-admin",
  "mnemonic": "...",
  "owner_address": "akash1..."
}
```

### Akash deployment — `yieldswarm/akash/deployment`

```json
{
  "role_id": "...",
  "wrapped_secret_id": "...",
  "chain_id": "akashnet-2",
  "node": "https://rpc.akash.network:443"
}
```

### Tesla Fleet — `yieldswarm/integrations/tesla`

```json
{
  "client_id": "...",
  "client_secret": "...",
  "private_key_path": "/run/secrets/tesla-private-key.pem",
  "domain": "your-registered-domain.com",
  "region": "na"
}
```

### Multi-cloud — `yieldswarm/cloud/<provider>`

| Provider | Keys |
|----------|------|
| `aws` | `access_key_id`, `secret_access_key`, `region` |
| `azure` | `client_id`, `client_secret`, `tenant_id`, `subscription_id` |
| `gcp` | `project_id`, `credentials_json` |
| `runpod` | `api_key` |
| `vast` | `api_key` |
| `alibaba` | `access_key_id`, `access_key_secret` |

### Internal — `yieldswarm/internal/database` / `redis`

```json
// database
{ "url": "postgresql://...", "neon_project_id": "..." }

// redis
{ "url": "redis://...", "password": "..." }
```

---

### Treasury manifest — `yieldswarm/treasury/*` + `yieldswarm/iotex/*`

```json
// treasury/manifest
{
  "nexus_treasury_solana": "kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN",
  "treasury_manifest_path": "config/TREASURY_MANIFEST.json"
}

// treasury/mining_roots
{
  "base_etc": "0x3ec1...",
  "zec": "t1KC...",
  "tao": "5GwC...",
  "iotex": "0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567",
  "btc_via_iopay": "bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8"
}

// iotex/hub
{
  "primary": "0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567",
  "btc_bridge": "bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8"
}

// iotex/api
{ "api_key": "..." }
```

Policy: `vault/policies/treasury-runtime.hcl` · Canonical file: `config/TREASURY_MANIFEST.json`

---

## AppRoles and policies

| AppRole | Policy | Consumer |
|---------|--------|----------|
| `payments-runtime` | `payments-runtime` | Vercel payments app |
| `akash-runtime` | `akash-runtime` | Akash GPU workers |
| `multicloud-operator` | `multicloud-operator` | Ops hosts (Beefcake, CI burst) |
| `beefcake-runtime` | `beefcake-runtime` | AWS Beefcake 1 worker |
| `terraform` / `ci` | `terraform` / `ci` | Terraform plan/apply |
| `treasury-runtime` | `treasury-runtime` | Helix cross-chain + IoTeX relayer |

Mint wrapped SecretIDs:

```bash
./vault/scripts/issue-secret-id.sh multicloud-operator
./vault/scripts/issue-secret-id.sh beefcake-runtime
```

---

## Seeding

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_TOKEN=...   # admin — never commit

# From operator .env (see .env.example)
./vault/scripts/seed-secrets.sh
```

Re-runnable: only paths with env vars set are written.

---

## Beefcake 1 bootstrap

On AWS instance `i-0b078f1f51b4ec46c`:

```bash
scp -i YSHXYSRL255ascii.pem scripts/bootstrap-beefcake.sh ec2-user@18.218.5.137:~/
ssh -i YSHXYSRL255ascii.pem ec2-user@18.218.5.137 'chmod +x ~/bootstrap-beefcake.sh && ~/bootstrap-beefcake.sh'
```

Optional domain join after bootstrap:

```bash
./scripts/join-yieldswarm-internal.sh
```

---

## Related docs

- [`vault/README.md`](../vault/README.md) — bootstrap orchestration
- [`docs/VAULT_AKASH_RUNTIME.md`](VAULT_AKASH_RUNTIME.md) — Akash injection
- [`docs/MULTI_CLOUD_30DAY_PLAN.md`](MULTI_CLOUD_30DAY_PLAN.md) — cloud burst runbook
- [`SECRETS.md`](../SECRETS.md) — operator runbook
