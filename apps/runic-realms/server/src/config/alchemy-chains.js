/**
 * Alchemy-supported networks for Runic Realms multi-chain routing.
 * URLs: https://{subdomain}.g.alchemy.com/v2/{ALCHEMY_API_KEY}
 */
export const ALCHEMY_CHAINS = Object.freeze([
  { id: 'eth-mainnet', name: 'Ethereum', subdomain: 'eth-mainnet', chainId: 1, symbol: 'ETH' },
  { id: 'eth-sepolia', name: 'Ethereum Sepolia', subdomain: 'eth-sepolia', chainId: 11155111, symbol: 'ETH', testnet: true },
  { id: 'polygon-mainnet', name: 'Polygon', subdomain: 'polygon-mainnet', chainId: 137, symbol: 'MATIC' },
  { id: 'polygon-amoy', name: 'Polygon Amoy', subdomain: 'polygon-amoy', chainId: 80002, symbol: 'MATIC', testnet: true },
  { id: 'arb-mainnet', name: 'Arbitrum', subdomain: 'arb-mainnet', chainId: 42161, symbol: 'ETH' },
  { id: 'arb-sepolia', name: 'Arbitrum Sepolia', subdomain: 'arb-sepolia', chainId: 421614, symbol: 'ETH', testnet: true },
  { id: 'opt-mainnet', name: 'Optimism', subdomain: 'opt-mainnet', chainId: 10, symbol: 'ETH' },
  { id: 'opt-sepolia', name: 'Optimism Sepolia', subdomain: 'opt-sepolia', chainId: 11155420, symbol: 'ETH', testnet: true },
  { id: 'base-mainnet', name: 'Base', subdomain: 'base-mainnet', chainId: 8453, symbol: 'ETH' },
  { id: 'base-sepolia', name: 'Base Sepolia', subdomain: 'base-sepolia', chainId: 84532, symbol: 'ETH', testnet: true },
  { id: 'blast-mainnet', name: 'Blast', subdomain: 'blast-mainnet', chainId: 81457, symbol: 'ETH' },
  { id: 'zksync-mainnet', name: 'zkSync Era', subdomain: 'zksync-mainnet', chainId: 324, symbol: 'ETH' },
  { id: 'linea-mainnet', name: 'Linea', subdomain: 'linea-mainnet', chainId: 59144, symbol: 'ETH' },
  { id: 'scroll-mainnet', name: 'Scroll', subdomain: 'scroll-mainnet', chainId: 534352, symbol: 'ETH' },
  { id: 'mantle-mainnet', name: 'Mantle', subdomain: 'mantle-mainnet', chainId: 5000, symbol: 'MNT' },
  { id: 'bnb-mainnet', name: 'BNB Chain', subdomain: 'bnb-mainnet', chainId: 56, symbol: 'BNB' },
  { id: 'avax-mainnet', name: 'Avalanche', subdomain: 'avax-mainnet', chainId: 43114, symbol: 'AVAX' },
  { id: 'gnosis-mainnet', name: 'Gnosis', subdomain: 'gnosis-mainnet', chainId: 100, symbol: 'xDAI' },
]);
