import { ok, fail } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/integrations/notion — God Task #53 status webhook stub */
export async function POST(request: Request) {
  const token = process.env.NOTION_API_KEY;
  if (!token) return fail("NOTION_API_KEY not configured", 503);

  const body = await request.json().catch(() => ({}));
  return ok({
    accepted: true,
    message: "Notion sync queued",
    payload: body,
    note: "Wire to Notion API database for 55-task epic sync",
  });
}

/** GET /api/integrations/notion — integration health */
export async function GET() {
  return ok({
    configured: Boolean(process.env.NOTION_API_KEY),
    linearConfigured: Boolean(process.env.LINEAR_API_KEY),
    tasksRegistry: "config/god-tasks.json",
    docs: "docs/GOD_TASKS_55.md",
  });
}
