/**
 * Odysseus orchestration layer models.
 */

export interface OdysseusAgent {
  agentId: string;
  shardId: number;
  deityId: number | null;
  provider: 'ollama' | 'fireworks' | 'openrouter';
  model: string;
  status: 'idle' | 'running' | 'error';
  memoryCollectionId: string;
}

export interface OdysseusMemoryEntry {
  id: string;
  collection: string;
  content: string;
  metadata: Record<string, string>;
  embedding?: number[];
  createdAt: string;
}

export interface OdysseusProviderConfig {
  ollama: { url: string; models: string[] };
  fireworks: { apiBase: string; enabled: boolean };
  openrouter: { apiBase: string; enabled: boolean };
}

export interface AgentStats {
  totalAgents: number;
  activeAgents: number;
  deityCount: number;
  shardCount: number;
  memoryEntries: number;
  providers: Record<string, number>;
}
