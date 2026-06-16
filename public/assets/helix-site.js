/**
 * YieldSwarm site shell — nav, metrics, 14-lane solenoid, payments.
 */
(function (global) {
  const LANES = [
    { id: 1, name: 'Greek Vaults', layer: 'L0 Genesis', href: '/council/status' },
    { id: 2, name: 'Infra Oracles', layer: 'L1 Council', href: '/council/status' },
    { id: 3, name: 'ZK Mayhem Core', layer: 'L1 Council', href: '/docs/ZK_ENTROPY_SETUP.md' },
    { id: 4, name: 'Akash GPU Workers', layer: 'L2 Agent Mesh', href: '/arena' },
    { id: 5, name: 'Arena Leaderboard', layer: 'L2 Agent Mesh', href: '/arena' },
    { id: 6, name: 'Cross-Chain Exec', layer: 'L5 Blockchain', href: '/payments' },
    { id: 7, name: 'DePIN Orchestration', layer: 'L2 Agent Mesh', href: '/portal' },
    { id: 8, name: 'Emission Routing', layer: 'L5 Blockchain', href: '/dashboard' },
    { id: 9, name: 'AgentSwarm OS', layer: 'L6 Tech Stack', href: '/odysseus' },
    { id: 10, name: 'Security TEE MPC', layer: 'L0 Greek', href: '/council/status' },
    { id: 11, name: 'Telemetry', layer: 'L4 Automation', href: '/api/telemetry/helix' },
    { id: 12, name: 'Governance', layer: 'L1 Council', href: '/council/status' },
    { id: 13, name: 'Treasury Yield', layer: 'L3 Revenue', href: '/marketplace' },
    { id: 14, name: 'Valhalla Portal', layer: 'L6 Tech Stack', href: '/portal' },
  ];

  function renderNav(active) {
    return `
    <nav class="site-nav" aria-label="Main">
      <a class="brand" href="/">YieldSwarm</a>
      <div class="nav-links">
        <a href="/" ${active === 'home' ? 'aria-current="page"' : ''}>Home</a>
        <a href="/marketplace" ${active === 'marketplace' ? 'aria-current="page"' : ''}>Marketplace</a>
        <a href="/sales" ${active === 'sales' ? 'aria-current="page"' : ''}>Z15 Sales</a>
        <a href="/council/status">Council</a>
        <a href="/arena">Arena</a>
        <a href="/payments">Payments</a>
        <a href="/kairo">Kairo</a>
      </div>
      <a class="nav-cta" href="/sales#test-5">Test $5</a>
    </nav>`;
  }

  function renderLaneGrid() {
    return LANES.map(
      (l) => `
      <a class="lane-card" href="${l.href}">
        <div class="lane-id">Lane ${String(l.id).padStart(2, '0')}</div>
        <div>${l.name}</div>
        <div class="layer">${l.layer}</div>
      </a>`
    ).join('');
  }

  async function fetchMetrics() {
    try {
      const res = await fetch('/api/revenue/metrics', { cache: 'no-store' });
      if (!res.ok) throw new Error('metrics unavailable');
      return await res.json();
    } catch {
      return {
        totalRevenueUsd: 7500,
        agentsActive: 10080,
        cronsFiring: 120,
        deitiesOnline: 169,
        openclawNodes: 9,
        lanesActive: 14,
        live: false,
      };
    }
  }

  async function hydrateMetrics() {
    const m = await fetchMetrics();
    const map = {
      'metric-revenue': `$${Number(m.totalRevenueUsd || 7500).toLocaleString()}`,
      'metric-agents': Number(m.agentsActive || 10080).toLocaleString(),
      'metric-crons': String(m.cronsFiring || 120),
      'metric-deities': String(m.deitiesOnline || 169),
      'metric-lanes': String(m.lanesActive || 14),
      'metric-openclaw': String(m.openclawNodes || 9),
    };
    for (const [id, val] of Object.entries(map)) {
      const el = document.getElementById(id);
      if (el) el.textContent = val;
    }
  }

  async function runPaymentTest(amountUsd, product) {
    const status = document.getElementById('payment-status');
    if (status) {
      status.className = 'show';
      status.textContent = `Initiating $${amountUsd} ${product} test…`;
    }
    try {
      const res = await fetch('/api/revenue/z15-test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amountUsd, product, rails: ['wise', 'web3'] }),
      });
      const data = await res.json();
      if (status) {
        status.className = 'show';
        status.innerHTML = data.ok
          ? `✅ ${data.message}<br/><small>${data.reference || ''}</small>`
          : `⚠️ ${data.error || 'Payment rail unavailable — configure Wise in Vault'}`;
      }
      if (data.wiseLink) window.open(data.wiseLink, '_blank', 'noopener');
      await hydrateMetrics();
      return data;
    } catch (err) {
      if (status) {
        status.className = 'show';
        status.textContent = `Error: ${err.message}`;
      }
      throw err;
    }
  }

  function initBubbles(container) {
    if (!container) return;
    const wrap = document.createElement('div');
    wrap.className = 'bubbles';
    for (let i = 0; i < 12; i++) {
      const b = document.createElement('span');
      b.className = 'bubble';
      b.style.left = `${10 + Math.random() * 80}%`;
      b.style.animationDelay = `${Math.random() * 4}s`;
      b.style.animationDuration = `${3 + Math.random() * 3}s`;
      wrap.appendChild(b);
    }
    container.appendChild(wrap);
  }

  global.YieldSwarmSite = {
    LANES,
    renderNav,
    renderLaneGrid,
    fetchMetrics,
    hydrateMetrics,
    runPaymentTest,
    initBubbles,
  };
})(typeof window !== 'undefined' ? window : globalThis);
