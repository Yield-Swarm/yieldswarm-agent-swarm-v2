/**
 * Marketing platform secrets — Vault KV paths under yieldswarm/data/marketing/*
 * with env fallbacks for local dev (Christopher's First App pattern).
 */

import { vaultReadKv } from "./client";

export type MarketingPlatform =
  | "moltbook"
  | "reddit"
  | "x-twitter"
  | "email"
  | "twilio";

export type MarketingSecret = Record<string, string>;

const PLATFORM_ENV_FALLBACKS: Record<MarketingPlatform, Record<string, string>> = {
  moltbook: {
    api_key: "MOLTBOOK_API_KEY",
  },
  reddit: {
    client_id: "REDDIT_CLIENT_ID",
    client_secret: "REDDIT_CLIENT_SECRET",
    refresh_token: "REDDIT_REFRESH_TOKEN",
    user_agent: "REDDIT_USER_AGENT",
    username: "REDDIT_USERNAME",
  },
  "x-twitter": {
    bearer_token: "X_TWITTER_BEARER_TOKEN",
    access_token: "X_TWITTER_ACCESS_TOKEN",
    access_secret: "X_TWITTER_ACCESS_SECRET",
    api_key: "X_TWITTER_API_KEY",
    api_secret: "X_TWITTER_API_SECRET",
  },
  email: {
    api_key: "RESEND_API_KEY",
    from_address: "EMAIL_FROM_ADDRESS",
    from_name: "EMAIL_FROM_NAME",
  },
  twilio: {
    account_sid: "TWILIO_ACCOUNT_SID",
    auth_token: "TWILIO_AUTH_TOKEN",
    from_number: "TWILIO_FROM_NUMBER",
  },
};

function loadFromEnv(platform: MarketingPlatform): MarketingSecret {
  const mapping = PLATFORM_ENV_FALLBACKS[platform];
  const out: MarketingSecret = {};
  for (const [vaultKey, envKey] of Object.entries(mapping)) {
    const val = process.env[envKey]?.trim();
    if (val) out[vaultKey] = val;
  }
  return out;
}

/**
 * Load marketing credentials for a platform.
 * Vault path: yieldswarm/data/marketing/{platform}
 * Falls back to env when Vault is unavailable or path is empty.
 */
export async function getMarketingSecret(
  platform: MarketingPlatform,
  secretId?: string,
): Promise<MarketingSecret> {
  const envSecrets = loadFromEnv(platform);

  if (!process.env.VAULT_ADDR?.trim()) {
    return envSecrets;
  }

  try {
    const vaultSecrets = await vaultReadKv(`marketing/${platform}`, {
      secretId,
    });
    return { ...envSecrets, ...vaultSecrets };
  } catch (err) {
    if (Object.keys(envSecrets).length > 0) {
      return envSecrets;
    }
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(`Failed to load ${platform} secret from Vault: ${message}`);
  }
}

export async function marketingPlatformsConfigured(): Promise<
  Record<MarketingPlatform, boolean>
> {
  const platforms: MarketingPlatform[] = [
    "moltbook",
    "reddit",
    "x-twitter",
    "email",
    "twilio",
  ];
  const out = {} as Record<MarketingPlatform, boolean>;
  for (const p of platforms) {
    try {
      const secrets = await getMarketingSecret(p);
      out[p] = Object.keys(secrets).length > 0;
    } catch {
      out[p] = false;
    }
  }
  return out;
}
