/**
 * Centralised, typed environment access.
 *
 * Server secrets are only read on the server. Anything that must reach the
 * browser is exposed through NEXT_PUBLIC_* and surfaced via `publicConfig`.
 *
 * Nothing here throws at import time so the app can boot (and the Payments
 * page can render in "demo" mode) even when a given rail is not configured.
 * Each rail validates its own required vars lazily when it is actually used.
 */

function str(name: string, fallback = ""): string {
  return process.env[name]?.trim() || fallback;
}

function bool(name: string, fallback = false): boolean {
  const v = process.env[name]?.trim().toLowerCase();
  if (v === undefined || v === "") return fallback;
  return v === "1" || v === "true" || v === "yes" || v === "on";
}

export type SquareEnvironment = "sandbox" | "production";

export const serverEnv = {
  appUrl: str("APP_URL", str("NEXT_PUBLIC_APP_URL", "http://localhost:3000")),
  sessionSecret: (() => {
    const secret = str("SESSION_SECRET");
    const isNextBuild = process.env.NEXT_PHASE === "phase-production-build";
    if (!secret && process.env.NODE_ENV === "production" && !isNextBuild) {
      throw new Error("SESSION_SECRET is required in production");
    }
    return secret || "yieldswarm-dev-session-secret-change-me";
  })(),

  square: {
    accessToken: () => str("SQUARE_ACCESS_TOKEN"),
    locationId: () => str("SQUARE_LOCATION_ID"),
    environment: (): SquareEnvironment =>
      (str("SQUARE_ENVIRONMENT", "sandbox") as SquareEnvironment),
    /** Signature key from the Square webhook subscription. */
    webhookSignatureKey: () => str("SQUARE_WEBHOOK_SIGNATURE_KEY"),
    /** Public URL Square posted the event to (used in signature base string). */
    webhookNotificationUrl: () =>
      str(
        "SQUARE_WEBHOOK_URL",
        `${str("APP_URL", "http://localhost:3000")}/api/webhooks/square`,
      ),
  },

  wise: {
    apiToken: () => str("WISE_API_TOKEN"),
    profileId: () => str("WISE_PROFILE_ID"),
    /** api.transferwise.com (prod) or api.sandbox.transferwise.tech (sandbox). */
    apiBase: () =>
      str(
        "WISE_API_BASE",
        bool("WISE_SANDBOX", true)
          ? "https://api.sandbox.transferwise.tech"
          : "https://api.transferwise.com",
      ),
    /** PEM public key Wise uses to sign webhook deliveries. */
    webhookPublicKey: () => str("WISE_WEBHOOK_PUBLIC_KEY"),
  },

  web3: {
    evmRpcUrls: (): Record<number, string> => ({
      1: str("EVM_RPC_URL_1", "https://eth.llamarpc.com"),
      8453: str("EVM_RPC_URL_8453", "https://mainnet.base.org"),
      137: str("EVM_RPC_URL_137", "https://polygon-rpc.com"),
      42161: str("EVM_RPC_URL_42161", "https://arb1.arbitrum.io/rpc"),
    }),
    solanaRpcUrl: () => str("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com"),
    tonApiBase: () => str("TON_API_BASE", "https://tonapi.io"),
    tonApiKey: () => str("TON_API_KEY"),
    /** Treasury deposit addresses users send on-chain funds to. */
    treasury: {
      evm: () => str("TREASURY_EVM_ADDRESS"),
      solana: () => str("TREASURY_SOLANA_ADDRESS"),
      ton: () => str("TREASURY_TON_ADDRESS"),
    },
    /** Hot-wallet keys for off-ramp (withdrawals to user wallets). */
    hotWallet: {
      evmPrivateKey: () => str("HOT_WALLET_EVM_PRIVATE_KEY"),
      solanaSecretKey: () => str("HOT_WALLET_SOLANA_SECRET_KEY"),
    },
    confirmations: () => Number(str("ONCHAIN_MIN_CONFIRMATIONS", "3")) || 3,
  },

  store: {
    /** "memory" (default) or "file". Swap for a real DB in production. */
    driver: () => str("PAYMENTS_STORE_DRIVER", "memory"),
    fileDir: () => str("PAYMENTS_STORE_DIR", ".data"),
  },

  payments: {
    /** Flat customer fee (default 1%). */
    customerFeePercent: () => Number(str("MAX_FEE_PERCENT", "0.01")) || 0.01,
    /** Driver pay multiplier (default 2×). */
    driverPayMultiplier: () => Number(str("DRIVER_PAY_MULTIPLIER", "2")) || 2,
    /** Instant cashout fee when driver opts in (default 1.5%). */
    instantCashoutFeePercent: () =>
      Number(str("INSTANT_CASHOUT_FEE_PERCENT", "0.015")) || 0.015,
    kairoWebhookSecret: () => str("KAIRO_WEBHOOK_SECRET"),
  },
};

/** Config safe to send to the browser. */
export const publicConfig = {
  appUrl: str("NEXT_PUBLIC_APP_URL", "http://localhost:3000"),
  tonManifestUrl: str(
    "NEXT_PUBLIC_TONCONNECT_MANIFEST_URL",
    `${str("NEXT_PUBLIC_APP_URL", "http://localhost:3000")}/tonconnect-manifest.json`,
  ),
  square: {
    appId: str("NEXT_PUBLIC_SQUARE_APP_ID"),
    locationId: str("NEXT_PUBLIC_SQUARE_LOCATION_ID"),
    environment: str("NEXT_PUBLIC_SQUARE_ENVIRONMENT", "sandbox"),
  },
};

export function railConfigured(rail: "square" | "wise" | "web3"): boolean {
  if (rail === "square") {
    return Boolean(serverEnv.square.accessToken() && serverEnv.square.locationId());
  }
  if (rail === "wise") {
    return Boolean(serverEnv.wise.apiToken() && serverEnv.wise.profileId());
  }
  return true; // web3 reads are always available via public RPCs
}
