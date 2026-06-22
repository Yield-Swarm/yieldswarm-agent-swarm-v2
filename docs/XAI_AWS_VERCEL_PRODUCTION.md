# AWS + Vercel Production — xAI Portfolio Architecture

High-density compute narrative for **Telegram Mini App (Vercel Edge)** + **VPC-isolated AWS Lambda settle engine (us-west-2)** + **ElastiCache Redis token bucket** + **TON mainnet RPC**.

## Topology

```
       +------------------------------------------------------+
       |                  TELEGRAM TMA FRONTEND               |
       |  Vercel Global Edge Network Deployment (Next.js App)  |
       +--------------------------+---------------------------+
                                  |
                   (Secure API Payload Exchanges)
                                  |
       +--------------------------v---------------------------+
       |                  VPC ISOLATED BACKEND                |
       |  Multi-AZ AWS Lambda Execution & Core State Manager  |
       +-------------------+------------------------------+---+
                           |                              |
           (Private IAM Database Access)          (JSON-RPC State Queries)
                           |                              |
       +-------------------v-------------------+  +-------v-----------+
       |      AMAZON ELASTICACHE REDIS         |  |   TON MAINNET     |
       |  Atomic Token Bucket Rate Limiter    |  |   RPC BINDINGS    |
       +---------------------------------------+  +-------------------+
```

## Statement of exceptional work (xAI matrix)

| Property | Implementation |
|----------|----------------|
| **Computational density** | ARM64 Lambda 512MB, warm-path Redis eval, single-cell TON BOC output |
| **Resource isolation** | Private subnets + NAT, Lambda SG → Redis SG only on 6379 |
| **State authority** | Fixed-point $10^9$ nano arithmetic — no float in reward path |
| **Operational telemetry** | Structured JSON logs + CloudWatch alarms (5xx, throttles) |

### Precision-safe fixed-point (10⁹ scale)

IEEE 754 drift eliminated. See `deploy/aws/ton-settle-engine/lib/fixedPoint.js`.

$$\text{reward} = \min\left(\frac{k \cdot L \cdot \Delta t \cdot 10^9}{1000}, 500 \cdot 10^9\right)$$

where $k = \lfloor \text{baseFactor} \cdot 1000 \rfloor$, $L$ = enemy level, $\Delta t \in [1, 3600]$.

### Atomic rate limiting (Sybil defense)

Lua token-bucket script executed atomically in Redis (`lib/tokenBucket.lua`). Non-blocking reject → HTTP 429.

### Asynchronous cryptographic authentication

Zod-validated payloads. Optional on-chain `get_last_save` RPC temporal check. Ed25519 sign over TVM cell hash via `@ton/crypto`.

## Repository layout

| Path | Role |
|------|------|
| `deploy/aws/ton-settle-engine/handler.js` | Lambda compute worker |
| `deploy/aws/ton-settle-engine/template.yaml` | Multi-AZ SAM (VPC, Redis, API Gateway) |
| `deploy/aws/ton-settle-engine/lib/fixedPoint.js` | Integer reward engine |
| `scripts/deploy-aws-ton-settle.sh` | One-command SAM deploy |
| `vercel.json` | Edge frontend routes |

## Deploy

### AWS (us-west-2)

```bash
# Seed signer secret (32-byte hex) — never commit
aws secretsmanager put-secret-value \
  --secret-id yieldswarm/production/ton-ed25519-signer \
  --secret-string '{"SERVER_ED25519_PRIVATE_KEY":"YOUR_64_HEX_CHARS"}'

export AWS_REGION=us-west-2
export CORS_ORIGIN=https://yieldswarm.crypto
chmod +x scripts/deploy-aws-ton-settle.sh
./scripts/deploy-aws-ton-settle.sh
```

### Vercel (TMA frontend)

```bash
# Set in Vercel project → Environment Variables
NEXT_PUBLIC_TON_SETTLE_API_URL=https://<api-id>.execute-api.us-west-2.amazonaws.com/production/v1/compute/allocate
```

### Tests

```bash
cd deploy/aws/ton-settle-engine && npm test
```

## CloudWatch metrics (portfolio quant)

Track for xAI / infra narrative:

| Metric | Namespace | Use |
|--------|-----------|-----|
| `Count` | `AWS/ApiGateway` | Invocation spikes under load |
| `5XXError` | `AWS/ApiGateway` | Error mitigation story |
| `Throttles` | `AWS/Lambda` | Concurrency saturation |
| `Duration` | `AWS/Lambda` | p99 latency |

Alarms defined in `template.yaml` (`ApiGateway5xxAlarm`, `LambdaThrottleAlarm`).

## API contract

`POST /v1/compute/allocate`

```json
{
  "walletAddress": "EQ...",
  "actionData": {
    "baseFactor": 1.25,
    "enemyLevel": 12,
    "deltaTime": 120
  }
}
```

Response: `{ "success", "tokensAllocated", "bocPayload", "epochSeconds" }`

## Related

- [`ARCHITECTURE_FULL.md`](ARCHITECTURE_FULL.md) — full YieldSwarm + Kairo stack
- [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md) — production env + traffic
