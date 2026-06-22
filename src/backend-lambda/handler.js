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

let redis = null;
let secretsClient = null;
/** @type {Buffer | null} */
let cachedSignerSeed = null;

async function bootstrapContext() {
  if (!secretsClient) {
    secretsClient = new SecretsManagerClient({});
  }
  if (!redis) {
    redis = new Redis({
      host: process.env.REDIS_HOST,
      port: parseInt(process.env.REDIS_PORT || '6379', 10),
      connectTimeout: 2000,
      maxRetriesPerRequest: 1,
    });
  }
  if (!cachedSignerSeed) {
    const rawSecret = await secretsClient.send(
      new GetSecretValueCommand({ SecretId: process.env.SECRETS_ARN }),
    );
    const keyData = JSON.parse(rawSecret.SecretString || '{}');
    const hex = keyData.SERVER_ED25519_PRIVATE_KEY;
    if (!hex) throw new Error('SERVER_ED25519_PRIVATE_KEY missing in Secrets Manager');
    cachedSignerSeed = Buffer.from(String(hex).replace(/^0x/, ''), 'hex');
    if (cachedSignerSeed.length !== 32) throw new Error('Ed25519 seed must be 32 bytes');
  }
}

/**
 * PlayerSBT on-chain state — getCharacterState getter (server-authoritative Δt).
 * @param {string} walletAddress
 * @returns {Promise<{ lastSaveEpoch: number | null; enemyLevel: number | null }>}
 */
async function fetchCharacterState(walletAddress) {
  const rpc = process.env.TON_RPC_URL;
  const contract = process.env.PLAYER_SBT_CONTRACT;
  if (!rpc || !contract) return { lastSaveEpoch: null, enemyLevel: null };

  try {
    const res = await fetch(rpc, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: 1,
        jsonrpc: '2.0',
        method: 'runGetMethod',
        params: {
          address: contract,
          method: 'getCharacterState',
          stack: [{ type: 'slice', cell: walletAddress }],
        },
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return { lastSaveEpoch: null, enemyLevel: null };
    const body = await res.json();
    const stack = body?.result?.stack;
    if (!Array.isArray(stack) || stack.length < 2) {
      return await fetchCharacterStateFallback(walletAddress);
    }
    const lastSaveEpoch = parseStackInt(stack[0]);
    const enemyLevel = parseStackInt(stack[1]);
    return { lastSaveEpoch, enemyLevel };
  } catch {
    return fetchCharacterStateFallback(walletAddress);
  }
}

async function fetchCharacterStateFallback(walletAddress) {
  const rpc = process.env.TON_RPC_URL;
  if (!rpc) return { lastSaveEpoch: null, enemyLevel: null };
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
    if (!res.ok) return { lastSaveEpoch: null, enemyLevel: null };
    const body = await res.json();
    return { lastSaveEpoch: parseStackInt(body?.result?.stack?.[0]), enemyLevel: null };
  } catch {
    return { lastSaveEpoch: null, enemyLevel: null };
  }
}

function parseStackInt(entry) {
  if (!entry) return null;
  const raw = Array.isArray(entry) ? entry[1] : entry;
  const n = parseInt(String(raw).replace(/^0x/, ''), 10);
  return Number.isFinite(n) ? n : null;
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

exports.claimReward = async (event) => {
  const startMs = Date.now();
  try {
    await bootstrapContext();
    const requestData = JSON.parse(event.body || '{}');
    const { walletAddress, actionData } = PayloadValidator.parse(requestData);

    const nowSeconds = Math.floor(Date.now() / 1000);
    const rateLimitKey = `ratelimit:${walletAddress}`;

    const executionTokenGranted = await redis.eval(
      LUA_TOKEN_BUCKET,
      1,
      rateLimitKey,
      String(process.env.RATE_LIMIT_MAX_TOKENS || '5'),
      String(process.env.RATE_LIMIT_REFILL_PER_SEC || '0.0166'),
      String(nowSeconds),
    );

    if (executionTokenGranted !== 1) {
      console.warn(JSON.stringify({ metric: 'rate_limit_reject', wallet: walletAddress }));
      return jsonResponse(429, { error: 'Rate limit saturated. Execution denied.' });
    }

    const onChain = await fetchCharacterState(walletAddress);
    if (onChain.lastSaveEpoch != null) {
      const chainDelta = nowSeconds - onChain.lastSaveEpoch;
      const tolerance = parseInt(process.env.CHAIN_DELTA_TOLERANCE_SEC || '120', 10);
      if (chainDelta < 0 || Math.abs(chainDelta - actionData.deltaTime) > tolerance) {
        return jsonResponse(400, {
          error: 'On-chain temporal delta mismatch (untrusted client rejected).',
          chainDelta,
          claimedDelta: actionData.deltaTime,
        });
      }
    }
    if (onChain.enemyLevel != null && onChain.enemyLevel !== actionData.enemyLevel) {
      return jsonResponse(400, {
        error: 'On-chain enemy level mismatch.',
        chainLevel: onChain.enemyLevel,
        claimedLevel: actionData.enemyLevel,
      });
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
        metric: 'claim_reward_ok',
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
        metric: 'claim_reward_fault',
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

exports.processComputeAllocation = exports.claimReward;
exports.handler = exports.claimReward;
