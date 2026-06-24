/**
 * DePIN miner profile + checklist persistence.
 * File-backed by default; swap driver when DATABASE_URL (Neon) is wired.
 */

import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { streakMultiplier } from '../lib/poeMath.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const storePath = path.join(repoRoot, '.run', 'depin-store.json');

const INTRO_STEPS = [
  { id: 'gateway_subnet', label: 'Secure gateway local subnet' },
  { id: 'ioid_register', label: 'Register IoTeX machine identity (ioID)' },
  { id: 'pour_over_sim', label: 'Run first Pour Over simulation workload' },
];

const DAILY_TASKS = [
  { id: 'heartbeat', label: 'Verify 420s agent heartbeat' },
  { id: 'atomic_pulse', label: 'Trigger ATOMIC_PULSE audit' },
  { id: 'yslr_scan', label: 'Run YSLR scanner (blocks 1–128000)' },
  { id: 'venti_workload', label: 'Complete Venti workload' },
];

function emptyStore() {
  return { profiles: {}, checklists: {} };
}

async function load() {
  try {
    const raw = await fs.readFile(storePath, 'utf8');
    return { ...emptyStore(), ...JSON.parse(raw) };
  } catch {
    return emptyStore();
  }
}

async function save(data) {
  await fs.mkdir(path.dirname(storePath), { recursive: true });
  await fs.writeFile(storePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

function defaultProfile(email) {
  return {
    email,
    currentPlan: 'Lite',
    currentBalance: 1000,
    allTimeRedeems: 0,
    allTimeCollected: 0,
    geominesAllTime: 0,
    geodropsAllTime: 0,
    surveysAllTime: 0,
    spentGeoclaims: 0,
    spentGeodrops: 0,
    spentSweepstakes: 0,
    lastSynchronized: new Date().toISOString(),
  };
}

function defaultChecklist(email) {
  return {
    email,
    intro: Object.fromEntries(INTRO_STEPS.map((s) => [s.id, false])),
    introComplete: false,
    daily: Object.fromEntries(DAILY_TASKS.map((t) => [t.id, false])),
    dailyCompletedDays: 0,
    lastDailyUtc: null,
    streakDays: 0,
  };
}

/**
 * Upsert miner telemetry from mobile / geomining client.
 */
export async function syncMinerProfile(payload) {
  const data = await load();
  const email = String(payload.email).toLowerCase();
  const existing = data.profiles[email] || defaultProfile(email);

  const profile = {
    ...existing,
    currentPlan: payload.plan ?? existing.currentPlan,
    currentBalance: payload.currentBalance ?? existing.currentBalance,
    geominesAllTime: existing.geominesAllTime + (payload.geomines ?? 0),
    geodropsAllTime: existing.geodropsAllTime + (payload.geodrops ?? 0),
    surveysAllTime: existing.surveysAllTime + (payload.surveys ?? 0),
    spentGeoclaims: existing.spentGeoclaims + (payload.spentGeoclaims ?? 0),
    spentGeodrops: existing.spentGeodrops + (payload.spentGeodrops ?? 0),
    spentSweepstakes: existing.spentSweepstakes + (payload.spentSweepstakes ?? 0),
    lastSynchronized: new Date().toISOString(),
  };

  data.profiles[email] = profile;
  if (!data.checklists[email]) data.checklists[email] = defaultChecklist(email);
  await save(data);
  return profile;
}

export async function getMinerProfile(email) {
  const data = await load();
  return data.profiles[String(email).toLowerCase()] ?? null;
}

export async function getChecklist(email) {
  const data = await load();
  const key = String(email).toLowerCase();
  if (!data.checklists[key]) data.checklists[key] = defaultChecklist(key);
  return {
    ...data.checklists[key],
    introSteps: INTRO_STEPS,
    dailyTasks: DAILY_TASKS,
    streakMultiplier: streakMultiplier(data.checklists[key].streakDays),
  };
}

export async function completeChecklistItem(email, { phase, taskId }) {
  const data = await load();
  const key = String(email).toLowerCase();
  if (!data.checklists[key]) data.checklists[key] = defaultChecklist(key);
  const cl = data.checklists[key];

  if (phase === 'intro' && taskId in cl.intro) {
    cl.intro[taskId] = true;
    cl.introComplete = INTRO_STEPS.every((s) => cl.intro[s.id]);
  } else if (phase === 'daily' && taskId in cl.daily) {
    cl.daily[taskId] = true;
    const allDone = DAILY_TASKS.every((t) => cl.daily[t.id]);
    const today = new Date().toISOString().slice(0, 10);
    if (allDone && cl.lastDailyUtc !== today) {
      cl.lastDailyUtc = today;
      cl.dailyCompletedDays += 1;
      cl.streakDays = Math.min(cl.streakDays + 1, 6);
      for (const t of DAILY_TASKS) cl.daily[t.id] = false;
    }
  } else {
    throw new Error('invalid checklist phase or taskId');
  }

  await save(data);
  return getChecklist(key);
}

export { INTRO_STEPS, DAILY_TASKS };
