const test = require('node:test');
const assert = require('node:assert/strict');
const { TelemetrySchema } = require('../lib/telemetrySchema');

test('TelemetrySchema accepts valid geomining payload', () => {
  const parsed = TelemetrySchema.parse({
    email: 'ethyswarm@proton.me',
    plan: 'Lite',
    currentBalance: 1250.5,
    geomines: 12,
    geodrops: 3,
    surveys: 1,
    spentGeoclaims: 0.5,
    spentGeodrops: 0.25,
    spentSweepstakes: 0.1,
  });

  assert.equal(parsed.email, 'ethyswarm@proton.me');
  assert.equal(parsed.geomines, 12);
});

test('TelemetrySchema rejects invalid email', () => {
  assert.throws(() => TelemetrySchema.parse({ email: 'not-an-email' }));
});
