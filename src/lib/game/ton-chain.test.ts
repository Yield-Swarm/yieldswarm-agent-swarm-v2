import { describe, it, expect } from "vitest";
import { deriveDeltaTime } from "@/lib/game/ton-chain";

describe("deriveDeltaTime", () => {
  it("clamps between 1 and 3600", () => {
    expect(deriveDeltaTime(1000, 5000)).toBe(3600);
    expect(deriveDeltaTime(1000, 1000)).toBe(1);
    expect(deriveDeltaTime(0, 5000)).toBe(1);
  });

  it("computes honest delta", () => {
    expect(deriveDeltaTime(1000, 1120)).toBe(120);
  });
});
