import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, PublicKey } from '@solana/web3.js';
import { HelixClient } from '../client.js';
import type { BridgeEventLog } from '../constants.js';

export interface CrossChainYieldSnapshot {
  treasuryTotalDeposited: bigint;
  recentEvents: BridgeEventLog[];
}

export interface UseCrossChainYieldOptions {
  connection: Connection;
  wallet: { publicKey: PublicKey | null };
}

export interface UseCrossChainYieldResult {
  snapshot: CrossChainYieldSnapshot | null;
  loading: boolean;
  error: string | null;
  subscribe: () => () => void;
}

/** Track cross-chain yield events and treasury inflows. */
export function useCrossChainYield(opts: UseCrossChainYieldOptions): UseCrossChainYieldResult {
  const [snapshot, setSnapshot] = useState<CrossChainYieldSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const client = useMemo(() => {
    if (!opts.wallet.publicKey) return null;
    return new HelixClient({
      connection: opts.connection,
      wallet: opts.wallet as HelixClient['provider']['wallet'],
    });
  }, [opts.connection, opts.wallet]);

  useEffect(() => {
    if (!client) {
      setSnapshot(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const [treasuryPda] = await import('../pdas.js').then((m) => m.treasuryPda());
        const acct = await opts.connection.getAccountInfo(treasuryPda);
        if (cancelled) return;
        setSnapshot({
          treasuryTotalDeposited: BigInt(acct?.lamports ?? 0),
          recentEvents: [],
        });
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [client, opts.connection]);

  const subscribe = useCallback(() => {
    if (!client) return () => {};
    return client.onBridgeEvents((event) => {
      setSnapshot((prev) => ({
        treasuryTotalDeposited: prev?.treasuryTotalDeposited ?? 0n,
        recentEvents: [event, ...(prev?.recentEvents ?? [])].slice(0, 50),
      }));
    });
  }, [client]);

  return { snapshot, loading, error, subscribe };
}
