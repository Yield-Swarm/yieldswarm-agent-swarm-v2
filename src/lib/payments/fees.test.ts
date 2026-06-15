import { describe, expect, it } from "vitest";
import { quoteTrip, settleDriverTrip, KAIRO_CUSTOMER_PLATFORM_FEE_BPS } from "@/lib/payments/fees";

describe("Kairo fees", () => {
  it("applies 1% customer platform fee", () => {
    const q = quoteTrip({ baseFare: "100.00" });
    expect(q.customerPlatformFee).toBe("1.00");
    expect(q.customerTotal).toBe("101.00");
    expect(KAIRO_CUSTOMER_PLATFORM_FEE_BPS).toBe(100);
  });

  it("pays driver 2x base fare", () => {
    const q = quoteTrip({ baseFare: "50.00" });
    expect(q.driverGrossPay).toBe("100.00");
    expect(q.driverBasePay).toBe("50.00");
    expect(q.driverBonusPay).toBe("50.00");
  });

  it("deducts instant cashout fee when requested", () => {
    const s = settleDriverTrip({
      driverId: "drv_test",
      baseFare: "100.00",
      instantCashout: true,
    });
    expect(parseFloat(s.driverNetPay)).toBeLessThan(parseFloat(s.driverGrossPay));
    expect(s.instantCashout).toBe(true);
  });
});
