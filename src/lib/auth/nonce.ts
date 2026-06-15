/**
 * Stateless, time-bounded, server-signed nonce for wallet-link challenges.
 *
 * The issued message embeds an HMAC `Tag` over its fields so we can later
 * confirm the message was genuinely issued by us (and is fresh) before
 * verifying the wallet's signature over it.
 */

import { createHmac, randomBytes } from "node:crypto";
import { serverEnv } from "@/lib/config/env";
import { Chain } from "@/lib/db/models";

const MAX_AGE_MS = 10 * 60 * 1000;

function tag(address: string, chain: string, nonce: string, issuedAt: string): string {
  return createHmac("sha256", serverEnv.sessionSecret)
    .update(`${address.toLowerCase()}|${chain}|${nonce}|${issuedAt}`)
    .digest("hex");
}

export function issueNonceMessage(address: string, chain: Chain): { message: string } {
  const nonce = randomBytes(16).toString("hex");
  const issuedAt = new Date().toISOString();
  const t = tag(address, chain, nonce, issuedAt);
  const message = [
    "YieldSwarm Wallet Link",
    `Address: ${address}`,
    `Chain: ${chain}`,
    `Nonce: ${nonce}`,
    `Issued-At: ${issuedAt}`,
    `Tag: ${t}`,
  ].join("\n");
  return { message };
}

export function validateNonceMessage(message: string, address: string, chain: Chain): boolean {
  const fields: Record<string, string> = {};
  for (const line of message.split("\n")) {
    const idx = line.indexOf(": ");
    if (idx > -1) fields[line.slice(0, idx)] = line.slice(idx + 2);
  }
  const { Nonce, "Issued-At": issuedAt, Tag, Address, Chain: chainField } = fields;
  if (!Nonce || !issuedAt || !Tag) return false;
  if (Address?.toLowerCase() !== address.toLowerCase()) return false;
  if (chainField !== chain) return false;
  const expected = tag(address, chain, Nonce, issuedAt);
  if (expected !== Tag) return false;
  const age = Date.now() - new Date(issuedAt).getTime();
  return Number.isFinite(age) && age >= 0 && age <= MAX_AGE_MS;
}
