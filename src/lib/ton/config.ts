import { serverEnv } from "@/lib/config/env";

function str(name: string, fallback = ""): string {
  return process.env[name]?.trim() || fallback;
}

/**
 * Central TON mainnet / testnet configuration for server-authoritative claims.
 */
export const TON_CONFIG = {
  network: str("TON_NETWORK", "mainnet"),
  rpcEndpoint: str(
    "TON_RPC_ENDPOINT",
    "https://toncenter.com/api/v2/jsonRPC",
  ),
  apiKey: str("TONCENTER_API_KEY", serverEnv.web3.tonApiKey()),
  indexerBase: str("TON_INDEXER_URL", serverEnv.web3.tonApiBase()),
  contracts: {
    /** Player SBT / character state contract (getCharacterState). */
    sbt: str("TON_PLAYER_SBT_CONTRACT", str("TON_MINI_GAME_CONTRACT")),
    /** Jetton master for PoE emissions. */
    jetton: str("TON_POE_JETTON_MASTER"),
  },
  claim: {
    defaultDeltaSeconds: Number(str("POE_DEFAULT_DELTA_SECONDS", "60")) || 60,
    maxDeltaSeconds: Number(str("POE_MAX_DELTA_SECONDS", "3600")) || 3600,
  },
} as const;

export function tonContractsConfigured(): boolean {
  return Boolean(TON_CONFIG.contracts.sbt || TON_CONFIG.indexerBase);
}
