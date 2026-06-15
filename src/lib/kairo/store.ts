/**
 * In-memory Kairo driver + telemetry store.
 * Swap for Postgres/Redis in production.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join } from "path";

export interface DriverRecord {
  driverId: string;
  evmAddress: string;
  iotexAddress: string;
  publicKeyFingerprint: string;
  registeredAt: string;
  telemetryCount: number;
  totalRewardWeight: number;
  totalDistanceM: number;
  appEarningsUsd: string;
  depinRewardsUsd: string;
}

export interface TelemetryRecord {
  id: string;
  driverId: string;
  treeNode: string;
  rewardWeight: number;
  payload: Record<string, unknown>;
  receivedAt: string;
}

interface KairoDB {
  drivers: Record<string, DriverRecord>;
  telemetry: TelemetryRecord[];
}

const DATA_DIR = process.env.KAIRO_STORE_DIR ?? ".data";
const DATA_FILE = join(DATA_DIR, "kairo.json");

function load(): KairoDB {
  if (!existsSync(DATA_FILE)) {
    return { drivers: {}, telemetry: [] };
  }
  return JSON.parse(readFileSync(DATA_FILE, "utf-8")) as KairoDB;
}

function save(db: KairoDB): void {
  if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });
  writeFileSync(DATA_FILE, JSON.stringify(db, null, 2));
}

export function registerDriver(record: DriverRecord): DriverRecord {
  const db = load();
  db.drivers[record.driverId] = record;
  save(db);
  return record;
}

export function getDriver(driverId: string): DriverRecord | null {
  return load().drivers[driverId] ?? null;
}

export function appendTelemetry(
  driverId: string,
  items: Array<{ treeNode: string; rewardWeight: number; payload: Record<string, unknown> }>,
): TelemetryRecord[] {
  const db = load();
  const driver = db.drivers[driverId];
  if (!driver) return [];

  const created: TelemetryRecord[] = items.map((item) => ({
    id: `${driverId}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    driverId,
    treeNode: item.treeNode,
    rewardWeight: item.rewardWeight,
    payload: item.payload,
    receivedAt: new Date().toISOString(),
  }));

  db.telemetry.push(...created);
  driver.telemetryCount += created.length;
  driver.totalRewardWeight += created.reduce((s, t) => s + t.rewardWeight, 0);
  for (const t of created) {
    const odo = Number((t.payload.odometer_m as number) ?? 0);
    if (odo > 0) driver.totalDistanceM += odo;
  }
  save(db);
  return created;
}

export function addDriverEarnings(
  driverId: string,
  appUsd: string,
  depinUsd: string,
): DriverRecord | null {
  const db = load();
  const driver = db.drivers[driverId];
  if (!driver) return null;
  driver.appEarningsUsd = (parseFloat(driver.appEarningsUsd) + parseFloat(appUsd)).toFixed(2);
  driver.depinRewardsUsd = (parseFloat(driver.depinRewardsUsd) + parseFloat(depinUsd)).toFixed(2);
  save(db);
  return driver;
}

export function driverEarningsSummary(driverId: string) {
  const driver = getDriver(driverId);
  if (!driver) return null;
  const recent = load()
    .telemetry.filter((t) => t.driverId === driverId)
    .slice(-20)
    .reverse();
  return { driver, recentTelemetry: recent };
}
