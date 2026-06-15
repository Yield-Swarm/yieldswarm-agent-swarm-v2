import { createContext } from "react";
import type { WalletManager, WalletManagerState } from "../manager";
import type { ChainNamespace } from "../types";

export interface ConnectModalControl {
  isOpen: boolean;
  /** Open the connect modal, optionally pre-filtered to one ecosystem. */
  open: (namespace?: ChainNamespace) => void;
  close: () => void;
  /** Namespace filter currently applied to the modal, if any. */
  namespaceFilter: ChainNamespace | null;
}

export interface WalletContextValue {
  manager: WalletManager;
  state: WalletManagerState;
  modal: ConnectModalControl;
}

export const WalletContext = createContext<WalletContextValue | null>(null);
