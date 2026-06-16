import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateKairoFare, KAIRO_CUSTOMER_FEE_PCT, KAIRO_DRIVER_MULTIPLIER } from './kairoFare.js';
import { createRideRequest, getRide } from '../adapters/kairoRides.js';

test('calculateKairoFare applies 1% fee and 2x driver pay', () => {
  const fare = calculateKairoFare({ distanceKm: 10, durationMin: 20 });
  const base = 10 * 1.5 + 20 * 0.25 + 2.5;
  assert.equal(fare.customerFeePct, KAIRO_CUSTOMER_FEE_PCT);
  assert.equal(Number(fare.customerFeeUsd), Number((base * 0.01).toFixed(2)));
  assert.equal(Number(fare.driverAppPayUsd), Number((base * KAIRO_DRIVER_MULTIPLIER).toFixed(2)));
});

test('createRideRequest persists ride with fare', () => {
  const ride = createRideRequest({
    pickup: 'A',
    dropoff: 'B',
    distanceKm: 5,
    durationMin: 10,
    driver_id: 'test-driver',
  });
  assert.ok(ride.id.startsWith('ride_'));
  assert.equal(ride.status, 'matching');
  const loaded = getRide(ride.id);
  assert.equal(loaded.pickup, 'A');
});
