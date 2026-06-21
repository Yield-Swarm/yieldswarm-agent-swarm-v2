import {
  TREASURY_MANIFEST_DEFAULT,
  BTC_BRIDGE_HASH_HEX,
  type TreasuryManifest,
} from './defaults';

export const CHAIN_IOTEX = 0x00001250;
export const CHAIN_IOPAY_BTC = 0x00494f50;

export const YIELD_DEST_NEXUS = 0;
export const YIELD_DEST_IOTEX = 1;
export const YIELD_DEST_BTC_IOPAY = 2;

export type YieldDestination =
  | typeof YIELD_DEST_NEXUS
  | typeof YIELD_DEST_IOTEX
  | typeof YIELD_DEST_BTC_IOPAY;

export type { TreasuryManifest };

export function loadTreasuryManifest(): TreasuryManifest {
  return TREASURY_MANIFEST_DEFAULT;
}

export function evmAddressToBytes(hex: string): Uint8Array {
  const clean = hex.startsWith('0x') ? hex.slice(2) : hex;
  if (clean.length !== 40) {
    throw new Error(`Invalid EVM address length: ${hex}`);
  }
  const out = new Uint8Array(20);
  for (let i = 0; i < 20; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

export function hexToBytes32(hex: string): Uint8Array {
  const clean = hex.length === 64 ? hex : hex.replace(/^0x/, '');
  const out = new Uint8Array(32);
  for (let i = 0; i < 32; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

export function getIotexRoutingConfig(manifest: TreasuryManifest = loadTreasuryManifest()) {
  return {
    iotexTreasury: manifest.iotex_hub.primary,
    iotexTreasuryBytes: evmAddressToBytes(manifest.iotex_hub.primary),
    btcBridge: manifest.iotex_hub.btc_bridge,
    btcBridgeHash: hexToBytes32(BTC_BRIDGE_HASH_HEX),
    defaultDestination: YIELD_DEST_IOTEX as YieldDestination,
  };
}
