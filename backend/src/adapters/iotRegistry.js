/**
 * IoT device registry adapter — bridges Python registry to Node API.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');

function runPython(snippet) {
  return new Promise((resolve, reject) => {
    const child = spawn('python3', ['-c', snippet], {
      cwd: repoRoot,
      env: { ...process.env, PYTHONPATH: repoRoot },
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.stderr.on('data', (d) => { stderr += d; });
    child.on('close', (code) => {
      if (code !== 0) {
        resolve({ ok: false, error: stderr || `exit ${code}` });
        return;
      }
      try {
        resolve({ ok: true, data: JSON.parse(stdout || '{}') });
      } catch {
        resolve({ ok: false, error: 'invalid json', raw: stdout });
      }
    });
    child.on('error', reject);
  });
}

export async function getIoTSummary() {
  const snippet = `
import json
from services.iot.device_registry import DeviceRegistry
r = DeviceRegistry()
r.bootstrap_from_env()
print(json.dumps(r.summary()))
`;
  return runPython(snippet);
}

export async function listDevices() {
  const result = await getIoTSummary();
  if (!result.ok) return result;
  return { ok: true, data: result.data?.devices || [] };
}

export default { getIoTSummary, listDevices };
