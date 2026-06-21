/**
 * Phase 3 — Kimi Claw scheduled task automation connector.
 */

export interface ClawTaskConfig {
  task_name: string;
  cron_schedule: string;
  target_skill: string;
  runtime_instructions: string;
}

export async function deployPersistentScheduledTask(
  config: ClawTaskConfig,
  opts?: { bearerToken?: string; endpointBase?: string },
): Promise<string> {
  const bearerToken =
    opts?.bearerToken ||
    process.env.KIMICLAW_CONSENSUS_KEY ||
    process.env.KIMI_CLAW_API_TOKEN;
  if (!bearerToken) {
    throw new Error("KIMICLAW_CONSENSUS_KEY or KIMI_CLAW_API_TOKEN is not set");
  }

  const base = (opts?.endpointBase || process.env.KIMI_CLAW_API_BASE || "https://api.kimi.com/v1/claw").replace(
    /\/$/,
    "",
  );
  const endpoint = `${base}/tasks/register`;

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${bearerToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: config.task_name,
      schedule: config.cron_schedule,
      skill_id: config.target_skill,
      config: {
        prompt_instructions: config.runtime_instructions,
        persistence_strategy: "always_on",
        output_target: "yield_swarm_ingest_pipeline",
      },
    }),
  });

  const bodyText = await res.text();
  if (!res.ok) {
    throw new Error(`KimiClaw deployment failure (${res.status}): ${bodyText}`);
  }
  return bodyText;
}
