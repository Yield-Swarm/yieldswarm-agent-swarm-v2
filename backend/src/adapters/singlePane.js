/**
 * Single Pane of Glass — aggregates all 20 prompts + subsystem health.
 */

import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildTvDashboard } from './tvDashboard.js';
import * as miningFleet from './miningFleet.js';
import * as iotRegistry from './iotRegistry.js';
import { getHelixStatus } from './helix.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');

function pyStatus(moduleFn) {
  return new Promise((resolve) => {
    const child = spawn(
      'python3',
      ['-c', `import json; ${moduleFn}; print(json.dumps(result))`],
      { cwd: repoRoot, env: { ...process.env, PYTHONPATH: repoRoot } },
    );
    let stdout = '';
    child.stdout.on('data', (d) => { stdout += d; });
    child.on('close', () => {
      try {
        resolve(JSON.parse(stdout || '{}'));
      } catch {
        resolve({});
      }
    });
    child.on('error', () => resolve({}));
  });
}

export async function getPromptRegistry() {
  return pyStatus(`
from services.single_pane.registry import get_prompt_status
result = get_prompt_status()
`);
}

export async function getSubsystemSnapshots() {
  const [prompts, tv, iot, helix, miningStatus, yslr, utc, astro, operators, profit, magic, dune, qb, mesh, sharding, oauth] =
    await Promise.all([
      getPromptRegistry(),
      buildTvDashboard().catch(() => ({})),
      iotRegistry.getIoTSummary(),
      getHelixStatus(),
      miningFleet.readMiningStatus(),
      pyStatus('from services.yslr.queue import YslrQueue; result = YslrQueue().summary()'),
      pyStatus('from services.utc.scheduler import UniversalTimeCoordinate; result = UniversalTimeCoordinate().now().to_dict()'),
      pyStatus('from services.astro_schedule.engine import AstrologicalScheduleEngine; result = AstrologicalScheduleEngine().evaluate().to_dict()'),
      pyStatus('from services.depin.mainnet_operators import operator_summary; result = operator_summary()'),
      pyStatus('from services.business.profit_share import load_partners; result = {"partners": load_partners()}'),
      pyStatus('from services.business.magic_links import team_roster; result = {"team": team_roster()}'),
      pyStatus('from services.integrations.dune import dune_status; result = dune_status()'),
      pyStatus('from services.integrations.quickbooks import quickbooks_status; result = quickbooks_status()'),
      pyStatus('from services.neural_mesh.elevators import NeuralMeshElevators; result = NeuralMeshElevators().status()'),
      pyStatus('from services.helix.sharding import HelixSharding; result = HelixSharding().snapshot()'),
      pyStatus('from services.agent_deploy.oauth import agent_deploy_auth_summary; result = agent_deploy_auth_summary()'),
    ]);

  return {
    prompts,
    tv,
    iot: iot.ok ? iot.data : { total: 0, devices: [] },
    helix,
    mining: {
      status: miningStatus,
      auth: miningFleet.getMiningAuthSummary(),
      rewards: miningFleet.getRewardRoutes(),
    },
    yslr,
    utc,
    astro,
    operators,
    profit,
    magic,
    dune,
    quickbooks: qb,
    neuralMesh: mesh,
    helixSharding: sharding,
    agentDeploy: oauth,
    surfaces: {
      commandCenter: '/command-center',
      arena: '/arena/',
      portal: '/portal/',
      vault: '/dashboard/sovereign-dashboard.html',
      neuralViz: '/dashboard/neural-mesh-viz.html',
    },
  };
}

export default { getPromptRegistry, getSubsystemSnapshots };
