# Akash Authentication — Keyring vs JWT

JWT tokens are **cryptographically signed with your private key**. This repo cannot generate them for you — you must run the commands locally in your Codespace or CI environment.

---

## Quick pick

| Path | When to use | Command |
|------|-------------|---------|
| **A — Keyring only** | First deploy, Codespaces, simplest | `bash scripts/akash-verify-setup.sh` then deploy |
| **B — JWT only** | CI/CD, no interactive keyring | `bash scripts/akash-generate-jwt.sh` |
| **C — Both** | Production flexibility | Keyring for txs, JWT for manifest in automation |

**Recommendation for GitHub Codespaces:** Start with **Option A** (`AKASH_KEYRING_BACKEND=test`).

> **Codespace JWT workflow:** See [`docs/AKASH_CODESPACE_JWT.md`](AKASH_CODESPACE_JWT.md) for secure generate → export → expiry → keyring fallback.

---

## Option A — Keyring only (simplest)

### 1. Load environment

```bash
source scripts/akash-env.sh
```

### 2. Verify setup

```bash
bash scripts/akash-verify-setup.sh
```

### 3. Deploy

```bash
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

With Vault runtime injection:

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<admin-token>
USE_VAULT_AKASH=1 ./deploy/scripts/akash-production-deploy.sh
```

**How it works:** `provider-services` v0.10+ auto-signs JWTs when you pass `--from $AKASH_KEY_NAME`. You do not need to manually generate a JWT for normal CLI deploys.

---

## Option B — Manual JWT (CI / automation)

### 1. Load environment

```bash
source scripts/akash-env.sh
export PATH="$PATH:$HOME/bin:/root/bin"
hash -r
```

### 2. Generate JWT (you sign with your key)

```bash
bash scripts/akash-generate-jwt.sh
```

Or manually:

```bash
provider-services tx auth generate-jwt \
  --from "$AKASH_KEY_NAME" \
  --chain-id "$AKASH_CHAIN_ID" \
  --node "$AKASH_NODE" \
  --keyring-backend "$AKASH_KEYRING_BACKEND" \
  --gas auto \
  --gas-adjustment 1.25 \
  --yes
```

### 3. Export the token

```bash
source .run/akash-jwt.env
# or:
export AKASH_JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
export AKASH_AUTH_METHOD=jwt
```

### 4. Deploy using JWT for manifest send

On-chain transactions (create deployment, create lease) still use the keyring. `send-manifest` uses `AKASH_JWT` when set:

```bash
AUTO_SELECT_BID=1 AKASH_AUTH_METHOD=jwt scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

**Important:** JWTs are short-lived (typically a few hours). Regenerate with `akash-generate-jwt.sh` when expired.

---

## Option C — Both methods (recommended for production)

```bash
# Always load env first
source scripts/akash-env.sh

# Verify wallet + RPC
bash scripts/akash-verify-setup.sh

# Default: keyring handles everything
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml

# When automating manifest sends in CI:
bash scripts/akash-generate-jwt.sh
source .run/akash-jwt.env
AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

---

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `AKASH_KEY_NAME` | `yieldswarm` | Wallet name in keyring |
| `AKASH_KEYRING_BACKEND` | `test` | `test` (Codespaces), `os` (prod desktop) |
| `AKASH_NODE` | `https://rpc.akashnet.net:443` | RPC endpoint |
| `AKASH_CHAIN_ID` | `akashnet-2` | Mainnet chain ID |
| `AKASH_JWT` | — | Pre-generated JWT for `send-manifest` |
| `AKASH_JWT_FILE` | `.run/akash-jwt.txt` | JWT file path |
| `AKASH_AUTH_METHOD` | `keyring` | `keyring` or `jwt` |

Set these in `deploy/config.env` (see `deploy/config.env.example`).

---

## Security notes

- **Never** commit mnemonics, private keys, or JWTs to git.
- **Never** paste your mnemonic or private key into chat or CI logs.
- Store wallet material in Vault (`yieldswarm/akash/runtime`) for production.
- Rotate JWTs regularly; treat them like short-lived API keys.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `key not found` | Import wallet: `provider-services keys add $AKASH_KEY_NAME --recover` |
| `insufficient funds` | Fund `AKASH_ACCOUNT_ADDRESS` with AKT |
| `no bids` | Raise uakt pricing in SDL or wait longer |
| JWT expired | Re-run `bash scripts/akash-generate-jwt.sh` |
| `generate-jwt` not found | Upgrade `provider-services` to v0.10+ or use Option A |
