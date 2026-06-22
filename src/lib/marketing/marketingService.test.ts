import { describe, expect, it } from "vitest";
import { MarketingService } from "./marketingService";

describe("MarketingService", () => {
  it("runs dry-run campaign without credentials", async () => {
    const svc = new MarketingService();
    const result = await svc.runCampaign({
      platforms: ["moltbook", "x-twitter"],
      message: { text: "YieldSwarm test campaign" },
      dryRun: true,
    });

    expect(result.dryRun).toBe(true);
    expect(result.results).toHaveLength(2);
    expect(result.succeeded).toBe(2);
    expect(result.results.every((r) => r.ok)).toBe(true);
  });

  it("reports platform health structure", async () => {
    const svc = new MarketingService();
    const health = await svc.health();
    expect(health.length).toBe(5);
    expect(health[0]).toMatchObject({
      platform: expect.any(String),
      configured: expect.any(Boolean),
      vaultPath: expect.stringContaining("marketing/"),
    });
  });
});
