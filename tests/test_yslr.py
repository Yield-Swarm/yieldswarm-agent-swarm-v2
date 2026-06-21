"""YSLR encryption, PQC, and ZK treasury tests."""

from __future__ import annotations

import json
import os

os.environ.setdefault("KAIRO_PQC_STUB", "1")

from kairo.services.orchard_keys import derive_orchard_keys
from kairo.services.pqc import generate_pqc_keypair, lattice_entropy, pqc_sign, pqc_verify
from kairo.services.yslr import generate_yslr_keys, yslr_decrypt, yslr_encrypt
from kairo.services.zk_treasury import prove_treasury_split, verify_treasury_split


def test_orchard_key_hierarchy():
    keys = derive_orchard_keys()
    pub = keys.to_public_dict()
    assert "ivk_fingerprint" in pub
    assert len(keys.diversifier) == 11


def test_pqc_stub_sign_verify():
    bundle = generate_pqc_keypair()
    msg = b"yieldswarm-telemetry-batch"
    sig = pqc_sign(msg, bundle.sig_secret, alg=bundle.public.sig_alg)
    assert pqc_verify(msg, sig, bundle.public.sig_public, alg=bundle.public.sig_alg)


def test_yslr_roundtrip():
    keys = generate_yslr_keys()
    plaintext = {"driver_id": "drv-test", "speed_kmh": 42}
    envelope = yslr_encrypt(json.dumps(plaintext), keys=keys, include_zk=True)
    recovered = json.loads(yslr_decrypt(envelope, keys=keys).decode())
    assert recovered["driver_id"] == "drv-test"


def test_treasury_split_proof():
    proof = prove_treasury_split(1_000_000)
    assert proof.valid
    assert verify_treasury_split(proof)


def test_lattice_entropy_deterministic():
    seed = b"sovereign-loop-100"
    a = lattice_entropy(seed, 1)
    b = lattice_entropy(seed, 1)
    c = lattice_entropy(seed, 2)
    assert a == b
    assert a != c


def test_yslr_layers_include_zk():
    keys = generate_yslr_keys()
    env = yslr_encrypt(b"secret", keys=keys, include_zk=True, zk_context="telemetry")
    assert 2 in env.layers
