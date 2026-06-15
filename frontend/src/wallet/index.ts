/**
 * YieldSwarm unified wallet layer — public API.
 *
 * Usage:
 *   import { WalletProvider, WalletButton, useWallet, useBalance, useTransfer } from "@/wallet";
 *
 * Wrap the app in <WalletProvider>, drop a <WalletButton/> in the nav, and use
 * the hooks anywhere to read accounts/balances and sign deposits/withdrawals
 * across EVM, Solana, TON and Bitcoin.
 */

// React layer
export { WalletProvider } from "./react/WalletProvider";
export {
  useWallet,
  useWalletManager,
  useConnectModal,
  useAccount,
  useChain,
  useBalance,
  useTransfer,
} from "./react/hooks";
export type {
  UseBalanceResult,
  UseTransferResult,
  TransferStatus,
} from "./react/hooks";

// UI
export { WalletButton } from "./ui/WalletButton";
export { ConnectModal } from "./ui/ConnectModal";
export { AccountModal } from "./ui/AccountModal";
export { BalanceLine } from "./ui/BalanceLine";

// Core
export { WalletManager } from "./manager";
export type { WalletManagerState } from "./manager";
export {
  CHAINS,
  DEFAULT_CHAIN,
  NAMESPACE_LABEL,
  getChain,
  chainIdFrom,
  chainsForNamespace,
  explorerTxUrl,
  explorerAddressUrl,
} from "./chains";
export { walletConfig } from "./config";
export {
  toBaseUnits,
  fromBaseUnits,
  formatBalance,
  shortenAddress,
} from "./format";

export {
  WalletError,
} from "./types";
export type {
  ChainNamespace,
  ChainId,
  ChainInfo,
  NativeCurrency,
  WalletAccount,
  TokenBalance,
  WalletConnector,
  TransferRequest,
  TransactionResult,
  WalletStatus,
  AdapterState,
  ChainAdapter,
  AmountInput,
  WalletErrorCode,
} from "./types";
