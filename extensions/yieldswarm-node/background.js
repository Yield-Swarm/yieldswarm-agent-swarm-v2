/**
 * YieldSwarm Node — MV3 background service worker (God Prompt 2)
 * Token-bucket heartbeat, efficiency scoring, local credit counter.
 */

const ALARM_NAME = 'yieldswarm-heartbeat';
const INTERVAL_MINUTES = 1;
const STORAGE_KEYS = {
  status: 'nodeStatus',
  credits: 'creditsToday',
  tickets: 'lotteryTickets',
  efficiency: 'lastEfficiency',
  lastBeat: 'lastHeartbeat',
  dayKey: 'creditsDayKey',
};

const todayKey = () => new Date().toISOString().slice(0, 10);

async function readState() {
  return chrome.storage.local.get(Object.values(STORAGE_KEYS));
}

async function writeState(patch) {
  return chrome.storage.local.set(patch);
}

function mockEfficiency() {
  return 85 + Math.floor(Math.random() * 16);
}

async function runHeartbeat() {
  const state = await readState();
  const day = todayKey();
  let credits = state[STORAGE_KEYS.credits] ?? 0;
  let tickets = state[STORAGE_KEYS.tickets] ?? 0;

  if (state[STORAGE_KEYS.dayKey] !== day) {
    credits = 0;
    tickets = 0;
  }

  const efficiency = mockEfficiency();
  const active = efficiency >= 88;
  const creditGain = active ? Math.max(1, Math.floor(efficiency / 10)) : 0;
  credits += creditGain;

  if (credits > 0 && credits % 50 === 0) {
    tickets += 1;
  }

  const payload = {
    [STORAGE_KEYS.status]: active ? 'active' : 'idle',
    [STORAGE_KEYS.credits]: credits,
    [STORAGE_KEYS.tickets]: tickets,
    [STORAGE_KEYS.efficiency]: efficiency,
    [STORAGE_KEYS.lastBeat]: Date.now(),
    [STORAGE_KEYS.dayKey]: day,
  };

  await writeState(payload);

  try {
    chrome.runtime.sendMessage({ type: 'heartbeat', ...payload }).catch(() => {});
  } catch {
    /* popup may be closed */
  }

  return payload;
}

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) {
    runHeartbeat().catch((err) => console.error('[yieldswarm-node]', err));
  }
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type === 'getState') {
    readState()
      .then((state) => sendResponse({ ok: true, state }))
      .catch((err) => sendResponse({ ok: false, error: String(err) }));
    return true;
  }
  if (msg?.type === 'ping') {
    runHeartbeat()
      .then((state) => sendResponse({ ok: true, state }))
      .catch((err) => sendResponse({ ok: false, error: String(err) }));
    return true;
  }
  return false;
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.alarms.create(ALARM_NAME, { periodInMinutes: INTERVAL_MINUTES });
  runHeartbeat().catch(console.error);
});
