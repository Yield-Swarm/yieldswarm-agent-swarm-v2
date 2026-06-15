import { describe, it, expect } from "vitest";
import {
  calculateCustomerPayment,
  PLATFORM_FEE_RATE,
  multiplyRate,
} from "@/lib/payments/fees";

describe("customer payment fees", () => {
  it("applies 1% flat fee on top of credit amount", () => {
    const b = calculateCustomerPayment("100");
    expect(b.creditAmount).toBe("100");
    expect(b.platformFee).toBe("1");
    expect(b.totalCharge).toBe("101");
    expect(b.feeRate).toBe(PLATFORM_FEE_RATE);
  });

  it("handles decimal credit amounts", () => {
    const b = calculateCustomerPayment("24.50");
    expect(b.platformFee).toBe("0.245");
    expect(b.totalCharge).toBe("24.745");
  });

  it("multiplies rates without float drift", () => {
    expect(multiplyRate("10", "0.01")).toBe("0.1");
  });
});
