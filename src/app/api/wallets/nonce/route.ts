import { z } from "zod";
import { requireUser, parseBody, ok } from "@/lib/http";
import { issueNonceMessage } from "@/lib/auth/nonce";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  chain: z.enum(["evm", "solana", "ton"]),
  address: z.string().min(4),
});

export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;

  const { message } = issueNonceMessage(body.data.address, body.data.chain);
  return ok({ message });
}
