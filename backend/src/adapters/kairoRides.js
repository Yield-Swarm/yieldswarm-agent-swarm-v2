/**
 * In-memory Kairo ride requests (production: persist to Postgres).
 */

import crypto from 'node:crypto';
import { calculateKairoFare } from '../lib/kairoFare.js';

/** @type {Map<string, object>} */
const rides = new Map();

export function createRideRequest(body = {}) {
  const pickup = String(body.pickup || '').trim();
  const dropoff = String(body.dropoff || '').trim();
  const driverId = String(body.driver_id || body.driverId || 'kairo-driver-1').trim();

  if (!pickup || !dropoff) {
    const err = new Error('pickup and dropoff are required');
    err.status = 400;
    throw err;
  }

  const distanceKm = Number(body.distanceKm ?? body.distance_km ?? 0);
  const durationMin = Number(body.durationMin ?? body.duration_min ?? 0);

  if (distanceKm <= 0 && durationMin <= 0) {
    const err = new Error('distanceKm or durationMin required — quote route first');
    err.status = 400;
    throw err;
  }

  const fare = body.fare || calculateKairoFare({ distanceKm, durationMin });
  const id = `ride_${crypto.randomBytes(8).toString('hex')}`;
  const now = new Date().toISOString();

  const ride = {
    id,
    status: 'matching',
    driver_id: driverId,
    pickup,
    dropoff,
    pickup_coords: body.pickup_coords || body.pickupCoords || null,
    dropoff_coords: body.dropoff_coords || body.dropoffCoords || null,
    distance_km: distanceKm,
    duration_min: durationMin,
    fare,
    created_at: now,
    updated_at: now,
  };

  rides.set(id, ride);

  // Simulated match — real implementation assigns nearest Akash worker driver
  setTimeout(() => {
    const current = rides.get(id);
    if (current && current.status === 'matching') {
      current.status = 'driver_en_route';
      current.updated_at = new Date().toISOString();
      current.matched_driver = driverId;
    }
  }, 1500);

  return ride;
}

export function getRide(rideId) {
  const ride = rides.get(rideId);
  if (!ride) {
    const err = new Error('ride not found');
    err.status = 404;
    throw err;
  }
  return ride;
}

export function listRides(limit = 20) {
  return Array.from(rides.values())
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
    .slice(0, limit);
}
