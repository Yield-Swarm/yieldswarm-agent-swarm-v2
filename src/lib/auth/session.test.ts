import { describe, it, expect } from "vitest";
import { signSession, verifySession, newSessionToken } from "@/lib/auth/session";

describe("session tokens", () => {
  it("round-trips a signed session", async () => {
    const token = await signSession("user-123");
    expect(await verifySession(token)).toBe("user-123");
  });

  it("rejects a tampered token", async () => {
    const token = await signSession("user-123");
    const tampered = token.replace(/.$/, (c) => (c === "a" ? "b" : "a"));
    expect(await verifySession(tampered)).toBeNull();
  });

  it("rejects garbage", async () => {
    expect(await verifySession(undefined)).toBeNull();
    expect(await verifySession("nope")).toBeNull();
  });

  it("issues unique session ids", async () => {
    const a = await newSessionToken();
    const b = await newSessionToken();
    expect(a.userId).not.toBe(b.userId);
    expect(await verifySession(a.token)).toBe(a.userId);
  });
});
