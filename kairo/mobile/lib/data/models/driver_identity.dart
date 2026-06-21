class DriverIdentity {
  const DriverIdentity({
    required this.driverId,
    required this.evmAddress,
    required this.iotexAddress,
    required this.publicKeyHex,
    this.createdAt,
    this.mnemonic,
  });

  final String driverId;
  final String evmAddress;
  final String iotexAddress;
  final String publicKeyHex;
  final String? createdAt;
  final String? mnemonic;

  factory DriverIdentity.fromJson(Map<String, dynamic> json) {
    final identity = json['identity'] as Map<String, dynamic>? ?? json;
    return DriverIdentity(
      driverId: identity['driver_id'] as String? ?? '',
      evmAddress: identity['evm_address'] as String? ?? '',
      iotexAddress: identity['iotex_address'] as String? ?? '',
      publicKeyHex: identity['public_key_hex'] as String? ?? '',
      createdAt: identity['created_at'] as String?,
      mnemonic: json['mnemonic'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'evm_address': evmAddress,
        'iotex_address': iotexAddress,
        'public_key_hex': publicKeyHex,
        'created_at': createdAt,
      };
}

class ConsentFlags {
  const ConsentFlags({required this.telemetry, required this.fsdTraining});

  final bool telemetry;
  final bool fsdTraining;
}
