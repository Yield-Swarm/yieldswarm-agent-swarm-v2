import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { reserveWithdrawal, completeWithdrawal, refundWithdrawal } from "@/lib/ledger";
import { withdrawCrypto } from "@/lib/web3/withdraw";
import { findAsset } from "@/lib/web3/chains";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  chain: z.enum(["evm", "solana", "ton"]),
  asset: z.string().min(2).max(12),
  amount: z.string().regex(/^\d+(\.\d+)?$/),
  toAddress: z.string().min(4),
  evmChainId: z.number().int().optional(),
});

/** Off-ramp: withdraw crypto to any wallet address. */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const { chain, asset, amount, toAddress, evmChainId } = body.data;

  if (!findAsset(chain, asset, evmChainId)) {
    return fail(`Unsupported asset ${asset} on ${chain}`, 400);
  }

  const reserved = await reserveWithdrawal({
    userId: auth.user.id,
    rail: "web3",
    amount,
    currency: asset,
    chain,
    metadata: { toAddress, evmChainId },
  });
  if ("error" in reserved) return fail(reserved.error, 400);
  const { tx } = reserved;

  try {
    const result = await withdrawCrypto({
      chain,
      to: toAddress,
      amount,
      assetSymbol: asset,
      evmChainId,
    });
    const completed = await completeWithdrawal(tx.id, {
      externalId: result.txHash,
      metadata: { explorerUrl: result.explorerUrl },
    });
    return ok({ transaction: completed, result });
  } catch (err) {
    await refundWithdrawal(tx.id, (err as Error).message);
    return fail((err as Error).message || "Crypto withdrawal failed", 502);
  }
}
