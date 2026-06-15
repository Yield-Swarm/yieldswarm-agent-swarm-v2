/**
 * Kairo payment and earnings logic.
 *
 * - Customer: 1% flat platform fee on every ride fare.
 * - Driver: 2× base pay rate + optional instant cashout.
 * - Earnings breakdown: app revenue + DePIN/crypto rewards.
 */

import type { DriverEarnings, EarningsLineItem, KairoRide } from "./models";
import { kairoStore } from "./store";
import { createTransaction } from "@/lib/ledger";
import { uuid, nowIso } from "@/lib/ids";

export const KAIRO_PLATFORM_FEE_RATE = 0.01; // 1%
export const KAIRO_DRIVER_MULTIPLIER = 2; // 2× base pay
export const KAIRO_INSTANT_CASHOUT_FEE_RATE = 0.015; // 1.5%

function parseAmount(s: string): number {
  return parseFloat(s) || 0;
}

function formatAmount(n: number): string {
  return n.toFixed(2);
}

/** Calculate ride economics: 1% customer fee, 2× driver pay. */
export function calculateRideEconomics(baseFare: string): {
  platformFee: string;
  customerTotal: string;
  driverEarnings: string;
} {
  const fare = parseAmount(baseFare);
  const platformFee = fare * KAIRO_PLATFORM_FEE_RATE;
  const customerTotal = fare + platformFee;
  const driverEarnings = fare * KAIRO_DRIVER_MULTIPLIER;
  return {
    platformFee: formatAmount(platformFee),
    customerTotal: formatAmount(customerTotal),
    driverEarnings: formatAmount(driverEarnings),
  };
}

/** Create a Kairo ride with fee calculation. */
export async function createRide(
  customerId: string,
  driverId: string,
  baseFare: string,
  currency = "USD",
): Promise<KairoRide> {
  const econ = calculateRideEconomics(baseFare);
  const ride: KairoRide = {
    id: uuid(),
    customerId,
    driverId,
    fare: baseFare,
    currency,
    platformFee: econ.platformFee,
    driverEarnings: econ.driverEarnings,
    status: "pending",
    createdAt: nowIso(),
  };

  await kairoStore.mutate((db) => {
    db.rides[ride.id] = ride;
  });

  return ride;
}

/** Complete a ride and record ledger transactions. */
export async function completeRide(rideId: string): Promise<KairoRide | null> {
  const ride = await kairoStore.mutate((db) => {
    const r = db.rides[rideId];
    if (!r || r.status === "completed") return null;
    r.status = "completed";
    r.completedAt = nowIso();
    return r;
  });
  if (!ride) return null;

  // Customer charged fare + 1% fee.
  const econ = calculateRideEconomics(ride.fare);
  await createTransaction({
    userId: ride.customerId,
    direction: "withdrawal",
    rail: "square",
    amount: econ.customerTotal,
    currency: ride.currency,
    status: "completed",
    metadata: { rideId, type: "kairo_ride_charge", platformFee: econ.platformFee },
  });

  // Driver credited 2× base.
  await createTransaction({
    userId: ride.driverId,
    direction: "deposit",
    rail: "square",
    amount: econ.driverEarnings,
    currency: ride.currency,
    status: "completed",
    metadata: { rideId, type: "kairo_driver_payout", multiplier: KAIRO_DRIVER_MULTIPLIER },
  });

  return ride;
}

/** Build earnings breakdown for a driver in a given period. */
export async function buildDriverEarnings(
  driverId: string,
  period: string,
): Promise<DriverEarnings> {
  const db = await kairoStore.read();
  const rides = Object.values(db.rides).filter(
    (r) => r.driverId === driverId && r.status === "completed" && r.completedAt?.startsWith(period),
  );

  let grossRevenue = 0;
  let driverPayout = 0;
  let platformFees = 0;

  for (const ride of rides) {
    grossRevenue += parseAmount(ride.fare);
    driverPayout += parseAmount(ride.driverEarnings);
    platformFees += parseAmount(ride.platformFee);
  }

  const contribution = db.contributions[driverId];
  const depinPoints = contribution?.estimatedRewardPoints ?? 0;
  const depinRewards = formatAmount(depinPoints * 0.01); // illustrative conversion

  const breakdown: EarningsLineItem[] = [
    { label: "Ride revenue (2× base)", amount: formatAmount(driverPayout), currency: "USD", category: "ride" },
    { label: "DePIN data rewards", amount: depinRewards, currency: "APN", category: "depin" },
    { label: "Platform fees collected", amount: formatAmount(platformFees), currency: "USD", category: "fee" },
  ];

  const earnings: DriverEarnings = {
    driverId,
    period,
    grossRideRevenue: formatAmount(grossRevenue),
    driverPayout: formatAmount(driverPayout),
    currency: "USD",
    platformFeeCollected: formatAmount(platformFees),
    depinRewards,
    depinRewardCurrency: "APN",
    netEarnings: formatAmount(driverPayout + parseAmount(depinRewards)),
    breakdown,
  };

  await kairoStore.mutate((d) => {
    if (!d.earnings[driverId]) d.earnings[driverId] = [];
    d.earnings[driverId].push(earnings);
  });

  return earnings;
}

/** Process instant cashout for a driver (with fee). */
export async function instantCashout(
  driverId: string,
  amount: string,
  currency = "USD",
): Promise<{ netAmount: string; fee: string }> {
  const amt = parseAmount(amount);
  const fee = amt * KAIRO_INSTANT_CASHOUT_FEE_RATE;
  const net = amt - fee;

  await createTransaction({
    userId: driverId,
    direction: "withdrawal",
    rail: "wise",
    amount: formatAmount(net),
    currency,
    status: "processing",
    metadata: { type: "kairo_instant_cashout", fee: formatAmount(fee) },
  });

  return { netAmount: formatAmount(net), fee: formatAmount(fee) };
}
