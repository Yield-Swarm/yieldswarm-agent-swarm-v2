# YieldSwarm Vault Layer

Production HashiCorp Vault integration for YieldSwarm AgentSwarm OS.

## Layout

```
infra/vault/
├── config/                Vault server HCL configs (HA Raft + TLS)
├── policies/              ACL policies (least-privilege per consumer)
├── scripts/               Idempotent bootstrap / rotation scripts
└── agent/                 Vault Agent templates for sidecar/init use
```

## Consumers

| Consumer            | Auth method | Policy                | Source of credentials                       |
|---------------------|-------------|-----------------------|---------------------------------------------|
| Operator (human)    | OIDC/token  | `operator`            | Personal token via OIDC                     |
| Terraform / CI      | AppRole     | `terraform-cicd`      | `VAULT_ROLE_ID` + response-wrapped secret_id|
| Akash workload      | AppRole     | `akash-runtime`       | Role_id baked into image; wrapped secret_id |
| In-cluster agents   | AppRole     | `agent-readonly`      | Periodic token, renewed by Vault Agent      |
| Break-glass admin   | Token       | `admin`               | Root-shielded, audit-logged                 |

All policies are scoped to `kv/data/yieldswarm/<env>/...` paths so non-prod
credentials can never be read by prod consumers and vice-versa.

## Secret layout (KV v2 @ `kv/`)

```
kv/data/yieldswarm/<env>/azure          { client_id, client_secret, tenant_id, subscription_id, ... }
kv/data/yieldswarm/<env>/runpod         { api_key, pod_template_id }
kv/data/yieldswarm/<env>/vultr          { api_key, region, plan }
kv/data/yieldswarm/<env>/digitalocean   { token, spaces_access_key, spaces_secret_key }
kv/data/yieldswarm/<env>/rpc/solana     { url, helius_api_key, jupiter_api_key, birdeye_api_key, raydium_api_key }
kv/data/yieldswarm/<env>/rpc/eth        { mainnet_url, sepolia_url, bundler_url }
kv/data/yieldswarm/<env>/rpc/ton        { url, api_key }
kv/data/yieldswarm/<env>/rpc/tao        { url, subnet_key }
kv/data/yieldswarm/<env>/akash          { wallet_mnemonic, keyring_passphrase, provider_uri, chain_id }
kv/data/yieldswarm/<env>/app/agentswarm { master_key, kimiclaw_key, grok_api_key, openai_api_key, ... }
```

## Transit engine (encryption-as-a-service)

`transit/keys/wallet-encryption`, `transit/keys/db-encryption`,
`transit/keys/tee-signing` (ed25519).  Application code never sees raw key
material.

## Bootstrap

See `../../SECRETS.md` for the end-to-end commands.  Short version:

```bash
cd infra/vault/scripts
./10-init-unseal.sh        # init + unseal (records key shares to TEE)
./20-enable-engines.sh     # kv v2, transit, approle, audit
./30-apply-policies.sh
./40-enable-auth.sh
./50-seed-secrets.sh       # pulls plaintext from $SECRETS_BUNDLE (air-gapped)
```
