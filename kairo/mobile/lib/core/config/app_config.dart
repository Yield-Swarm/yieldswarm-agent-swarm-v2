import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.flavor,
    required this.mapboxToken,
    required this.telemetryBatchSize,
    required this.telemetryIntervalSeconds,
    required this.coloradoBounds,
  });

  final String apiBaseUrl;
  final String flavor;
  final String mapboxToken;
  final int telemetryBatchSize;
  final int telemetryIntervalSeconds;
  final ColoradoBounds coloradoBounds;

  factory AppConfig.fromEnvironment() {
    const apiBase = String.fromEnvironment(
      'KAIRO_API_BASE',
      defaultValue: 'http://localhost:8080/api/kairo',
    );
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    const mapbox = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');
    return AppConfig(
      apiBaseUrl: apiBase,
      flavor: flavor,
      mapboxToken: mapbox,
      telemetryBatchSize: 10,
      telemetryIntervalSeconds: 15,
      coloradoBounds: ColoradoBounds.defaults,
    );
  }

  bool get isDev => flavor == 'dev';
}

class ColoradoBounds {
  const ColoradoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  static const defaults = ColoradoBounds(
    minLat: 36.99,
    maxLat: 41.00,
    minLng: -109.06,
    maxLng: -102.04,
  );

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('AppConfig must be overridden at bootstrap'),
);
