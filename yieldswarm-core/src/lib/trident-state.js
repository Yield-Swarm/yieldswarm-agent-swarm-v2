/**
 * Trident Protocol — hardware inventory & cloud pricing matrices.
 */

export const QUANTUM_EQUATION = "∇⨂Ψ = ∮∂Ω(t,c)";

export function temporalContext(now = new Date()) {
  const month = now.getUTCMonth();
  const season =
    month >= 2 && month <= 4 ? "Spring" : month >= 5 && month <= 7 ? "Summer" : month >= 8 && month <= 10 ? "Fall" : "Winter";
  const start = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((now - start) / 86400000 + start.getUTCDay() + 1) / 7);
  return {
    iso: now.toISOString(),
    year: now.getUTCFullYear(),
    month: now.getUTCMonth() + 1,
    season,
    week,
    label: `${now.toLocaleString("en-US", { month: "long", timeZone: "UTC" })} ${now.getUTCFullYear()}, ${season}, Week ${week}`,
  };
}

export const ON_PREM_HARDWARE = {
  asic: {
    antminerS19: { count: 3, series: "S19", role: "sha256-btc-lane" },
    antminerL7: { count: 1, series: "L7", role: "scrypt-lane" },
    nerdaxetaxeRev31: { count: 1, model: "Nerdaxetaxe Rev 3.1", algorithm: "sha256", role: "home-office-mini" },
    jasminerX4QC: { count: 1, model: "Jasminer X4-Q-C", hashrate: "900MH/s", algorithm: "etchash", powerW: 340 },
    iceRiverK0Ultra: { count: 1, model: "IceRiver K0 Ultra", algorithm: "kheavyhash", coin: "KAS" },
    z15Fleet: { count: 30, model: "Antminer Z15 Pro", algorithm: "equihash", coin: "ZEC", site: "carrizozo-nm" },
  },
  edge: {
    attVistaWTATTRW2: {
      count: 700,
      model: "AT&T Vista WTATTRW2",
      oem: "Wingtech",
      vlan: 20,
      ramMb: 4096,
      storageGb: 64,
    },
    termuxInstances: { count: 8, ramMbPerInstance: 16384, storageGbPerInstance: 128 },
  },
  network: {
    mesh: "ASUS ZenWiFi BE5000 Pro",
    switches: ["TL-SG608P", "TL-SG605P"],
  },
};

export const REMOTE_FLEET = {
  creditUsd: 36000,
  gpus: {
    h100: { count: 16, vramGb: 80, provider: ["runpod", "akash", "vast"] },
    h200: { count: 16, vramGb: 141, provider: ["runpod", "akash"] },
  },
  workerName: process.env.PRL_WORKER_NAME || "16xH100-YieldSwarm-Fleet1",
};

export function cloudPricingMatrix() {
  const env = (key, fallback) => {
    const v = process.env[key];
    return v !== undefined && v !== "" ? Number(v) : fallback;
  };
  return {
    normalizedUsdPerGpuHour: {
      akash: env("CLOUD_PRICE_AKASH_GPU_HR", 0.42),
      vast: env("CLOUD_PRICE_VAST_GPU_HR", 0.55),
      runpod: env("CLOUD_PRICE_RUNPOD_GPU_HR", 1.89),
      vultr: env("CLOUD_PRICE_VULTR_GPU_HR", 2.1),
    },
    aktUsd: env("AKT_USD", 1.2),
    fleetCreditRemainingUsd: env("FLEET_CREDIT_REMAINING_USD", REMOTE_FLEET.creditUsd),
    updatedAt: new Date().toISOString(),
  };
}

export function profitabilitySnapshot() {
  const quotes = {
    PRL: Number(process.env.MINING_QUOTE_USD_PRL || 12.5),
    ETC: Number(process.env.MINING_QUOTE_USD_ETC || 8.2),
    ERG: Number(process.env.MINING_QUOTE_USD_ERG || 6.4),
  };
  const ranked = Object.entries(quotes)
    .map(([coin, usdDay]) => ({ coin, algorithm: { PRL: "pearlhash", ETC: "etchash", ERG: "autolykos2" }[coin], usdDay }))
    .sort((a, b) => b.usdDay - a.usdDay);
  return { quotes, best: ranked[0], ranked };
}

export function buildSystemState() {
  const temporal = temporalContext();
  const profit = profitabilitySnapshot();
  return {
    schemaVersion: "trident/systemState/v1",
    quantum: { equation: QUANTUM_EQUATION },
    temporal: {
      ...temporal,
      contextFlag: `Current Context: ${temporal.label}`,
    },
    cloud: cloudPricingMatrix(),
    onPrem: ON_PREM_HARDWARE,
    remoteFleet: REMOTE_FLEET,
    mining: {
      activeAlgorithm: profit.best.algorithm,
      activeCoin: profit.best.coin,
      profitability: profit,
      pouwCoins: ["PRL", "KRX", "ZANO", "QTC", "IRON", "TON"],
      yieldswarmNative: "PRL",
    },
    networkProfile: "config/network/vlan-trident.json",
    websocket: { host: "127.0.0.1", port: Number(process.env.TRIDENT_WS_PORT || 8095) },
  };
}
