# AWS + Vercel Production — xAI Engineering Narrative

Bridges **optimistic Next.js TMA client** → **server-authoritative AWS Lambda** → **ElastiCache Serverless Redis** → **TON PlayerSBT attestation**.

## Core engineering narrative (xAI hook)

This system solves the disconnect between rapid client interaction and secure blockchain settlement.

```
+--------------------------------------------------------+
|                   Next.js Client (TMA)                 |
|             Optimistic Local State Update              |
+---------------------------+----------------------------+
                            |
           Secure REST Payload (Zod Schema Guard)
                            |
+---------------------------v----------------------------+
|             Multi-AZ AWS Lambda Execution              |
|        - Serverless Rate Limiter Validation            |
|        - On-Chain Verification via TON RPC             |
|        - Fixed-Point BigInt Reward Computation         |
+---------------------+----------------------------+-----+
                      |                            |
       Private IAM Access Pipeline        JSON-RPC Sync Loop
                      |                            |
+---------------------v--------------------+  +----v-----+
|       Amazon ElastiCache Serverless      |  | TON Node |
|  Redis Hash Token Bucket (Anti-Sybil)   |  | Network  |
+------------------------------------------+  +----------+
```

| Property | Implementation |
|----------|----------------|
| **Fixed-point 10⁹ math** | `src/backend-lambda/lib/fixedPoint.js` — BigInt only |
| **Atomic rate limiting** | Lua script in ElastiCache Serverless |
| **State attestation** | `getCharacterState` on PlayerSBT via TON RPC; client params untrusted |
| **Secrets isolation** | VPC interface endpoint → Secrets Manager (no NAT for signing keys) |
| **Telemetry** | `deploy-telemetry.js` → CloudWatch dashboard + SAM alarms |

## Code layout

| Path | Role |
|------|------|
| `src/backend-lambda/handler.js` | `claimReward` — authoritative execution core |
| `src/backend-lambda/lib/` | fixedPoint + tokenBucket.lua |
| `deploy/aws/ton-settle-engine/template.yaml` | Multi-AZ SAM — VPC, Serverless Redis, VPC endpoints |
| `deploy/aws/ton-settle-engine/deploy-telemetry.js` | CloudWatch dashboard provisioner |
| `scripts/deploy-aws-ton-settle.sh` | Build + deploy + telemetry |

## Deploy pipeline

```bash
# 1. Dependencies
cd src/backend-lambda && npm ci --omit=dev && npm test

# 2. Signer secret (32-byte hex)
aws secretsmanager put-secret-value \
  --region us-west-2 \
  --secret-id ton-mmorpg-production-signer \
  --secret-string '{"SERVER_ED25519_PRIVATE_KEY":"YOUR_64_HEX"}'

# 3. Stack + dashboard
export AWS_REGION=us-west-2
export PLAYER_SBT_CONTRACT=EQ...   # PlayerSBT mainnet address
export CORS_ORIGIN=https://yieldswarm.crypto
chmod +x scripts/deploy-aws-ton-settle.sh
./scripts/deploy-aws-ton-settle.sh

# 4. Vercel TMA
NEXT_PUBLIC_TON_SETTLE_API_URL=<ClaimEndpoint from stack output>
```

Manual SAM:

```bash
cd deploy/aws/ton-settle-engine
sam build && sam deploy --guided
LAMBDA_FUNCTION_NAME=AuthoritativePoE-production npm run telemetry
```

## API

`POST /api/claim` (alias: `/v1/compute/allocate`)

```json
{
  "walletAddress": "EQ...",
  "actionData": { "baseFactor": 1.2, "enemyLevel": 8, "deltaTime": 90 }
}
```

## Vercel env

```bash
NEXT_PUBLIC_TON_SETTLE_API_URL=https://<api-id>.execute-api.us-west-2.amazonaws.com/production/api/claim
PLAYER_SBT_CONTRACT=EQ...
```

## Portfolio metrics (CloudWatch)

- API Gateway `Count`, `4XXError`, `5XXError`
- Lambda `Duration` p99, `Errors`, `Throttles`, `Invocations`

Dashboard: `TON_MMORPG_Compute_Telemetry`

## Related

- [`ARCHITECTURE_FULL.md`](ARCHITECTURE_FULL.md)
- [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md)
