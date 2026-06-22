/**
 * Ed25519 settlement signing — Step 4 of async settlement loop.
 */
import {
  createHash,
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  sign,
  verify,
} from "crypto";
import { gameEnv } from "@/lib/game/config";

export interface SettlementPayload {
  wallet: string;
  level: number;
  equipmentHash: string;
  emissionNano: string;
  chainTimestamp: number;
  serverTimestamp: number;
  deltaTime: number;
  actionType: string;
}

export function canonicalSettlementBytes(payload: SettlementPayload): Buffer {
  const json = JSON.stringify({
    wallet: payload.wallet,
    level: payload.level,
    equipmentHash: payload.equipmentHash.toLowerCase(),
    emissionNano: payload.emissionNano,
    chainTimestamp: payload.chainTimestamp,
    serverTimestamp: payload.serverTimestamp,
    deltaTime: payload.deltaTime,
    actionType: payload.actionType,
  });
  return createHash("sha256").update(json).digest();
}

const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const SPKI_ED25519_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

function privateKeyFromSeedHex(seedHex: string) {
  const seed = Buffer.from(seedHex.slice(0, 64), "hex");
  return createPrivateKey({
    key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]),
    format: "der",
    type: "pkcs8",
  });
}

export function getSettlementPublicKeyHex(): string {
  const configured = gameEnv.settlementPublicKeyHex();
  if (configured) return configured;
  const priv = gameEnv.settlementPrivateKeyHex();
  if (priv) {
    const pub = createPublicKey(privateKeyFromSeedHex(priv));
    return pub.export({ type: "spki", format: "der" }).subarray(-32).toString("hex");
  }
  return getOrGenerateDevKeyPair().publicKeyHex;
}

export function getOrGenerateDevKeyPair(): { publicKeyHex: string; privateKeyHex: string } {
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  return {
    privateKeyHex: privateKey.export({ type: "pkcs8", format: "der" }).subarray(-32).toString("hex"),
    publicKeyHex: publicKey.export({ type: "spki", format: "der" }).subarray(-32).toString("hex"),
  };
}

export function signSettlementPayload(payload: SettlementPayload): string {
  const digest = canonicalSettlementBytes(payload);
  const hex = gameEnv.settlementPrivateKeyHex();
  if (hex) {
    return sign(null, digest, privateKeyFromSeedHex(hex)).toString("hex");
  }
  if (process.env.NODE_ENV === "production") {
    throw new Error("GAME_SETTLEMENT_PRIVATE_KEY_HEX required in production");
  }
  const { privateKeyHex } = getOrGenerateDevKeyPair();
  return sign(null, digest, privateKeyFromSeedHex(privateKeyHex)).toString("hex");
}

export function verifySettlementSignature(
  payload: SettlementPayload,
  signatureHex: string,
  publicKeyHex: string,
): boolean {
  const digest = canonicalSettlementBytes(payload);
  const sig = Buffer.from(signatureHex, "hex");
  const pubDer = Buffer.concat([SPKI_ED25519_PREFIX, Buffer.from(publicKeyHex, "hex")]);
  return verify(null, digest, { key: pubDer, format: "der", type: "spki" }, sig);
}
