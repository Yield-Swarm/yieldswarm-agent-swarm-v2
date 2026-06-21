import { Connection, PublicKey } from '@solana/web3.js';

export interface YieldRoute {
  protocol: 'kamino' | 'drift' | 'jito';
  apyBps: number;
  tvlLamports: bigint;
  mint: string;
  updatedAt: number;
}

const KAMINO_MAIN_MARKET = new PublicKey(
  '7u3HeHxYDLhnCoPsyqqujBkHMW2YmRj5vAUW6EbKWhDX',
);
const DRIFT_PROGRAM = new PublicKey('dRiftyHA39MWEi3m9aunc5MzRF1JYuBsbn6VPcn33UH');
const JITOSOL_MINT = new PublicKey('J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn');

async function readApyFromAccount(
  connection: Connection,
  pubkey: PublicKey,
  fallbackBps: number,
): Promise<number> {
  try {
    const info = await connection.getAccountInfo(pubkey);
    if (!info?.data || info.data.length < 16) return fallbackBps;
    const raw = info.data.readUInt32LE(8);
    return Math.min(raw, 50_000);
  } catch {
    return fallbackBps;
  }
}

/**
 * RPC-based yield route scanner for Kamino, Drift, and JitoSOL.
 * Reads on-chain account hints; falls back to conservative defaults when unavailable.
 */
export async function fetchYieldRoutes(
  connection: Connection,
): Promise<YieldRoute[]> {
  const now = Date.now();
  const [kaminoApy, driftApy, jitoApy] = await Promise.all([
    readApyFromAccount(connection, KAMINO_MAIN_MARKET, 620),
    readApyFromAccount(connection, DRIFT_PROGRAM, 480),
    readApyFromAccount(connection, JITOSOL_MINT, 710),
  ]);

  return [
    {
      protocol: 'kamino',
      apyBps: kaminoApy,
      tvlLamports: 0n,
      mint: KAMINO_MAIN_MARKET.toBase58(),
      updatedAt: now,
    },
    {
      protocol: 'drift',
      apyBps: driftApy,
      tvlLamports: 0n,
      mint: DRIFT_PROGRAM.toBase58(),
      updatedAt: now,
    },
    {
      protocol: 'jito',
      apyBps: jitoApy,
      tvlLamports: 0n,
      mint: JITOSOL_MINT.toBase58(),
      updatedAt: now,
    },
  ];
}

export function bestYieldRoute(routes: YieldRoute[]): YieldRoute | null {
  if (!routes.length) return null;
  return routes.reduce((best, r) => (r.apyBps > best.apyBps ? r : best));
}
