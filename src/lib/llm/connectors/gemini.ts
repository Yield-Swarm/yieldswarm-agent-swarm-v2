/**
 * Phase 3 — Gemini structured JSON yield strategies.
 * Mirrors crates/llm-connectors/src/connectors/gemini for the TypeScript stack.
 */

export interface YieldStrategy {
  protocol: string;
  token_pair: string;
  target_allocation_pct: number;
  logic_justification: string;
}

export interface StructuredYieldResponse {
  batch_id: string;
  strategies: YieldStrategy[];
  execution_risk_score: number;
}

const YIELD_SCHEMA = {
  type: "OBJECT",
  properties: {
    batch_id: { type: "STRING" },
    execution_risk_score: { type: "INTEGER" },
    strategies: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          protocol: { type: "STRING" },
          token_pair: { type: "STRING" },
          target_allocation_pct: { type: "NUMBER" },
          logic_justification: { type: "STRING" },
        },
        required: ["protocol", "token_pair", "target_allocation_pct", "logic_justification"],
      },
    },
  },
  required: ["batch_id", "strategies", "execution_risk_score"],
} as const;

function geminiModel(): string {
  return process.env.GEMINI_MODEL || "gemini-2.5-pro";
}

export async function fetchStructuredStrategy(
  prompt: string,
  opts?: { apiKey?: string; correctionHint?: string },
): Promise<StructuredYieldResponse> {
  const apiKey = opts?.apiKey || process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  const userText = opts?.correctionHint ? `${prompt}\n\n${opts.correctionHint}` : prompt;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel()}:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: userText }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: YIELD_SCHEMA,
      },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini API error ${res.status}: ${await res.text()}`);
  }

  const body = await res.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Failed to extract text from Gemini response");

  return JSON.parse(text) as StructuredYieldResponse;
}

/** Fetch with automatic schema-correction retries (max 2). */
export async function fetchStructuredStrategyWithRetry(
  prompt: string,
): Promise<StructuredYieldResponse> {
  let lastErr = "unknown";
  for (let attempt = 0; attempt <= 2; attempt++) {
    try {
      return await fetchStructuredStrategy(
        prompt,
        attempt > 0
          ? {
              correctionHint: `Previous response failed validation: ${lastErr}. Return ONLY valid JSON matching the schema.`,
            }
          : undefined,
      );
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(lastErr);
}
