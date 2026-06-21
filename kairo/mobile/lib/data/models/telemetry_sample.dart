class TelemetrySample {
  const TelemetrySample({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.timestamp,
    this.accelerationMps2,
    this.headingDeg,
    this.distanceKm,
    this.durationSeconds,
    this.anonymized = false,
  });

  final String driverId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final DateTime timestamp;
  final double? accelerationMps2;
  final double? headingDeg;
  final double? distanceKm;
  final int? durationSeconds;
  final bool anonymized;

  Map<String, dynamic> toPayload() => {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'speed_kmh': speedKmh,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (accelerationMps2 != null) 'acceleration_mps2': accelerationMps2,
        if (headingDeg != null) 'heading_deg': headingDeg,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        'anonymized': anonymized,
      };
}

class SignedTelemetryBatch {
  const SignedTelemetryBatch({
    required this.driverId,
    required this.samples,
    required this.signedBatch,
    required this.batchId,
  });

  final String driverId;
  final List<TelemetrySample> samples;
  final String signedBatch;
  final String batchId;

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'batch_id': batchId,
        'signedBatch': signedBatch,
        'samples': samples.map((s) => s.toPayload()).toList(),
      };
}
