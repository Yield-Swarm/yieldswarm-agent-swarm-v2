/**
 * VRF lottery draw stub — Chainlink / drand integration point (God Prompt 3)
 * @see services/quests/engine.ts pickLotteryWinner
 */

export type VrfProvider = 'chainlink' | 'drand' | 'stub';

export interface VrfClient {
  requestRandomness(req: { drawingId: string; ticketRootHash: string }): Promise<{ seed: string; proof?: string }>;
}

/** Stub VRF for dev/test — SHA256-based seed */
export class StubVrfClient implements VrfClient {
  async requestRandomness(req: { drawingId: string; ticketRootHash: string }): Promise<{ seed: string }> {
    const payload = `${req.drawingId}:${req.ticketRootHash}:${Date.now()}`;
    const seed = await sha256Hex(payload);
    return { seed };
  }
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const buf = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Chainlink VRF v2 stub — wire Coordinator contract address at deploy time.
 * Solidity sketch (not compiled here):
 *
 *   function requestDraw(bytes32 drawingId, bytes32 ticketRoot) external returns (uint256 requestId);
 *   function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override;
 */
export const CHAINLINK_VRF_COORDINATOR_STUB = '0x0000000000000000000000000000000000000000';
