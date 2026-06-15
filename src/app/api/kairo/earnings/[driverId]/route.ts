import { ok, fail } from "@/lib/http";
import { driverEarningsSummary } from "@/lib/kairo/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: { driverId: string } },
) {
  const summary = driverEarningsSummary(params.driverId);
  if (!summary) return fail("Driver not found", 404);

  const { driver, recentTelemetry } = summary;
  const potentialRewards =
    driver.totalRewardWeight * 0.01 + parseFloat(driver.depinRewardsUsd);

  return ok({
    driverId: driver.driverId,
    evmAddress: driver.evmAddress,
    iotexAddress: driver.iotexAddress,
    telemetryCount: driver.telemetryCount,
    totalDistanceM: driver.totalDistanceM,
    totalRewardWeight: driver.totalRewardWeight,
    earnings: {
      appRevenue: driver.appEarningsUsd,
      depinCryptoRewards: driver.depinRewardsUsd,
      potentialRewardsUsd: potentialRewards.toFixed(2),
    },
    recentTelemetry: recentTelemetry.map((t) => ({
      id: t.id,
      treeNode: t.treeNode,
      rewardWeight: t.rewardWeight,
      receivedAt: t.receivedAt,
    })),
  });
}
