/**
 * Wallet ownership verification for the "connect wallet" / link flow.
 *
 * A user proves control of an address by signing a server-issued nonce:
 *   - EVM:    personal_sign / EIP-191, verified with viem.
 *   - Solana: ed25519 over the nonce bytes, verified against the base58 pubkey.
 *   - TON:    TON Connect `ton_proof`, verified per the v2 spec.
 */

import { createHash, createPublicKey, verify as nodeVerify } from "node:crypto";
import { verifyMessage as viemVerifyMessage } from "viem";
import { PublicKey } from "@solana/web3.js";
import { Chain } from "@/lib/db/models";

const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

function ed25519Verify(message: Buffer, signature: Buffer, rawPublicKey: Buffer): boolean {
  if (rawPublicKey.length !== 32) return false;
  try {
    const der = Buffer.concat([ED25519_SPKI_PREFIX, rawPublicKey]);
    const key = createPublicKey({ key: der, format: "der", type: "spki" });
    return nodeVerify(null, message, key, signature);
  } catch {
    return false;
  }
}

export async function verifyEvmSignature(
  address: string,
  message: string,
  signature: string,
): Promise<boolean> {
  try {
    return await viemVerifyMessage({
      address: address as `0x${string}`,
      message,
      signature: signature as `0x${string}`,
    });
  } catch {
    return false;
  }
}

export function verifySolanaSignature(
  address: string,
  message: string,
  signatureBase64: string,
): boolean {
  try {
    const pubkey = Buffer.from(new PublicKey(address).toBytes());
    const sig = Buffer.from(signatureBase64, "base64");
    return ed25519Verify(Buffer.from(message, "utf8"), sig, pubkey);
  } catch {
    return false;
  }
}

export interface TonProof {
  /** raw ed25519 public key of the wallet, hex or base64 */
  publicKey: string;
  /** wallet address "0:..." (workchain:hash hex) */
  address: string;
  domain: string;
  timestamp: number;
  payload: string;
  /** base64 signature */
  signature: string;
}

/** Verify a TON Connect ton_proof per the v2 message construction. */
export function verifyTonProof(proof: TonProof): boolean {
  try {
    const [wcStr, hashHex] = proof.address.split(":");
    const workchain = Number(wcStr);
    const addrHash = Buffer.from(hashHex, "hex");
    if (addrHash.length !== 32) return false;

    const wcBuf = Buffer.alloc(4);
    wcBuf.writeInt32BE(workchain, 0);

    const domainBytes = Buffer.from(proof.domain, "utf8");
    const domainLen = Buffer.alloc(4);
    domainLen.writeUInt32LE(domainBytes.length, 0);

    const ts = Buffer.alloc(8);
    ts.writeBigUInt64LE(BigInt(proof.timestamp), 0);

    const message = Buffer.concat([
      Buffer.from("ton-proof-item-v2/", "utf8"),
      wcBuf,
      addrHash,
      domainLen,
      domainBytes,
      ts,
      Buffer.from(proof.payload, "utf8"),
    ]);

    const messageHash = createHash("sha256").update(message).digest();
    const fullMessage = Buffer.concat([
      Buffer.from([0xff, 0xff]),
      Buffer.from("ton-connect", "utf8"),
      messageHash,
    ]);
    const signedHash = createHash("sha256").update(fullMessage).digest();

    const pub = decodeKey(proof.publicKey);
    const sig = Buffer.from(proof.signature, "base64");
    return ed25519Verify(signedHash, sig, pub);
  } catch {
    return false;
  }
}

function decodeKey(key: string): Buffer {
  if (/^[0-9a-fA-F]+$/.test(key) && key.length === 64) return Buffer.from(key, "hex");
  return Buffer.from(key, "base64");
}

export async function verifyWalletOwnership(params: {
  chain: Chain;
  address: string;
  message: string;
  signature: string;
  tonProof?: TonProof;
}): Promise<boolean> {
  if (params.chain === "evm") {
    return verifyEvmSignature(params.address, params.message, params.signature);
  }
  if (params.chain === "solana") {
    return verifySolanaSignature(params.address, params.message, params.signature);
  }
  if (params.chain === "ton" && params.tonProof) {
    return verifyTonProof(params.tonProof);
  }
  return false;
}
