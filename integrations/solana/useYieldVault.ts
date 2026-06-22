/**
 * Treasury vault read via integration backend + on-chain PDA helpers.
 */
import { useCallback, useEffect, useState } from 'react';

export type YieldVaultSnapshot = {
  vaultUsd: number | null;
  vaultTargetUsd: number;
  progress: number | null;
  helixTreasury?: Record<string, unknown>;
  live: boolean;
};

const API_BASE = (import.meta as { env?: { VITE_API_BASE?: string } }).env?.VITE_API_BASE || '/api';

export function useYieldVault(pollMs = 30_000) {
  const [vault, setVault] = useState<YieldVaultSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const [sovereign, helix, cross] = await Promise.all([
        fetch(`${API_BASE}/sovereign/overview`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`${API_BASE}/helix/treasury`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`${API_BASE}/cross-chain/overview`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
      ]);

      setVault({
        vaultUsd: sovereign.vault_usd ?? sovereign.net_worth_usd ?? null,
        vaultTargetUsd: sovereign.vault_target_usd ?? 5_000_000,
        progress: sovereign.progress ?? null,
        helixTreasury: helix,
        live: Boolean(cross?.live ?? helix?.live),
      });
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'vault unreachable');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, pollMs);
    return () => clearInterval(id);
  }, [refresh, pollMs]);

  return { vault, loading, error, refresh };
}
