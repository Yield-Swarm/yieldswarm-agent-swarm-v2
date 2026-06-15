"use client";

import { useCallback } from "react";
import { useTonConnectUI, useTonWallet, useTonAddress } from "@tonconnect/ui-react";

/** Convenience wrapper around TonConnect for connect / proof / send. */
export function useTon() {
  const [tonConnectUI] = useTonConnectUI();
  const wallet = useTonWallet();
  const address = useTonAddress();

  const connectWithProof = useCallback(
    async (payload: string) => {
      tonConnectUI.setConnectRequestParameters({ state: "ready", value: { tonProof: payload } });
      await tonConnectUI.openModal();
    },
    [tonConnectUI],
  );

  const disconnect = useCallback(async () => {
    await tonConnectUI.disconnect();
  }, [tonConnectUI]);

  /** Send TON (native). Returns the external-message BOC from the wallet. */
  const sendTon = useCallback(
    async (to: string, amountTon: string) => {
      const nano = BigInt(Math.round(Number(amountTon) * 1e9)).toString();
      const result = await tonConnectUI.sendTransaction({
        validUntil: Math.floor(Date.now() / 1000) + 600,
        messages: [{ address: to, amount: nano }],
      });
      return result.boc;
    },
    [tonConnectUI],
  );

  return { tonConnectUI, wallet, address, connectWithProof, disconnect, sendTon };
}
