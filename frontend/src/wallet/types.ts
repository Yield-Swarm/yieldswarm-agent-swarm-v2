/**
 * Core type system for the YieldSwarm unified wallet layer.
 *
 * The design goal is a single, ecosystem-agnostic surface that the rest of the
 * app (Arena, Portal, Payments) can program against without caring whether the
 * underlying chain is EVM, Solana, TON or Bitcoin. Each ecosystem is integrated
 * through a {@link ChainAdapter} that translates these common shapes into the
 * native SDK calls.
 */

/** The high level blockchain ecosystems we support. */
export type ChainNamespace = "evm" | "solana" | "ton" | "bitcoin";

/** Stable identifier for a single chain (e.g. "evm:1", "solana:mainnet"). */
export type ChainId = string;

export interface NativeCurrency {
  name: string;
  symbol: string;
  decimals: number;
}

export interface ChainInfo {
  /** Stable cross-ecosystem id, e.g. "evm:1". */
  id: ChainId;
  namespace: ChainNamespace;
  /** Native numeric/string id used by the underlying ecosystem (1, "mainnet"). */
  reference: string | number;
  name: string;
  shortName: string;
  nativeCurrency: NativeCurrency;
  rpcUrls: string[];
  blockExplorerUrl?: string;
  iconUrl?: string;
  testnet?: boolean;
}

/** A connected account scoped to a single ecosystem. */
export interface WalletAccount {
  address: string;
  namespace: ChainNamespace;
  chainId: ChainId;
  /** Wallet provider id that produced this account (e.g. "metamask"). */
  walletId: string;
  walletName: string;
  /** Short ENS / SNS / domain style label when resolvable. */
  ens?: string | null;
}

export interface TokenBalance {
  /** Raw on-chain value in the smallest unit (wei, lamports, sats, nanoton). */
  raw: bigint;
  decimals: number;
  symbol: string;
  /** Human readable, fixed precision string (e.g. "1.2345"). */
  formatted: string;
  /** Optional fiat estimate in USD when a price feed is available. */
  usd?: number;
  /** Token contract / mint address. Absent for the native asset. */
  token?: string;
}

/** Metadata describing a wallet a user can connect with. */
export interface WalletConnector {
  id: string;
  name: string;
  namespace: ChainNamespace;
  iconUrl: string;
  /** Whether the wallet is detected/installed in the current environment. */
  installed: boolean;
  /** Whether connecting is possible without a browser extension (QR/deeplink). */
  remote?: boolean;
  downloadUrl?: string;
}

export type AmountInput = string | number | bigint;

/** A normalized transfer request used for deposits and withdrawals. */
export interface TransferRequest {
  /** Recipient address in the destination ecosystem's native format. */
  to: string;
  /** Human readable amount (e.g. "0.5"). Interpreted using token decimals. */
  amount: AmountInput;
  /** Token contract / mint. Omit for the native asset. */
  token?: string;
  /** Optional memo / comment (TON comment, BTC OP_RETURN-ish note, etc.). */
  memo?: string;
  /** Decimals override for token transfers when not auto-resolvable. */
  decimals?: number;
}

export interface TransactionResult {
  hash: string;
  chainId: ChainId;
  explorerUrl?: string;
}

export type WalletStatus =
  | "disconnected"
  | "connecting"
  | "connected"
  | "reconnecting";

/** Snapshot of an adapter's connection state, emitted on every change. */
export interface AdapterState {
  namespace: ChainNamespace;
  status: WalletStatus;
  account: WalletAccount | null;
  chain: ChainInfo | null;
}

export type Unsubscribe = () => void;

/**
 * Contract every ecosystem integration must implement. Adapters are intentionally
 * imperative and event driven so they can be wrapped by any UI framework; the
 * React layer in this package is just one consumer.
 */
export interface ChainAdapter {
  readonly namespace: ChainNamespace;

  /** List wallets selectable for this ecosystem, with install detection. */
  getConnectors(): WalletConnector[];

  /** Attempt to restore a previous session silently (no user prompt). */
  autoConnect(): Promise<WalletAccount | null>;

  connect(connectorId: string): Promise<WalletAccount>;
  disconnect(): Promise<void>;

  getState(): AdapterState;

  /** Fetch native (or specified token) balance for the active account. */
  getBalance(token?: string): Promise<TokenBalance>;

  signMessage(message: string): Promise<string>;

  /** Build, sign and broadcast a transfer. Returns the broadcast tx hash. */
  sendTransfer(request: TransferRequest): Promise<TransactionResult>;

  /** Switch the active chain within this ecosystem (EVM only in practice). */
  switchChain?(chainId: ChainId): Promise<void>;

  /** Subscribe to account/chain/status changes. */
  subscribe(listener: (state: AdapterState) => void): Unsubscribe;

  /** Tear down listeners and timers. */
  destroy(): void;
}

export class WalletError extends Error {
  code: WalletErrorCode;
  cause?: unknown;
  constructor(code: WalletErrorCode, message: string, cause?: unknown) {
    super(message);
    this.name = "WalletError";
    this.code = code;
    this.cause = cause;
  }
}

export type WalletErrorCode =
  | "not_installed"
  | "rejected"
  | "not_connected"
  | "unsupported"
  | "wrong_chain"
  | "insufficient_funds"
  | "rpc_error"
  | "unknown";
