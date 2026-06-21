import { DOMAINS } from "./config";

export interface DomainStatus {
  id: string;
  label: string;
  host: string;
  kind: "official" | "unstoppable";
  resolved: boolean;
  records: Record<string, string>;
  error?: string;
}

async function resolveUdDomain(host: string, apiKey: string): Promise<Record<string, string>> {
  const tld = host.includes(".") ? host : `${host}.crypto`;
  const url = `https://api.unstoppabledomains.com/resolve/domains/${encodeURIComponent(tld)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
    next: { revalidate: 300 },
  });
  if (!res.ok) throw new Error(`UD API ${res.status}`);
  const data = (await res.json()) as { records?: Record<string, string> };
  return data.records || {};
}

export async function fetchDomainStatuses(): Promise<DomainStatus[]> {
  const apiKey = process.env.UD_API_KEY || process.env.UNSTOPPABLE_API_KEY || "";
  const results: DomainStatus[] = [];

  for (const d of DOMAINS) {
    if (d.kind === "official") {
      results.push({
        id: d.id,
        label: d.label,
        host: d.host,
        kind: "official",
        resolved: true,
        records: { website: d.url },
      });
      continue;
    }

    if (!apiKey) {
      results.push({
        id: d.id,
        label: d.label,
        host: d.host,
        kind: "unstoppable",
        resolved: false,
        records: {},
        error: "UD_API_KEY not set",
      });
      continue;
    }

    try {
      const records = await resolveUdDomain(d.host, apiKey);
      results.push({
        id: d.id,
        label: d.label,
        host: d.host,
        kind: "unstoppable",
        resolved: Object.keys(records).length > 0,
        records,
      });
    } catch (e) {
      results.push({
        id: d.id,
        label: d.label,
        host: d.host,
        kind: "unstoppable",
        resolved: false,
        records: {},
        error: e instanceof Error ? e.message : "resolve failed",
      });
    }
  }

  return results;
}
