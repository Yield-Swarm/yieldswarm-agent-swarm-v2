import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { serverEnv } from "@/lib/config/env";
import { createDepositIntent } from "@/lib/web3/intents";
import { findAsset } from "@/lib/web3/chains";
import { Chain } from "@/lib/db/models";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  chain: z.enum(["evm", "solana", "ton"]),
  asset: z.string().min(2).max(12),
  evmChainId: z.number().int().optional(),
  expectedAmount: z
    .string()
    .regex(/^\d+(\.\d+)?$/)
    .optional(),
});

function treasuryFor(chain: Chain): string | null {
  if (chain === "evm") return serverEnv.web3.treasury.evm() || null;
  if (chain === "solana") return serverEnv.web3.treasury.solana() || null;
  return serverEnv.web3.treasury.ton() || null;
}

/**
 * Start an on-chain (Web3) deposit. We return the treasury address the user
 * should send funds to plus an intent id; the client later calls /verify with
 * the resulting tx hash so we can detect and credit it.
 */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const { chain, asset, evmChainId, expectedAmount } = body.data;

  if (!findAsset(chain, asset, evmChainId)) {
    return fail(`Unsupported asset ${asset} on ${chain}`, 400);
  }
  const depositAddress = treasuryFor(chain);
  if (!depositAddress) {
    return fail(`Treasury address for ${chain} is not configured`, 503);
  }

  const intent = await createDepositIntent({
    userId: auth.user.id,
    chain,
    asset,
    depositAddress,
    expectedAmount,
  });

  return ok({
    intent,
    depositAddress,
    asset: asset.toUpperCase(),
    chain,
    evmChainId,
    minConfirmations: serverEnv.web3.confirmations(),
    instructions: `Send ${asset.toUpperCase()} to ${depositAddress}, then submit the transaction hash to confirm your deposit.`,
  });
}
