const API = () =>
  (import.meta.env.VITE_KAIRO_API_URL as string | undefined)?.replace(/\/$/, "") || "";

export function apiBase(): string {
  return API() || window.location.origin;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const base = API() || "";
  const res = await fetch(`${base}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(err || res.statusText);
  }
  return res.json() as Promise<T>;
}

export async function createDriverIdentity() {
  return request<Record<string, unknown>>("/api/v1/drivers/identity", { method: "POST", body: "{}" });
}

export async function fetchContribution(driverId: string) {
  return request<Record<string, unknown>>(`/api/v1/drivers/${driverId}/contribution`);
}

export async function submitTelemetry(payload: Record<string, unknown>) {
  return request<Record<string, unknown>>("/api/v1/telemetry", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
