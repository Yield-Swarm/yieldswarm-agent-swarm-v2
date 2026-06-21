import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/dio_client.dart';
import '../models/telemetry_sample.dart';
import 'identity_repository.dart';

class TelemetryRepository {
  TelemetryRepository(this._dio, this._identityRepo);

  final Dio _dio;
  final IdentityRepository _identityRepo;
  final _uuid = const Uuid();

  Future<Map<String, dynamic>> submitBatch({
    required String driverId,
    required List<TelemetrySample> samples,
    bool anonymized = false,
  }) async {
    final payloadSamples = samples
        .map((s) => s.toPayload())
        .toList();
    final signedBatch = _identityRepo.signBatchPayload(driverId, payloadSamples);
    final body = SignedTelemetryBatch(
      driverId: driverId,
      samples: samples,
      signedBatch: signedBatch,
      batchId: _uuid.v4(),
    ).toJson();

    final res = await _dio.post<Map<String, dynamic>>('/telemetry', data: body);
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> submitSingle(TelemetrySample sample) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/telemetry',
      data: {'driver_id': sample.driverId, 'payload': sample.toPayload()},
    );
    return res.data ?? {};
  }
}

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  return TelemetryRepository(
    ref.watch(dioProvider),
    ref.watch(identityRepositoryBoundProvider),
  );
});
