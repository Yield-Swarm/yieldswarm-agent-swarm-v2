import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_client.dart';
import '../models/driver_identity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityRepository {
  IdentityRepository({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Dio? _dio;
  final FlutterSecureStorage _secureStorage;

  Dio get dio => _dio!;

  void bind(Dio dio) => _dio = dio;

  static const _identityKey = 'kairo_identity';
  static const _mnemonicKey = 'kairo_mnemonic';
  static const _consentTelemetryKey = 'kairo_consent_telemetry';
  static const _consentFsdKey = 'kairo_consent_fsd';

  Future<DriverIdentity> registerRemote({String? driverId}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/drivers',
      data: {
        if (driverId != null) 'driver_id': driverId,
        'mirror_vault': true,
      },
    );
    final data = res.data?['data'] as Map<String, dynamic>? ?? res.data ?? {};
    final identity = DriverIdentity.fromJson(data);
    if (identity.mnemonic != null) {
      await _secureStorage.write(key: _mnemonicKey, value: identity.mnemonic);
    }
    return identity;
  }

  Future<void> persistIdentity(DriverIdentity identity) async {
    await _secureStorage.write(
      key: _identityKey,
      value: jsonEncode(identity.toJson()),
    );
  }

  Future<DriverIdentity?> loadLocalIdentity() async {
    final raw = await _secureStorage.read(key: _identityKey);
    if (raw == null) return null;
    return DriverIdentity.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveConsentFlags({
    required bool telemetry,
    required bool fsdTraining,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentTelemetryKey, telemetry);
    await prefs.setBool(_consentFsdKey, fsdTraining);
  }

  Future<ConsentFlags> loadConsentFlags() async {
    final prefs = await SharedPreferences.getInstance();
    return ConsentFlags(
      telemetry: prefs.getBool(_consentTelemetryKey) ?? false,
      fsdTraining: prefs.getBool(_consentFsdKey) ?? false,
    );
  }

  String signBatchPayload(String driverId, List<Map<String, dynamic>> samples) {
    final canonical = jsonEncode({'driver_id': driverId, 'samples': samples});
    final digest = sha256.convert(utf8.encode(canonical)).toString();
    return '0x$digest';
  }
}

final identityRepositoryBoundProvider = Provider<IdentityRepository>((ref) {
  final repo = IdentityRepository();
  repo.bind(ref.watch(dioProvider));
  return repo;
});
