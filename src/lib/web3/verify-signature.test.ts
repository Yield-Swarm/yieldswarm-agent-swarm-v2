import { describe, it, expect } from "vitest";
import { generateKeyPairSync, sign } from "node:crypto";
import { privateKeyToAccount } from "viem/accounts";
import { PublicKey } from "@solana/web3.js";
import { verifySolanaSignature, verifyEvmSignature } from "@/lib/web3/verify-signature";

describe("solana signature verification", () => {
  it("accepts a valid ed25519 signature and rejects a bad one", () => {
    const { publicKey, privateKey } = generateKeyPairSync("ed25519");
    const raw = publicKey.export({ format: "der", type: "spki" }).subarray(-32);
    const address = new PublicKey(raw).toBase58();
    const message = "YieldSwarm Wallet Link\nNonce: abc";
    const signature = sign(null, Buffer.from(message, "utf8"), privateKey).toString("base64");

    expect(verifySolanaSignature(address, message, signature)).toBe(true);
    expect(verifySolanaSignature(address, "different message", signature)).toBe(false);
  });
});

describe("evm signature verification", () => {
  it("verifies a personal_sign signature", async () => {
    const account = privateKeyToAccount(
      "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    );
    const message = "YieldSwarm Wallet Link\nNonce: xyz";
    const signature = await account.signMessage({ message });

    expect(await verifyEvmSignature(account.address, message, signature)).toBe(true);
    expect(await verifyEvmSignature(account.address, "tampered", signature)).toBe(false);
  });
});
