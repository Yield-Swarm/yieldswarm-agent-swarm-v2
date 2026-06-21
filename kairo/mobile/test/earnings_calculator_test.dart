import 'package:flutter_test/flutter_test.dart';

import 'package:kairo_mobile/core/payments/earnings_calculator.dart';

void main() {
  test('1% customer fee and 2x driver pay', () {
    final fare = EarningsCalculator.calculate(distanceKm: 10, durationMin: 20);
    expect(fare.customerFeePct, 0.01);
    expect(fare.driverMultiplier, 2.0);
    expect(fare.customerFeeUsd, greaterThan(0));
    expect(fare.driverAppPayUsd, greaterThan(fare.baseFareUsd));
    expect(fare.customerTotalUsd, fare.baseFareUsd + fare.customerFeeUsd);
  });

  test('earnings summary includes 2x boost', () {
    final fare = EarningsCalculator.calculate(distanceKm: 5, durationMin: 10);
    final summary = EarningsCalculator.summarizeTrip(fare, tipsUsd: 3);
    expect(summary.twoXBoostUsd, fare.driverAppPayUsd - fare.baseFareUsd);
    expect(summary.totalUsd, fare.driverAppPayUsd + fare.depinRewardEstimateUsd + 3);
  });
}
