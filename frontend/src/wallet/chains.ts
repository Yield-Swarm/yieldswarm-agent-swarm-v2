/**
 * Chain registry. Every supported chain is described once here with a stable
 * cross-ecosystem id of the form `<namespace>:<reference>`. Adapters and UI both
 * resolve metadata (name, explorer, native currency, icon) from this registry.
 */
import { walletConfig } from "./config";
import type { ChainId, ChainInfo, ChainNamespace } from "./types";

export const CHAINS: Record<ChainId, ChainInfo> = {
  // ---- EVM ----
  "evm:1": {
    id: "evm:1",
    namespace: "evm",
    reference: 1,
    name: "Ethereum",
    shortName: "ETH",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: [walletConfig.rpc.ethereum],
    blockExplorerUrl: "https://etherscan.io",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_ethereum.jpg",
  },
  "evm:137": {
    id: "evm:137",
    namespace: "evm",
    reference: 137,
    name: "Polygon",
    shortName: "MATIC",
    nativeCurrency: { name: "POL", symbol: "POL", decimals: 18 },
    rpcUrls: [walletConfig.rpc.polygon],
    blockExplorerUrl: "https://polygonscan.com",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_polygon.jpg",
  },
  "evm:8453": {
    id: "evm:8453",
    namespace: "evm",
    reference: 8453,
    name: "Base",
    shortName: "BASE",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: [walletConfig.rpc.base],
    blockExplorerUrl: "https://basescan.org",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_base.jpg",
  },
  "evm:42161": {
    id: "evm:42161",
    namespace: "evm",
    reference: 42161,
    name: "Arbitrum One",
    shortName: "ARB",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: [walletConfig.rpc.arbitrum],
    blockExplorerUrl: "https://arbiscan.io",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_arbitrum.jpg",
  },

  // ---- Solana ----
  "solana:mainnet": {
    id: "solana:mainnet",
    namespace: "solana",
    reference: "mainnet-beta",
    name: "Solana",
    shortName: "SOL",
    nativeCurrency: { name: "Solana", symbol: "SOL", decimals: 9 },
    rpcUrls: [walletConfig.rpc.solana],
    blockExplorerUrl: "https://solscan.io",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_solana.jpg",
  },

  // ---- TON ----
  "ton:mainnet": {
    id: "ton:mainnet",
    namespace: "ton",
    reference: "-239",
    name: "TON",
    shortName: "TON",
    nativeCurrency: { name: "Toncoin", symbol: "TON", decimals: 9 },
    rpcUrls: ["https://toncenter.com/api/v2/jsonRPC"],
    blockExplorerUrl: "https://tonviewer.com",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_ton.jpg",
  },

  // ---- Bitcoin ----
  "bitcoin:mainnet": {
    id: "bitcoin:mainnet",
    namespace: "bitcoin",
    reference: "mainnet",
    name: "Bitcoin",
    shortName: "BTC",
    nativeCurrency: { name: "Bitcoin", symbol: "BTC", decimals: 8 },
    rpcUrls: [walletConfig.bitcoinApiUrl],
    blockExplorerUrl: "https://mempool.space",
    iconUrl: "https://icons.llamao.fi/icons/chains/rsz_bitcoin.jpg",
  },
};

export const DEFAULT_CHAIN: Record<ChainNamespace, ChainId> = {
  evm: "evm:1",
  solana: "solana:mainnet",
  ton: "ton:mainnet",
  bitcoin: "bitcoin:mainnet",
};

export const NAMESPACE_LABEL: Record<ChainNamespace, string> = {
  evm: "EVM",
  solana: "Solana",
  ton: "TON",
  bitcoin: "Bitcoin",
};

export function getChain(id: ChainId): ChainInfo | undefined {
  return CHAINS[id];
}

/** Resolve a cross-ecosystem ChainId from a namespace + native reference. */
export function chainIdFrom(
  namespace: ChainNamespace,
  reference: string | number,
): ChainId {
  return `${namespace}:${reference}`;
}

export function chainsForNamespace(namespace: ChainNamespace): ChainInfo[] {
  return Object.values(CHAINS).filter((c) => c.namespace === namespace);
}

export function explorerTxUrl(chain: ChainInfo, hash: string): string | undefined {
  if (!chain.blockExplorerUrl) return undefined;
  switch (chain.namespace) {
    case "solana":
      return `${chain.blockExplorerUrl}/tx/${hash}`;
    case "ton":
      return `${chain.blockExplorerUrl}/transaction/${hash}`;
    case "bitcoin":
      return `${chain.blockExplorerUrl}/tx/${hash}`;
    case "evm":
    default:
      return `${chain.blockExplorerUrl}/tx/${hash}`;
  }
}

export function explorerAddressUrl(
  chain: ChainInfo,
  address: string,
): string | undefined {
  if (!chain.blockExplorerUrl) return undefined;
  if (chain.namespace === "bitcoin")
    return `${chain.blockExplorerUrl}/address/${address}`;
  if (chain.namespace === "solana")
    return `${chain.blockExplorerUrl}/account/${address}`;
  return `${chain.blockExplorerUrl}/address/${address}`;
}
