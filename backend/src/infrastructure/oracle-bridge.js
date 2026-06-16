/**
 * Chainlink Functions consumer bridge — relays mutation proofs on-chain.
 */

import { ethers } from 'ethers';

export { logPillarTelemetry } from '../../../src/infrastructure/pillar-telemetry-log.js';

const ORACLE_CONSUMER_ABI = [
  'function executeAgentMutation(uint256 tokenId, bytes32 requestId, bytes calldata response, bytes calldata err) external',
  'event MutationRequested(bytes32 indexed requestId, uint256 indexed tokenId)',
  'event MutationFulfilled(bytes32 indexed requestId, uint256 indexed tokenId, uint8 tier)',
];

export class YieldSwarmOracleBridge {
  /**
   * @param {string} providerUrl - Sepolia or mainnet JSON-RPC URL
   * @param {string} contractAddress - MutationController address
   * @param {string} privateKey - Relayer wallet (oracleRelayer on contract)
   */
  constructor(providerUrl, contractAddress, privateKey) {
    if (!providerUrl || !contractAddress) {
      throw new Error('providerUrl and contractAddress are required');
    }
    this.provider = new ethers.JsonRpcProvider(providerUrl);
    this.wallet = privateKey
      ? new ethers.Wallet(privateKey, this.provider)
      : null;
    this.contractAddress = contractAddress;
    this.contract = this.wallet
      ? new ethers.Contract(contractAddress, ORACLE_CONSUMER_ABI, this.wallet)
      : new ethers.Contract(contractAddress, ORACLE_CONSUMER_ABI, this.provider);
  }

  get configured() {
    return Boolean(this.wallet);
  }

  /**
   * Encode mutation payload for executeAgentMutation.
   * @param {object} params
   * @param {bigint|number|string} params.tokenId
   * @param {number} params.tier
   * @param {number} params.winRateBps - basis points (e.g. 7500 = 75%)
   * @param {string} params.uri
   */
  static encodeMutationResponse({ tokenId, tier, winRateBps, uri }) {
    return ethers.AbiCoder.defaultAbiCoder().encode(
      ['uint256', 'uint8', 'uint16', 'string'],
      [BigInt(tokenId), tier, winRateBps, uri],
    );
  }

  /**
   * Broadcast off-chain telemetry confirmation to the mutation engine.
   * @param {string|number} tokenId
   * @param {string} requestId - bytes32 hex (0x...)
   * @param {string} telemetryPayload - ABI-encoded response bytes (0x...)
   */
  async submitMutationProof(tokenId, requestId, telemetryPayload) {
    if (!this.wallet) {
      throw new Error('ORACLE_RELAYER_PRIVATE_KEY not configured');
    }

    const id = requestId.startsWith('0x') ? requestId : `0x${requestId}`;
    const payload = telemetryPayload.startsWith('0x') ? telemetryPayload : `0x${telemetryPayload}`;

    console.log(`Relaying validation proof for Agent NFT #${tokenId}...`);

    const tx = await this.contract.executeAgentMutation(
      BigInt(tokenId),
      id,
      payload,
      '0x',
      { gasLimit: 300_000n },
    );
    const receipt = await tx.wait();
    console.log(`Oracle mutation execution confirmed in block: ${receipt.blockNumber}`);
    return receipt.hash;
  }

  /**
   * Convenience: encode + submit in one call.
   */
  async submitMutation(tokenId, requestId, mutation) {
    const response = YieldSwarmOracleBridge.encodeMutationResponse(mutation);
    return this.submitMutationProof(tokenId, requestId, response);
  }
}

export default YieldSwarmOracleBridge;
