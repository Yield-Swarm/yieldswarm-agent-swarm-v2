import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { detectDeposit } from "@/lib/web3/deposit-detection";
import {
  getDepositIntent,
  updateDepositIntent,
  isTerminal,
} from "@/lib/web3/intents";
import {
  createTransaction,
  findByExternalId,
  updateTransactionStatus,
} from "@/lib/ledger";
import { Chain } from "@/lib/db/models";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  txHash: z.string().min(8),
  // Either reference an intent, or pass chain/asset directly.
  intentId: z.string().optional(),
  chain: z.enum(["evm", "solana", "ton"]).optional(),
  asset: z.string().min(2).max(12).optional(),
  evmChainId: z.number().int().optional(),
});

/**
 * Verify a Web3 deposit: independently confirm the on-chain transfer to our
 * treasury and, once it has enough confirmations, credit the user's balance
 * exactly once (idempotent on the tx hash).
 */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const { txHash, intentId, evmChainId } = body.data;

  let chain: Chain | undefined = body.data.chain;
  let asset: string | undefined = body.data.asset;
  let evmChainIdResolved = evmChainId;

  if (intentId) {
    const intent = await getDepositIntent(intentId);
    if (!intent || intent.userId !== auth.user.id) return fail("Intent not found", 404);
    if (isTerminal(intent.status)) {
      return ok({ status: intent.status, alreadyProcessed: true, intent });
    }
    chain = intent.chain;
    asset = intent.asset;
  }

  if (!chain || !asset) {
    return fail("Provide intentId or both chain and asset", 400);
  }

  // Idempotency: if we already credited this tx hash, return the existing tx.
  const existing = await findByExternalId("web3", txHash);
  if (existing && existing.status === "completed") {
    return ok({ status: "completed", alreadyProcessed: true, transaction: existing });
  }

  let detection;
  try {
    detection = await detectDeposit({ chain, txHash, assetSymbol: asset, evmChainId: evmChainIdResolved });
  } catch (err) {
    return fail((err as Error).message || "Deposit detection failed", 502);
  }

  if (!detection.found) {
    return ok({ status: "pending", detection });
  }
  if (!detection.confirmed) {
    return ok({
      status: "processing",
      detection,
      message: `Seen on-chain, waiting for confirmations (${detection.confirmations ?? 0}).`,
    });
  }

  // Confirmed — credit the balance.
  const tx =
    existing ??
    (await createTransaction({
      userId: auth.user.id,
      direction: "deposit",
      rail: "web3",
      amount: detection.amount ?? "0",
      currency: detection.asset ?? asset,
      chain,
      externalId: txHash,
      status: "pending",
      metadata: { from: detection.from, to: detection.to, evmChainId: evmChainIdResolved },
    }));

  const settled = await updateTransactionStatus(tx.id, "completed", {
    externalId: txHash,
    metadata: { confirmations: detection.confirmations, amount: detection.amount },
  });

  if (intentId) {
    await updateDepositIntent(intentId, {
      txHash,
      fromAddress: detection.from,
      status: "completed",
    });
  }

  return ok({ status: "completed", transaction: settled, detection });
}
