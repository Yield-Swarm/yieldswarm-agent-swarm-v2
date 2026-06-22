import { z } from "zod";
import { fail, ok, parseBody } from "@/lib/http";
import { getMarketingService } from "@/lib/marketing/marketingService";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const campaignSchema = z.object({
  platforms: z
    .array(z.enum(["moltbook", "reddit", "x-twitter", "email", "twilio"]))
    .min(1),
  message: z.object({
    text: z.string().min(1).max(10_000),
    subject: z.string().max(500).optional(),
    subreddit: z.string().max(120).optional(),
    smsTo: z.string().max(32).optional(),
    emailTo: z.union([z.string().email(), z.array(z.string().email())]).optional(),
    moltChannel: z.string().max(120).optional(),
  }),
  dryRun: z.boolean().optional(),
});

/** POST /api/integrations/marketing/campaign — multi-platform blast */
export async function POST(request: Request) {
  const parsed = await parseBody(request, campaignSchema);
  if ("response" in parsed) return parsed.response;

  const svc = getMarketingService();
  const result = await svc.runCampaign(parsed.data);

  if (result.failed > 0 && result.succeeded === 0) {
    return fail("All platform dispatches failed", 502, { result });
  }

  return ok(result);
}
