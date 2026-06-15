"use client";

export interface ApiResult<T> {
  ok: boolean;
  data?: T;
  error?: string;
  [key: string]: unknown;
}

export async function api<T = unknown>(
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<ApiResult<T>> {
  const res = await fetch(path, {
    method: options.method ?? (options.body ? "POST" : "GET"),
    headers: options.body ? { "Content-Type": "application/json" } : undefined,
    body: options.body ? JSON.stringify(options.body) : undefined,
    credentials: "same-origin",
  });
  let json: ApiResult<T>;
  try {
    json = (await res.json()) as ApiResult<T>;
  } catch {
    return { ok: false, error: `Request failed (${res.status})` };
  }
  if (!res.ok && json.ok === undefined) json.ok = false;
  return json;
}
