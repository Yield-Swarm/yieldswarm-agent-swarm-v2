import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { WalletManager, type WalletManagerState } from "../manager";
import type { ChainNamespace } from "../types";
import { WalletContext, type ConnectModalControl } from "./context";
import { ConnectModal } from "../ui/ConnectModal";

interface WalletProviderProps {
  children: ReactNode;
  /** Set false to render your own connect modal instead of the built-in one. */
  withModal?: boolean;
}

/**
 * Root provider. Instantiates a single {@link WalletManager}, wires its state
 * into React, runs silent auto-reconnect on mount, and (by default) mounts the
 * built-in multi-wallet connect modal. Wrap the whole app in this once.
 */
export function WalletProvider({ children, withModal = true }: WalletProviderProps) {
  const managerRef = useRef<WalletManager | null>(null);
  if (!managerRef.current) {
    managerRef.current = new WalletManager();
  }
  const manager = managerRef.current;

  const [state, setState] = useState<WalletManagerState>(() => manager.getState());
  const [modalOpen, setModalOpen] = useState(false);
  const [namespaceFilter, setNamespaceFilter] = useState<ChainNamespace | null>(null);

  useEffect(() => {
    const unsub = manager.subscribe(setState);
    void manager.init();
    // Only detach this React listener on cleanup. The manager is a long-lived
    // singleton tied to the provider's ref (not the effect lifecycle), so we do
    // not tear down adapter watchers here — that would break StrictMode remounts.
    return () => {
      unsub();
    };
  }, [manager]);

  const open = useCallback((namespace?: ChainNamespace) => {
    setNamespaceFilter(namespace ?? null);
    setModalOpen(true);
  }, []);

  const close = useCallback(() => setModalOpen(false), []);

  const modal: ConnectModalControl = useMemo(
    () => ({ isOpen: modalOpen, open, close, namespaceFilter }),
    [modalOpen, open, close, namespaceFilter],
  );

  const value = useMemo(
    () => ({ manager, state, modal }),
    [manager, state, modal],
  );

  return (
    <WalletContext.Provider value={value}>
      {children}
      {withModal && <ConnectModal />}
    </WalletContext.Provider>
  );
}
