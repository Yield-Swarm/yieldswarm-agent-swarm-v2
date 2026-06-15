import { randomUUID, randomBytes } from "node:crypto";

export function uuid(): string {
  return randomUUID();
}

/** Human-friendly, collision-resistant reference for an intent/transaction. */
export function reference(prefix: string): string {
  const ts = Date.now().toString(36);
  const rand = randomBytes(5).toString("hex");
  return `${prefix}_${ts}_${rand}`;
}

export function nowIso(): string {
  return new Date().toISOString();
}
