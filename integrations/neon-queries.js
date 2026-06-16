/**
 * Neon / revenue query client for YieldSwarm static pages.
 */
(function (global) {
  async function fetchRevenueMetrics() {
    const res = await fetch('/api/revenue/metrics', { cache: 'no-store' });
    if (!res.ok) throw new Error(`Metrics ${res.status}`);
    return res.json();
  }

  async function logSale(payload) {
    const res = await fetch('/api/revenue/log', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `Log failed ${res.status}`);
    }
    return res.json();
  }

  async function queryRecentSales(limit = 10) {
    const res = await fetch(`/api/revenue/log?limit=${limit}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`Query ${res.status}`);
    return res.json();
  }

  global.YieldSwarmNeon = { fetchRevenueMetrics, logSale, queryRecentSales };
})(typeof window !== 'undefined' ? window : globalThis);
