/**
 * Helix Nodes background service worker.
 * Sends periodic heartbeats; accrues lottery tickets server-side.
 */
const DEFAULT_API = 'http://127.0.0.1:8080';

async function apiBase() {
  const { apiBase: stored } = await chrome.storage.local.get('apiBase');
  return stored || DEFAULT_API;
}

async function ensureRegistered() {
  const data = await chrome.storage.local.get(['nodeId', 'referralCode']);
  if (data.nodeId) return data.nodeId;

  const body = {};
  if (data.referralCode) body.referral_code = data.referralCode;

  const res = await fetch(`${await apiBase()}/api/helix-nodes/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...body, platform: 'chrome-extension' }),
  });
  const json = await res.json();
  if (!json.ok || !json.node?.node_id) throw new Error('register failed');
  await chrome.storage.local.set({
    nodeId: json.node.node_id,
    myReferralCode: json.node.referral_code,
  });
  return json.node.node_id;
}

async function heartbeat() {
  try {
    const nodeId = await ensureRegistered();
    const res = await fetch(`${await apiBase()}/api/helix-nodes/heartbeat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        node_id: nodeId,
        extension_version: chrome.runtime.getManifest().version,
        tasks_completed: 1,
      }),
    });
    const json = await res.json();
    if (json.ok && json.node) {
      await chrome.storage.local.set({
        lastHeartbeat: Date.now(),
        lotteryTickets: json.node.lottery_tickets,
        points: json.node.points,
        status: json.node.status,
      });
    }
  } catch (err) {
    console.warn('[helix-node] heartbeat failed', err);
    await chrome.storage.local.set({ status: 'offline' });
  }
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create('helix-heartbeat', { periodInMinutes: 5 });
  heartbeat();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'helix-heartbeat') heartbeat();
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === 'heartbeat-now') {
    heartbeat().then(() => sendResponse({ ok: true })).catch((e) => sendResponse({ ok: false, error: String(e) }));
    return true;
  }
  if (msg.type === 'record-action') {
    chrome.storage.local.get('nodeId').then(async ({ nodeId }) => {
      const res = await fetch(`${await apiBase()}/api/helix-nodes/actions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ node_id: nodeId, action: msg.action }),
      });
      sendResponse(await res.json());
    });
    return true;
  }
});
