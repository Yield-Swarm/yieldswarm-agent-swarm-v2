import { Router } from 'express';
import { getSubsystemSnapshots, getPromptRegistry } from '../adapters/singlePane.js';

const router = Router();

router.get('/overview', async (_req, res) => {
  try {
    const data = await getSubsystemSnapshots();
    res.json({ ok: true, data, generatedAt: new Date().toISOString() });
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message || 'single pane failed' });
  }
});

router.get('/prompts', async (_req, res) => {
  try {
    const data = await getPromptRegistry();
    res.json({ ok: true, data });
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message || 'prompt registry failed' });
  }
});

export default router;
