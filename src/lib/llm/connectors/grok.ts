/**
 * Phase 3 — SuperGrok (xAI) real-time market intelligence connector.
 */

export async function queryRealtimeMarketIntel(
  analyticalQuery: string,
  opts?: { apiKey?: string; model?: string },
): Promise<string> {
  const apiKey = opts?.apiKey || process.env.GROK_API_KEY || process.env.XAI_API_KEY;
  if (!apiKey) throw new Error("GROK_API_KEY or XAI_API_KEY is not set");

  const url = process.env.GROK_API_BASE || "https://api.x.ai/v1/chat/completions";
  const model = opts?.model || process.env.GROK_MODEL || "grok-2-latest";

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content:
            "You are the YieldSwarm real-time intelligence node. Analyze live web and X context metrics. Cite uncertainty when data is stale.",
        },
        { role: "user", content: analyticalQuery },
      ],
      temperature: 0.1,
    }),
  });

  if (!res.ok) {
    throw new Error(`SuperGrok API failure ${res.status}: ${await res.text()}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) throw new Error("SuperGrok returned an empty completion");
  return content;
}
