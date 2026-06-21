import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/job_request.dart';

class RideRepository {
  RideRepository(this._dio);

  final Dio _dio;

  Future<FareBreakdown> quoteFare({
    required double distanceKm,
    required double durationMin,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/fare/quote',
      data: {'distanceKm': distanceKm, 'durationMin': durationMin},
    );
    final data = res.data?['data'] as Map<String, dynamic>? ?? {};
    return FareBreakdown.fromJson(data);
  }

  Future<JobRequest> createRide({
    required String pickup,
    required String dropoff,
    required double distanceKm,
    required double durationMin,
    String? driverId,
    JobType type = JobType.ride,
  }) async {
    final fare = await quoteFare(distanceKm: distanceKm, durationMin: durationMin);
    final res = await _dio.post<Map<String, dynamic>>(
      '/rides',
      data: {
        'pickup': pickup,
        'dropoff': dropoff,
        'distance_km': distanceKm,
        'duration_min': durationMin,
        if (driverId != null) 'driver_id': driverId,
        'type': type.name,
        'fare': {
          'baseFareUsd': fare.baseFareUsd.toStringAsFixed(2),
          'customerFeeUsd': fare.customerFeeUsd.toStringAsFixed(2),
          'customerTotalUsd': fare.customerTotalUsd.toStringAsFixed(2),
          'driverAppPayUsd': fare.driverAppPayUsd.toStringAsFixed(2),
          'depinRewardEstimateUsd': fare.depinRewardEstimateUsd.toStringAsFixed(4),
          'driverTotalUsd': fare.driverTotalUsd.toStringAsFixed(2),
          'customerFeePct': fare.customerFeePct,
          'driverMultiplier': fare.driverMultiplier,
        },
      },
    );
    final data = res.data?['data'] as Map<String, dynamic>? ?? {};
    return JobRequest.fromJson(data);
  }

  Future<JobRequest> getRide(String rideId) async {
    final res = await _dio.get<Map<String, dynamic>>('/rides/$rideId');
    final data = res.data?['data'] as Map<String, dynamic>? ?? {};
    return JobRequest.fromJson(data);
  }
}

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.watch(dioProvider));
});
