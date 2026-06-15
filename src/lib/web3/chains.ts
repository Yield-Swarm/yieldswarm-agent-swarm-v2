/**
 * Chain + asset registry shared by deposit detection, withdrawals and the UI.
 *
 * Covers the three wallet ecosystems requested:
 *   - EVM   (viem + ethers.js)  — Ethereum, Base, Polygon, Arbitrum
 *   - Solana (@solana/web3.js)
 *   - TON   (@tonconnect)
 */

import { Chain } from "@/lib/db/models";

export interface AssetDef {
  symbol: string;
  decimals: number;
  /** Native asset of the chain (no contract). */
  native?: boolean;
  /** EVM ERC-20 contract address. */
  erc20?: string;
  /** Solana SPL mint address. */
  splMint?: string;
  /** TON jetton master address. */
  jetton?: string;
}

export interface EvmChainDef {
  kind: "evm";
  id: number;
  name: string;
  shortName: string;
  nativeSymbol: string;
  explorer: string;
  assets: AssetDef[];
}

export interface SolanaChainDef {
  kind: "solana";
  name: string;
  explorer: string;
  assets: AssetDef[];
}

export interface TonChainDef {
  kind: "ton";
  name: string;
  explorer: string;
  assets: AssetDef[];
}

export const EVM_CHAINS: Record<number, EvmChainDef> = {
  1: {
    kind: "evm",
    id: 1,
    name: "Ethereum",
    shortName: "eth",
    nativeSymbol: "ETH",
    explorer: "https://etherscan.io",
    assets: [
      { symbol: "ETH", decimals: 18, native: true },
      { symbol: "USDC", decimals: 6, erc20: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" },
      { symbol: "USDT", decimals: 6, erc20: "0xdAC17F958D2ee523a2206206994597C13D831ec7" },
    ],
  },
  8453: {
    kind: "evm",
    id: 8453,
    name: "Base",
    shortName: "base",
    nativeSymbol: "ETH",
    explorer: "https://basescan.org",
    assets: [
      { symbol: "ETH", decimals: 18, native: true },
      { symbol: "USDC", decimals: 6, erc20: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" },
    ],
  },
  137: {
    kind: "evm",
    id: 137,
    name: "Polygon",
    shortName: "polygon",
    nativeSymbol: "POL",
    explorer: "https://polygonscan.com",
    assets: [
      { symbol: "POL", decimals: 18, native: true },
      { symbol: "USDC", decimals: 6, erc20: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359" },
    ],
  },
  42161: {
    kind: "evm",
    id: 42161,
    name: "Arbitrum One",
    shortName: "arb",
    nativeSymbol: "ETH",
    explorer: "https://arbiscan.io",
    assets: [
      { symbol: "ETH", decimals: 18, native: true },
      { symbol: "USDC", decimals: 6, erc20: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831" },
    ],
  },
};

export const SOLANA_CHAIN: SolanaChainDef = {
  kind: "solana",
  name: "Solana",
  explorer: "https://solscan.io",
  assets: [
    { symbol: "SOL", decimals: 9, native: true },
    { symbol: "USDC", decimals: 6, splMint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v" },
    { symbol: "APN", decimals: 6, splMint: "8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump" },
  ],
};

export const TON_CHAIN: TonChainDef = {
  kind: "ton",
  name: "TON",
  explorer: "https://tonviewer.com",
  assets: [
    { symbol: "TON", decimals: 9, native: true },
    {
      symbol: "USDT",
      decimals: 6,
      jetton: "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs",
    },
  ],
};

export function findAsset(chain: Chain, symbol: string, evmChainId?: number): AssetDef | null {
  const s = symbol.toUpperCase();
  if (chain === "evm") {
    const def = EVM_CHAINS[evmChainId ?? 1];
    return def?.assets.find((a) => a.symbol === s) ?? null;
  }
  if (chain === "solana") return SOLANA_CHAIN.assets.find((a) => a.symbol === s) ?? null;
  return TON_CHAIN.assets.find((a) => a.symbol === s) ?? null;
}

export function explorerTxUrl(chain: Chain, hash: string, evmChainId?: number): string {
  if (chain === "evm") {
    const def = EVM_CHAINS[evmChainId ?? 1];
    return `${def?.explorer ?? "https://etherscan.io"}/tx/${hash}`;
  }
  if (chain === "solana") return `${SOLANA_CHAIN.explorer}/tx/${hash}`;
  return `${TON_CHAIN.explorer}/transaction/${hash}`;
}

/** Public, serialisable chain catalog for the frontend. */
export function chainCatalog() {
  const evmAssetMeta: Record<string, { decimals: number; native: boolean; erc20?: string }> = {};
  for (const c of Object.values(EVM_CHAINS)) {
    for (const a of c.assets) {
      evmAssetMeta[`${c.id}:${a.symbol}`] = {
        decimals: a.decimals,
        native: Boolean(a.native),
        erc20: a.erc20,
      };
    }
  }
  return {
    evm: Object.values(EVM_CHAINS).map((c) => ({
      id: c.id,
      name: c.name,
      shortName: c.shortName,
      nativeSymbol: c.nativeSymbol,
      assets: c.assets.map((a) => a.symbol),
    })),
    solana: { name: SOLANA_CHAIN.name, assets: SOLANA_CHAIN.assets.map((a) => a.symbol) },
    ton: { name: TON_CHAIN.name, assets: TON_CHAIN.assets.map((a) => a.symbol) },
    evmAssetMeta,
  };
}
