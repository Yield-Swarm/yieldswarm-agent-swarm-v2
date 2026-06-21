import '../../data/models/job_request.dart';

/// Driver-first economics: 1% customer fee, 2× driver app pay, DePIN separate.
class EarningsCalculator {
  static const customerFeePct = 0.01;
  static const driverMultiplier = 2.0;
  static const depinRewardRate = 0.02;

  static FareBreakdown calculate({
    required double distanceKm,
    required double durationMin,
    double baseRatePerKm = 1.5,
    double baseRatePerMin = 0.25,
    double flatFee = 2.5,
  }) {
    final base = distanceKm * baseRatePerKm + durationMin * baseRatePerMin + flatFee;
    final customerFee = base * customerFeePct;
    final customerTotal = base + customerFee;
    final driverAppPay = base * driverMultiplier;
    final depinScore = distanceKm * 0.01 + durationMin * 0.005;
    final depinReward = depinScore * depinRewardRate;

    return FareBreakdown(
      baseFareUsd: base,
      customerFeeUsd: customerFee,
      customerTotalUsd: customerTotal,
      driverAppPayUsd: driverAppPay,
      depinRewardEstimateUsd: depinReward,
      driverTotalUsd: driverAppPay + depinReward,
      customerFeePct: customerFeePct,
      driverMultiplier: driverMultiplier,
    );
  }

  static EarningsSummary summarizeTrip(FareBreakdown fare, {double tipsUsd = 0}) {
    final twoXBoost = fare.driverAppPayUsd - fare.baseFareUsd;
    return EarningsSummary(
      appEarningsUsd: fare.driverAppPayUsd,
      depinRewardsUsd: fare.depinRewardEstimateUsd,
      tipsUsd: tipsUsd,
      twoXBoostUsd: twoXBoost,
      totalUsd: fare.driverAppPayUsd + fare.depinRewardEstimateUsd + tipsUsd,
    );
  }
}
