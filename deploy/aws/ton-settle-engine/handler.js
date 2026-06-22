const fs = require('node:fs');
const path = require('node:path');
const { Redis } = require('ioredis');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { z } = require('zod');
const { beginCell, Address } = require('@ton/ton');
const { keyPairFromSeed, sign } = require('@ton/crypto');
const { computeRewardAllocation } = require('./lib/fixedPoint');

const PayloadValidator = z.object({
  walletAddress: z.string().regex(/^(EQ|UQ)[a-zA-Z0-9_-]{46}$/),
  actionData: z.object({
    baseFactor: z.number().positive(),
    enemyLevel: z.number().int().positive(),
    deltaTime: z.number().int().nonnegative(),
  }),
});

const LUA_TOKEN_BUCKET = fs.readFileSync(path.join(__dirname, 'lib', 'tokenBucket.lua'), 'utf8');

let redisInstance = null;
let secretsManagerClient = null;
/** @type {Buffer | null} */
let cachedSignerSeed = null;

async function coldStartBootstrap() {
  if (!secretsManagerClient) {
    secretsManagerClient = new SecretsManagerClient({ region: process.env.AWS_REGION });
  }
  if (!redisInstance) {
    redisInstance = new Redis({
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379', 10),
      connectTimeout: 2000,
      maxRetriesPerRequest: 1,
    });
  }
  if (!cachedSignerSeed) {
    const rawSecret = await secretsManagerClient.send(
      new GetSecretValueCommand({ SecretId: process.env.SECRETS_ARN }),
    );
    const keyData = JSON.parse(rawSecret.SecretString || '{}');
    const hex = keyData.SERVER_ED25519_PRIVATE_KEY || keyData.ed25519_seed_hex;
    if (!hex || typeof hex !== 'string') {
      throw new Error('SERVER_ED25519_PRIVATE_KEY missing in Secrets Manager payload');
    }
    cachedSignerSeed = Buffer.from(hex.replace(/^0x/, ''), 'hex');
    if (cachedSignerSeed.length !== 32) {
      throw new Error('Ed25519 seed must be 32 bytes');
    }
  }
}

/**
 * Optional on-chain last-save validation (TON JSON-RPC).
 * @param {string} walletAddress
 * @returns {Promise<number | null>}
 */
async function fetchOnChainLastSaveEpoch(walletAddress) {
  const rpc = process.env.TON_RPC_URL;
  if (!rpc) return null;
  try {
    const res = await fetch(rpc, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: 1,
        jsonrpc: '2.0',
        method: 'runGetMethod',
        params: { address: walletAddress, method: 'get_last_save', stack: [] },
      }),
      signal: AbortSignal.timeout(4000),
    });
    if (!res.ok) return null;
    const body = await res.json();
    const stack = body?.result?.stack;
    if (!Array.isArray(stack) || !stack[0]) return null;
    const val = stack[0][1] ?? stack[0];
    return parseInt(String(val), 10) || null;
  } catch {
    return null;
  }
}

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || '*',
    },
    body: JSON.stringify(payload),
  };
}

exports.processComputeAllocation = async (event) => {
  const startMs = Date.now();
  try {
    await coldStartBootstrap();

    const requestData = JSON.parse(event.body || '{}');
    const { walletAddress, actionData } = PayloadValidator.parse(requestData);

    const nowSeconds = Math.floor(Date.now() / 1000);
    const rateLimitKey = `ratelimit:${walletAddress}`;

    const executionTokenGranted = await redisInstance.eval(
      LUA_TOKEN_BUCKET,
      1,
      rateLimitKey,
      String(process.env.RATE_LIMIT_MAX_TOKENS || '5'),
      String(process.env.RATE_LIMIT_REFILL_PER_SEC || '0.0166'),
      String(nowSeconds),
    );

    if (executionTokenGranted !== 1) {
      console.warn(JSON.stringify({ metric: 'rate_limit_reject', wallet: walletAddress }));
      return jsonResponse(429, {
        error: 'Rate limit saturation detected. Security boundaries active.',
      });
    }

    const onChainLast = await fetchOnChainLastSaveEpoch(walletAddress);
    if (onChainLast != null) {
      const chainDelta = nowSeconds - onChainLast;
      if (chainDelta < 0 || Math.abs(chainDelta - actionData.deltaTime) > 120) {
        return jsonResponse(400, { error: 'On-chain temporal delta mismatch (Sybil defense).' });
      }
    }

    const finalRewardAllocation = computeRewardAllocation(actionData);
    const keyPair = keyPairFromSeed(cachedSignerSeed);

    const cellSpecification = beginCell()
      .storeAddress(Address.parse(walletAddress))
      .storeUint(nowSeconds, 32)
      .storeCoins(finalRewardAllocation)
      .endCell();

    const secureSignature = sign(cellSpecification.hash(), keyPair.secretKey);

    const binaryDeliveryEnvelope = beginCell()
      .storeBuffer(secureSignature)
      .storeRef(cellSpecification)
      .endCell();

    console.log(
      JSON.stringify({
        metric: 'compute_allocation_ok',
        wallet: walletAddress,
        tokens: finalRewardAllocation.toString(),
        latencyMs: Date.now() - startMs,
      }),
    );

    return jsonResponse(200, {
      success: true,
      tokensAllocated: finalRewardAllocation.toString(),
      bocPayload: binaryDeliveryEnvelope.toBoc().toString('base64'),
      epochSeconds: nowSeconds,
    });
  } catch (executionFault) {
    console.error(
      JSON.stringify({
        metric: 'compute_allocation_fault',
        error: executionFault instanceof Error ? executionFault.message : String(executionFault),
        latencyMs: Date.now() - startMs,
      }),
    );
    if (executionFault instanceof z.ZodError) {
      return jsonResponse(400, { error: executionFault.flatten() });
    }
    return jsonResponse(500, {
      error: executionFault instanceof Error ? executionFault.message : 'Internal compute pipeline exception.',
    });
  }
};

/** API Gateway HTTP API entry */
exports.handler = async (event) => exports.processComputeAllocation(event);
