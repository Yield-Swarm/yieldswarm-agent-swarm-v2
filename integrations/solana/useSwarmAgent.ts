/**
 * Swarm ops — register agents via Nexus API (521-agent coordination layer).
 * On-chain: swarm_ops::register_agent via HelixClient when wallet connected.
 */
import { useCallback, useState } from 'react';

export type SwarmAgentRecord = {
  agentId: string;
  registered: boolean;
  dailyLimit?: number;
  permissions?: number;
};

const API_BASE = (import.meta as { env?: { VITE_API_BASE?: string } }).env?.VITE_API_BASE || '/api';

export function useSwarmAgent(agentId?: string) {
  const [agent, setAgent] = useState<SwarmAgentRecord | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const register = useCallback(async (id: string, opts: { shardId?: number; gpuClass?: string } = {}) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/nexus/agents/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          agentId: id,
          shardId: opts.shardId ?? 0,
          gpuClass: opts.gpuClass ?? 'rtx5090',
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setAgent({
        agentId: id,
        registered: true,
        dailyLimit: json.dailyHarvestLimit,
        permissions: json.permissions,
      });
      return json;
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'register failed';
      setError(msg);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const refresh = useCallback(async () => {
    if (!agentId) return;
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/nexus/status`, { cache: 'no-store' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setAgent({
        agentId,
        registered: (json.registry?.agentCount ?? 0) > 0,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'status failed');
    } finally {
      setLoading(false);
    }
  }, [agentId]);

  return { agent, loading, error, register, refresh };
}
