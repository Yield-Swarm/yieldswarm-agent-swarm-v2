import { ok } from "@/lib/http";
import { getMarketingService } from "@/lib/marketing/marketingService";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/integrations/marketing/health */
export async function GET() {
  const svc = getMarketingService();
  const platforms = await svc.health();
  const configuredCount = platforms.filter((p) => p.configured).length;

  return ok({
    app: svc.appName,
    dryRunDefault:
      process.env.MARKETING_DRY_RUN !== "0" &&
      (process.env.MARKETING_DRY_RUN === "1" ||
        process.env.NODE_ENV !== "production"),
    vaultMount: process.env.VAULT_KV_MOUNT || "yieldswarm",
    vaultAddrConfigured: Boolean(process.env.VAULT_ADDR),
    platforms,
    configuredCount,
    totalPlatforms: platforms.length,
    docs: "docs/MARKETING_VAULT_INTEGRATION.md",
  });
}
