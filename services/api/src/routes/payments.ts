import { Router } from 'express';
import {
  processCustomerPayment,
  processDriverEarnings,
  verifySquareWebhook,
  verifyWiseWebhook,
  handleWebhook,
  getUnifiedWallet,
  getDriverEarningsHistory,
  getPaymentStats,
} from '../services/payments.js';

export const paymentsRouter = Router();

paymentsRouter.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'payments', ...getPaymentStats() });
});

paymentsRouter.get('/stats', (_req, res) => {
  res.json(getPaymentStats());
});

paymentsRouter.post('/customer/charge', (req, res) => {
  const { tripId, customerId, baseAmountCents, provider } = req.body;
  if (!tripId || !customerId || !baseAmountCents) {
    res.status(400).json({ error: 'tripId, customerId, baseAmountCents required' });
    return;
  }
  const payment = processCustomerPayment({
    tripId,
    customerId,
    baseAmountCents,
    provider,
  });
  res.status(201).json(payment);
});

paymentsRouter.post('/driver/earnings', (req, res) => {
  const {
    driverId,
    tripId,
    basePayCents,
    instantCashout,
    depinRewardsCents,
    cryptoRewardsCents,
  } = req.body;

  if (!driverId || !tripId || !basePayCents) {
    res.status(400).json({ error: 'driverId, tripId, basePayCents required' });
    return;
  }

  const record = processDriverEarnings({
    driverId,
    tripId,
    basePayCents,
    instantCashout,
    depinRewardsCents,
    cryptoRewardsCents,
  });
  res.status(201).json(record);
});

paymentsRouter.get('/driver/:driverId/wallet', (req, res) => {
  const wallet = getUnifiedWallet(req.params.driverId);
  if (!wallet) {
    res.status(404).json({ error: 'Driver not found' });
    return;
  }
  res.json(wallet);
});

paymentsRouter.get('/driver/:driverId/earnings', (req, res) => {
  res.json(getDriverEarningsHistory(req.params.driverId));
});

paymentsRouter.post('/webhooks/square', (req, res) => {
  const signature = (req.headers['x-square-hmacsha256-signature'] as string) || '';
  const webhookUrl = process.env.SQUARE_WEBHOOK_URL || '';
  const body = JSON.stringify(req.body);
  const verified = verifySquareWebhook(body, signature, webhookUrl);

  const event = handleWebhook(
    'square',
    req.body?.type || 'unknown',
    req.body,
    verified
  );

  res.status(verified ? 200 : 401).json(event);
});

paymentsRouter.post('/webhooks/wise', (req, res) => {
  const signature = (req.headers['x-signature'] as string) || '';
  const body = JSON.stringify(req.body);
  const verified = verifyWiseWebhook(body, signature);

  const event = handleWebhook(
    'wise',
    req.body?.event_type || 'unknown',
    req.body,
    verified
  );

  res.status(verified ? 200 : 401).json(event);
});
