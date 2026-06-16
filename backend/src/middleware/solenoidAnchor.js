/**
 * Helix state-anchor middleware — rate limit + x-helix-state-anchor headers.
 */

import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);
const { solenoidEngine } = require(path.join(repoRoot, 'src', 'infrastructure', 'solenoid-engine.js'));

const RATE_LIMIT = Number(process.env.SOLENOID_RATE_LIMIT || 100);
const RATE_WINDOW_SEC = Number(process.env.SOLENOID_RATE_WINDOW_SEC || 60);

export function solenoidAnchorMiddleware(req, res, next) {
  const identityKey = req.ip || req.headers['x-forwarded-for'] || 'anonymous';

  solenoidEngine
    .enforceRateLimit(identityKey, RATE_LIMIT, RATE_WINDOW_SEC)
    .then((limiterStatus) => {
      if (!limiterStatus.allowed) {
        return res.status(429).json({
          error: 'SOLENOID_RATE_EXCEEDED',
          message: 'Rate allocation limits breached along this solenoid lane.',
        });
      }

      const anchorPayload = solenoidEngine.generateStateAnchor({
        path: req.path,
        method: req.method,
        query: req.query,
      });

      res.setHeader('x-helix-state-anchor', anchorPayload.stateAnchor);
      res.setHeader('x-solenoid-mode', anchorPayload.activeMode);
      res.setHeader('x-dimensional-depth', String(anchorPayload.dimensionLevel));
      req.stateAnchor = anchorPayload.stateAnchor;
      next();
    })
    .catch((err) => {
      console.error('[CRITICAL ROUTE EXCEPTION INTERCEPT]:', err.message);
      next();
    });
}

export { solenoidEngine };
