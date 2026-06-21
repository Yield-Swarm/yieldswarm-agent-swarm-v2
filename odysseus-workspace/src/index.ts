#!/usr/bin/env node
/**
 * Odysseus workspace entrypoint — boots config, AI Foundry, GEOD scheduler.
 */

import { bootstrapOdysseusWorkspace } from "./bootstrap.js";

const runtime = await bootstrapOdysseusWorkspace({
  skipFoundryValidate: process.env.ODYSSEUS_SKIP_FOUNDRY_VALIDATE === "1",
  skipGeod: process.env.GEOD_CRON_ENABLED === "0",
});

console.info(
  JSON.stringify({
    ok: true,
    profile: runtime.profile,
    endpoint: runtime.foundry.endpoint,
    resourceId: runtime.foundry.resourceId,
    geodEnabled: runtime.config.geod.enabled,
    litellm: runtime.config.odysseus.litellmBaseUrl,
  }),
);
