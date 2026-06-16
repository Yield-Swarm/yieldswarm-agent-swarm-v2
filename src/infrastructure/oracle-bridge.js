/**
 * Oracle Bridge — Chainlink Functions + Automation hybrid (PDs¹).
 *
 * Greek: explicit request/response schemas and replay protection.
 * Eastern: entropy-core feeds emergent mutation seeds.
 * Paradigm Shift: trust-minimized weekly NFT mutation loop.
 *
 * @module src/infrastructure/oracle-bridge
 */

import { deriveMutationSeed, proposeGenomeDelta } from './entropy-core.js';

const CHAINLINK_FUNCTIONS_URL = process.env.CHAINLINK_FUNCTIONS_URL ?? '';
const MUTATION_CONTROLLER = process.env.MUTATION_CONTROLLER_ADDRESS ?? '';

/**
 * Build Chainlink Functions request payload for mutate-agent.js.
 * @param {object} input
 * @param {string|number} input.tokenId
 * @param {Record<string, number>} input.telemetry
 * @param {object} input.currentGenome
 */
export function buildFunctionsRequest(input) {
  const { seed, vector } = deriveMutationSeed(input.telemetry, input.tokenId);
  const { genome, genomeHash } = proposeGenomeDelta(input.currentGenome ?? {}, seed);

  return {
    version: '1',
    tokenId: String(input.tokenId),
    entropySeed: seed,
    telemetryVector: vector,
    proposedGenome: genome,
    genomeHash,
    controller: MUTATION_CONTROLLER,
    callback: 'scheduleMutation',
    layers: {
      greek: 'schema_bound_request',
      eastern: 'entropy_driven',
      paradigm: 'on_chain_co_evolution',
    },
  };
}

/**
 * Validate oracle response before on-chain submission.
 * @param {object} response from Chainlink Functions DON
 */
export function validateOracleResponse(response) {
  if (!response?.genomeHash || !response?.tokenId) {
    return { valid: false, reason: 'missing_fields' };
  }
  if (!/^0x[a-fA-F0-9]{64}$/.test(response.genomeHash)) {
    return { valid: false, reason: 'invalid_genome_hash' };
  }
  if (!/^0x[a-fA-F0-9]{64}$/.test(response.entropySeed ?? '0x00')) {
    return { valid: false, reason: 'invalid_entropy_seed' };
  }
  return { valid: true };
}

/**
 * Encode calldata for MutationController.executeMutation (for Automation performUpkeep).
 */
export function encodeExecuteMutationCalldata(tokenId, genomeHash, genome) {
  // ABI encoding placeholder — use viem/ethers in production deploy script.
  return {
    to: MUTATION_CONTROLLER,
    function: 'executeMutation(uint256,bytes32,(uint16,uint16,uint16,uint16,uint16,uint8,uint32,uint64))',
    args: [tokenId, genomeHash, genome],
  };
}

export default { buildFunctionsRequest, validateOracleResponse, encodeExecuteMutationCalldata };
