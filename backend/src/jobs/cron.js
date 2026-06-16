/**
 * Background cron jobs — warm telemetry adapters on a schedule.
 */

import cron from 'node-cron';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as akash from '../adapters/akash.js';
import * as treasury from '../adapters/treasury.js';
import * as emission from '../adapters/emissionRouter.js';
import * as rtx5090 from '../adapters/rtx5090Telemetry.js';
import config from '../config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);
const { processPillarElevatorHeartbeat } = require(
  path.join(repoRoot, 'src', 'jobs', 'solenoidHeartbeat.js'),
);

const jobs = [];

function safeJob(name, fn) {
  return async () => {
    try {
      await fn();
    } catch (err) {
      console.error(`[cron] ${name} failed:`, err.message);
    }
  };
}

export function startCronJobs(opts = {}) {
  if (opts.enabled === false || process.env.CRON_JOBS_ENABLED === '0') {
    return stopCronJobs;
  }

  const schedules = {
    akash: process.env.CRON_AKASH_POLL || '*/2 * * * *',
    treasury: process.env.CRON_TREASURY_POLL || '*/5 * * * *',
    emission: process.env.CRON_EMISSION_POLL || '*/5 * * * *',
  };

  jobs.push(cron.schedule(schedules.akash, safeJob('akash-poll', () => akash.getWorkers())));
  jobs.push(cron.schedule(schedules.treasury, safeJob('treasury-poll', () => treasury.getTreasurySplits())));
  jobs.push(cron.schedule(schedules.emission, safeJob('emission-poll', () => emission.getEmissions())));

  const solenoidSchedule = process.env.CRON_SOLENOID_HEARTBEAT || '*/10 * * * *';
  jobs.push(
    cron.schedule(solenoidSchedule, safeJob('solenoid-heartbeat', () => processPillarElevatorHeartbeat())),
  );

  if (config.inference.enabled && config.inference.rtx5090Endpoint) {
    const interval = setInterval(
      safeJob('rtx5090-telemetry', () => rtx5090.refreshTelemetry()),
      config.inference.telemetryPollMs,
    );
    jobs.push({ stop: () => clearInterval(interval) });
  }

  console.log(`[cron] started ${jobs.length} background poll(s)`);
  return stopCronJobs;
}

export function stopCronJobs() {
  for (const job of jobs) job.stop();
  jobs.length = 0;
}
