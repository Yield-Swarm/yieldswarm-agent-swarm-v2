/**
 * @jest-environment node
 */
import { calculateRideFare, calculateDriverEarnings } from "./fees";

describe("Kairo fee model", () => {
  it("applies 1% customer platform fee", () => {
    const fare = calculateRideFare({ baseFare: "100.00" });
    expect(fare.customerPlatformFee).toBe("1.00");
    expect(fare.customerTotal).toBe("101.00");
  });

  it("applies 2x driver pay multiplier", () => {
    const fare = calculateRideFare({ baseFare: "100.00" });
    expect(fare.driverBasePay).toBe("70.00");
    expect(fare.driverGrossPay).toBe("140.00");
    expect(fare.driverBonusPay).toBe("70.00");
  });

  it("calculates driver earnings with instant cashout fee", () => {
    const earnings = calculateDriverEarnings({
      appRevenueUsd: "100",
      depinRewardsUsd: "10",
      cryptoRewardsUsd: "5",
      instantCashout: true,
    });
    expect(earnings.grossTotalUsd).toBe("115.00");
    expect(parseFloat(earnings.instantCashoutFeeUsd)).toBeGreaterThan(0);
    expect(parseFloat(earnings.netPayoutUsd)).toBeLessThan(115);
  });
});
