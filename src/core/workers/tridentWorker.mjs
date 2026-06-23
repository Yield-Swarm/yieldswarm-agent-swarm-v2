import { parentPort, workerData } from 'node:worker_threads';

const kind = workerData.kind;
const tickRate = workerData.tickRate;
const config = workerData.config;

function post(state) {
  parentPort?.postMessage({ kind, ts: Date.now(), ...state });
}

async function runSentinel() {
  const vehicleId = config.VEHICLE_ID ?? 'APOLLO_NEXUS_TEST_01';
  const wssUrl =
    config.HELIXPOW_WSS_URL ??
    `wss://helixpow.pw/api/iot/telemetry?vehicle=${vehicleId}`;
  let connected = false;
  const WS = globalThis.WebSocket;
  if (!WS) {
    setInterval(
      () => post({ connected: false, vehicleId, tunnelSilence: true, sim: true }),
      tickRate,
    );
    return;
  }
  try {
    const ws = new WS(wssUrl);
    ws.onopen = () => {
      connected = true;
      post({ connected: true, vehicleId, wssUrl });
    };
    ws.onmessage = (ev) => {
      try {
        const payload = JSON.parse(String(ev.data));
        post({
          connected: true,
          vehicleId,
          gps: payload.gps ?? payload.coordinates,
          heliumCredits: payload.heliumCredits ?? payload.coverage,
        });
      } catch {
        post({ connected: true, vehicleId, raw: String(ev.data).slice(0, 200) });
      }
    };
    ws.onclose = () => {
      connected = false;
      post({ connected: false, vehicleId, tunnelSilence: true });
    };
    ws.onerror = () => {
      connected = false;
      post({ connected: false, vehicleId, tunnelSilence: true });
    };
    setInterval(() => post({ connected, vehicleId, heartbeat: true }), tickRate);
  } catch {
    post({ connected: false, vehicleId, tunnelSilence: true, sim: true });
  }
}

async function runNexus() {
  const port = Number(config.LOLMINER_LOCAL_PORT ?? 4067);
  setInterval(async () => {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/v1/summary`);
      const data = await res.json();
      post({
        hashRate: data.hashrate ?? data.total_hashrate,
        blocks: data.blocks ?? data.shares,
        miner: 'lolminer',
      });
    } catch {
      post({ hashRate: 0, blocks: 0, miner: 'lolminer', offline: true });
    }
  }, tickRate);
}

function runLiquidity() {
  const assets = ['SOL', 'TON', 'XRP', 'LTC', 'TAO', 'HYPE'];
  setInterval(() => {
    post({
      orderBooks: Object.fromEntries(
        assets.map((a) => [a, { bid: Math.random(), ask: Math.random() }]),
      ),
    });
  }, tickRate);
}

function runTreasury() {
  const stables = ['USDC', 'USDT', 'USD1'];
  setInterval(() => {
    post({
      balances: Object.fromEntries(stables.map((s) => [s, 1000 + Math.random() * 100])),
      deltaRisk: Math.random() * 0.1,
      kairosFrozen: config.KAIROS_RISK_FROZEN === '1',
    });
  }, tickRate);
}

function runCodex() {
  const codexUrl = config.CODEX_INGEST_URL ?? 'https://yslrcodex.com/api/ingest';
  setInterval(async () => {
    const bundle = {
      trident: config.TRIDENT_VERSION,
      ts: Date.now(),
      workers: workerData.snapshot ?? {},
    };
    try {
      if (config.CODEX_PUSH_ENABLED === '1') {
        await fetch(codexUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(bundle),
        });
      }
      post({ codexPushed: true, bytes: JSON.stringify(bundle).length });
    } catch {
      post({ codexPushed: false, bytes: JSON.stringify(bundle).length });
    }
  }, tickRate);
}

switch (kind) {
  case 'sentinel':
    void runSentinel();
    break;
  case 'nexus':
    void runNexus();
    break;
  case 'liquidity':
    runLiquidity();
    break;
  case 'treasury':
    runTreasury();
    break;
  case 'codex':
    runCodex();
    break;
}

parentPort?.on('message', (msg) => {
  if (msg.type === 'snapshot' && kind === 'codex') {
    workerData.snapshot = msg.snapshot;
  }
  if (msg.type === 'freeze-kairos' && kind === 'treasury') {
    config.KAIROS_RISK_FROZEN = '1';
    post({ kairosFrozen: true, reroute: 'USD1/USDC delta-neutral' });
  }
});
