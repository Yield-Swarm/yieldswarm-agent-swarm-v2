import { useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import { WalletContext, type WalletContextValue } from "./context";
import { CHAINS, chainsForNamespace } from "../chains";
import {
  WalletError,
  type ChainId,
  type ChainInfo,
  type ChainNamespace,
  type TokenBalance,
  type TransactionResult,
  type TransferRequest,
  type WalletAccount,
} from "../types";

function useWalletContext(): WalletContextValue {
  const ctx = useContext(WalletContext);
  if (!ctx) {
    throw new Error("Wallet hooks must be used inside <WalletProvider>");
  }
  return ctx;
}

/** Low-level access to the manager and full snapshot. */
export function useWalletManager(): WalletContextValue {
  return useWalletContext();
}

/** Control the built-in connect modal. */
export function useConnectModal() {
  return useWalletContext().modal;
}

/**
 * Primary wallet hook. Exposes the active account/chain, per-ecosystem
 * connection map, and imperative actions (connect, disconnect, sign, transfer).
 */
export function useWallet() {
  const { manager, state, modal } = useWalletContext();

  const connect = useCallback(
    (namespace: ChainNamespace, connectorId: string) =>
      manager.connect(namespace, connectorId),
    [manager],
  );

  const disconnect = useCallback(
    (namespace?: ChainNamespace) => manager.disconnect(namespace),
    [manager],
  );

  const setActiveNamespace = useCallback(
    (namespace: ChainNamespace | null) => manager.setActiveNamespace(namespace),
    [manager],
  );

  const signMessage = useCallback(
    (message: string, namespace?: ChainNamespace) =>
      manager.signMessage(message, namespace),
    [manager],
  );

  const sendTransfer = useCallback(
    (request: TransferRequest, namespace?: ChainNamespace) =>
      manager.sendTransfer(request, namespace),
    [manager],
  );

  const switchChain = useCallback(
    (chainId: ChainId) => manager.switchChain(chainId),
    [manager],
  );

  const isConnected = useMemo(
    () => Object.values(state.accounts).some(Boolean),
    [state.accounts],
  );

  return {
    ...state,
    isConnected,
    isConnecting: Object.values(state.statuses).some((s) => s === "connecting"),
    connect,
    disconnect,
    setActiveNamespace,
    signMessage,
    sendTransfer,
    switchChain,
    openConnectModal: modal.open,
  };
}

/** The account connected for a specific ecosystem (or the active one). */
export function useAccount(namespace?: ChainNamespace): WalletAccount | null {
  const { state } = useWalletContext();
  if (namespace) return state.accounts[namespace] ?? null;
  return state.activeAccount;
}

/**
 * Auto-detected active chain plus chain-switching utilities. EVM supports
 * switching between configured chains; other ecosystems are single-chain.
 */
export function useChain() {
  const { manager, state } = useWalletContext();

  const switchChain = useCallback(
    (chainId: ChainId) => manager.switchChain(chainId),
    [manager],
  );

  const supportedChains = useMemo<ChainInfo[]>(() => {
    const ns = state.activeNamespace;
    if (!ns) return Object.values(CHAINS);
    return chainsForNamespace(ns);
  }, [state.activeNamespace]);

  return {
    chain: state.activeChain,
    namespace: state.activeNamespace,
    supportedChains,
    canSwitch: state.activeNamespace === "evm",
    switchChain,
  };
}

export interface UseBalanceResult {
  data: TokenBalance | null;
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
}

interface UseBalanceOptions {
  namespace?: ChainNamespace;
  token?: string;
  /** Poll interval in ms. Set 0 to disable. Default 20s. */
  refetchInterval?: number;
}

/**
 * Fetch the (native or token) balance for the active or specified ecosystem.
 * Re-fetches when the account/chain changes and on a polling interval.
 */
export function useBalance(options: UseBalanceOptions = {}): UseBalanceResult {
  const { namespace, token, refetchInterval = 20_000 } = options;
  const { manager, state } = useWalletContext();
  const [data, setData] = useState<TokenBalance | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const ns = namespace ?? state.activeNamespace;
  const account = ns ? state.accounts[ns] : null;
  const chainId = account?.chainId;
  const requestId = useRef(0);

  const fetchBalance = useCallback(async () => {
    if (!ns || !account) {
      setData(null);
      return;
    }
    const id = ++requestId.current;
    setIsLoading(true);
    setError(null);
    try {
      const result = await manager.getBalance(ns, token);
      if (id === requestId.current) setData(result);
    } catch (err) {
      if (id === requestId.current) {
        setError(err instanceof Error ? err : new WalletError("unknown", String(err)));
        setData(null);
      }
    } finally {
      if (id === requestId.current) setIsLoading(false);
    }
  }, [manager, ns, account, token]);

  useEffect(() => {
    void fetchBalance();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ns, account?.address, chainId, token]);

  useEffect(() => {
    if (!refetchInterval || !account) return;
    const timer = setInterval(() => void fetchBalance(), refetchInterval);
    return () => clearInterval(timer);
  }, [refetchInterval, account, fetchBalance]);

  return { data, isLoading, error, refetch: () => void fetchBalance() };
}

export type TransferStatus = "idle" | "signing" | "pending" | "success" | "error";

export interface UseTransferResult {
  send: (
    request: TransferRequest,
    namespace?: ChainNamespace,
  ) => Promise<TransactionResult | null>;
  status: TransferStatus;
  result: TransactionResult | null;
  error: Error | null;
  reset: () => void;
}

/**
 * Transaction helper for deposits/withdrawals. Tracks signing/broadcast status
 * so UIs can render progress and surface explorer links on success.
 */
export function useTransfer(): UseTransferResult {
  const { manager } = useWalletContext();
  const [status, setStatus] = useState<TransferStatus>("idle");
  const [result, setResult] = useState<TransactionResult | null>(null);
  const [error, setError] = useState<Error | null>(null);

  const send = useCallback(
    async (request: TransferRequest, namespace?: ChainNamespace) => {
      setStatus("signing");
      setError(null);
      setResult(null);
      try {
        const res = await manager.sendTransfer(request, namespace);
        setResult(res);
        setStatus("success");
        return res;
      } catch (err) {
        setError(err instanceof Error ? err : new WalletError("unknown", String(err)));
        setStatus("error");
        return null;
      }
    },
    [manager],
  );

  const reset = useCallback(() => {
    setStatus("idle");
    setResult(null);
    setError(null);
  }, []);

  return { send, status, result, error, reset };
}
