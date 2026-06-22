# Marketing Vault Integration — Christopher's First App

Wire **Moltbook + Reddit + X.com + Email (Resend) + Twilio** into the Next.js TypeScript stack. Credentials live in HashiCorp Vault under `yieldswarm/data/marketing/*` (same mount as Alchemy).

## Vault paths

| Platform | Vault path (`vault kv put yieldswarm/...`) | Keys |
|----------|--------------------------------------------|------|
| Moltbook | `marketing/moltbook` | `api_key`, `default_channel` |
| Reddit | `marketing/reddit` | `client_id`, `client_secret`, `refresh_token`, `user_agent` |
| X.com | `marketing/x-twitter` | `bearer_token` or OAuth `api_key`, `api_secret`, `access_token`, `access_secret` |
| Email | `marketing/email` | `api_key` (Resend), `from_address`, `from_name` |
| Twilio | `marketing/twilio` | `account_sid`, `auth_token`, `from_number` |

## Seed from env

```bash
export VAULT_ADDR=...
export VAULT_TOKEN=...
export MOLTBOOK_API_KEY=moltdev_...
export REDDIT_CLIENT_ID=...
export REDDIT_CLIENT_SECRET=...
export REDDIT_REFRESH_TOKEN=...
export X_TWITTER_BEARER_TOKEN=...
export RESEND_API_KEY=re_...
export EMAIL_FROM_ADDRESS=campaigns@yieldswarm.io
export TWILIO_ACCOUNT_SID=...
export TWILIO_AUTH_TOKEN=...
export TWILIO_FROM_NUMBER=+1...
./vault/scripts/seed-secrets.sh
```

Policy: `vault/policies/marketing-runtime.hcl` (AppRole read on `marketing/*`).

## TypeScript layout

| File | Role |
|------|------|
| `src/lib/vault/client.ts` | AppRole + KV v2 read |
| `src/lib/vault/marketingVault.ts` | `getMarketingSecret(platform)` |
| `src/lib/marketing/marketingService.ts` | Unified multi-platform campaigns |
| `src/lib/marketing/*Client.ts` | Per-platform clients with retries |
| `src/app/api/integrations/marketing/health` | Operator health pane |
| `src/app/api/integrations/marketing/campaign` | POST multi-blast |

## API

```bash
# Health (configured platforms, Vault status)
curl -s http://localhost:3000/api/integrations/marketing/health | jq

# Dry-run campaign (default outside production)
curl -s -X POST http://localhost:3000/api/integrations/marketing/campaign \
  -H 'Content-Type: application/json' \
  -d '{
    "platforms": ["moltbook", "x-twitter"],
    "message": { "text": "YieldSwarm is live — mine with us." },
    "dryRun": true
  }' | jq
```

## Environment fallbacks

When `VAULT_ADDR` is unset, secrets load from env (see `.env.example` marketing section). Explicit env values are merged under Vault reads when both are present.

| Env var | Platform |
|---------|----------|
| `MOLTBOOK_API_KEY` | Moltbook |
| `REDDIT_*` | Reddit |
| `X_TWITTER_*` | X.com |
| `RESEND_API_KEY`, `EMAIL_FROM_ADDRESS` | Email |
| `TWILIO_*` | Twilio |

`MARKETING_DRY_RUN=true` (default in dev) prevents live posts until you set `MARKETING_DRY_RUN=0` in production.

## Libraries

- Moltbook — `axios` REST
- Reddit — `snoowrap`
- X.com — `twitter-api-v2`
- Email — `resend`
- Twilio — `twilio`

Apply for Moltbook dev access at [moltbook.com/developers](https://moltbook.com/developers).
