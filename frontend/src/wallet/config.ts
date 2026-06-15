/**
 * Runtime configuration for the wallet layer. Values are read from Vite env
 * (`import.meta.env`) with sensible public defaults so the app boots without a
 * `.env` file. Override in production via `VITE_*` variables.
 */

interface RawEnv {
  VITE_WALLETCONNECT_PROJECT_ID?: string;
  VITE_EVM_RPC_ETHEREUM?: string;
  VITE_EVM_RPC_POLYGON?: string;
  VITE_EVM_RPC_BASE?: string;
  VITE_EVM_RPC_ARBITRUM?: string;
  VITE_SOLANA_RPC_URL?: string;
  VITE_TON_MANIFEST_URL?: string;
  VITE_BITCOIN_API_URL?: string;
  VITE_APP_NAME?: string;
  VITE_APP_URL?: string;
}

const env = (import.meta.env ?? {}) as unknown as RawEnv;

export const walletConfig = {
  appName: env.VITE_APP_NAME ?? "YieldSwarm v2",
  appUrl:
    env.VITE_APP_URL ??
    (typeof window !== "undefined" ? window.location.origin : "https://yieldswarm.app"),

  /**
   * WalletConnect project id enables QR / mobile deep-link connections for EVM.
   * Without it, only injected (extension) wallets are offered. Get one free at
   * https://cloud.reown.com.
   */
  walletConnectProjectId: env.VITE_WALLETCONNECT_PROJECT_ID ?? "",

  rpc: {
    ethereum: env.VITE_EVM_RPC_ETHEREUM ?? "https://eth.llamarpc.com",
    polygon: env.VITE_EVM_RPC_POLYGON ?? "https://polygon.llamarpc.com",
    base: env.VITE_EVM_RPC_BASE ?? "https://base.llamarpc.com",
    arbitrum: env.VITE_EVM_RPC_ARBITRUM ?? "https://arbitrum.llamarpc.com",
    solana: env.VITE_SOLANA_RPC_URL ?? "https://api.mainnet-beta.solana.com",
  },

  /**
   * TonConnect requires a publicly reachable manifest describing the dApp. A
   * default is provided; replace with your hosted manifest in production.
   */
  tonManifestUrl:
    env.VITE_TON_MANIFEST_URL ??
    (typeof window !== "undefined"
      ? `${window.location.origin}/tonconnect-manifest.json`
      : "https://yieldswarm.app/tonconnect-manifest.json"),

  /** Public Bitcoin REST API used for read-only balance/UTXO lookups. */
  bitcoinApiUrl: env.VITE_BITCOIN_API_URL ?? "https://mempool.space/api",
} as const;

export type WalletConfig = typeof walletConfig;
