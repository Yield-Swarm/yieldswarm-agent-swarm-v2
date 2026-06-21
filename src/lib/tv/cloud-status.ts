import { backendBase } from "./config";

export interface CloudProviderStatus {
  id: string;
  label: string;
  live: boolean;
  detail: string;
  workers?: number;
}

async function pingUrl(url: string): Promise<boolean> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5000), next: { revalidate: 15 } });
    return res.ok;
  } catch {
    return false;
  }
}

export async function fetchMultiCloudStatus(): Promise<CloudProviderStatus[]> {
  const base = backendBase();
  const [health, akashWorkers] = await Promise.all([
    fetch(`${base}/health`, { next: { revalidate: 15 } })
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null),
    fetch(`${base}/akash/workers`, { next: { revalidate: 15 } })
      .then((r) => (r.ok ? r.json() : null))
      .catch(() => null),
  ]);

  const akashLive = Boolean(health?.upstreams?.akash?.live || akashWorkers?.live);
  const akashCount = akashWorkers?.totalWorkers ?? akashWorkers?.workers?.length ?? 0;

  const azureConfigured = Boolean(
    process.env.AZURE_SUBSCRIPTION_ID || process.env.AZURE_OPENAI_ENDPOINT,
  );
  const vastConfigured = Boolean(process.env.VAST_API_KEY);
  const runpodConfigured = Boolean(process.env.RUNPOD_API_KEY);

  const akashConsole = await pingUrl(
    (process.env.AKASH_CONSOLE_API || "https://console-api.akash.network/v1") + "/status",
  );

  return [
    {
      id: "akash",
      label: "Akash Network",
      live: akashLive || akashConsole,
      detail: akashLive ? `${akashCount} workers` : akashConsole ? "console online" : "degraded",
      workers: akashCount,
    },
    {
      id: "azure",
      label: "Azure",
      live: azureConfigured,
      detail: azureConfigured ? "subscription configured" : "not configured",
    },
    {
      id: "vast",
      label: "Vast.ai",
      live: vastConfigured,
      detail: vastConfigured ? "API key present" : "not configured",
    },
    {
      id: "runpod",
      label: "RunPod",
      live: runpodConfigured,
      detail: runpodConfigured ? "API key present" : "not configured",
    },
  ];
}
