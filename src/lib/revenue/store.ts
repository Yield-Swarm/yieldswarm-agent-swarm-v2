/**
 * Revenue metrics + sale log (Neon when configured, JSON fallback).
 */

import fs from "node:fs/promises";
import path from "node:path";

export interface RevenueMetrics {
  totalRevenueUsd: number;
  agentsActive: number;
  cronsFiring: number;
  deitiesOnline: number;
  openclawNodes: number;
  lanesActive: number;
  live: boolean;
  updatedAt: string;
}

export interface SaleRecord {
  id: string;
  product: string;
  amountUsd: number;
  tier?: string;
  reference: string;
  rails: string[];
  source: string;
  createdAt: string;
}

const DATA_DIR = path.join(process.cwd(), ".data");
const SALES_FILE = path.join(DATA_DIR, "revenue-sales.json");
const METRICS_FILE = path.join(DATA_DIR, "revenue-metrics.json");

const BASE_METRICS: RevenueMetrics = {
  totalRevenueUsd: 7500,
  agentsActive: 10080,
  cronsFiring: 120,
  deitiesOnline: 169,
  openclawNodes: 9,
  lanesActive: 14,
  live: true,
  updatedAt: new Date().toISOString(),
};

async function ensureDataDir() {
  await fs.mkdir(DATA_DIR, { recursive: true });
}

async function readJson<T>(file: string, fallback: T): Promise<T> {
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

async function writeJson(file: string, data: unknown) {
  await ensureDataDir();
  await fs.writeFile(file, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

async function neonLogSale(record: SaleRecord): Promise<boolean> {
  const url = process.env.NEON_DATABASE_URL || process.env.DATABASE_URL;
  if (!url || !url.includes("neon")) return false;
  try {
    const { neon } = await import("@neondatabase/serverless");
    const sql = neon(url);
    await sql`
      CREATE TABLE IF NOT EXISTS revenue_sales (
        id TEXT PRIMARY KEY,
        product TEXT NOT NULL,
        amount_usd NUMERIC NOT NULL,
        tier TEXT,
        reference TEXT,
        rails JSONB,
        source TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`
      INSERT INTO revenue_sales (id, product, amount_usd, tier, reference, rails, source, created_at)
      VALUES (${record.id}, ${record.product}, ${record.amountUsd}, ${record.tier ?? null},
              ${record.reference}, ${JSON.stringify(record.rails)}, ${record.source}, ${record.createdAt})
    `;
    return true;
  } catch {
    return false;
  }
}

export async function getRevenueMetrics(): Promise<RevenueMetrics> {
  const stored = await readJson<Partial<RevenueMetrics>>(METRICS_FILE, {});
  return { ...BASE_METRICS, ...stored, updatedAt: new Date().toISOString() };
}

export async function addRevenue(amountUsd: number) {
  const metrics = await getRevenueMetrics();
  metrics.totalRevenueUsd = Math.round((metrics.totalRevenueUsd + amountUsd) * 100) / 100;
  metrics.updatedAt = new Date().toISOString();
  await writeJson(METRICS_FILE, metrics);
  return metrics;
}

export async function logSale(input: {
  product: string;
  amountUsd: number;
  tier?: string;
  reference?: string;
  rails?: string[];
  source?: string;
}): Promise<SaleRecord> {
  const record: SaleRecord = {
    id: `sale_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    product: input.product,
    amountUsd: input.amountUsd,
    tier: input.tier,
    reference: input.reference ?? `YSW-${Date.now()}`,
    rails: input.rails ?? ["wise", "web3"],
    source: input.source ?? "web",
    createdAt: new Date().toISOString(),
  };

  const sales = await readJson<SaleRecord[]>(SALES_FILE, []);
  sales.unshift(record);
  await writeJson(SALES_FILE, sales.slice(0, 500));
  await addRevenue(input.amountUsd);
  await neonLogSale(record);

  return record;
}

export async function listRecentSales(limit = 20): Promise<SaleRecord[]> {
  const url = process.env.NEON_DATABASE_URL || process.env.DATABASE_URL;
  if (url && url.includes("neon")) {
    try {
      const { neon } = await import("@neondatabase/serverless");
      const sql = neon(url);
      const rows = await sql`
        SELECT id, product, amount_usd as "amountUsd", tier, reference, rails, source, created_at as "createdAt"
        FROM revenue_sales ORDER BY created_at DESC LIMIT ${limit}
      `;
      if (rows.length) return rows as SaleRecord[];
    } catch { /* fallback */ }
  }
  const sales = await readJson<SaleRecord[]>(SALES_FILE, []);
  return sales.slice(0, limit);
}
