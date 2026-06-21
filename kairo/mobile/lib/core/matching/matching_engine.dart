import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job_request.dart';
import '../../data/repositories/ride_repository.dart';
import '../payments/earnings_calculator.dart';

/// Scores and broadcasts ride/delivery jobs to available drivers.
class MatchingEngine {
  MatchingEngine(this._rides);

  final RideRepository _rides;

  Future<JobRequest> requestJob({
    required String pickup,
    required String dropoff,
    required double distanceKm,
    required double durationMin,
    String? driverId,
    JobType type = JobType.ride,
  }) {
    return _rides.createRide(
      pickup: pickup,
      dropoff: dropoff,
      distanceKm: distanceKm,
      durationMin: durationMin,
      driverId: driverId,
      type: type,
    );
  }

  double scoreDriver({
    required double distanceToPickupKm,
    required double rating,
    required bool evAvailable,
  }) {
    final distanceScore = (5 - distanceToPickupKm.clamp(0, 5)) / 5;
    final ratingScore = rating / 5;
    final vehicleScore = evAvailable ? 1.0 : 0.85;
    return distanceScore * 0.5 + ratingScore * 0.35 + vehicleScore * 0.15;
  }

  FareBreakdown previewFare(double distanceKm, double durationMin) {
    return EarningsCalculator.calculate(
      distanceKm: distanceKm,
      durationMin: durationMin,
    );
  }
}

final matchingEngineProvider = Provider<MatchingEngine>((ref) {
  return MatchingEngine(ref.watch(rideRepositoryProvider));
});
