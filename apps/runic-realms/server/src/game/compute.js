import crypto from 'node:crypto';

/**
 * Proof-of-compute — every gameplay action becomes Swarm work + $RUNE yield.
 * Sanscript YSLR primitives label jobs for Helix / Runic Chain indexing.
 */
export function sanscriptOp(action, meta = {}) {
  const payload = JSON.stringify({ action, ...meta, ts: Date.now() });
  const hash = crypto.createHash('sha256').update(payload).digest('hex');
  return `YSLR::COMPUTE::${action}::${hash.slice(0, 16)}`;
}

export function harvestCompute(action, context = {}) {
  const weight = Number(context.computeWeight ?? 1);
  const floor = Number(context.floor ?? 1);
  const level = Number(context.level ?? 1);

  const job = {
    id: `job_${crypto.randomBytes(8).toString('hex')}`,
    sanscript: sanscriptOp(action, context),
    action,
    proof: proofOfCompute(action, context),
    chains: ['runic', 'nexus', 'helix', 'shadow'],
    midasGoldEquivalent: 0,
  };

  // Midas Swarm miner — playtime → gold-equivalent yield curve
  const baseRune = 0.01 * weight * (1 + floor * 0.15) * (1 + level * 0.05);
  const runeEarned = Math.round(baseRune * 10000) / 10000;
  job.midasGoldEquivalent = Math.round(runeEarned * 42 * 100) / 100;

  return { job, runeEarned, proofHash: job.proof };
}

function proofOfCompute(action, context) {
  const material = `${action}:${JSON.stringify(context)}:${process.hrtime.bigint()}`;
  let hash = crypto.createHash('sha256').update(material).digest('hex');
  // Simulated work units (real deployment → Akash GPU batch)
  for (let i = 0; i < 64; i += 1) {
    hash = crypto.createHash('sha256').update(hash).digest('hex');
  }
  return hash;
}

export const RUNE_TOKEN = Object.freeze({
  symbol: 'RUNE',
  name: 'Runic Realms Token',
  decimals: 18,
  earnRatePerHourBase: 1.5,
});
