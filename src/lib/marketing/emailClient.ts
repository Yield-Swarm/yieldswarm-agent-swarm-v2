import { Resend } from "resend";
import { getMarketingSecret } from "@/lib/vault/marketingVault";
import { withRetry } from "./retry";

export interface EmailSendResult {
  id?: string;
  raw: unknown;
}

export async function sendMarketingEmail(
  to: string | string[],
  subject: string,
  html: string,
  opts: { dryRun?: boolean } = {},
): Promise<EmailSendResult> {
  const recipients = Array.isArray(to) ? to : [to];
  const payload = {
    from: process.env.EMAIL_FROM_ADDRESS?.trim() || "campaigns@yieldswarm.io",
    to: recipients,
    subject,
    html,
  };

  if (opts.dryRun) {
    return { id: "dry-run-email", raw: { dryRun: true, payload } };
  }

  const secrets = await getMarketingSecret("email");
  const apiKey = secrets.api_key;
  const from =
    secrets.from_address ||
    process.env.EMAIL_FROM_ADDRESS?.trim() ||
    "campaigns@yieldswarm.io";

  if (!apiKey) {
    throw Object.assign(new Error("Resend api_key not configured"), { status: 503 });
  }

  payload.from = secrets.from_name ? `${secrets.from_name} <${from}>` : from;

  return withRetry("email.send", async () => {
    const resend = new Resend(apiKey);
    const result = await resend.emails.send(payload);
    if (result.error) {
      throw Object.assign(new Error(result.error.message), {
        status: 502,
        detail: result.error,
      });
    }
    return { id: result.data?.id, raw: result };
  });
}
