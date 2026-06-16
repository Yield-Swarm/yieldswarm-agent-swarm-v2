/**
 * NinjaTrader strategy signal generator (PDs¹ trading module).
 * @module src/trading/ninjatrader-bridge
 */

import { optimizeTick } from '../infrastructure/sovereign-optimizer.js';

/**
 * Generate strategy signals from sovereign optimizer + Arena ROI.
 * @param {object} input
 */
export function generateStrategySignals(input) {
  const opt = optimizeTick(input);
  const primary = opt.signal?.primary;
  if (!primary) return { signals: [], reason: 'no_workers' };

  const roiBps = input.arena?.roiBps ?? 0;
  const direction = roiBps >= 0 ? 'long' : 'short';

  return {
    platform: 'ninjatrader',
    signals: [{
      instrument: input.instrument ?? 'ES 03-26',
      direction,
      confidence: opt.signal.compositeScore ?? 0.5,
      sizeContracts: Math.max(1, Math.floor((input.mutationTier ?? 0) + 1)),
      source: 'sovereign_optimizer_v6',
    }],
    optimizer: opt,
  };
}

export default { generateStrategySignals };
