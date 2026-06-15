import { store } from "@/lib/db/store";
import { Chain, OnchainDepositIntent, TxStatus } from "@/lib/db/models";
import { nowIso, reference, uuid } from "@/lib/ids";

export async function createDepositIntent(params: {
  userId: string;
  chain: Chain;
  asset: string;
  depositAddress: string;
  expectedAmount?: string;
}): Promise<OnchainDepositIntent> {
  return store.mutate((db) => {
    const intent: OnchainDepositIntent = {
      id: uuid(),
      userId: params.userId,
      reference: reference("onchain"),
      chain: params.chain,
      asset: params.asset.toUpperCase(),
      expectedAmount: params.expectedAmount,
      depositAddress: params.depositAddress,
      status: "pending",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.depositIntents[intent.id] = intent;
    return intent;
  });
}

export async function getDepositIntent(id: string): Promise<OnchainDepositIntent | null> {
  const db = await store.read();
  return db.depositIntents[id] ?? null;
}

export async function findIntentByTxHash(txHash: string): Promise<OnchainDepositIntent | null> {
  const db = await store.read();
  return Object.values(db.depositIntents).find((i) => i.txHash === txHash) ?? null;
}

export async function updateDepositIntent(
  id: string,
  patch: Partial<Pick<OnchainDepositIntent, "txHash" | "fromAddress" | "status">>,
): Promise<OnchainDepositIntent | null> {
  return store.mutate((db) => {
    const intent = db.depositIntents[id];
    if (!intent) return null;
    Object.assign(intent, patch);
    intent.updatedAt = nowIso();
    return intent;
  });
}

export function isTerminal(status: TxStatus): boolean {
  return status === "completed" || status === "failed" || status === "cancelled";
}
