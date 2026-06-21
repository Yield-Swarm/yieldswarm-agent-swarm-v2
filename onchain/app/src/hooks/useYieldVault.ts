import { useCallback, useEffect, useState } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { PublicKey } from '@solana/web3.js';
import { PROGRAM_IDS } from '@yieldswarm/onchain-sdk';

const VAULT_STATE_SEED = 'vault_state';

function vaultStatePda(): PublicKey {
  const [pda] = PublicKey.findProgramAddressSync(
    [Buffer.from(VAULT_STATE_SEED)],
    PROGRAM_IDS.yieldVault,
  );
  return pda;
}

export interface YieldVaultState {
  totalAssets: bigint;
  pendingYield: bigint;
  initialized: boolean;
  loading: boolean;
  deposit: (lamports: bigint) => Promise<void>;
  withdraw: (lamports: bigint) => Promise<void>;
  claim: () => Promise<void>;
}

export function useYieldVault(): YieldVaultState {
  const { connection } = useConnection();
  const { publicKey } = useWallet();
  const [totalAssets, setTotalAssets] = useState(0n);
  const [pendingYield, setPendingYield] = useState(0n);
  const [initialized, setInitialized] = useState(false);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const pda = vaultStatePda();
      const info = await connection.getAccountInfo(pda);
      if (info?.data && info.data.length >= 24) {
        setInitialized(true);
        setTotalAssets(info.data.readBigUInt64LE(8));
        setPendingYield(info.data.readBigUInt64LE(16));
      } else {
        setInitialized(false);
        setTotalAssets(0n);
        setPendingYield(0n);
      }
    } finally {
      setLoading(false);
    }
  }, [connection]);

  useEffect(() => {
    void refresh();
    const id = setInterval(() => void refresh(), 20_000);
    return () => clearInterval(id);
  }, [refresh]);

  const deposit = useCallback(
    async (lamports: bigint) => {
      if (!publicKey) return;
      console.info('[useYieldVault] deposit', lamports.toString(), publicKey.toBase58());
      await refresh();
    },
    [publicKey, refresh],
  );

  const withdraw = useCallback(
    async (lamports: bigint) => {
      if (!publicKey) return;
      console.info('[useYieldVault] withdraw', lamports.toString());
      await refresh();
    },
    [publicKey, refresh],
  );

  const claim = useCallback(async () => {
    if (!publicKey) return;
    console.info('[useYieldVault] claim yield');
    await refresh();
  }, [publicKey, refresh]);

  return { totalAssets, pendingYield, initialized, loading, deposit, withdraw, claim };
}
