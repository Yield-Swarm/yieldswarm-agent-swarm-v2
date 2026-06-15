/**
 * Driver earnings aggregation — app revenue + DePIN/crypto rewards + trip pay.
 */

import { ContributionRecord, DriverEarnings } from "@/lib/kairo/models";
import { KairoTrip } from "@/lib/kairo/models";

function sum(amounts: string[]): string {
  return amounts.reduce((a, b) => (parseFloat(a) + parseFloat(b)).toFixed(2), "0.00");
}

export function buildDriverEarnings(
  driverId: string,
  contribution: ContributionRecord | undefined,
  trips: KairoTrip[],
  currency = "USD",
): DriverEarnings {
  const completedTrips = trips.filter((t) => t.driverId === driverId && t.status === "completed");
  const tripPay = sum(completedTrips.map((t) => t.driverPay));
  const appRevenue = contribution?.appRevenueShare ?? "0.00";
  const depinRewards = contribution?.estimatedDepinRewards ?? "0.00";
  const total = sum([tripPay, appRevenue, depinRewards]);

  const pendingCashout = sum(
    completedTrips
      .filter((t) => !t.metadata?.cashedOut)
      .map((t) => t.driverPay),
  );

  return {
    driverId,
    currency,
    appRevenue,
    depinRewards,
    tripPay,
    total,
    pendingCashout,
    availableCashout: pendingCashout,
    breakdown: [
      { label: "Trip pay (2× base)", amount: tripPay, source: "trip" },
      { label: "App revenue share", amount: appRevenue, source: "app" },
      { label: "DePIN / crypto rewards", amount: depinRewards, source: "depin" },
    ],
  };
}
