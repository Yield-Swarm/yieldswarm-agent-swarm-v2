import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { validateNonceMessage } from "@/lib/auth/nonce";
import { verifyWalletOwnership } from "@/lib/web3/verify-signature";
import { linkWallet, listWallets } from "@/lib/wallets";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  return ok({ wallets: await listWallets(auth.user.id) });
}

const linkSchema = z.object({
  chain: z.enum(["evm", "solana", "ton"]),
  address: z.string().min(4),
  message: z.string().min(10),
  signature: z.string().min(2),
  label: z.string().max(64).optional(),
  tonProof: z
    .object({
      publicKey: z.string(),
      address: z.string(),
      domain: z.string(),
      timestamp: z.number(),
      payload: z.string(),
      signature: z.string(),
    })
    .optional(),
});

export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;

  const body = await parseBody(request, linkSchema);
  if ("response" in body) return body.response;
  const { chain, address, message, signature, label, tonProof } = body.data;

  // For EVM/Solana the signed message must be one we issued and is still fresh.
  if (chain !== "ton" && !validateNonceMessage(message, address, chain)) {
    return fail("Invalid or expired challenge message", 400);
  }

  const verified = await verifyWalletOwnership({
    chain,
    address,
    message,
    signature,
    tonProof,
  });
  if (!verified) return fail("Wallet signature verification failed", 401);

  const wallet = await linkWallet({ userId: auth.user.id, chain, address, label });
  return ok({ wallet });
}
