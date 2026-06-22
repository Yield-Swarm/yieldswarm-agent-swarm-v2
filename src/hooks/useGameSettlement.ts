"use client";

/**
 * Layer 3 — broadcast server-signed settlement cell via TonConnect.
 *
 * Usage (Telegram Mini App / Next.js client):
 *   const { sendSettlement } = useGameSettlement(tonConnectUI);
 *   await sendSettlement(claimResponse.settlement);
 */
import { useCallback } from "react";
import type { TonConnectUI } from "@tonconnect/ui-react";
import type { TonConnectSettlementMessage } from "@/types/game";

export interface ClaimApiSettlement {
  contractAddress: string;
  valueNanoton: string;
  bocBase64: string;
}

export function useGameSettlement(tonConnectUI: TonConnectUI | null) {
  const sendSettlement = useCallback(
    async (settlement: ClaimApiSettlement | undefined) => {
      if (!tonConnectUI) throw new Error("TonConnect not initialized");
      if (!settlement) throw new Error("No settlement cell — configure PLAYERSBT_CONTRACT_ADDRESS");

      const message: TonConnectSettlementMessage = {
        address: settlement.contractAddress,
        amount: settlement.valueNanoton,
        payload: settlement.bocBase64,
      };

      return tonConnectUI.sendTransaction({
        validUntil: Math.floor(Date.now() / 1000) + 300,
        messages: [message],
      });
    },
    [tonConnectUI],
  );

  return { sendSettlement };
}
