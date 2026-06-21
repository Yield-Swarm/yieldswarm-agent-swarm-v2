/**
 * IoT Hub adapter — FWA_37KN9S-IoT device management.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const IOT_CLI = path.join(REPO_ROOT, 'services', 'iot_hub', 'cli.py');

export const IOT_NETWORK_ID = process.env.IOT_NETWORK_ID || 'FWA_37KN9S-IoT';

function runIotCli(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [IOT_CLI, ...args], {
      cwd: REPO_ROOT,
      env: { ...process.env, IOT_NETWORK_ID },
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        const err = new Error(stderr || `iot cli exit ${code}`);
        err.status = 502;
        return reject(err);
      }
      try {
        resolve(JSON.parse(stdout));
      } catch {
        resolve({ raw: stdout });
      }
    });
  });
}

export async function getIotStatus() {
  return runIotCli(['status']);
}

export async function registerDevices() {
  return runIotCli(['register']);
}

export async function monitorDevices() {
  return runIotCli(['monitor']);
}

export async function syncCoordinator() {
  return runIotCli(['sync']);
}

export async function checkDevice(deviceId) {
  return runIotCli(['device', 'check', deviceId]);
}

export async function listDevices() {
  return runIotCli(['device', 'list']);
}

export async function ping() {
  try {
    const status = await getIotStatus();
    return { live: true, source: 'iot-hub', networkId: IOT_NETWORK_ID, ...status };
  } catch (err) {
    return { live: false, source: 'iot-hub', error: err.message };
  }
}
