import type { MarketingPlatform } from "@/lib/vault/marketingVault";

export interface CampaignMessage {
  text: string;
  subject?: string;
  /** Reddit subreddit without r/ prefix */
  subreddit?: string;
  /** SMS / WhatsApp destination E.164 */
  smsTo?: string;
  emailTo?: string | string[];
  /** Moltbook sub-molt or channel id */
  moltChannel?: string;
}

export interface CampaignRequest {
  platforms: MarketingPlatform[];
  message: CampaignMessage;
  dryRun?: boolean;
}

export interface PlatformResult {
  platform: MarketingPlatform;
  ok: boolean;
  dryRun: boolean;
  id?: string;
  error?: string;
  detail?: unknown;
}

export interface CampaignResult {
  dryRun: boolean;
  results: PlatformResult[];
  succeeded: number;
  failed: number;
}

export interface PlatformHealth {
  platform: MarketingPlatform;
  configured: boolean;
  vaultPath: string;
}
