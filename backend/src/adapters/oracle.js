/**
 * Oracle adapter — wraps YieldSwarmOracleBridge for API + dry-run mode.
 */

import config from '../config.js';
import { YieldSwarmOracleBridge } from '../infrastructure/oracle-bridge.js';

let bridge;

function getBridge() {
  if (!bridge) {
    bridge = new YieldSwarmOracleBridge(
      config.oracle.rpcUrl,
      config.oracle.mutationControllerAddress,
      config.oracle.relayerPrivateKey || undefined,
    );
  }
  return bridge;
}

export async function getOracleStatus() {
  const b = getBridge();
  return {
    live: Boolean(config.oracle.mutationControllerAddress && config.oracle.rpcUrl),
    configured: b.configured,
    mutationController: config.oracle.mutationControllerAddress || null,
    rpcUrl: config.oracle.rpcUrl ? '[configured]' : null,
    agentNft: config.oracle.agentNftAddress || null,
    source: config.oracle.mutationControllerAddress ? 'evm-oracle' : 'disabled',
  };
}

/**
 * Submit mutation proof (dry-run when relayer key missing).
 */
export async function syncMutationProof({ tokenId, requestId, tier, winRateBps, uri, responseHex }) {
  const b = getBridge();
  const payload = responseHex || YieldSwarmOracleBridge.encodeMutationResponse({
    tokenId,
    tier: tier ?? 1,
    winRateBps: winRateBps ?? 0,
    uri: uri ?? '',
  });

  if (!b.configured) {
    return {
      dryRun: true,
      tokenId: String(tokenId),
      requestId: requestId || ethersZeroRequestId(),
      payload,
      message: 'Set ORACLE_RELAYER_PRIVATE_KEY for on-chain submission',
    };
  }

  const txHash = await b.submitMutationProof(
    tokenId,
    requestId || ethersZeroRequestId(),
    payload,
  );
  return { dryRun: false, txHash, tokenId: String(tokenId) };
}

function ethersZeroRequestId() {
  return '0x' + '00'.repeat(32);
}

export { YieldSwarmOracleBridge };
