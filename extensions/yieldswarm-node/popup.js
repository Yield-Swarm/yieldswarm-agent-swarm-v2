/**
 * YieldSwarm Node popup — messaging bridge to background worker.
 */

const KEYS = {
  status: 'nodeStatus',
  credits: 'creditsToday',
  tickets: 'lotteryTickets',
  efficiency: 'lastEfficiency',
};

const $ = (id) => document.getElementById(id);

function setStatus(status) {
  const badge = $('status-badge');
  const text = $('status-text');
  const active = status === 'active';
  badge.className = `badge ${active ? 'active' : 'idle'}`;
  text.textContent = active ? 'Active' : 'Idle';
}

function render(state) {
  if (!state) return;
  setStatus(state[KEYS.status] || 'idle');
  $('credits').textContent = String(state[KEYS.credits] ?? 0);
  $('tickets').textContent = String(state[KEYS.tickets] ?? 0);
  const eff = state[KEYS.efficiency];
  $('efficiency').textContent = eff != null ? `${eff}%` : '—';
  $('error').hidden = true;
}

async function refresh() {
  try {
    const res = await chrome.runtime.sendMessage({ type: 'getState' });
    if (!res?.ok) throw new Error(res?.error || 'unknown error');
    render(res.state);
  } catch (err) {
    $('error').textContent = String(err.message || err);
    $('error').hidden = false;
  }
}

$('refresh').addEventListener('click', async () => {
  try {
    const res = await chrome.runtime.sendMessage({ type: 'ping' });
    if (!res?.ok) throw new Error(res?.error || 'ping failed');
    render(res.state);
  } catch (err) {
    $('error').textContent = String(err.message || err);
    $('error').hidden = false;
  }
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg?.type === 'heartbeat') render(msg);
});

refresh();
