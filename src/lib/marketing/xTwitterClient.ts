import { TwitterApi } from "twitter-api-v2";
import { getMarketingSecret } from "@/lib/vault/marketingVault";
import { withRetry } from "./retry";

async function twitterClient(): Promise<TwitterApi> {
  const secrets = await getMarketingSecret("x-twitter");

  if (secrets.bearer_token) {
    return new TwitterApi(secrets.bearer_token);
  }

  const { api_key, api_secret, access_token, access_secret } = secrets;
  if (api_key && api_secret && access_token && access_secret) {
    return new TwitterApi({
      appKey: api_key,
      appSecret: api_secret,
      accessToken: access_token,
      accessSecret: access_secret,
    });
  }

  if (access_token) {
    return new TwitterApi(access_token);
  }

  throw Object.assign(new Error("X/Twitter credentials not configured"), { status: 503 });
}

export interface XPostResult {
  id?: string;
  raw: unknown;
}

export async function postToX(
  text: string,
  opts: { dryRun?: boolean } = {},
): Promise<XPostResult> {
  if (opts.dryRun) {
    return { id: "dry-run-x", raw: { dryRun: true, text } };
  }

  return withRetry("x.tweet", async () => {
    const client = await twitterClient();
    const rw = client.readWrite;
    const tweet = await rw.v2.tweet(text);
    return { id: tweet.data.id, raw: tweet };
  });
}
