import { z } from "zod";
import { fail, ok, parseBody } from "@/lib/http";
import { routeLlmRequest } from "@/lib/llm/connectors";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const bodySchema = z.object({
  connector: z.enum(["gemini", "grok", "kimi"]),
  prompt: z.string().min(1),
  claw: z
    .object({
      task_name: z.string().min(1),
      cron_schedule: z.string().min(1),
      target_skill: z.string().min(1),
    })
    .optional(),
});

/** POST /api/llm/route — Phase 3 multi-LLM connector dispatch */
export async function POST(request: Request) {
  const parsed = await parseBody(request, bodySchema);
  if ("response" in parsed) return parsed.response;

  try {
    const result = await routeLlmRequest(parsed.data);
    return ok({ connector: parsed.data.connector, result });
  } catch (e) {
    return fail(e instanceof Error ? e.message : "LLM route failed", 502);
  }
}
