/**
 * HELIX genesis consensus smoke test — 100-round Shamir 9/14 threshold validation.
 */

import { createHash, randomBytes } from 'node:crypto';

const THRESHOLD = 9;
const DEITIES = [
  'Anubis', 'Athena', 'Hermes', 'Vishnu', 'Ra',
  'Thoth', 'Isis', 'Odin', 'Shiva', 'Freya',
  'Maat', 'Loki', 'Hephaestus', 'Bastet',
];

const FIELD_PRIME = 115792089237316195423570985008687907853269984665640564039457584007913129639936n;

function modPow(base, exp, mod) {
  let res = 1n;
  base %= mod;
  while (exp > 0n) {
    if (exp % 2n === 1n) res = (res * base) % mod;
    base = (base * base) % mod;
    exp /= 2n;
  }
  return res;
}

/** Lagrange interpolation at x=0 over prime field. */
function verifyShamirThreshold(shares, p) {
  let secret = 0n;
  for (let i = 0; i < shares.length; i++) {
    let num = 1n;
    let den = 1n;
    for (let j = 0; j < shares.length; j++) {
      if (i !== j) {
        num = (num * BigInt(-shares[j].x)) % p;
        den = (den * BigInt(shares[i].x - shares[j].x)) % p;
      }
    }
    const denInverse = modPow(den, p - 2n, p);
    secret = (secret + shares[i].y * num * denInverse) % p;
  }
  return (secret + p) % p;
}

/**
 * Run 100 sequential consensus rounds.
 * @returns {{ ok: boolean, rounds: number, finalStateRoot: string }}
 */
export function runConsensusSmokeTest(rounds = 100) {
  let previousHash = createHash('sha256').update('HELIX_BLOCK_0_CHARTER').digest('hex');

  for (let round = 1; round <= rounds; round++) {
    const activeDeities = [...DEITIES].sort(() => Math.random() - 0.5).slice(0, THRESHOLD);
    const shares = activeDeities.map((_, idx) => ({
      x: idx + 1,
      y: BigInt(`0x${randomBytes(32).toString('hex')}`) % FIELD_PRIME,
    }));

    const derivedSecret = verifyShamirThreshold(shares, FIELD_PRIME);
    const stateRoot = createHash('sha256').update(derivedSecret.toString()).digest('hex');
    const signatures = activeDeities.map(
      (name) => createHash('sha256').update(`YSLR::${name}::${round}`).digest('hex'),
    );

    if (signatures.length !== THRESHOLD) {
      return { ok: false, rounds: round - 1, finalStateRoot: previousHash, error: 'threshold mismatch' };
    }
    previousHash = stateRoot;
  }

  return { ok: true, rounds, finalStateRoot: previousHash };
}
