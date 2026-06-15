"""
Kairo driver identity — public API.

Persistent IoTeX + EVM compatible addresses with encrypted local storage,
BIP39 mnemonic recovery, and optional Vault mirroring.
"""

from kairo.services.identity import (
    DEFAULT_DERIVATION_PATH,
    DriverStore,
    MnemonicBackup,
    RegistrationResult,
    decrypt_mnemonic,
    decrypt_private_key,
    encrypt_mnemonic,
    encrypt_private_key,
    evm_address_from_public_key,
    generate_driver_identity,
    identity_from_mnemonic,
    iotex_address_from_evm,
    recover_driver,
    register_driver,
)

__all__ = [
    "DEFAULT_DERIVATION_PATH",
    "DriverStore",
    "MnemonicBackup",
    "RegistrationResult",
    "decrypt_mnemonic",
    "decrypt_private_key",
    "encrypt_mnemonic",
    "encrypt_private_key",
    "evm_address_from_public_key",
    "generate_driver_identity",
    "identity_from_mnemonic",
    "iotex_address_from_evm",
    "recover_driver",
    "register_driver",
]
