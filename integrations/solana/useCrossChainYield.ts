/**
 * Re-export Helix cross-chain yield hook (full Anchor SDK in sdk/helix).
 * @see sdk/helix/src/hooks/useCrossChainYield.ts
 */
export {
  useCrossChainYield,
  type CrossChainYieldSnapshot,
  type UseCrossChainYieldOptions,
  type UseCrossChainYieldResult,
} from '../../sdk/helix/src/hooks/useCrossChainYield.js';

export { HelixClient, CHAIN_IDS, DEFAULT_MAX_SLIPPAGE_BPS } from '../../sdk/helix/src/client.js';
export { PROGRAM_IDS } from './programs.js';
