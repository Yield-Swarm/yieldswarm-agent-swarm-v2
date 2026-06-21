import type { AzureAiFoundryClient } from "../azure/ai-foundry.js";

export interface ServerConfig {
  host: string;
  port: number;
}

export interface AzureAiFoundryConfig {
  endpoint: string;
  resourceId: string;
  apiKey: string;
  apiVersion: string;
}

export interface OdysseusStackConfig {
  chromaHost: string;
  chromaPort: number;
  litellmBaseUrl: string;
}

export interface GeodConfig {
  enabled: boolean;
  cronExpression: string;
  entropyShardCount: number;
}

export interface ObservabilityConfig {
  applicationInsightsConnectionString: string;
  roleName: string;
}

export interface OdysseusWorkspaceConfig {
  server: ServerConfig;
  azureAiFoundry: AzureAiFoundryConfig;
  odysseus: OdysseusStackConfig;
  geod: GeodConfig;
  observability: ObservabilityConfig;
}

export type DeploymentProfile = "local" | "docker" | "azure";

export interface OdysseusRuntime {
  config: OdysseusWorkspaceConfig;
  profile: DeploymentProfile;
  foundry: AzureAiFoundryClient;
}
