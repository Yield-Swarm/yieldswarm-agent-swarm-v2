import { v4 as uuidv4 } from 'uuid';
import type {
  OdysseusAgent,
  OdysseusMemoryEntry,
  AgentStats,
  OdysseusProviderConfig,
} from '../models/odysseus.js';

const AGENT_COUNT = parseInt(process.env.AGENT_COUNT_TOTAL || '10080', 10);
const DEITY_COUNT = parseInt(process.env.DEITY_COUNT || '169', 10);
const SHARD_COUNT = parseInt(process.env.CRON_SHARD_COUNT || '120', 10);

const agents: OdysseusAgent[] = [];
const memoryStore: OdysseusMemoryEntry[] = [];

function initAgents() {
  if (agents.length > 0) return;

  const providers: OdysseusAgent['provider'][] = ['ollama', 'fireworks', 'openrouter'];
  const models: Record<OdysseusAgent['provider'], string> = {
    ollama: 'llama3.1:70b',
    fireworks: 'accounts/fireworks/models/llama-v3p1-70b-instruct',
    openrouter: 'meta-llama/llama-3.1-70b-instruct',
  };

  for (let i = 0; i < AGENT_COUNT; i++) {
    const provider = providers[i % 3];
    agents.push({
      agentId: `agent-${i.toString().padStart(5, '0')}`,
      shardId: i % SHARD_COUNT,
      deityId: i < DEITY_COUNT ? i : null,
      provider,
      model: models[provider],
      status: 'idle',
      memoryCollectionId: `chroma-shard-${i % SHARD_COUNT}`,
    });
  }
}

export function getProviderConfig(): OdysseusProviderConfig {
  return {
    ollama: {
      url: process.env.OLLAMA_URL || 'http://ollama-worker:11434',
      models: (process.env.OLLAMA_MODELS || 'llama3.1:70b').split(','),
    },
    fireworks: {
      apiBase: process.env.FIREWORKS_API_BASE || 'https://api.fireworks.ai/inference/v1',
      enabled: !!process.env.FIREWORKS_API_KEY,
    },
    openrouter: {
      apiBase: process.env.OPENROUTER_API_BASE || 'https://openrouter.ai/api/v1',
      enabled: !!process.env.OPENROUTER_API_KEY,
    },
  };
}

export async function routeToProvider(
  agentId: string,
  prompt: string
): Promise<{ response: string; provider: string; latencyMs: number }> {
  initAgents();
  const agent = agents.find((a) => a.agentId === agentId) || agents[0];
  agent.status = 'running';
  const start = Date.now();

  let response: string;
  const config = getProviderConfig();

  switch (agent.provider) {
    case 'ollama':
      response = await callOllama(config.ollama.url, agent.model, prompt);
      break;
    case 'fireworks':
      response = await callOpenAICompatible(
        config.fireworks.apiBase,
        process.env.FIREWORKS_API_KEY || '',
        agent.model,
        prompt
      );
      break;
    case 'openrouter':
      response = await callOpenAICompatible(
        config.openrouter.apiBase,
        process.env.OPENROUTER_API_KEY || '',
        agent.model,
        prompt
      );
      break;
  }

  agent.status = 'idle';
  const latencyMs = Date.now() - start;

  storeMemory(agent.memoryCollectionId, prompt, response, agent.agentId);

  return { response, provider: agent.provider, latencyMs };
}

async function callOllama(baseUrl: string, model: string, prompt: string): Promise<string> {
  try {
    const res = await fetch(`${baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, prompt, stream: false }),
    });
    if (!res.ok) throw new Error(`Ollama ${res.status}`);
    const data = (await res.json()) as { response: string };
    return data.response;
  } catch (err) {
    return `[Ollama unavailable] Echo: ${prompt.slice(0, 200)}`;
  }
}

async function callOpenAICompatible(
  baseUrl: string,
  apiKey: string,
  model: string,
  prompt: string
): Promise<string> {
  if (!apiKey) return `[${model} — no API key configured]`;

  try {
    const res = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 1024,
      }),
    });
    if (!res.ok) throw new Error(`API ${res.status}`);
    const data = (await res.json()) as {
      choices: { message: { content: string } }[];
    };
    return data.choices[0]?.message?.content || '';
  } catch {
    return `[Provider unavailable] Echo: ${prompt.slice(0, 200)}`;
  }
}

function storeMemory(
  collection: string,
  prompt: string,
  response: string,
  agentId: string
): OdysseusMemoryEntry {
  const entry: OdysseusMemoryEntry = {
    id: uuidv4(),
    collection,
    content: `Q: ${prompt}\nA: ${response}`,
    metadata: { agentId, source: 'odysseus' },
    createdAt: new Date().toISOString(),
  };
  memoryStore.push(entry);
  persistToChroma(entry);
  return entry;
}

async function persistToChroma(entry: OdysseusMemoryEntry): Promise<void> {
  const chromaUrl = process.env.CHROMA_URL || 'http://chromadb:8000';
  try {
    await fetch(`${chromaUrl}/api/v1/collections/${entry.collection}/add`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ids: [entry.id],
        documents: [entry.content],
        metadatas: [entry.metadata],
      }),
    });
  } catch {
    // ChromaDB may not be available in dev — in-memory fallback active
  }
}

export function getAgentStats(): AgentStats {
  initAgents();
  const providerCounts: Record<string, number> = {};
  for (const a of agents) {
    providerCounts[a.provider] = (providerCounts[a.provider] || 0) + 1;
  }
  return {
    totalAgents: agents.length,
    activeAgents: agents.filter((a) => a.status === 'running').length,
    deityCount: DEITY_COUNT,
    shardCount: SHARD_COUNT,
    memoryEntries: memoryStore.length,
    providers: providerCounts,
  };
}

export function queryMemory(collection: string, limit = 20): OdysseusMemoryEntry[] {
  return memoryStore.filter((m) => m.collection === collection).slice(-limit);
}

export function getAgentsByShard(shardId: number): OdysseusAgent[] {
  initAgents();
  return agents.filter((a) => a.shardId === shardId);
}
