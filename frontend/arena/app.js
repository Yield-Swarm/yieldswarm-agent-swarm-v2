/**
 * Arena dashboard client.
 *
 * Pulls the aggregated overview from /api/arena/overview and renders the four
 * live surfaces: Akash workers, emission router, treasury splits, and the agent
 * leaderboard. Connection health for each surface is derived from the `live`
 * flag returned by the backend so operators can see at a glance which upstreams
 * are connected vs. serving fallback data.
 */

const REFRESH_MS = 10_000;
// API base is same-origin by default; override via ?api=<url> for split hosting.
const API_BASE = new URLSearchParams(location.search).get('api') || '';

const $ = (sel) => document.querySelector(sel);

function fmtNum(n, opts = {}) {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return '—';
  return Number(n).toLocaleString(undefined, { maximumFractionDigits: 2, ...opts });
}

function shortAddr(a) {
  if (!a) return '—';
  return a.length > 12 ? `${a.slice(0, 5)}…${a.slice(-4)}` : a;
}

function setBadge(el, live) {
  el.textContent = live ? 'live' : 'fallback';
  el.classList.toggle('live', live);
  el.classList.toggle('fallback', !live);
}

function renderConnections(connections) {
  let healthy = 0;
  const total = Object.keys(connections).length;
  for (const [key, info] of Object.entries(connections)) {
    const el = document.querySelector(`.conn[data-conn="${key}"]`);
    if (!el) continue;
    el.classList.remove('live', 'fallback', 'down');
    el.classList.add(info.connected ? 'live' : 'fallback');
    if (info.connected) healthy++;
    el.querySelector('.src').textContent = info.source || '';
  }
  const summary = $('#conn-summary');
  summary.textContent = `${healthy}/${total} live`;
  summary.className = 'pill ' + (healthy === total ? 'pill-good' : healthy === 0 ? 'pill-bad' : 'pill-warn');
}

function renderAkash(akash) {
  setBadge($('#akash-badge'), akash.live);
  $('#workers-active').textContent = fmtNum(akash.activeWorkers);

  const net = akash.network;
  if (net && net.gpu) {
    $('#net-gpu').textContent = `${fmtNum(net.gpu.active)} / ${fmtNum(net.gpu.total)}`;
    $('#net-providers').textContent = `${fmtNum(net.providersOnline)} / ${fmtNum(net.providersTotal)}`;
  } else {
    $('#net-gpu').textContent = '—';
    $('#net-providers').textContent = '—';
  }

  const note = $('#workers-note');
  if (akash.reason) {
    note.textContent = `${akash.workersSource === 'owner-leases' ? '' : 'Sample fleet — '}${akash.reason}`;
    note.hidden = false;
  } else {
    note.hidden = true;
  }

  const rows = (akash.workers || []).map((w) => {
    const stateCls = w.state === 'active' ? 'state-active' : 'state-other';
    const cpu = w.cpuUtil != null ? `${(w.cpuUtil * 100).toFixed(0)}%` : '—';
    const uptime = w.uptimePct != null ? `${w.uptimePct.toFixed(1)}%` : '—';
    const hr = w.hashrateMhs != null ? `${w.hashrateMhs} MH/s` : '—';
    return `<tr>
      <td class="mono">${w.id}</td>
      <td>${w.kind}</td>
      <td class="${stateCls}">${w.state}</td>
      <td>${cpu}</td>
      <td>${uptime}</td>
      <td>${hr}</td>
    </tr>`;
  });
  $('#workers-rows').innerHTML = rows.join('') || '<tr><td colspan="6">no workers</td></tr>';
}

function renderEmission(em) {
  setBadge($('#emission-badge'), em.live);
  $('#emission-supply').textContent = fmtNum(em.circulatingSupply);
  $('#emission-epoch').textContent = fmtNum(em.emissionPerEpoch);
  $('#emission-day').textContent = fmtNum(em.emissionPerDay);
  $('#emission-routes').innerHTML = (em.routes || [])
    .map(
      (r) => `<li><span>${r.destination} · ${(r.share * 100).toFixed(0)}%</span><span>${fmtNum(r.perEpoch)}/epoch</span></li>`,
    )
    .join('');
}

function renderTreasury(t) {
  setBadge($('#treasury-badge'), t.live);
  $('#treasury-total').textContent = fmtNum(t.totalSol);
  $('#treasury-splits').innerHTML = (t.splits || [])
    .map(
      (s) => `<li class="split-row">
        <div class="split-top"><span>${s.bucket} · ${s.pct}%</span><span>${fmtNum(s.sol)} SOL</span></div>
        <div class="bar"><span style="width:${s.pct}%"></span></div>
      </li>`,
    )
    .join('');
}

function renderLeaderboard(lb) {
  setBadge($('#leaderboard-badge'), lb.live);
  const rows = (lb.rows || []).map(
    (r) => `<tr>
      <td>${r.rank}</td>
      <td class="mono">${r.account ? shortAddr(r.account) : r.agentId}</td>
      <td>${r.shard}</td>
      <td>${fmtNum(r.rewardsApn)}</td>
      <td>${r.tasksCompleted != null ? fmtNum(r.tasksCompleted) : '—'}</td>
    </tr>`,
  );
  $('#leaderboard-rows').innerHTML = rows.join('') || '<tr><td colspan="5">no data</td></tr>';
}

function showError(msg) {
  const el = $('#error-banner');
  if (!msg) {
    el.hidden = true;
    return;
  }
  el.hidden = false;
  el.textContent = msg;
}

async function refresh() {
  try {
    const res = await fetch(`${API_BASE}/api/arena/overview`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`API responded ${res.status}`);
    const data = await res.json();

    renderConnections(data.connections);
    renderAkash(data.akash);
    renderEmission(data.emissionRouter);
    renderTreasury(data.treasury);
    renderLeaderboard(data.leaderboard);

    $('#last-updated').textContent = `updated ${new Date(data.generatedAt).toLocaleTimeString()}`;
    showError(null);
  } catch (err) {
    showError(`Could not reach the integration backend: ${err.message}. Retrying…`);
    const summary = $('#conn-summary');
    summary.textContent = 'backend offline';
    summary.className = 'pill pill-bad';
  }
}

$('#refresh-secs').textContent = String(REFRESH_MS / 1000);
refresh();
setInterval(refresh, REFRESH_MS);
