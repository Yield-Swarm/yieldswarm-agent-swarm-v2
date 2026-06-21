/**
 * Odysseus workspace bootstrap — config → AI Foundry → GEOD hooks.
 */

import { createAzureAiFoundryClient } from "./azure/ai-foundry.js";
import { attachGeodScheduler } from "./geod/scheduler-hook.js";
import {
  detectDeploymentProfile,
  loadOdysseusConfig,
} from "./config/loader.js";
import type { OdysseusRuntime } from "./config/types.js";

export interface BootstrapOptions {
  /** Skip live Foundry health probe (useful when offline). */
  skipFoundryValidate?: boolean;
  /** Skip GEOD cron attachment. */
  skipGeod?: boolean;
}

export async function bootstrapOdysseusWorkspace(
  options: BootstrapOptions = {},
): Promise<OdysseusRuntime> {
  const profile = detectDeploymentProfile();
  const config = loadOdysseusConfig();
  const foundry = createAzureAiFoundryClient(config.azureAiFoundry);

  console.info(`[odysseus] bootstrap profile=${profile} bind=${config.server.host}:${config.server.port}`);

  if (!options.skipFoundryValidate) {
    const health = await foundry.validate();
    if (!health.ok) {
      const strict =
        process.env.NODE_ENV === "production" ||
        process.env.AZURE_AI_FOUNDRY_STRICT === "1";
      const msg = `Azure AI Foundry validation failed (${health.status}): ${health.detail}`;
      if (strict) {
        throw new Error(msg);
      }
      console.warn(`[odysseus] ${msg}`);
    } else {
      console.info(`[odysseus] Azure AI Foundry connected resource=${health.resourceId}`);
    }
  }

  const runtime: OdysseusRuntime = { config, profile, foundry };

  if (!options.skipGeod) {
    await attachGeodScheduler(runtime);
  }

  return runtime;
}
