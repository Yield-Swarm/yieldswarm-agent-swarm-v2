import axios, { type AxiosError } from "axios";
import { getMarketingSecret } from "@/lib/vault/marketingVault";
import { withRetry } from "./retry";

const MOLTBOOK_API_BASE =
  process.env.MOLTBOOK_API_BASE?.trim() || "https://api.moltbook.com/v1";

export interface MoltbookPostResult {
  id?: string;
  raw: unknown;
}

export async function postToMoltbook(
  content: string,
  opts: { channel?: string; dryRun?: boolean } = {},
): Promise<MoltbookPostResult> {
  const payload = {
    content,
    channel: opts.channel || "yieldswarm",
  };

  if (opts.dryRun) {
    return { id: "dry-run-moltbook", raw: { dryRun: true, payload } };
  }

  const secrets = await getMarketingSecret("moltbook");
  const apiKey = secrets.api_key;
  if (!apiKey) {
    throw Object.assign(new Error("Moltbook api_key not configured"), { status: 503 });
  }

  payload.channel = opts.channel || secrets.default_channel || payload.channel;

  return withRetry("moltbook.post", async () => {
    try {
      const res = await axios.post(`${MOLTBOOK_API_BASE}/posts`, payload, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30_000,
      });
      const data = res.data as { id?: string };
      return { id: data.id, raw: res.data };
    } catch (err) {
      const ax = err as AxiosError;
      const status = ax.response?.status;
      throw Object.assign(
        new Error(ax.message || "Moltbook API error"),
        { status, detail: ax.response?.data },
      );
    }
  });
}
