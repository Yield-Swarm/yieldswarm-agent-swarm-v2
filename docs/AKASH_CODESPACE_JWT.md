# Akash JWT — Secure Codespace Workflow

Secure workflow for generating, exporting, expiring, and falling back to keyring auth in **GitHub Codespaces**.

> JWTs are signed with **your** private key. Never commit tokens, mnemonics, or keyring files.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Codespace session                                   │
│                                                             │
│  deploy/config.env  →  scripts/akash-env.sh                 │
│                              ↓                              │
│         ┌────────────────────┴────────────────────┐         │
│         ↓                                         ↓         │
│  akash-generate-jwt.sh                   keyring (default)  │
│         ↓                                         ↓         │
│  .run/akash-jwt.txt (600)              provider-services    │
│  .run/akash-jwt.env (600)              --from $KEY_NAME     │
│  .run/akash-jwt.meta.json                                   │
│         ↓                                         ↓         │
│  akash-jwt-ensure.sh ──expired?──→ keyring fallback         │
│         ↓                                                   │
│  akash-deploy.sh / akash-with-auth.sh                       │
└─────────────────────────────────────────────────────────────┘
```

All `.run/` artifacts are **gitignored** and **chmod 600**.

---

## One-time Codespace setup

```bash
# 1. Config
cp deploy/config.env.example deploy/config.env
$EDITOR deploy/config.env   # set AKASH_KEY_NAME, GHCR_OWNER, etc.

# 2. Import wallet (if not already done)
export AKASH_KEYRING_BACKEND=test   # recommended for Codespaces
provider-services keys add yieldswarm --recover

# 3. Verify
source scripts/akash-env.sh
bash scripts/akash-verify-setup.sh
```

---

## Workflow A — Keyring only (default, simplest)

No manual JWT. The CLI auto-signs when you pass `--from`.

```bash
source scripts/akash-env.sh
export AKASH_AUTH_METHOD=keyring

AUTO_SELECT_BID=1 scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

---

## Workflow B — JWT with secure export (automation / explicit control)

### Step 1 — Generate token

```bash
source scripts/akash-env.sh
bash scripts/akash-generate-jwt.sh
```

Underlying command (equivalent):

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

### Step 2 — Export into session (secure pattern)

**Do not** `export AKASH_JWT=eyJ...` by hand in shared logs. Use the export helper:

```bash
source scripts/akash-jwt-export.sh
# Sets AKASH_JWT from file, AKASH_AUTH_METHOD=jwt, prints prefix only
```

Or load the env file directly:

```bash
source .run/akash-jwt.env
```

### Step 3 — Check expiration

```bash
bash scripts/akash-jwt-status.sh
```

Output example:

```
Akash JWT status: valid
  expires_at=2026-06-15 14:30:00 UTC
  remaining=3420s (~57 min)
  action=ready
```

Status values:

| Status | Meaning | Action |
|--------|---------|--------|
| `valid` | Token OK | Deploy |
| `stale` | Expires within 5 min buffer | Deploy now or refresh |
| `expired` | Past `exp` claim | Regenerate or keyring fallback |
| `missing` | No token file | Generate or use keyring |
| `malformed` | Bad JWT structure | Regenerate |

### Step 4 — Deploy with auto-refresh + fallback

```bash
bash scripts/akash-with-auth.sh \
  scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

`akash-with-auth.sh` calls `akash-jwt-ensure.sh` which:
1. Uses valid/stale JWT
2. Regenerates if expired/missing
3. Falls back to `AKASH_AUTH_METHOD=keyring` if regeneration fails

---

## Workflow C — Force modes

```bash
# JWT only (fail if no valid token)
bash scripts/akash-with-auth.sh --jwt-only scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml

# Keyring only (ignore any stored JWT)
bash scripts/akash-with-auth.sh --keyring-only scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml
```

---

## Expiration handling

| Variable | Default | Purpose |
|----------|---------|---------|
| `AKASH_JWT_REFRESH_BUFFER_SECONDS` | `300` | Treat token as `stale` this many seconds before `exp` |

Refresh proactively:

```bash
bash scripts/akash-jwt-ensure.sh --refresh   # not in keyring-only mode
# or
bash scripts/akash-generate-jwt.sh
```

`akash-deploy.sh` automatically falls back to keyring for `send-manifest` when JWT is expired.

---

## Security rules

1. **Never commit** `.run/akash-jwt.*`, mnemonics, or `keyring-*` files
2. **Never paste** full JWTs into issues, Slack, or chat
3. **chmod 600** — enforced by `akash-generate-jwt.sh` on token files
4. **Short TTL** — regenerate every few hours; do not cache JWTs in Vault long-term
5. **Codespace keyring** — use `AKASH_KEYRING_BACKEND=test`; keys are ephemeral to the VM
6. **Production** — prefer Vault-injected secrets + `os` keyring on hardened hosts

---

## File reference

| File | Purpose |
|------|---------|
| `scripts/akash-env.sh` | Load deploy config + defaults |
| `scripts/akash-generate-jwt.sh` | Mint JWT, write `.run/` securely |
| `scripts/akash-jwt-export.sh` | Load JWT into env without logging it |
| `scripts/akash-jwt-status.sh` | Check expiry (no full token printed) |
| `scripts/akash-jwt-ensure.sh` | Valid JWT or refresh or keyring fallback |
| `scripts/akash-with-auth.sh` | Run any command with auth resolved |
| `scripts/lib/jwt-utils.sh` | Expiry parsing, secure write helpers |
| `scripts/lib/akash-auth.sh` | Flags for deploy commands |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `generate-jwt` not found | Upgrade `provider-services` or use keyring (`AKASH_AUTH_METHOD=keyring`) |
| JWT expired mid-deploy | Re-run with `akash-with-auth.sh` (auto-fallback) |
| Permission denied on `.run/` | `mkdir -p .run && chmod 700 .run` |
| Key not in keyring | `provider-services keys list --keyring-backend test` |

See also: `docs/AKASH_AUTH.md`
