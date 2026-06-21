import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { loadOdysseusConfig } from "./loader.js";

describe("loadOdysseusConfig", () => {
  it("loads Azure AI Foundry endpoint from defaults", () => {
    const cfg = loadOdysseusConfig("development");
    assert.ok(cfg.azureAiFoundry.endpoint.includes("yieldswarmazuurecustomm-resource"));
    assert.ok(cfg.azureAiFoundry.resourceId.startsWith("/subscriptions/"));
  });

  it("overrides api key from environment mapping", () => {
    process.env.AZURE_AI_FOUNDRY_KEY = "test-key-from-env";
    const cfg = loadOdysseusConfig("development");
    assert.equal(cfg.azureAiFoundry.apiKey, "test-key-from-env");
    delete process.env.AZURE_AI_FOUNDRY_KEY;
  });
});
