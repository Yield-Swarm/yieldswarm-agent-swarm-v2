import { describe, it, expect } from "vitest";
import {
  addAmounts,
  subAmounts,
  gte,
  toMinorUnits,
  fromMinorUnits,
  normalizeAmount,
} from "@/lib/money";

describe("money", () => {
  it("adds without float error", () => {
    expect(addAmounts("0.1", "0.2")).toBe("0.3");
    expect(addAmounts("10.50", "0.50")).toBe("11");
  });

  it("subtracts and compares", () => {
    expect(subAmounts("1", "0.4")).toBe("0.6");
    expect(gte("1.0", "1")).toBe(true);
    expect(gte("0.99", "1")).toBe(false);
  });

  it("converts fiat minor units", () => {
    expect(toMinorUnits("10.50", 2)).toBe("1050");
    expect(fromMinorUnits("1050", 2)).toBe("10.5");
  });

  it("converts 18-decimal crypto minor units", () => {
    expect(toMinorUnits("1", 18)).toBe("1000000000000000000");
    expect(fromMinorUnits("1500000", 6)).toBe("1.5");
  });

  it("normalizes", () => {
    expect(normalizeAmount("00.500")).toBe("0.5");
    expect(normalizeAmount(2)).toBe("2");
  });
});
