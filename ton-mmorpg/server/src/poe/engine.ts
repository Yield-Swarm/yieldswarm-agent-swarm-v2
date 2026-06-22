/**
 * Proof of Engagement engine — fixed-point BigInt accrual with caps.
 * All amounts in nanoTON / IGJ smallest units unless noted.
 */

export interface PoeConfig {
  nanoPerSecond: bigint;
  nanoCapPerSync: bigint;
  igjCapPerSync: bigint;
  /** IGJ per nano (fixed-point scale 1e9) */
  igjPerNanoScale: bigint;
}

export interface PoeInput {
  deltaTSeconds: number;
  activityScore: number;
  sessionAccumulatedNano: bigint;
}

export interface PoeResult {
  deltaTSeconds: number;
  earnedNano: bigint;
  earnedIgj: bigint;
  capped: boolean;
  engine: {
    nanoPerSecond: string;
    activityMultiplier: number;
    rawNano: string;
  };
}

const DEFAULT_CONFIG: PoeConfig = {
  nanoPerSecond: 1_000_000n,
  nanoCapPerSync: 1_000_000_000n,
  igjCapPerSync: 1_000_000_000_000n,
  igjPerNanoScale: 1_000n,
};

function parseBigIntEnv(value: string | undefined, fallback: bigint): bigint {
  if (!value) return fallback;
  if (/[eE]/.test(value)) {
    return BigInt(Math.floor(Number(value)));
  }
  return BigInt(value);
}

export function loadPoeConfigFromEnv(): PoeConfig {
  const nanoPerSecond = parseBigIntEnv(process.env.POE_NANO_PER_SECOND, 1_000_000n);
  const nanoCapPerSync = parseBigIntEnv(process.env.POE_NANO_CAP_PER_SYNC, 1_000_000_000n);
  const igjCapPerSync = parseBigIntEnv(process.env.POE_IGJ_CAP_PER_SYNC, 1_000_000_000_000n);
  return { ...DEFAULT_CONFIG, nanoPerSecond, nanoCapPerSync, igjCapPerSync };
}

/** Activity score 0–100 maps to multiplier 0.5–1.5 */
export function activityMultiplier(activityScore: number): number {
  const clamped = Math.max(0, Math.min(100, activityScore));
  return 0.5 + clamped / 100;
}

export function computePoe(input: PoeInput, config: PoeConfig = DEFAULT_CONFIG): PoeResult {
  const deltaT = Math.max(0, Math.floor(input.deltaTSeconds));
  const mult = activityMultiplier(input.activityScore);
  const rawNano = BigInt(Math.floor(deltaT)) * config.nanoPerSecond;
  const scaledNano = BigInt(Math.floor(Number(rawNano) * mult));

  let earnedNano = scaledNano;
  let capped = false;
  if (earnedNano > config.nanoCapPerSync) {
    earnedNano = config.nanoCapPerSync;
    capped = true;
  }

  let earnedIgj = (earnedNano * config.igjPerNanoScale) / 1_000_000_000n;
  if (earnedIgj > config.igjCapPerSync) {
    earnedIgj = config.igjCapPerSync;
    capped = true;
  }

  return {
    deltaTSeconds: deltaT,
    earnedNano,
    earnedIgj,
    capped,
    engine: {
      nanoPerSecond: config.nanoPerSecond.toString(),
      activityMultiplier: mult,
      rawNano: rawNano.toString(),
    },
  };
}
