/**
 * Phase 3 multi-LLM routing connectors — TypeScript bridge layer.
 * Rust implementations: crates/llm-connectors/src/connectors/
 */

import { fetchStructuredStrategyWithRetry } from "./gemini";
import { queryRealtimeMarketIntel } from "./grok";
import { deployPersistentScheduledTask } from "./kimi";

export {
  fetchStructuredStrategy,
  fetchStructuredStrategyWithRetry,
  type StructuredYieldResponse,
  type YieldStrategy,
} from "./gemini";
export { queryRealtimeMarketIntel } from "./grok";
export { deployPersistentScheduledTask, type ClawTaskConfig } from "./kimi";

export type LlmConnectorId = "gemini" | "grok" | "kimi";

export interface LlmRouteRequest {
  connector: LlmConnectorId;
  prompt: string;
  /** Kimi Claw only */
  claw?: {
    task_name: string;
    cron_schedule: string;
    target_skill: string;
  };
}

export async function routeLlmRequest(req: LlmRouteRequest): Promise<unknown> {
  switch (req.connector) {
    case "gemini":
      return fetchStructuredStrategyWithRetry(req.prompt);
    case "grok":
      return queryRealtimeMarketIntel(req.prompt);
    case "kimi": {
      if (!req.claw) throw new Error("Kimi route requires claw task config");
      return deployPersistentScheduledTask({
        task_name: req.claw.task_name,
        cron_schedule: req.claw.cron_schedule,
        target_skill: req.claw.target_skill,
        runtime_instructions: req.prompt,
      });
    }
    default: {
      const _exhaustive: never = req.connector;
      throw new Error(`Unknown connector: ${_exhaustive}`);
    }
  }
}
