import Snoowrap from "snoowrap";
import { getMarketingSecret } from "@/lib/vault/marketingVault";
import { withRetry } from "./retry";

async function redditClient(): Promise<Snoowrap> {
  const secrets = await getMarketingSecret("reddit");
  const { client_id, client_secret, refresh_token, user_agent } = secrets;
  if (!client_id || !client_secret || !refresh_token) {
    throw Object.assign(new Error("Reddit OAuth credentials not configured"), {
      status: 503,
    });
  }
  return new Snoowrap({
    userAgent: user_agent || "yieldswarm-agent-swarm/2.0 by Christopher",
    clientId: client_id,
    clientSecret: client_secret,
    refreshToken: refresh_token,
  });
}

export interface RedditPostResult {
  id?: string;
  url?: string;
  raw: unknown;
}

export async function postToReddit(
  title: string,
  text: string,
  subreddit: string,
  opts: { dryRun?: boolean } = {},
): Promise<RedditPostResult> {
  const sub = subreddit.replace(/^r\//, "");
  if (opts.dryRun) {
    return {
      id: "dry-run-reddit",
      raw: { dryRun: true, subreddit: sub, title, text },
    };
  }

  return withRetry("reddit.submit", async () => {
    const r = await redditClient();
    const submission = await r.getSubreddit(sub).submitSelfpost({ title, text });
    return {
      id: submission.id,
      url: submission.url,
      raw: { name: submission.name, permalink: submission.permalink },
    };
  });
}
