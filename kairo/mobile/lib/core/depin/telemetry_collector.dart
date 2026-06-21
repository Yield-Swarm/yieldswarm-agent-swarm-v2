import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/telemetry_sample.dart';
import '../../data/repositories/telemetry_repository.dart';
import '../../shared/providers/session_provider.dart';
import '../config/app_config.dart';
import '../location/location_service.dart';

class TelemetryCollector extends StateNotifier<TelemetryCollectorState> {
  TelemetryCollector({
    required this.locationService,
    required this.telemetryRepo,
    required this.config,
    required this.session,
  }) : super(const TelemetryCollectorState());

  final LocationService locationService;
  final TelemetryRepository telemetryRepo;
  final AppConfig config;
  final SessionState session;

  Timer? _timer;
  final List<TelemetrySample> _buffer = [];

  void start() {
    if (!session.telemetryConsent || session.identity == null) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: config.telemetryIntervalSeconds),
      (_) => _collect(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _collect() async {
    final driverId = session.identity?.driverId;
    if (driverId == null) return;

    final pos = await locationService.currentPosition();
    if (pos == null) return;

    final sample = locationService.toSample(
      driverId: driverId,
      position: pos,
      anonymized: session.fsdTrainingConsent,
    );
    if (sample == null) return;

    _buffer.add(sample);
    state = state.copyWith(pendingCount: _buffer.length);

    if (_buffer.length >= config.telemetryBatchSize) {
      await flush();
    }
  }

  Future<void> flush() async {
    if (_buffer.isEmpty || session.identity == null) return;
    final batch = List<TelemetrySample>.from(_buffer);
    _buffer.clear();
    try {
      await telemetryRepo.submitBatch(
        driverId: session.identity!.driverId,
        samples: batch,
        anonymized: session.fsdTrainingConsent,
      );
      state = state.copyWith(
        pendingCount: 0,
        lastFlushAt: DateTime.now(),
        totalSubmitted: state.totalSubmitted + batch.length,
      );
    } catch (e) {
      _buffer.insertAll(0, batch);
      state = state.copyWith(error: e.toString(), pendingCount: _buffer.length);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class TelemetryCollectorState {
  const TelemetryCollectorState({
    this.pendingCount = 0,
    this.totalSubmitted = 0,
    this.lastFlushAt,
    this.error,
  });

  final int pendingCount;
  final int totalSubmitted;
  final DateTime? lastFlushAt;
  final String? error;

  TelemetryCollectorState copyWith({
    int? pendingCount,
    int? totalSubmitted,
    DateTime? lastFlushAt,
    String? error,
  }) {
    return TelemetryCollectorState(
      pendingCount: pendingCount ?? this.pendingCount,
      totalSubmitted: totalSubmitted ?? this.totalSubmitted,
      lastFlushAt: lastFlushAt ?? this.lastFlushAt,
      error: error,
    );
  }
}

final telemetryCollectorProvider =
    StateNotifierProvider<TelemetryCollector, TelemetryCollectorState>((ref) {
  return TelemetryCollector(
    locationService: ref.watch(locationServiceProvider),
    telemetryRepo: ref.watch(telemetryRepositoryProvider),
    config: ref.watch(appConfigProvider),
    session: ref.watch(sessionProvider),
  );
});
