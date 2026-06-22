import {
  getMarketingSecret,
  marketingPlatformsConfigured,
  type MarketingPlatform,
} from "@/lib/vault/marketingVault";
import { postToMoltbook } from "./moltbookClient";
import { postToReddit } from "./redditClient";
import { postToX } from "./xTwitterClient";
import { sendMarketingEmail } from "./emailClient";
import { sendSms } from "./twilioClient";
import type {
  CampaignRequest,
  CampaignResult,
  PlatformHealth,
  PlatformResult,
} from "./types";

function dryRunDefault(requestDryRun?: boolean): boolean {
  if (requestDryRun !== undefined) return requestDryRun;
  const env = process.env.MARKETING_DRY_RUN?.trim().toLowerCase();
  if (env === "0" || env === "false") return false;
  return env !== "0" && (env === "1" || env === "true" || process.env.NODE_ENV !== "production");
}

export class MarketingService {
  readonly appName =
    process.env.ALCHEMY_APP_NAME?.trim() || "Christopher's First App";

  async health(): Promise<PlatformHealth[]> {
    const configured = await marketingPlatformsConfigured();
    return (Object.keys(configured) as MarketingPlatform[]).map((platform) => ({
      platform,
      configured: configured[platform],
      vaultPath: `yieldswarm/data/marketing/${platform}`,
    }));
  }

  async isPlatformConfigured(platform: MarketingPlatform): Promise<boolean> {
    try {
      const secrets = await getMarketingSecret(platform);
      return Object.keys(secrets).length > 0;
    } catch {
      return false;
    }
  }

  async runCampaign(request: CampaignRequest): Promise<CampaignResult> {
    const dryRun = dryRunDefault(request.dryRun);
    const { platforms, message } = request;
    const results: PlatformResult[] = [];

    for (const platform of platforms) {
      results.push(await this.dispatchPlatform(platform, message, dryRun));
    }

    const succeeded = results.filter((r) => r.ok).length;
    return {
      dryRun,
      results,
      succeeded,
      failed: results.length - succeeded,
    };
  }

  private async dispatchPlatform(
    platform: MarketingPlatform,
    message: CampaignRequest["message"],
    dryRun: boolean,
  ): Promise<PlatformResult> {
    try {
      switch (platform) {
        case "moltbook": {
          const res = await postToMoltbook(message.text, {
            channel: message.moltChannel,
            dryRun,
          });
          return { platform, ok: true, dryRun, id: res.id, detail: res.raw };
        }
        case "reddit": {
          const sub = message.subreddit || "YieldSwarm";
          const title = message.subject || message.text.slice(0, 120);
          const res = await postToReddit(title, message.text, sub, { dryRun });
          return { platform, ok: true, dryRun, id: res.id, detail: res.raw };
        }
        case "x-twitter": {
          const res = await postToX(message.text, { dryRun });
          return { platform, ok: true, dryRun, id: res.id, detail: res.raw };
        }
        case "email": {
          const to = message.emailTo;
          if (!to) {
            return {
              platform,
              ok: false,
              dryRun,
              error: "emailTo required for email platform",
            };
          }
          const subject = message.subject || "YieldSwarm Campaign";
          const res = await sendMarketingEmail(to, subject, `<p>${message.text}</p>`, {
            dryRun,
          });
          return { platform, ok: true, dryRun, id: res.id, detail: res.raw };
        }
        case "twilio": {
          if (!message.smsTo) {
            return {
              platform,
              ok: false,
              dryRun,
              error: "smsTo required for twilio platform",
            };
          }
          const res = await sendSms(message.smsTo, message.text, { dryRun });
          return { platform, ok: true, dryRun, id: res.id, detail: res.raw };
        }
        default:
          return { platform, ok: false, dryRun, error: `unknown platform: ${platform}` };
      }
    } catch (err) {
      const error = err instanceof Error ? err.message : String(err);
      return { platform, ok: false, dryRun, error };
    }
  }
}

let _singleton: MarketingService | null = null;

export function getMarketingService(): MarketingService {
  if (!_singleton) _singleton = new MarketingService();
  return _singleton;
}
