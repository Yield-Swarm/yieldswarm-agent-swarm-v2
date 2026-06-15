/**
 * Lightweight session layer.
 *
 * There is no user-facing auth provider in this repo yet, so we issue an
 * anonymous, HMAC-signed session cookie that maps each browser to a stable
 * user id. Swap `ensureUser` / `getCurrentUser` for a real auth provider
 * (NextAuth, Clerk, wallet-SIWE, ...) without touching the rails.
 *
 * Implemented with Web Crypto so it runs in both the Edge middleware and the
 * Node.js route handlers.
 */

import { serverEnv } from "@/lib/config/env";

export const SESSION_COOKIE = "ys_session";
export const USER_HEADER = "x-ys-user";

function b64url(bytes: ArrayBuffer | Uint8Array): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let bin = "";
  for (const b of arr) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmac(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(serverEnv.sessionSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return b64url(sig);
}

/** token = base64url(userId) "." hmac(base64url(userId)) */
export async function signSession(userId: string): Promise<string> {
  const payload = b64url(new TextEncoder().encode(userId));
  const sig = await hmac(payload);
  return `${payload}.${sig}`;
}

export async function verifySession(token: string | undefined | null): Promise<string | null> {
  if (!token || !token.includes(".")) return null;
  const [payload, sig] = token.split(".");
  const expected = await hmac(payload);
  // Constant-time-ish compare.
  if (sig.length !== expected.length) return null;
  let diff = 0;
  for (let i = 0; i < sig.length; i++) diff |= sig.charCodeAt(i) ^ expected.charCodeAt(i);
  if (diff !== 0) return null;
  try {
    const bin = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  } catch {
    return null;
  }
}

export async function newSessionToken(): Promise<{ userId: string; token: string }> {
  // Web Crypto randomUUID works in both the Edge runtime and Node.js.
  const userId = crypto.randomUUID();
  const token = await signSession(userId);
  return { userId, token };
}
