import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { kairoRouter } from './routes/kairo.js';
import { mandelbrotRouter } from './routes/mandelbrot.js';
import { odysseusRouter } from './routes/odysseus.js';
import { paymentsRouter } from './routes/payments.js';
import { akashRouter } from './routes/akash.js';
import { telemetryRouter } from './routes/telemetry.js';

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'yieldswarm-api', version: '2.0.0' });
});

app.use('/api/v1/kairo', kairoRouter);
app.use('/api/v1/mandelbrot', mandelbrotRouter);
app.use('/api/v1/odysseus', odysseusRouter);
app.use('/api/v1/payments', paymentsRouter);
app.use('/api/v1/akash', akashRouter);
app.use('/api/v1/telemetry', telemetryRouter);

app.listen(PORT, () => {
  console.log(`YieldSwarm API listening on :${PORT}`);
});

export default app;
