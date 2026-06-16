/**
 * Cross-chain DEX adapter — Jupiter (Solana) + Uniswap V4 hook (EVM) MVP.
 */

import { splitAmount } from '../lib/great-delta-split.js';
import config from '../config.js';
import { fetchJson } from '../lib/http.js';

const SOL_MINT = 'So11111111111111111111111111111111111111112';
const USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

function jupiterHeaders() {
  const headers = { Accept: 'application/json' };
  if (config.dex.jupiterApiKey) {
    headers['x-api-key'] = config.dex.jupiterApiKey;
  }
  return headers;
}

function attachTreasurySplit(payload, grossUsd, source) {
  const split = splitAmount(grossUsd);
  return {
    ...payload,
    great_delta: {
      source,
      gross_revenue_usd: grossUsd,
      buckets: Object.fromEntries(split.map((row) => [row.bucket, row.amount])),
      split,
    },
  };
}

export async function getDexHealth() {
  const jupiterConfigured = Boolean(config.dex.jupiterApiKey || config.solana.rpcUrl);
  let jupiterLive = false;
  try {
    const quote = await quoteJupiter({
      inputMint: SOL_MINT,
      outputMint: USDC_MINT,
      amount: '1000000',
    });
    jupiterLive = quote.ok === true;
  } catch {
    jupiterLive = false;
  }

  let uniswapLive = false;
  if (config.dex.uniswapV4PoolManager && config.dex.evmRpcUrl) {
    try {
      const body = await fetchJson(config.dex.evmRpcUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          id: 1,
          method: 'eth_getCode',
          params: [config.dex.uniswapV4PoolManager, 'latest'],
        }),
        timeoutMs: config.upstreamTimeoutMs,
      });
      const code = body?.result || '0x';
      uniswapLive = code !== '0x' && code !== '0x0';
    } catch {
      uniswapLive = false;
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    services: {
      jupiter: { configured: jupiterConfigured, live: jupiterLive },
      uniswap_v4: {
        configured: Boolean(config.dex.uniswapV4PoolManager || config.dex.uniswapV4HookAddress),
        live: uniswapLive,
      },
    },
    configured_count: [jupiterConfigured, config.dex.uniswapV4PoolManager].filter(Boolean).length,
    live_count: [jupiterLive, uniswapLive].filter(Boolean).length,
  };
}

export async function quoteJupiter({ inputMint, outputMint, amount, slippageBps }) {
  const params = new URLSearchParams({
    inputMint,
    outputMint,
    amount: String(amount),
    slippageBps: String(slippageBps ?? config.dex.slippageBps),
    swapMode: 'ExactIn',
  });
  const url = `${config.dex.jupiterBaseUrl}/quote?${params}`;
  try {
    const quote = await fetchJson(url, { headers: jupiterHeaders(), timeoutMs: config.upstreamTimeoutMs });
    const inAmount = Number(quote.inAmount || amount);
    const outAmount = Number(quote.outAmount || 0);
    const estFeeUsd = outAmount > 0 ? outAmount / 1_000_000 * 0.001 : 0;
    return attachTreasurySplit(
      {
        ok: true,
        provider: 'jupiter',
        inputMint,
        outputMint,
        inAmount,
        outAmount,
        priceImpactPct: Number(quote.priceImpactPct || 0),
        routePlanSteps: (quote.routePlan || []).length,
        quote,
      },
      estFeeUsd,
      'jupiter_quote',
    );
  } catch (err) {
    return { ok: false, provider: 'jupiter', error: err.message || 'jupiter quote failed' };
  }
}

export async function quoteUniswapV4(body = {}) {
  const {
    tokenIn = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    tokenOut = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    amountInWei = '1000000000000000',
    bidder = '0x0000000000000000000000000000000000000001',
    poolId = '0x' + '11'.repeat(32),
  } = body;

  const bid = BigInt(amountInWei);
  const clearing = bid / 100n;
  const won = bid >= clearing * 2n;
  const estFeeUsd = Number(clearing) / 1e18 * 2500 * 0.003;

  return attachTreasurySplit(
    {
      ok: true,
      provider: 'uniswap_v4_hook',
      poolId,
      tokenIn,
      tokenOut,
      amountInWei: String(amountInWei),
      bidder,
      clearingPriceWei: String(clearing),
      wonAuction: won,
      nextAction: won ? 'execute_swap' : 'rebid_or_wait',
      hookAddress: config.dex.uniswapV4HookAddress || null,
      poolManager: config.dex.uniswapV4PoolManager || null,
    },
    estFeeUsd,
    'uniswap_v4_auction',
  );
}

export async function executeDexSwap(body = {}) {
  const dryRun = body.dry_run !== false;
  if (dryRun) {
    return {
      status: 'dry_run',
      message: 'DEX swap prepared — set dry_run=false and wallet SDK to broadcast.',
      data: body,
    };
  }
  return {
    status: 'adapter_missing',
    message: 'Wire YIELDSWARM_UNIFIED_WALLET_SDK_MODULE or YIELDSWARM_DEX_API_URL execute path.',
    data: body,
  };
}
