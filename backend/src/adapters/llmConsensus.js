/**
 * Live LLM council consensus — spawns Python engine or reads last report.
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const reportPath = path.join(repoRoot, '.run', 'llm-consensus-report.json');
const votersPath = path.join(repoRoot, 'config', 'governance', 'llm_voters.json');

function readJsonFile(filePath) {
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function runPythonConsensus(body) {
  return new Promise((resolve, reject) => {
    const args = [path.join(repoRoot, 'scripts', 'run-llm-consensus.py')];
    if (body.contextFile) {
      args.push('--context-file', body.contextFile);
    } else if (body.context) {
      args.push('--context', body.context);
    }
    if (body.options) {
      args.push('--options-json', JSON.stringify(body.options));
    }
    if (body.proposal) {
      args.push('--proposal', body.proposal);
    }
    if (body.output) {
      args.push('--output', body.output);
    }

    const proc = spawn('python3', args, {
      cwd: repoRoot,
      env: { ...process.env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    proc.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    proc.on('close', (code) => {
      try {
        const parsed = JSON.parse(stdout);
        resolve({ ...parsed, exit_code: code, stderr: stderr || undefined });
      } catch {
        reject(new Error(stderr || stdout || `llm consensus exited ${code}`));
      }
    });
  });
}

export function getLlmVoters() {
  const registry = readJsonFile(votersPath) ?? { voters: [] };
  return {
    registry_path: votersPath,
    voter_definitions: registry.voters?.length ?? 0,
    threshold: registry.consensus_threshold ?? { council_seats: 14, required_approvals: 9 },
    note: 'Run with API keys set; gospel_sim always available as fallback voter',
  };
}

export function getLastLlmConsensusReport() {
  const report = readJsonFile(reportPath);
  return {
    live: Boolean(report),
    report_path: reportPath,
    report: report ?? null,
  };
}

export async function runLlmConsensus(body = {}) {
  const result = await runPythonConsensus(body);
  return {
    source: 'llm-consensus-engine',
    live: result.live_voter_count > 0,
    ...result,
  };
}

export async function listLlmVoters() {
  return new Promise((resolve, reject) => {
    const proc = spawn('python3', [
      path.join(repoRoot, 'scripts', 'run-llm-consensus.py'),
      '--list-voters',
    ], { cwd: repoRoot, stdio: ['ignore', 'pipe', 'pipe'] });

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (c) => {
      stdout += c;
    });
    proc.stderr.on('data', (c) => {
      stderr += c;
    });
    proc.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(stderr || 'list voters failed'));
        return;
      }
      try {
        resolve(JSON.parse(stdout));
      } catch {
        reject(new Error('invalid voters json'));
      }
    });
  });
}
