import { useCallback, useEffect, useMemo, useState } from 'react';
import { Connection, PublicKey } from '@solana/web3.js';
import { parseCrossChainConfig } from '../client';
import { crossChainConfigPda, treasuryVaultPda } from '../pda';
import { CROSS_CHAIN_PROGRAM_ID } from '../constants';
import type { YieldVaultState } from '../types';

export interface UseYieldVaultOptions {
  rpcUrl?: string;
  programId?: PublicKey;
  userPubkey?: PublicKey | null;
  pollMs?: number;
}

const LAMPORTS_PER_SOL = 1_000_000_000n;

function deriveApyBps(totalReceived: bigint, deposits: bigint): number {
  if (deposits === 0n) return 0;
  const dailyYieldBps = Number((totalReceived * 10_000n) / deposits) / 365;
  return Math.min(Math.round(dailyYieldBps * 365), 50_000);
}

export function useYieldVault(options: UseYieldVaultOptions = {}): YieldVaultState & {
  refresh: () => Promise<void>;
} {
  const rpcUrl = options.rpcUrl ?? 'https://api.devnet.solana.com';
  const programId = options.programId ?? CROSS_CHAIN_PROGRAM_ID;
  const pollMs = options.pollMs ?? 12_000;

  const connection = useMemo(() => new Connection(rpcUrl, 'confirmed'), [rpcUrl]);

  const [state, setState] = useState<YieldVaultState>({
    apyBps: 0,
    userDeposits: 0n,
    pendingReferralRewards: 0n,
    totalReceived: 0n,
    loading: true,
    error: null,
  });

  const refresh = useCallback(async () => {
    setState((s: YieldVaultState) => ({ ...s, loading: true, error: null }));
    try {
      const [configPda] = crossChainConfigPda(programId);
      const [vaultPda] = treasuryVaultPda(configPda, programId);

      const accounts = await connection.getMultipleAccountsInfo([configPda, vaultPda]);
      const configData = accounts[0]?.data;
      const vaultData = accounts[1]?.data;

      let totalReceived = 0n;
      let vaultBalance = 0n;

      if (configData) {
        const cfg = parseCrossChainConfig(configData);
        totalReceived = cfg.totalReceived;
      }

      if (vaultData && vaultData.length >= 8 + 32 + 32 + 8) {
        vaultBalance = new DataView(
          vaultData.buffer,
          vaultData.byteOffset,
          vaultData.byteLength
        ).getBigUint64(8 + 32 + 32, true);
      }

      let userDeposits = 0n;
      let pendingReferralRewards = 0n;

      if (options.userPubkey) {
        const tokenAccounts = await connection.getParsedTokenAccountsByOwner(
          options.userPubkey,
          { programId: new PublicKey('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA') }
        );
        for (const { account } of tokenAccounts.value) {
          const amount = BigInt(account.data.parsed.info.tokenAmount.amount);
          userDeposits += amount;
        }
        pendingReferralRewards = (userDeposits * 25n) / 1000n;
      }

      const deposits = vaultBalance > 0n ? vaultBalance : userDeposits;
      const apyBps = deriveApyBps(totalReceived, deposits);

      setState({
        apyBps,
        userDeposits,
        pendingReferralRewards,
        totalReceived,
        loading: false,
        error: null,
      });
    } catch (e) {
      setState((s: YieldVaultState) => ({
        ...s,
        loading: false,
        error: e instanceof Error ? e.message : 'Failed to load vault state',
      }));
    }
  }, [connection, programId, options.userPubkey]);

  useEffect(() => {
    refresh();
    const id = window.setInterval(refresh, pollMs);
    return () => window.clearInterval(id);
  }, [refresh, pollMs]);

  return { ...state, refresh };
}

export function formatLamports(lamports: bigint, decimals = 4): string {
  const whole = lamports / LAMPORTS_PER_SOL;
  const frac = lamports % LAMPORTS_PER_SOL;
  const fracStr = frac.toString().padStart(9, '0').slice(0, decimals);
  return `${whole}.${fracStr}`;
}

export function formatApy(apyBps: number): string {
  return `${(apyBps / 100).toFixed(2)}%`;
}
