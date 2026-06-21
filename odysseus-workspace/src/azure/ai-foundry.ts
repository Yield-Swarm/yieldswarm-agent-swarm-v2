/**
 * Azure AI Foundry client bindings.
 * Authenticates via AZURE_AI_FOUNDRY_KEY — fails fast when missing in production.
 */

import type { AzureAiFoundryConfig } from "../config/types.js";
import { ConfigError } from "../config/loader.js";

export interface FoundryHealthResult {
  ok: boolean;
  endpoint: string;
  resourceId: string;
  status: number;
  detail?: string;
}

export class AzureAiFoundryClient {
  constructor(private readonly cfg: AzureAiFoundryConfig) {}

  get endpoint(): string {
    return this.cfg.endpoint.replace(/\/$/, "");
  }

  get resourceId(): string {
    return this.cfg.resourceId;
  }

  get apiVersion(): string {
    return this.cfg.apiVersion;
  }

  requireApiKey(): string {
    const key = this.cfg.apiKey?.trim();
    if (!key || key === "[REDACTED]") {
      throw new ConfigError(
        "AZURE_AI_FOUNDRY_KEY is required — set in environment or Azure App Service configuration",
        ["AZURE_AI_FOUNDRY_KEY"],
      );
    }
    return key;
  }

  chatCompletionsUrl(): string {
    return `${this.endpoint}/chat/completions?api-version=${encodeURIComponent(this.apiVersion)}`;
  }

  authHeaders(): Record<string, string> {
    return {
      "Content-Type": "application/json",
      "api-key": this.requireApiKey(),
    };
  }

  async validate(): Promise<FoundryHealthResult> {
    if (!this.cfg.endpoint) {
      throw new ConfigError("AZURE_AI_FOUNDRY_ENDPOINT is not configured", [
        "AZURE_AI_FOUNDRY_ENDPOINT",
      ]);
    }
    if (!this.cfg.resourceId) {
      throw new ConfigError("AZURE_AI_FOUNDRY_RESOURCE_ID is not configured", [
        "AZURE_AI_FOUNDRY_RESOURCE_ID",
      ]);
    }

    const key = this.requireApiKey();
    const url = `${this.endpoint}/models?api-version=${encodeURIComponent(this.apiVersion)}`;

    try {
      const res = await fetch(url, {
        method: "GET",
        headers: {
          "api-key": key,
        },
      });
      return {
        ok: res.ok,
        endpoint: this.endpoint,
        resourceId: this.resourceId,
        status: res.status,
        detail: res.ok ? "connected" : await res.text().catch(() => res.statusText),
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return {
        ok: false,
        endpoint: this.endpoint,
        resourceId: this.resourceId,
        status: 0,
        detail: message,
      };
    }
  }
}

export function createAzureAiFoundryClient(
  cfg: AzureAiFoundryConfig,
): AzureAiFoundryClient {
  return new AzureAiFoundryClient(cfg);
}
