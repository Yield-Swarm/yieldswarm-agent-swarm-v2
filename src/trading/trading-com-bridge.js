/**
 * Trading.com signal distribution bridge.
 * @module src/trading/trading-com-bridge
 */

/**
 * Format and distribute signals to Trading.com webhook/API.
 * @param {object[]} signals from ninjatrader-bridge or dydx-bridge
 */
export async function distributeSignals(signals, opts = {}) {
  const endpoint = process.env.TRADING_COM_WEBHOOK_URL ?? opts.endpoint;
  if (!endpoint) {
    return { ok: false, status: 'skipped', reason: 'TRADING_COM_WEBHOOK_URL unset' };
  }

  const payload = {
    source: 'yieldswarm',
    version: 'v6',
    timestamp: Date.now(),
    signals,
  };

  if (opts.dryRun) return { ok: true, status: 'dry_run', payload };

  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${process.env.TRADING_COM_API_KEY ?? ''}` },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10_000),
    });
    return { ok: res.ok, status: res.status, body: await res.text().catch(() => '') };
  } catch (err) {
    return { ok: false, status: 'error', reason: String(err.message ?? err) };
  }
}

export default { distributeSignals };
