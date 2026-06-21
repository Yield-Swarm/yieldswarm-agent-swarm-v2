import { PublicKey } from '@solana/web3.js';
import { PROGRAM_IDS } from '../index';
import {
  CHAIN_IOPAY_BTC,
  CHAIN_IOTEX,
  YIELD_DEST_BTC_IOPAY,
  YIELD_DEST_IOTEX,
  YIELD_DEST_NEXUS,
  YieldDestination,
  getIotexRoutingConfig,
} from '../treasury/manifest';

export {
  CHAIN_IOTEX,
  CHAIN_IOPAY_BTC,
  YIELD_DEST_NEXUS,
  YIELD_DEST_IOTEX,
  YIELD_DEST_BTC_IOPAY,
  type YieldDestination,
};

export function treasuryRoutingPda(): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(
    [Buffer.from('treasury_routing')],
    PROGRAM_IDS.crossChain,
  );
}

export interface IotexRoutingParams {
  iotexTreasuryBytes: Uint8Array;
  btcBridgeHash: Uint8Array;
  defaultDestination: YieldDestination;
}

export function resolveIotexRoutingFromManifest(): IotexRoutingParams {
  const cfg = getIotexRoutingConfig();
  return {
    iotexTreasuryBytes: cfg.iotexTreasuryBytes,
    btcBridgeHash: cfg.btcBridgeHash,
    defaultDestination: cfg.defaultDestination,
  };
}

export function destinationLabel(dest: YieldDestination): string {
  switch (dest) {
    case YIELD_DEST_NEXUS:
      return 'nexus_treasury';
    case YIELD_DEST_IOTEX:
      return 'iotex_treasury';
    case YIELD_DEST_BTC_IOPAY:
      return 'btc_via_iopay';
    default:
      return 'unknown';
  }
}
