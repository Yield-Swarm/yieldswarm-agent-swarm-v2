/** Kairo driver telemetry + contribution API adapter. */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const kairoCli = path.join(repoRoot, 'kairo', 'cli.py');

function runKairo(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [kairoCli, ...args], {
      cwd: repoRoot,
      env: process.env,
    });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `kairo cli exited ${code}`));
        return;
      }
      try {
        resolve(JSON.parse(stdout || '{}'));
      } catch {
        resolve({ raw: stdout });
      }
    });
  });
}

export async function ingestTelemetry(event) {
  return runKairo(['ingest', JSON.stringify(event)]);
}

export async function listContributions(limit = 50) {
  return runKairo(['contributions', String(limit)]);
}

export async function registerDriver(deviceFingerprint) {
  const args = ['register'];
  if (deviceFingerprint) args.push(deviceFingerprint);
  return runKairo(args);
}

export async function ping() {
  try {
    await runKairo(['ping']);
    return { live: true, source: 'kairo' };
  } catch (err) {
    return { live: false, source: 'kairo', error: err.message };
  }
}
