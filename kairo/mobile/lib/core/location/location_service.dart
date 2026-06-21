import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/telemetry_sample.dart';
import '../../shared/providers/session_provider.dart';
import '../config/app_config.dart';

class LocationService {
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> currentPosition() async {
    if (!await ensurePermission()) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  TelemetrySample? toSample({
    required String driverId,
    required Position position,
    bool anonymized = false,
  }) {
    return TelemetrySample(
      driverId: driverId,
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: position.speed * 3.6,
      headingDeg: position.heading,
      timestamp: position.timestamp ?? DateTime.now().toUtc(),
      anonymized: anonymized,
    );
  }

  bool inColorado(Position position, ColoradoBounds bounds) {
    return bounds.contains(position.latitude, position.longitude);
  }
}

final locationServiceProvider = Provider<LocationService>((_) => LocationService());

final coloradoLocationProvider = FutureProvider<Position?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  final config = ref.watch(appConfigProvider);
  final pos = await service.currentPosition();
  if (pos == null) return null;
  if (!service.inColorado(pos, config.coloradoBounds)) {
    throw StateError('Outside Colorado service area');
  }
  return pos;
});
