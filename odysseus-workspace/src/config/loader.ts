/**
 * Environment-agnostic configuration loader.
 * Mirrors Azure-Samples/todo-nodejs-mongo:
 *   config/default.json + {NODE_ENV}.json + custom-environment-variables.json
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { DeploymentProfile, OdysseusWorkspaceConfig } from "./types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONFIG_ROOT = path.resolve(__dirname, "..", "..", "config");

export class ConfigError extends Error {
  readonly missing: string[];

  constructor(message: string, missing: string[] = []) {
    super(message);
    this.name = "ConfigError";
    this.missing = missing;
  }
}

function readJson(filePath: string): Record<string, unknown> {
  if (!fs.existsSync(filePath)) return {};
  return JSON.parse(fs.readFileSync(filePath, "utf8")) as Record<string, unknown>;
}

function deepMerge(
  base: Record<string, unknown>,
  overlay: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...base };
  for (const [key, value] of Object.entries(overlay)) {
    if (
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      typeof out[key] === "object" &&
      out[key] !== null &&
      !Array.isArray(out[key])
    ) {
      out[key] = deepMerge(out[key] as Record<string, unknown>, value as Record<string, unknown>);
    } else if (value !== undefined) {
      out[key] = value;
    }
  }
  return out;
}

function applyEnvMapping(
  node: unknown,
  mapping: unknown,
): unknown {
  if (typeof mapping === "string") {
    const raw = process.env[mapping];
    return raw !== undefined && raw !== "" ? raw : undefined;
  }
  if (Array.isArray(mapping) || typeof mapping !== "object" || mapping === null) {
    return node;
  }
  const base =
    node && typeof node === "object" && !Array.isArray(node)
      ? { ...(node as Record<string, unknown>) }
      : {};
  for (const [key, childMap] of Object.entries(mapping as Record<string, unknown>)) {
    const envVal = applyEnvMapping((base as Record<string, unknown>)[key], childMap);
    if (envVal !== undefined) {
      (base as Record<string, unknown>)[key] = envVal;
    }
  }
  return base;
}

function coerceTypes(raw: Record<string, unknown>): OdysseusWorkspaceConfig {
  const server = raw.server as Record<string, unknown>;
  const foundry = raw.azureAiFoundry as Record<string, unknown>;
  const odysseus = raw.odysseus as Record<string, unknown>;
  const geod = raw.geod as Record<string, unknown>;
  const obs = raw.observability as Record<string, unknown>;

  return {
    server: {
      host: String(server?.host ?? "0.0.0.0"),
      port: Number(server?.port ?? 7000),
    },
    azureAiFoundry: {
      endpoint: String(foundry?.endpoint ?? ""),
      resourceId: String(foundry?.resourceId ?? ""),
      apiKey: String(foundry?.apiKey ?? ""),
      apiVersion: String(foundry?.apiVersion ?? "2024-05-01-preview"),
    },
    odysseus: {
      chromaHost: String(odysseus?.chromaHost ?? "chromadb"),
      chromaPort: Number(odysseus?.chromaPort ?? 8000),
      litellmBaseUrl: String(odysseus?.litellmBaseUrl ?? "http://127.0.0.1:4000/v1"),
    },
    geod: {
      enabled: parseBool(geod?.enabled, true),
      cronExpression: String(geod?.cronExpression ?? "*/15 * * * *"),
      entropyShardCount: Number(geod?.entropyShardCount ?? 120),
    },
    observability: {
      applicationInsightsConnectionString: String(obs?.applicationInsightsConnectionString ?? ""),
      roleName: String(obs?.roleName ?? "OdysseusWorkspace"),
    },
  };
}

function parseBool(value: unknown, fallback: boolean): boolean {
  if (value === undefined || value === null || value === "") return fallback;
  if (typeof value === "boolean") return value;
  const s = String(value).toLowerCase();
  return s === "1" || s === "true" || s === "yes" || s === "on";
}

export function detectDeploymentProfile(): DeploymentProfile {
  if (process.env.WEBSITE_SITE_NAME || process.env.AZURE_WEBAPP_NAME) {
    return "azure";
  }
  if (process.env.DOCKER_CONTAINER || fs.existsSync("/.dockerenv")) {
    return "docker";
  }
  return "local";
}

export function loadOdysseusConfig(
  envName = process.env.NODE_ENV || "development",
): OdysseusWorkspaceConfig {
  const defaults = readJson(path.join(CONFIG_ROOT, "default.json"));
  const envOverlay = readJson(path.join(CONFIG_ROOT, `${envName}.json`));
  const envMapping = readJson(path.join(CONFIG_ROOT, "custom-environment-variables.json"));

  const merged = deepMerge(defaults, envOverlay);
  const withEnv = applyEnvMapping(merged, envMapping) as Record<string, unknown>;

  return coerceTypes(withEnv);
}
