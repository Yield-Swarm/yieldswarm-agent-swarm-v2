import twilio from "twilio";
import { getMarketingSecret } from "@/lib/vault/marketingVault";
import { withRetry } from "./retry";

export interface SmsSendResult {
  id?: string;
  raw: unknown;
}

export async function sendSms(
  to: string,
  body: string,
  opts: { dryRun?: boolean } = {},
): Promise<SmsSendResult> {
  if (opts.dryRun) {
    return {
      id: "dry-run-sms",
      raw: { dryRun: true, to, body },
    };
  }

  const secrets = await getMarketingSecret("twilio");
  const accountSid = secrets.account_sid;
  const authToken = secrets.auth_token;
  const from = secrets.from_number;

  if (!accountSid || !authToken || !from) {
    throw Object.assign(
      new Error("Twilio account_sid, auth_token, and from_number required"),
      { status: 503 },
    );
  }

  return withRetry("twilio.sms", async () => {
    const client = twilio(accountSid, authToken);
    const message = await client.messages.create({ body, from, to });
    return { id: message.sid, raw: message };
  });
}
