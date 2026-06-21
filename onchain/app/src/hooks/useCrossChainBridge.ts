import { useCallback, useEffect, useState } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import {
  CrossChainClient,
  BridgeListener,
  HELIX_CHAIN_ID,
  TREASURY_MANIFEST_DEFAULT,
} from '@yieldswarm/onchain-sdk';

export interface CrossChainBridgeState {
  totalReceived: bigint;
  lastHarvestTs: number;
  loading: boolean;
  iotexTreasury: string;
  btcBridge: string;
  triggerHarvest: () => Promise<void>;
}

export function useCrossChainBridge(): CrossChainBridgeState {
  const { connection } = useConnection();
  const { publicKey } = useWallet();
  const [totalReceived, setTotalReceived] = useState(0n);
  const [lastHarvestTs, setLastHarvestTs] = useState(0);
  const [loading, setLoading] = useState(true);

  const client = new CrossChainClient(connection);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const state = await client.fetchBridgeState();
      if (state) {
        setTotalReceived(state.totalReceived);
        setLastHarvestTs(Number(state.lastHarvestTs));
      }
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    void refresh();
    const listener = new BridgeListener(connection, client, {
      pollIntervalMs: 15_000,
      onYieldReceived: () => void refresh(),
    });
    listener.start();
    return () => listener.stop();
  }, [connection, client, refresh]);

  const triggerHarvest = useCallback(async () => {
    if (!publicKey) return;
    await client.triggerRemoteHarvest(publicKey, HELIX_CHAIN_ID);
    await refresh();
  }, [client, publicKey, refresh]);

  return {
    totalReceived,
    lastHarvestTs,
    loading,
    iotexTreasury: TREASURY_MANIFEST_DEFAULT.iotex_hub.primary,
    btcBridge: TREASURY_MANIFEST_DEFAULT.iotex_hub.btc_bridge,
    triggerHarvest,
  };
}
