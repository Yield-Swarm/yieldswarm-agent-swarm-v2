import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/driver_identity.dart';
import '../../data/repositories/identity_repository.dart';

class SessionState {
  const SessionState({
    this.identity,
    this.isOnboarded = false,
    this.telemetryConsent = false,
    this.fsdTrainingConsent = false,
    this.isAvailable = false,
  });

  final DriverIdentity? identity;
  final bool isOnboarded;
  final bool telemetryConsent;
  final bool fsdTrainingConsent;
  final bool isAvailable;

  SessionState copyWith({
    DriverIdentity? identity,
    bool? isOnboarded,
    bool? telemetryConsent,
    bool? fsdTrainingConsent,
    bool? isAvailable,
  }) {
    return SessionState(
      identity: identity ?? this.identity,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      telemetryConsent: telemetryConsent ?? this.telemetryConsent,
      fsdTrainingConsent: fsdTrainingConsent ?? this.fsdTrainingConsent,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._identityRepo) : super(const SessionState()) {
    _restore();
  }

  final IdentityRepository _identityRepo;

  Future<void> _restore() async {
    final identity = await _identityRepo.loadLocalIdentity();
    final consent = await _identityRepo.loadConsentFlags();
    if (identity != null) {
      state = state.copyWith(
        identity: identity,
        isOnboarded: true,
        telemetryConsent: consent.telemetry,
        fsdTrainingConsent: consent.fsdTraining,
      );
    }
  }

  Future<void> completeOnboarding({
    required DriverIdentity identity,
    required bool telemetryConsent,
    required bool fsdTrainingConsent,
  }) async {
    await _identityRepo.persistIdentity(identity);
    await _identityRepo.saveConsentFlags(
      telemetry: telemetryConsent,
      fsdTraining: fsdTrainingConsent,
    );
    state = state.copyWith(
      identity: identity,
      isOnboarded: true,
      telemetryConsent: telemetryConsent,
      fsdTrainingConsent: fsdTrainingConsent,
    );
  }

  void setAvailability(bool available) {
    state = state.copyWith(isAvailable: available);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref.watch(identityRepositoryBoundProvider));
});
