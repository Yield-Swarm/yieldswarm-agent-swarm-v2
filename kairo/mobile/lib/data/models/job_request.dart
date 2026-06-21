enum JobType { ride, delivery }

enum JobStatus { matching, driverEnRoute, inProgress, completed, cancelled }

class JobRequest {
  const JobRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    this.driverId,
    this.matchedDriver,
    this.createdAt,
  });

  final String id;
  final JobType type;
  final JobStatus status;
  final String pickup;
  final String dropoff;
  final double distanceKm;
  final double durationMin;
  final FareBreakdown fare;
  final String? driverId;
  final String? matchedDriver;
  final DateTime? createdAt;

  factory JobRequest.fromJson(Map<String, dynamic> json) {
    final fareMap = json['fare'] as Map<String, dynamic>? ?? {};
    return JobRequest(
      id: json['id'] as String? ?? '',
      type: (json['type'] as String?) == 'delivery' ? JobType.delivery : JobType.ride,
      status: _parseStatus(json['status'] as String?),
      pickup: json['pickup'] as String? ?? '',
      dropoff: json['dropoff'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMin: (json['duration_min'] as num?)?.toDouble() ?? 0,
      fare: FareBreakdown.fromJson(fareMap),
      driverId: json['driver_id'] as String?,
      matchedDriver: json['matched_driver'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static JobStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'driver_en_route':
        return JobStatus.driverEnRoute;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.matching;
    }
  }
}

class FareBreakdown {
  const FareBreakdown({
    required this.baseFareUsd,
    required this.customerFeeUsd,
    required this.customerTotalUsd,
    required this.driverAppPayUsd,
    required this.depinRewardEstimateUsd,
    required this.driverTotalUsd,
    required this.customerFeePct,
    required this.driverMultiplier,
  });

  final double baseFareUsd;
  final double customerFeeUsd;
  final double customerTotalUsd;
  final double driverAppPayUsd;
  final double depinRewardEstimateUsd;
  final double driverTotalUsd;
  final double customerFeePct;
  final double driverMultiplier;

  factory FareBreakdown.fromJson(Map<String, dynamic> json) {
    double parse(String key) => double.tryParse(json[key]?.toString() ?? '') ?? 0;
    return FareBreakdown(
      baseFareUsd: parse('baseFareUsd'),
      customerFeeUsd: parse('customerFeeUsd'),
      customerTotalUsd: parse('customerTotalUsd'),
      driverAppPayUsd: parse('driverAppPayUsd'),
      depinRewardEstimateUsd: parse('depinRewardEstimateUsd'),
      driverTotalUsd: parse('driverTotalUsd'),
      customerFeePct: (json['customerFeePct'] as num?)?.toDouble() ?? 0.01,
      driverMultiplier: (json['driverMultiplier'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

class EarningsSummary {
  const EarningsSummary({
    required this.appEarningsUsd,
    required this.depinRewardsUsd,
    required this.tipsUsd,
    required this.totalUsd,
    required this.twoXBoostUsd,
  });

  final double appEarningsUsd;
  final double depinRewardsUsd;
  final double tipsUsd;
  final double totalUsd;
  final double twoXBoostUsd;
}
