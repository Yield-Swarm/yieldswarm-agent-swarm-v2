"""YSLR HTTP handlers for Kairo API."""

from __future__ import annotations

import json
from typing import Any

from kairo.services.yslr import (
    YslrEnvelope,
    encrypt_telemetry_batch,
    generate_yslr_keys,
    sovereign_mutation_seed,
    yslr_decrypt,
    yslr_encrypt,
)
from kairo.services.zk_treasury import prove_treasury_split, verify_treasury_split, prove_telemetry_bounds


class YslrApi:
    def encrypt(self, body: dict[str, Any]) -> dict[str, Any]:
        data = body.get("data", "")
        if isinstance(data, dict):
            data = json.dumps(data, sort_keys=True)
        envelope = yslr_encrypt(
            data,
            include_zk=body.get("include_zk", True),
            zk_context=body.get("zk_context", "telemetry"),
            treasury_total=body.get("treasury_total"),
        )
        return {"envelope": envelope.to_dict()}

    def decrypt(self, body: dict[str, Any]) -> dict[str, Any]:
        envelope = body.get("envelope", body)
        plaintext = yslr_decrypt(envelope)
        try:
            parsed = json.loads(plaintext.decode("utf-8"))
            return {"plaintext": parsed, "raw": None}
        except json.JSONDecodeError:
            return {"plaintext": None, "raw": plaintext.decode("utf-8", errors="replace")}

    def generate_keys(self, body: dict[str, Any]) -> dict[str, Any]:
        keys = generate_yslr_keys(rotation_epoch=int(body.get("rotation_epoch", 0)))
        return {"keys": keys.public_dict()}

    def encrypt_telemetry(self, body: dict[str, Any]) -> dict[str, Any]:
        driver_id = body["driver_id"]
        samples = body.get("samples", [])
        envelope = encrypt_telemetry_batch(samples, driver_id)
        return {"envelope": envelope.to_dict()}

    def prove_treasury(self, body: dict[str, Any]) -> dict[str, Any]:
        total = int(body["total"])
        proof = prove_treasury_split(total)
        return {"proof": proof.to_dict()}

    def verify_zk(self, body: dict[str, Any]) -> dict[str, Any]:
        proof = body.get("proof", body)
        if "driver_registered" in proof:
            valid = prove_telemetry_bounds(
                driver_registered=bool(proof.get("driver_registered", True)),
                in_bounds=bool(proof.get("in_bounds", True)),
                quality_score=int(proof.get("quality_score", 95)),
            )["valid"]
        else:
            valid = verify_treasury_split(proof)
        return {"valid": valid}

    def mutation_seed(self, body: dict[str, Any]) -> dict[str, Any]:
        loop_id = body.get("loop_id", "sovereign-100")
        iteration = int(body.get("iteration", 0))
        seed = sovereign_mutation_seed(loop_id, iteration)
        return {"loop_id": loop_id, "iteration": iteration, "seed": seed.hex()}
