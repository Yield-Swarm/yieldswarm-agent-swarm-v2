import type { PublicKey, Transaction, VersionedTransaction } from "@solana/web3.js";

declare global {
  interface EthereumProvider {
    request<T = unknown>(args: { method: string; params?: unknown[] | object }): Promise<T>;
    on?(event: string, handler: (...args: any[]) => void): void;
    removeListener?(event: string, handler: (...args: any[]) => void): void;
    isMetaMask?: boolean;
  }

  interface SolanaProvider {
    isPhantom?: boolean;
    publicKey?: PublicKey | null;
    connect(opts?: { onlyIfTrusted?: boolean }): Promise<{ publicKey: PublicKey }>;
    disconnect(): Promise<void>;
    signMessage(message: Uint8Array, display?: string): Promise<{ signature: Uint8Array }>;
    signAndSendTransaction(
      tx: Transaction | VersionedTransaction,
    ): Promise<{ signature: string }>;
  }

  interface Window {
    ethereum?: EthereumProvider;
    solana?: SolanaProvider;
  }
}

export {};
