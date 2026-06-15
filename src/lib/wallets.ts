import { store } from "@/lib/db/store";
import { Chain, LinkedWallet } from "@/lib/db/models";
import { nowIso, uuid } from "@/lib/ids";

export function normalizeAddress(chain: Chain, address: string): string {
  return chain === "evm" ? address.toLowerCase() : address.trim();
}

export async function linkWallet(params: {
  userId: string;
  chain: Chain;
  address: string;
  label?: string;
}): Promise<LinkedWallet> {
  const address = normalizeAddress(params.chain, params.address);
  return store.mutate((db) => {
    const existing = Object.values(db.wallets).find(
      (w) => w.userId === params.userId && w.chain === params.chain && w.address === address,
    );
    if (existing) {
      existing.verifiedAt = nowIso();
      if (params.label) existing.label = params.label;
      return existing;
    }
    const wallet: LinkedWallet = {
      id: uuid(),
      userId: params.userId,
      chain: params.chain,
      address,
      label: params.label,
      verifiedAt: nowIso(),
    };
    db.wallets[wallet.id] = wallet;
    return wallet;
  });
}

export async function listWallets(userId: string): Promise<LinkedWallet[]> {
  const db = await store.read();
  return Object.values(db.wallets).filter((w) => w.userId === userId);
}

export async function isWalletLinked(
  userId: string,
  chain: Chain,
  address: string,
): Promise<boolean> {
  const normalized = normalizeAddress(chain, address);
  const db = await store.read();
  return Object.values(db.wallets).some(
    (w) => w.userId === userId && w.chain === chain && w.address === normalized,
  );
}
