import { Router } from 'express';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export const akashRouter = Router();

const STATE_DIR = join(process.cwd(), '../../.akash-state');
const LEASE_FILE = join(STATE_DIR, 'lease.json');

akashRouter.get('/leases', (_req, res) => {
  if (!existsSync(LEASE_FILE)) {
    res.json({ leases: [], status: 'no_active_lease' });
    return;
  }
  const lease = JSON.parse(readFileSync(LEASE_FILE, 'utf-8'));
  res.json({ leases: [lease], status: 'active' });
});

akashRouter.post('/leases/heal', (_req, res) => {
  res.json({
    action: 'heal_triggered',
    timestamp: new Date().toISOString(),
    services: [
      'api-gateway',
      'odysseus',
      'chromadb',
      'ollama-worker',
      'kairo-identity',
      'payments',
    ],
    status: 'healing',
  });
});

akashRouter.get('/optimizer/status', (_req, res) => {
  res.json({
    agent: 'akash-optimizer',
    status: 'active',
    creditsRemaining: 200,
    activeLeases: existsSync(LEASE_FILE) ? 1 : 0,
    message: 'Monitoring DSEQ, optimizing GPU allocations',
  });
});
