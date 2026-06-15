import { requireUser, ok } from "@/lib/http";
import { getBalances, listTransactions } from "@/lib/ledger";
import { listWallets } from "@/lib/wallets";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  const { user } = auth;

  const [balances, transactions, wallets] = await Promise.all([
    getBalances(user.id),
    listTransactions(user.id),
    listWallets(user.id),
  ]);

  return ok({
    user: { id: user.id, email: user.email },
    balances,
    transactions,
    wallets,
  });
}
